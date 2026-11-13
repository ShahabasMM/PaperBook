import 'package:intl/intl.dart';

/// Presentation-only date, currency and size formatting.
abstract final class Formats {
  static final _monthDay = DateFormat('MMM d');
  static final _monthDayYear = DateFormat('MMM d, yyyy');
  static final _longDate = DateFormat('MMMM d, yyyy');
  static final _time = DateFormat('h:mm a');

  static String date(DateTime value) => _monthDayYear.format(value);
  static String shortDate(DateTime value) => _monthDay.format(value);
  static String longDate(DateTime value) => _longDate.format(value);
  static String time(DateTime value) => _time.format(value);

  /// Relative label for recency ("Today", "Yesterday", "Mar 4").
  static String relative(DateTime value) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(value.year, value.month, value.day);
    final difference = today.difference(target).inDays;
    if (difference == 0) return 'Today';
    if (difference == 1) return 'Yesterday';
    if (difference > 1 && difference < 7) return '$difference days ago';
    if (target.year == now.year) return _monthDay.format(value);
    return _monthDayYear.format(value);
  }

  /// Currency with grouped digits. Returns an em dash when no amount is known.
  static String amount(double? value, {bool symbol = true}) {
    if (value == null) return '—';
    final format = symbol
        ? NumberFormat.currency(locale: 'en_US', symbol: '\$', decimalDigits: 2)
        : NumberFormat.decimalPatternDigits(locale: 'en_US', decimalDigits: 2);
    return format.format(value);
  }

  static String compactAmount(double? value) {
    if (value == null) return '—';
    return NumberFormat.compactCurrency(
      locale: 'en_US',
      symbol: '\$',
      decimalDigits: value % 1 == 0 ? 0 : 2,
    ).format(value);
  }

  static String fileSize(int bytes) {
    if (bytes <= 0) return '—';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(0)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  static String initialize(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '?';
    return trimmed.substring(0, 1).toUpperCase();
  }

  static String greeting([DateTime? now]) {
    final hour = (now ?? DateTime.now()).hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  /// Parses user input such as "1,299.50" or "$42".
  static double? parseAmount(String raw) {
    if (raw.trim().isEmpty) return null;
    final cleaned = raw.replaceAll(RegExp(r'[^0-9.\-]'), '');
    if (cleaned.isEmpty) return null;
    return double.tryParse(cleaned);
  }
}
