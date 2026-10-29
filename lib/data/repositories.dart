import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthException;
import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthException, PostgrestException, User;
import 'package:url_launcher/url_launcher.dart';

import '../core/helpers.dart';
import '../core/models.dart';
import '../core/supabase_client.dart';

// ============================================================================
// 1. ERROR HANDLING & UTILS
// ============================================================================

class AppException implements Exception {
  final String message;
  const AppException(this.message);

  @override
  String toString() => message;
}

/// Turns any thrown object into a safe, user-friendly message.
String errorText(Object e) {
  if (e is AppException) return e.message;
  if (e is AuthException) return e.message;
  if (e is PostgrestException) {
    if (e.message.contains('duplicate key value')) {
      return 'This record already exists.';
    }
    if (e.message.contains('violates foreign key constraint')) {
      return 'Linked data not found.';
    }
    return 'Database error: ${e.message}';
  }
  if (e is SocketException) return 'No internet connection. Please try again.';

  // Network errors from supabase_flutter arrive as http.ClientException,
  // which wraps the real SocketException. Its message contains the cause
  // ('Failed host lookup', 'Connection refused', etc.), so we match on the
  // string form as well as the concrete type.
  final lower = e.toString().toLowerCase();
  if (lower.contains('socketexception') ||
      lower.contains('clientexception') ||
      lower.contains('failed host lookup') ||
      lower.contains('network is unreachable') ||
      lower.contains('connection refused') ||
      lower.contains('connection reset') ||
      lower.contains('xmlhttprequest error') ||
      lower.contains('no address associated with hostname')) {
    return 'Cannot reach the server. Please check your internet connection and try again.';
  }

  return 'Something went wrong. Please try again.';
}

String get _uid {
  final id = supabase.auth.currentUser?.id;
  if (id == null) {
    throw const AppException('Session expired. Please sign in again.');
  }
  return id;
}

String _generateRequestId() {
  final r = Random();
  return '${DateTime.now().microsecondsSinceEpoch}-${r.nextInt(999999)}';
}

/// Helper class for paginated results.
class PagedResult<T> {
  final List<T> items;
  final bool hasMore;
  final DateTime? lastCursor;

  PagedResult({required this.items, required this.hasMore, this.lastCursor});
}

// ============================================================================
// 2. AUTH & PROFILE SERVICE
// ============================================================================

class AuthService {
  User? get currentUser => supabase.auth.currentUser;
  bool get isSignedIn => currentUser != null;

  Future<void> signIn(String email, String password) async {
    try {
      await supabase.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
    } on AuthException catch (e) {
      throw AppException(e.message);
    } catch (e) {
      // Network / DNS / timeout — surface a friendly message.
      throw AppException(errorText(e));
    }
  }

  Future<void> signUp({
    required String fullName,
    required String email,
    required String password,
  }) async {
    try {
      final res = await supabase.auth.signUp(
        email: email.trim(),
        password: password,
        data: {'full_name': fullName.trim()},
      );

      // FIX: If Supabase doesn't return a session (even with confirm email off),
      // we force a manual login immediately to bypass the loop.
      if (res.session == null) {
        await signIn(email, password);
      }
    } on AuthException catch (e) {
      throw AppException(e.message);
    }
  }

  Future<void> signOut() async {
    await supabase.auth.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  /// Fetches the profile from the database.
  /// Self-heals: if the row is missing, it is created on the fly so the app
  /// never gets stuck on the auth screen after a successful sign-in.
  Future<Profile?> loadProfile() async {
    final user = currentUser;
    if (user == null) return null;

    try {
      // 1. Try DB first
      var row = await supabase
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      // 2. SELF-HEALING: If profile is missing, create it instantly!
      if (row == null) {
        final newProfile = {
          'id': user.id,
          'email': user.email,
          'full_name': user.userMetadata?['full_name'] ?? 'New User',
          'setup_complete': false,
        };
        row = await supabase
            .from('profiles')
            .insert(newProfile)
            .select()
            .single();
      }

      final profile = Profile.fromMap(row);

      // 3. Update local cache
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          'dastak_profile_${user.id}', jsonEncode(profile.toMap()));

      return profile;
    } catch (e) {
      // Fallback to cache if offline
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('dastak_profile_${user.id}');
      if (raw != null) {
        try {
          return Profile.fromMap(jsonDecode(raw) as Map<String, dynamic>);
        } catch (_) {}
      }
      throw AppException(errorText(e));
    }
  }

