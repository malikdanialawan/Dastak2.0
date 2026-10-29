import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

import 'constants.dart';

// ============================================================================
// 1. RANDOM EXAMPLE DATA (For rotating placeholders)
// ============================================================================

final Random _rng = Random();

T randomOf<T>(List<T> items) => items[_rng.nextInt(items.length)];

String sampleName({bool? female}) {
  final isFemale = female ?? _rng.nextBool();
  final first = randomOf(isFemale ? kFemaleFirstNames : kMaleFirstNames);
  return '$first ${randomOf(kSurnames)}';
}

String samplePhone() {
  final tail = List.generate(7, (_) => _rng.nextInt(10)).join();
  return '${randomOf(kOperatorPrefixes)}$tail';
}

String sampleEmail(String name) {
  final clean = name
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z ]'), '')
      .replaceAll(' ', '.');
  return '$clean@example.com';
}

// ============================================================================
// 2. DATE / TIME FORMATTING (Premium & Recurring)
// ============================================================================

const List<String> _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String formatDate(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

String formatTime(DateTime d) {
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final m = d.minute.toString().padLeft(2, '0');
  final ap = d.hour >= 12 ? 'PM' : 'AM';
  return '$h:$m $ap';
}

String formatDateTime(DateTime d) => '${formatDate(d)}, ${formatTime(d)}';

/// Formats a time string (e.g., '14:30:00') into '02:30 PM'
String formatTimeString(String? timeStr) {
  if (timeStr == null || timeStr.isEmpty) return '';
  try {
    final parts = timeStr.split(':');
    final h = int.parse(parts[0]);
    final m = int.parse(parts[1]);
    final dt = DateTime(2000, 1, 1, h, m);
    return formatTime(dt);
  } catch (_) {
    return timeStr;
  }
}

String formatRange(DateTime? from, DateTime? to) {
  if (from == null && to == null) return 'No time limit';
  if (from == null) return 'Until ${formatDateTime(to!)}';
  if (to == null) return 'From ${formatDateTime(from)}';
  final sameDay =
      from.year == to.year && from.month == to.month && from.day == to.day;
  if (sameDay) {
    return '${formatDate(from)} (${formatTime(from)} - ${formatTime(to)})';
  }
  return '${formatDateTime(from)} - ${formatDateTime(to)}';
}

/// Specifically formats the recurrence schedule for UI display
String formatRecurrenceSchedule(List<int> days, String? start, String? end) {
  if (days.isEmpty) return 'One-time pass';

  String dayStr = '';
  if (days.length == 7) {
    dayStr = 'Every day';
  } else if (days.length == 5 && !days.contains(6) && !days.contains(7)) {
    dayStr = 'Weekdays';
  } else if (days.length == 2 && days.contains(6) && days.contains(7)) {
    dayStr = 'Weekends';
  } else {
    final sorted = List<int>.from(days)..sort();
    dayStr = sorted.map((d) => kRecurrenceDays[d] ?? '').join(', ');
  }

  if (start != null && end != null) {
    return '$dayStr · ${formatTimeString(start)} - ${formatTimeString(end)}';
  }
  return dayStr;
}

String timeAgo(DateTime d) {
  final diff = DateTime.now().difference(d);
  if (diff.inSeconds < 60) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) return '${diff.inHours} hr ago';
  if (diff.inDays < 7) return '${diff.inDays} d ago';
  return formatDate(d);
}

Future<DateTime?> pickDateTime(
  BuildContext context, {
  DateTime? initial,
  DateTime? firstDate,
  DateTime? lastDate,
}) async {
  final now = DateTime.now();
  final init = initial ?? now;
  final first = firstDate ?? DateTime(now.year - 1);
  final last = lastDate ?? DateTime(now.year + 5);

  final date = await showDatePicker(
    context: context,
    initialDate: init,
    firstDate: first,
    lastDate: last,
  );
  if (date == null || !context.mounted) return null;

  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(init),
  );
  if (time == null) return null;

  return DateTime(date.year, date.month, date.day, time.hour, time.minute);
}

// ============================================================================
// 3. CSV PARSER (Organizer Bulk Import)
// ============================================================================

