// Pure Dart models. No Flutter imports.
// This file is the source of truth for all data structures in Dastak V2.

import 'dart:convert';

// ============================================================================
// ENUMS & EXTENSIONS
// ============================================================================

enum UserRole { resident, organizer, guard, admin }

extension UserRoleX on UserRole {
  String get label {
    switch (this) {
      case UserRole.resident:
        return 'Resident';
      case UserRole.organizer:
        return 'Organizer';
      case UserRole.guard:
        return 'Guard';
      case UserRole.admin:
        return 'Society Admin';
    }
  }
}

enum PassKind { visitor, event }

enum PassStatus { active, used, expired, revoked }

extension PassStatusX on PassStatus {
  String get label {
    switch (this) {
      case PassStatus.active:
        return 'Active';
      case PassStatus.used:
        return 'Used';
      case PassStatus.expired:
        return 'Expired';
      case PassStatus.revoked:
        return 'Revoked';
    }
  }
}

enum ScanResult { allowed, rejected }

extension ScanResultX on ScanResult {
  String get label => this == ScanResult.allowed ? 'Allowed' : 'Rejected';
}

enum ProfileStatus { active, revoked }

// ============================================================================
// PARSING HELPERS
// ============================================================================

T _enumFrom<T extends Enum>(List<T> values, String? name, T fallback) {
  for (final v in values) {
    if (v.name == name) return v;
  }
  return fallback;
}

DateTime? _dt(dynamic v) {
  if (v == null) return null;
  return DateTime.tryParse(v.toString())?.toLocal();
}

String? _s(dynamic v) {
  if (v == null) return null;
  final s = v.toString().trim();
  return s.isEmpty ? null : s;
}

int _i(dynamic v, [int fallback = 0]) {
  if (v is int) return v;
  return int.tryParse('$v') ?? fallback;
}

bool _b(dynamic v, [bool fallback = false]) {
  if (v is bool) return v;
  return fallback;
}

String? _iso(DateTime? d) => d?.toUtc().toIso8601String();

List<int> _intList(dynamic v) {
  if (v == null) return [];
  if (v is List) return v.map((e) => _i(e)).toList();
  return [];
}

// ============================================================================
// 1. SOCIETY & PROFILE
// ============================================================================

class Society {
  final String id;
  final String name;
  final String joinCode;
  final String guardCode;
  final String? adminId;

  const Society({
    required this.id,
    required this.name,
    required this.joinCode,
    required this.guardCode,
    this.adminId,
  });

  factory Society.fromMap(Map<String, dynamic> m) {
    return Society(
      id: _s(m['id']) ?? '',
      name: _s(m['name']) ?? 'Unknown Society',
      joinCode: _s(m['join_code']) ?? '',
      guardCode: _s(m['guard_code']) ?? '',
      adminId: _s(m['admin_id']),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'join_code': joinCode,
        'guard_code': guardCode,
        'admin_id': adminId,
      };
}

class Profile {
  final String id;
  final String email;
  final String? fullName;
  final UserRole? role;
  final String? societyId;
  final String? eventId;
  final String? gateName;
  final String? phone;
  final ProfileStatus status;
  final bool setupComplete;

  const Profile({
    required this.id,
    required this.email,
    this.fullName,
    this.role,
    this.societyId,
    this.eventId,
    this.gateName,
    this.phone,
    this.status = ProfileStatus.active,
    this.setupComplete = false,
  });

  bool get isSetupComplete {
    if (role == null || !setupComplete) return false;
    switch (role!) {
      case UserRole.resident:
        return societyId != null;
      case UserRole.guard:
        return gateName != null && (societyId != null || eventId != null);
      case UserRole.admin:
        return societyId != null;
      case UserRole.organizer:
        return true;
    }
  }