  // --- V2 Setup RPCs ---

  Future<void> createSociety({
    required String societyName,
    required String joinCode,
    required String guardCode,
  }) async {
    try {
      await supabase.rpc('create_society', params: {
        'p_name': societyName,
        'p_join_code': joinCode,
        'p_guard_code': guardCode,
      });
    } catch (e) {
      throw AppException(errorText(e));
    }
  }

  Future<void> joinSociety({
    required String joinCode,
    required String phone,
  }) async {
    try {
      final societyId = await supabase
          .from('societies')
          .select('id')
          .eq('join_code', joinCode)
          .maybeSingle();

      if (societyId == null) {
        throw const AppException('Invalid society join code.');
      }

      await supabase.from('profiles').update({
        'role': UserRole.resident.name,
        'society_id': societyId['id'],
        'phone': phone,
        'setup_complete': true,
      }).eq('id', _uid);
    } catch (e) {
      throw AppException(errorText(e));
    }
  }

  Future<void> joinAsGuard({
    required String guardCode,
    required String gateName,
    required bool isEventGuard,
    String? phone,
  }) async {
    try {
      await supabase.rpc('join_as_guard', params: {
        'p_code': guardCode,
        'p_gate_name': gateName,
        'p_is_event': isEventGuard,
      });
      if (phone != null) {
        await supabase.from('profiles').update({'phone': phone}).eq('id', _uid);
      }
    } catch (e) {
      throw AppException(errorText(e));
    }
  }

  Future<void> completeOrganizerSetup({required String phone}) async {
    try {
      await supabase.from('profiles').update({
        'role': UserRole.organizer.name,
        'phone': phone,
        'setup_complete': true,
      }).eq('id', _uid);
    } catch (e) {
      throw AppException(errorText(e));
    }
  }
}

// ============================================================================
// 3. PASS SERVICE (Visitor & Event)
// ============================================================================

class PassService {
  /// Uploads a photo to Supabase Storage and returns the file path.
  Future<String?> _uploadPhoto(Uint8List? bytes, String userId) async {
    if (bytes == null) return null;
    final fileName = '${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    await supabase.storage.from('pass-photos').uploadBinary(fileName, bytes);
    return fileName;
  }

  /// Generates a signed URL for viewing photos (expires in 1 hour).
  Future<String?> getPhotoUrl(String? path) async {
    if (path == null) return null;
    try {
      return await supabase.storage
          .from('pass-photos')
          .createSignedUrl(path, 3600);
    } catch (_) {
      return null;
    }
  }

  Future<Pass> createPass(Pass pass,
      {Uint8List? photoBytes, Uint8List? thumbBytes}) async {
    try {
      final userId = _uid;

      final photoPath = await _uploadPhoto(photoBytes, userId);
      final thumbPath = await _uploadPhoto(thumbBytes, userId);

      final payload = pass
          .copyWith(
            createdBy: userId,
            photoPath: photoPath,
            photoThumbPath: thumbPath,
          )
          .toMap();

      final row =
          await supabase.from('passes').insert(payload).select().single();
      return Pass.fromMap(row);
    } catch (e) {
      throw AppException(errorText(e));
    }
  }