/// A lightweight, dependency-free CSV parser.
/// Handles quoted values (e.g., "Smith, John") and splits rows safely.
List<Map<String, String>> parseCsv(String csvContent) {
  final lines = <List<String>>[];
  var currentRow = <String>[];
  var currentField = StringBuffer();
  bool inQuotes = false;

  for (int i = 0; i < csvContent.length; i++) {
    final char = csvContent[i];

    if (char == '"') {
      if (inQuotes && i + 1 < csvContent.length && csvContent[i + 1] == '"') {
        // Escaped quote
        currentField.write('"');
        i++; // Skip next quote
      } else {
        inQuotes = !inQuotes;
      }
    } else if (char == ',' && !inQuotes) {
      currentRow.add(currentField.toString().trim());
      currentField.clear();
    } else if ((char == '\n' || char == '\r') && !inQuotes) {
      if (char == '\r' &&
          i + 1 < csvContent.length &&
          csvContent[i + 1] == '\n') {
        i++; // Skip \n after \r
      }
      currentRow.add(currentField.toString().trim());
      currentField.clear();
      if (currentRow.any((f) => f.isNotEmpty)) {
        lines.add(currentRow);
      }
      currentRow = <String>[];
    } else {
      currentField.write(char);
    }
  }

  // Add the last field/row if the file doesn't end with a newline
  if (currentField.isNotEmpty || currentRow.isNotEmpty) {
    currentRow.add(currentField.toString().trim());
    if (currentRow.any((f) => f.isNotEmpty)) {
      lines.add(currentRow);
    }
  }

  if (lines.isEmpty) return [];

  // Assume first row is headers
  final headers = lines.first.map((h) => h.toLowerCase()).toList();
  final results = <Map<String, String>>[];

  for (int i = 1; i < lines.length; i++) {
    final row = lines[i];
    final map = <String, String>{};
    for (int j = 0; j < headers.length; j++) {
      if (j < row.length) {
        map[headers[j]] = row[j];
      }
    }
    results.add(map);
  }

  return results;
}

// ============================================================================
// 4. PHONE & TEXT FORMATTING
// ============================================================================

String? normalizePhone(String? raw) {
  if (raw == null) return null;
  var d = raw.replaceAll(RegExp(r'[^0-9]'), '');
  if (d.isEmpty) return null;
  if (d.startsWith('0092')) {
    d = d.substring(2);
  } else if (d.startsWith('92') && d.length >= 12) {
    // already international
  } else if (d.startsWith('0')) {
    d = '92${d.substring(1)}';
  } else if (d.startsWith('3') && d.length == 10) {
    d = '92$d';
  }
  return d;
}

String prettyPhone(String? raw) {
  final d = normalizePhone(raw);
  if (d == null) return 'N/A';
  if (d.startsWith('92') && d.length == 12) {
    return '+92 ${d.substring(2, 5)} ${d.substring(5)}';
  }
  return '+$d';
}

String initials(String? name) {
  if (name == null || name.trim().isEmpty) return 'U';
  final parts =
      name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return 'U';
  if (parts.length == 1) return parts.first[0].toUpperCase();
  return (parts.first[0] + parts.last[0]).toUpperCase();
}

// ============================================================================
// 5. VALIDATORS
// ============================================================================

String? validateRequired(String? v, [String label = 'This field']) {
  if (v == null || v.trim().isEmpty) return '$label is required';
  return null;
}

String? validateEmail(String? v) {
  if (v == null || v.trim().isEmpty) return 'Email is required';
  return _emailOk(v) ? null : 'Enter a valid email';
}

String? validateEmailOptional(String? v) {
  if (v == null || v.trim().isEmpty) return null;
  return _emailOk(v) ? null : 'Enter a valid email';
}

bool _emailOk(String v) =>
    RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim());

String? validatePassword(String? v) {
  if (v == null || v.isEmpty) return 'Password is required';
  if (v.length < 6) return 'Use at least 6 characters';
  return null;
}

String? validatePhone(String? v) {
  if (v == null || v.trim().isEmpty) return 'Phone is required';
  return _phoneOk(v) ? null : 'Enter a valid number, e.g. 0300 1234567';
}

String? validatePhoneOptional(String? v) {
  if (v == null || v.trim().isEmpty) return null;
  return _phoneOk(v) ? null : 'Enter a valid number, e.g. 0300 1234567';
}

bool _phoneOk(String v) {
  final d = normalizePhone(v);
  return d != null && d.length >= 11 && d.length <= 13;
}