  String get initials {
    if (fullName == null || fullName!.isEmpty) return 'U';
    final parts = fullName!.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  Profile copyWith({
    String? fullName,
    UserRole? role,
    String? societyId,
    String? eventId,
    String? gateName,
    String? phone,
    ProfileStatus? status,
    bool? setupComplete,
  }) {
    return Profile(
      id: id,
      email: email,
      fullName: fullName ?? this.fullName,
      role: role ?? this.role,
      societyId: societyId ?? this.societyId,
      eventId: eventId ?? this.eventId,
      gateName: gateName ?? this.gateName,
      phone: phone ?? this.phone,
      status: status ?? this.status,
      setupComplete: setupComplete ?? this.setupComplete,
    );
  }

  factory Profile.fromMap(Map<String, dynamic> m) {
    final roleName = _s(m['role']);
    return Profile(
      id: _s(m['id']) ?? '',
      email: _s(m['email']) ?? '',
      fullName: _s(m['full_name']),
      role: roleName == null
          ? null
          : _enumFrom(UserRole.values, roleName, UserRole.resident),
      societyId: _s(m['society_id']),
      eventId: _s(m['event_id']),
      gateName: _s(m['gate_name']),
      phone: _s(m['phone']),
      status: _enumFrom(
          ProfileStatus.values, _s(m['status']), ProfileStatus.active),
      setupComplete: _b(m['setup_complete']),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'email': email,
        'full_name': fullName,
        'role': role?.name,
        'society_id': societyId,
        'event_id': eventId,
        'gate_name': gateName,
        'phone': phone,
        'status': status.name,
        'setup_complete': setupComplete,
      };
}

// ============================================================================
// 2. EVENTS (Organizer)
// ============================================================================

class Event {
  final String id;
  final String organizerId;
  final String name;
  final String eventType;
  final String guardCode;
  final List<String> gates;
  final DateTime startAt;
  final DateTime? endAt;
  final String? venueName;
  final String? address;
  final bool isActive;
  final DateTime? createdAt;

  const Event({
    required this.id,
    required this.organizerId,
    required this.name,
    required this.eventType,
    required this.guardCode,
    required this.gates,
    required this.startAt,
    this.endAt,
    this.venueName,
    this.address,
    this.isActive = true,
    this.createdAt,
  });

  bool get isPast {
    final end = endAt ?? startAt.add(const Duration(hours: 6));
    return end.isBefore(DateTime.now());
  }

  // ── NEW: needed by EventService.createEvent ──
  Event copyWith({
    String? organizerId,
  }) {
    return Event(
      id: id,
      organizerId: organizerId ?? this.organizerId,
      name: name,
      eventType: eventType,
      guardCode: guardCode,
      gates: gates,
      startAt: startAt,
      endAt: endAt,
      venueName: venueName,
      address: address,
      isActive: isActive,
      createdAt: createdAt,
    );
  }

  factory Event.fromMap(Map<String, dynamic> m) {
    return Event(
      id: _s(m['id']) ?? '',
      organizerId: _s(m['organizer_id']) ?? '',
      name: _s(m['name']) ?? 'Untitled Event',
      eventType: _s(m['event_type']) ?? 'Other',
      guardCode: _s(m['guard_code']) ?? '',
      gates:
          (m['gates'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
              ['Main Entrance'],
      startAt: _dt(m['start_at']) ?? DateTime.now(),
      endAt: _dt(m['end_at']),
      venueName: _s(m['venue_name']),
      address: _s(m['address']),
      isActive: _b(m['is_active'], true),
      createdAt: _dt(m['created_at']),
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'organizer_id': organizerId,
      'name': name,
      'event_type': eventType,
      'guard_code': guardCode,
      'gates': gates,
      'start_at': _iso(startAt),
      'end_at': _iso(endAt),
      'venue_name': venueName,
      'address': address,
      'is_active': isActive,
    };
    if (id.isNotEmpty) map['id'] = id;
    return map;
  }
}

// ============================================================================
// 3. PASSES (Visitor & Event)
// ============================================================================

class Pass {
  final String id;
  final PassKind kind;
  final String qrToken;
  final String visitorName;
  final String? visitorPhone;
  final String? visitorEmail;
  final String? visitorType;
  final String? company;
  final int visitorCount;
  final String? vehicle;
  final String? apartment;
  final String? purpose;

  final String? photoPath;
  final String? photoThumbPath;

  final String? eventId;
  final String? societyId;
  final String createdBy;

  final DateTime? validFrom;
  final DateTime? validUntil;
  final bool multipleEntries;
  final int entriesUsed;

  final List<int> recurrenceDays;
  final String? windowStart;
  final String? windowEnd;

  final PassStatus status;
  final DateTime? createdAt;
  final DateTime? revokedAt;

  const Pass({
    required this.id,
    this.kind = PassKind.visitor,
    required this.qrToken,
    required this.visitorName,
    this.visitorPhone,
    this.visitorEmail,
    this.visitorType = 'Guest',
    this.company,
    this.visitorCount = 1,
    this.vehicle,
    this.apartment,
    this.purpose,
    this.photoPath,
    this.photoThumbPath,
    this.eventId,
    this.societyId,
    required this.createdBy,
    this.validFrom,
    this.validUntil,
    this.multipleEntries = false,
    this.entriesUsed = 0,
    this.recurrenceDays = const [],
    this.windowStart,
    this.windowEnd,
    this.status = PassStatus.active,
    this.createdAt,
    this.revokedAt,
  });

  PassStatus get effectiveStatus {
    if (status == PassStatus.revoked || revokedAt != null) {
      return PassStatus.revoked;
    }
    if (status == PassStatus.expired) return PassStatus.expired;

    if (validUntil != null && validUntil!.isBefore(DateTime.now())) {
      return PassStatus.expired;
    }

    if (recurrenceDays.isNotEmpty) {
      final now = DateTime.now();
      if (!recurrenceDays.contains(now.weekday)) return PassStatus.expired;

      if (windowStart != null && windowEnd != null) {
        final currentTime =
            '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:00';
        if (currentTime.compareTo(windowStart!) < 0 ||
            currentTime.compareTo(windowEnd!) > 0) {
          return PassStatus.expired;
        }
      }
    }

    if (!multipleEntries && entriesUsed > 0) return PassStatus.used;
    return PassStatus.active;
  }

  bool get notYetValid =>
      validFrom != null && validFrom!.isAfter(DateTime.now());

  String get typeLabel {
    if (kind == PassKind.event) return 'Event Attendee';
    if (company != null) return '$visitorType · $company';
    return visitorType ?? 'Guest';
  }

  String get qrData => 'dastak:${id}:$qrToken';

  factory Pass.fromMap(Map<String, dynamic> m) {
    return Pass(
      id: _s(m['id']) ?? '',
      kind: _enumFrom(PassKind.values, _s(m['kind']), PassKind.visitor),
      qrToken: _s(m['qr_token']) ?? '',
      visitorName: _s(m['visitor_name']) ?? 'Guest',
      visitorPhone: _s(m['visitor_phone']),
      visitorEmail: _s(m['visitor_email']),
      visitorType: _s(m['visitor_type']) ?? 'Guest',
      company: _s(m['company']),
      visitorCount: _i(m['visitor_count'], 1),
      vehicle: _s(m['vehicle']),
      apartment: _s(m['apartment']),
      purpose: _s(m['purpose']),
      photoPath: _s(m['photo_path']),
      photoThumbPath: _s(m['photo_thumb_path']),
      eventId: _s(m['event_id']),
      societyId: _s(m['society_id']),
      createdBy: _s(m['created_by']) ?? '',
      validFrom: _dt(m['valid_from']),
      validUntil: _dt(m['valid_until']),
      multipleEntries: _b(m['multiple_entries']),
      entriesUsed: _i(m['entries_used']),
      recurrenceDays: _intList(m['recurrence_days']),
      windowStart: _s(m['window_start']),
      windowEnd: _s(m['window_end']),
      status: _enumFrom(PassStatus.values, _s(m['status']), PassStatus.active),
      createdAt: _dt(m['created_at']),
      revokedAt: _dt(m['revoked_at']),
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'kind': kind.name,
      'qr_token': qrToken,
      'visitor_name': visitorName,
      'visitor_phone': visitorPhone,
      'visitor_email': visitorEmail,
      'visitor_type': visitorType,
      'company': company,
      'visitor_count': visitorCount,
      'vehicle': vehicle,
      'apartment': apartment,
      'purpose': purpose,
      'photo_path': photoPath,
      'photo_thumb_path': photoThumbPath,
      'event_id': eventId,
      'society_id': societyId,
      'created_by': createdBy,
      'valid_from': _iso(validFrom),
      'valid_until': _iso(validUntil),
      'multiple_entries': multipleEntries,
      'entries_used': entriesUsed,
      'recurrence_days': recurrenceDays.isEmpty ? null : recurrenceDays,
      'window_start': windowStart,
      'window_end': windowEnd,
      'status': status.name,
    };
    if (id.isNotEmpty) map['id'] = id;
    return map;
  }

  Pass copyWith({
    String? id,
    String? qrToken,
    String? createdBy,
    String? photoPath,
    String? photoThumbPath,
    PassStatus? status,
    int? entriesUsed,
  }) {
    return Pass(
      id: id ?? this.id,
      kind: kind,
      qrToken: qrToken ?? this.qrToken,
      visitorName: visitorName,
      visitorPhone: visitorPhone,
      visitorEmail: visitorEmail,
      visitorType: visitorType,
      company: company,
      visitorCount: visitorCount,
      vehicle: vehicle,
      apartment: apartment,
      purpose: purpose,
      photoPath: photoPath ?? this.photoPath,
      photoThumbPath: photoThumbPath ?? this.photoThumbPath,
      eventId: eventId,
      societyId: societyId,
      createdBy: createdBy ?? this.createdBy,
      validFrom: validFrom,
      validUntil: validUntil,
      multipleEntries: multipleEntries,
      entriesUsed: entriesUsed ?? this.entriesUsed,
      recurrenceDays: recurrenceDays,
      windowStart: windowStart,
      windowEnd: windowEnd,
      status: status ?? this.status,
      createdAt: createdAt,
      revokedAt: revokedAt,
    );
  }
}

// ============================================================================
// 4. SCAN RECORDS
// ============================================================================

class ScanRecord {
  final String id;
  final String passId;
  final String scannedBy;
  final String? societyId;
  final String? eventId;
  final String? gateName;
  final ScanResult result;
  final String? reason;
  final String requestId;
  final DateTime scannedAt;

  final String? visitorName;
  final String? visitorType;

  const ScanRecord({
    required this.id,
    required this.passId,
    required this.scannedBy,
    this.societyId,
    this.eventId,
    this.gateName,
    required this.result,
    this.reason,
    required this.requestId,
    required this.scannedAt,
    this.visitorName,
    this.visitorType,
  });

  factory ScanRecord.fromMap(Map<String, dynamic> m) {
    final joined = m['passes'] as Map<String, dynamic>?;
    return ScanRecord(
      id: _s(m['id']) ?? '',
      passId: _s(m['pass_id']) ?? '',
      scannedBy: _s(m['scanned_by']) ?? '',
      societyId: _s(m['society_id']),
      eventId: _s(m['event_id']),
      gateName: _s(m['gate_name']),
      result:
          _enumFrom(ScanResult.values, _s(m['result']), ScanResult.rejected),
      reason: _s(m['reason']),
      requestId: _s(m['request_id']) ?? '',
      scannedAt: _dt(m['scanned_at']) ?? DateTime.now(),
      visitorName: joined != null ? _s(joined['visitor_name']) : null,
      visitorType: joined != null ? _s(joined['visitor_type']) : null,
    );
  }

  Map<String, dynamic> toMap() => {
        'pass_id': passId,
        'scanned_by': scannedBy,
        'society_id': societyId,
        'event_id': eventId,
        'gate_name': gateName,
        'result': result.name,
        'reason': reason,
        'request_id': requestId,
      };
}