  /// Bulk insert with chunking to avoid payload size limits.
  Future<List<Pass>> createManyForEvent(List<Pass> passes) async {
    if (passes.isEmpty) return [];
    final inserted = <Pass>[];
    const chunkSize = 100;

    try {
      for (var i = 0; i < passes.length; i += chunkSize) {
        final end =
            (i + chunkSize < passes.length) ? i + chunkSize : passes.length;
        final chunk = passes
            .sublist(i, end)
            .map((p) => p.copyWith(createdBy: _uid).toMap())
            .toList();

        final rows = await supabase.from('passes').insert(chunk).select();
        inserted.addAll(rows.map((r) => Pass.fromMap(r)));
      }
      return inserted;
    } catch (e) {
      throw AppException('Failed during bulk import: ${errorText(e)}');
    }
  }

  /// Cursor-based pagination for resident passes (newest first).
  Future<PagedResult<Pass>> listMyPasses(
      {DateTime? cursor, int limit = 30}) async {
    try {
      var query = supabase
          .from('passes')
          .select()
          .eq('kind', PassKind.visitor.name)
          .eq('created_by', _uid);

      if (cursor != null) {
        query = query.lt('created_at', cursor.toUtc().toIso8601String());
      }

      final rows =
          await query.order('created_at', ascending: false).limit(limit + 1);

      final hasMore = rows.length > limit;
      final items = hasMore ? rows.sublist(0, limit) : rows;
      final lastCursor =
          items.isNotEmpty ? DateTime.parse(items.last['created_at']) : null;

      return PagedResult(
        items: items.map((r) => Pass.fromMap(r)).toList(),
        hasMore: hasMore,
        lastCursor: lastCursor,
      );
    } catch (e) {
      throw AppException(errorText(e));
    }
  }

  Future<Pass?> getPass(String id) async {
    final clean = id.trim();
    if (clean.isEmpty) return null;
    try {
      final row =
          await supabase.from('passes').select().eq('id', clean).maybeSingle();
      return row != null ? Pass.fromMap(row) : null;
    } catch (e) {
      return null; // network failure → UI shows "Unavailable"
    }
  }

  Future<void> revokePass(String id) async {
    try {
      await supabase.from('passes').update({
        'status': PassStatus.revoked.name,
        'revoked_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', id);
    } catch (e) {
      throw AppException(errorText(e));
    }
  }
}

// ============================================================================
// 4. EVENT SERVICE (Organizer)
// ============================================================================

class EventService {
  Future<Event> createEvent(Event event) async {
    try {
      final row = await supabase
          .from('events')
          .insert(event.copyWith(organizerId: _uid).toMap())
          .select()
          .single();
      return Event.fromMap(row);
    } catch (e) {
      throw AppException(errorText(e));
    }
  }

  Future<Event> updateEvent(Event event) async {
    try {
      final map = event.toMap()..remove('id');
      final row = await supabase
          .from('events')
          .update(map)
          .eq('id', event.id)
          .select()
          .single();
      return Event.fromMap(row);
    } catch (e) {
      throw AppException(errorText(e));
    }
  }

  Future<void> deleteEvent(String id) async {
    try {
      await supabase.from('events').delete().eq('id', id);
    } catch (e) {
      throw AppException(errorText(e));
    }
  }

  /// Cursor pagination for the organizer's events (soonest first).
  Future<PagedResult<Event>> listMyEvents(
      {DateTime? cursor, int limit = 20}) async {
    try {
      var query = supabase.from('events').select().eq('organizer_id', _uid);

      if (cursor != null) {
        query = query.gt('start_at', cursor.toUtc().toIso8601String());
      }

      final rows =
          await query.order('start_at', ascending: true).limit(limit + 1);

      final hasMore = rows.length > limit;
      final items = hasMore ? rows.sublist(0, limit) : rows;
      final lastCursor =
          items.isNotEmpty ? DateTime.parse(items.last['start_at']) : null;

      return PagedResult(
        items: items.map((r) => Event.fromMap(r)).toList(),
        hasMore: hasMore,
        lastCursor: lastCursor,
      );
    } catch (e) {
      throw AppException(errorText(e));
    }
  }