String? validateIntRange(String? v,
    {required int min, required int max, String label = 'Value'}) {
  if (v == null || v.trim().isEmpty) return null; // Optional
  final n = int.tryParse(v.trim());
  if (n == null || n < min || n > max) return '$label must be $min-$max';
  return null;
}

// ============================================================================
// 6. IMAGE COMPRESSION & PREPARATION (For Supabase Storage)
// ============================================================================

/// Opens camera or gallery, compresses the image, and returns the bytes.
/// Returns null if cancelled.
Future<Uint8List?> pickAndCompressPhoto(
    {required bool fromCamera, bool isThumbnail = false}) async {
  final picker = ImagePicker();
  final XFile? picked = await picker.pickImage(
    source: fromCamera ? ImageSource.camera : ImageSource.gallery,
    maxWidth: isThumbnail ? 300 : 1600,
    imageQuality: isThumbnail ? 60 : 90,
  );

  if (picked == null) return null;
  final bytes = await picked.readAsBytes();

  try {
    // Aggressive compression for DB/Storage efficiency
    final out = await FlutterImageCompress.compressWithList(
      bytes,
      minWidth: isThumbnail ? 150 : 800,
      minHeight: isThumbnail ? 150 : 800,
      quality: isThumbnail ? 50 : 80,
      format: CompressFormat.jpeg,
    );
    return Uint8List.fromList(out);
  } catch (e) {
    return bytes; // Fallback to original if compression fails
  }
}

/// Renders a network image from Supabase Storage, with a premium placeholder.
Widget storageImage(String? path,
    {double? width, double? height, BoxFit fit = BoxFit.cover}) {
  final placeholder = Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: AppColors.surfaceMuted,
      borderRadius: BorderRadius.circular(16),
    ),
    child: const Center(
      child: Icon(Icons.person, size: 32, color: AppColors.textSecondary),
    ),
  );

  if (path == null || path.isEmpty) return placeholder;

  // Note: The actual URL generation is handled by SupabaseClient in the repository,
  // but we use this generic builder to keep the UI code clean.
  // In V2, the repository will pass the signed URL directly if needed, or
  // we use the Supabase client here.
  return ClipRRect(
    borderRadius: BorderRadius.circular(16),
    child: Image.network(
      path, // Assuming `path` is actually a fully signed URL by the time it hits the UI
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (_, __, ___) => placeholder,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Container(
          width: width,
          height: height,
          color: AppColors.surfaceMuted,
          child: const Center(
              child: CircularProgressIndicator(color: AppColors.primary)),
        );
      },
    ),
  );
}

// ============================================================================
// 7. UI HELPERS (Matching the Premium Soft-Squircle Design)
// ============================================================================

InputDecoration fieldDecoration({
  String? label,
  String? hint,
  IconData? icon,
  Widget? suffix,
  bool isDense = false,
}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    // 1. FORCE HINT COLOR TO BE DARK/GREY
    hintStyle: AppTextStyles.bodyMedium
        .copyWith(color: AppColors.textSecondary.withOpacity(0.7)),
    labelStyle: AppTextStyles.label,
    // 2. FORCE TYPED TEXT COLOR TO BE BLACK (OR DARK CHARCOAL)
    // This fixes the white-on-white issue
    // Wait, InputDecoration doesn't have a 'style' property for the text itself.
    // The text style is set on the TextFormField. We need to handle this in the ThemeData or inside the widgets.

    prefixIcon: icon == null
        ? null
        : Padding(
            padding: const EdgeInsets.only(left: 16, right: 12),
            child: Icon(icon, color: AppColors.textSecondary, size: 20),
          ),
    prefixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 40),
    suffixIcon: suffix,
    filled: true,
    fillColor: AppColors.surface, // This is white
    isDense: isDense,
    contentPadding: EdgeInsets.symmetric(
      horizontal: 20,
      vertical: isDense ? 12 : 18,
    ),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: AppColors.primary, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: AppColors.danger, width: 1),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: AppColors.danger, width: 2),
    ),
  );
}

void showSnack(BuildContext context, String message, {bool isError = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: AppTextStyles.bodyMedium.copyWith(color: Colors.white),
        ),
        backgroundColor: isError ? AppColors.danger : AppColors.textPrimary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
}