  /// Fetches event stats (Total, Checked-in, Pending) via RPC.
  Future<Map<String, int>> getEventStats(String eventId) async {
    try {
      final res =
          await supabase.rpc('event_stats', params: {'p_event_id': eventId});
      final data = res as Map<String, dynamic>;
      return {
        'total': data['total'] as int? ?? 0,
        'checked_in': data['checked_in'] as int? ?? 0,
        'pending': data['pending'] as int? ?? 0,
      };
    } catch (e) {
      return {'total': 0, 'checked_in': 0, 'pending': 0};
    }
  }

  /// Re-issues a pass by rotating its QR token in the DB.
  Future<void> reissuePass(String passId) async {
    try {
      await supabase.rpc('reissue_pass', params: {
        'p_pass_id': passId,
        'p_organizer_id': _uid,
      });
    } catch (e) {
      throw AppException(errorText(e));
    }
  }
}

// ============================================================================
// 5. SCAN SERVICE (Guard)
// ============================================================================

enum LookupStatus { found, notFound, unavailable }

class LookupResult {
  final LookupStatus status;
  final Pass? pass;
  final String? errorMessage;

  LookupResult({required this.status, this.pass, this.errorMessage});
}

class ScanService {
  /// Looks up a pass by scanned code.
  Future<LookupResult> lookupPass(String code) async {
    // Expected format: dastak:<pass_id>:<qr_token>
    final parts = code.split(':');
    if (parts.length != 3 || parts[0] != 'dastak') {
      return LookupResult(status: LookupStatus.notFound);
    }

    final passId = parts[1];
    final qrToken = parts[2];

    try {
      final row =
          await supabase.from('passes').select().eq('id', passId).maybeSingle();
      if (row == null) return LookupResult(status: LookupStatus.notFound);

      final pass = Pass.fromMap(row);
      if (pass.qrToken != qrToken) {
        return LookupResult(status: LookupStatus.notFound);
      }

      return LookupResult(status: LookupStatus.found, pass: pass);
    } catch (e) {
      return LookupResult(
          status: LookupStatus.unavailable, errorMessage: errorText(e));
    }
  }

  /// Returns a human reason if the pass must NOT be allowed in, else null.
  String? entryBlockReason(Pass pass) {
    switch (pass.effectiveStatus) {
      case PassStatus.revoked:
        return 'This pass was revoked.';
      case PassStatus.expired:
        return 'This pass has expired.';
      case PassStatus.used:
        return 'This pass was already used.';
      case PassStatus.active:
        break;
    }

    if (pass.notYetValid) {
      return 'Pass is not valid yet (starts ${formatDateTime(pass.validFrom!)})';
    }
    return null;
  }

  /// Records the guard's decision atomically via RPC.
  Future<void> recordScan({
    required Pass pass,
    required ScanResult result,
    String? reason,
    String? gateName,
  }) async {
    try {
      await supabase.rpc('record_scan', params: {
        'p_pass_id': pass.id,
        'p_result': result.name,
        'p_reason': reason,
        'p_gate_name': gateName,
        'p_request_id': _generateRequestId(),
      });
    } catch (e) {
      throw AppException('Failed to record scan: ${errorText(e)}');
    }
  }

  /// Fetches recent scans for the guard's gate/society.
  Future<List<ScanRecord>> recentScans({int limit = 30}) async {
    try {
      final profile = await authService.loadProfile();
      if (profile == null) return [];

      var query = supabase
          .from('scans')
          .select('*, passes(visitor_name, visitor_type)');

      if (profile.societyId != null) {
        query = query.eq('society_id', profile.societyId!);
      } else if (profile.eventId != null) {
        query = query.eq('event_id', profile.eventId!);
      } else {
        query = query.eq('scanned_by', _uid);
      }

      final rows =
          await query.order('scanned_at', ascending: false).limit(limit);
      return rows.map((r) => ScanRecord.fromMap(r)).toList();
    } catch (e) {
      return [];
    }
  }
}

// ============================================================================
// 6. SHARE SERVICE
// ============================================================================

class ShareService {
  /// Renders the QR (pass id + token) to a PNG in memory.
  Future<Uint8List> qrPng(String data, {double size = 800}) async {
    const black = ui.Color(0xFF1A1A1A);
    const white = ui.Color(0xFFFFFFFF);
    const pad = 64.0;
    const radius = 32.0;

    final painter = QrPainter(
      data: data,
      version: QrVersions.auto,
      errorCorrectionLevel: QrErrorCorrectLevel.H,
      gapless: true,
      eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: black),
      dataModuleStyle: const QrDataModuleStyle(
          dataModuleShape: QrDataModuleShape.square, color: black),
    );

    final total = size + (pad * 2);
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);

    final bgPaint = ui.Paint()..color = white;
    final rect = ui.Rect.fromLTWH(0, 0, total, total);
    canvas.drawRRect(
        ui.RRect.fromRectAndRadius(rect, const ui.Radius.circular(radius)),
        bgPaint);

    canvas.translate(pad, pad);
    painter.paint(canvas, ui.Size(size, size));

    final image =
        await recorder.endRecording().toImage(total.toInt(), total.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return bytes!.buffer.asUint8List();
  }

  String caption(Pass pass, {String? eventName}) {
    final b = StringBuffer();
    if (pass.kind == PassKind.event) {
      b.writeln(
          '✨ Dastak Event Pass ${eventName != null ? '- $eventName' : ''}');
      b.writeln('Name: ${pass.visitorName}');
      b.writeln('Type: ${pass.visitorType ?? 'Guest'}');
      if (pass.company != null) b.writeln('Company: ${pass.company}');
    } else {
      b.writeln('🚪 Dastak Visitor Pass');
      b.writeln('Name: ${pass.visitorName}');
      if (pass.apartment != null) b.writeln('Visiting: ${pass.apartment}');
      if (pass.vehicle != null) b.writeln('Vehicle: ${pass.vehicle}');
    }

    if (pass.recurrenceDays.isNotEmpty) {
      b.writeln(
          'Schedule: ${formatRecurrenceSchedule(pass.recurrenceDays, pass.windowStart, pass.windowEnd)}');
    } else {
      b.writeln('Valid: ${formatRange(pass.validFrom, pass.validUntil)}');
    }

    b.writeln('Show the QR code at the gate.');
    return b.toString();
  }

  Future<void> sharePass(Pass pass, {String? eventName}) async {
    final png = await qrPng(pass.qrData);
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/dastak_pass_${pass.id}.png');
    await file.writeAsBytes(png, flush: true);

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'image/png')],
      text: caption(pass, eventName: eventName),
      subject: 'Dastak Pass',
    );
  }

  Future<bool> openWhatsApp(Pass pass, {String? eventName}) async {
    final phone = normalizePhone(pass.visitorPhone);
    if (phone == null) return false;

    final text = Uri.encodeComponent(caption(pass, eventName: eventName));
    final uri = Uri.parse('https://wa.me/$phone?text=$text');
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  Future<bool> openEmail(Pass pass, {String? eventName}) async {
    final email = pass.visitorEmail;
    if (email == null) return false;

    final body =
        '${caption(pass, eventName: eventName)}\n\nPlease show the QR code (shared separately) or this Pass ID at the gate: ${pass.id}';
    final uri = Uri.parse(
        'mailto:$email?subject=${Uri.encodeComponent('Dastak Pass')}&body=${Uri.encodeComponent(body)}');
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}

// ============================================================================
// 7. SINGLETON INSTANCES
// ============================================================================

final AuthService authService = AuthService();
final PassService passService = PassService();
final EventService eventService = EventService();
final ScanService scanService = ScanService();
final ShareService shareService = ShareService();
