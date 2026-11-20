import 'package:intl/intl.dart';

/// Formats minor units (cents/kobo) as money, e.g. 150000 -> ₦1,500.00
String money(int minor, String symbol) {
  final f = NumberFormat.currency(symbol: symbol, decimalDigits: 2);
  return f.format(minor / 100);
}

/// Compact money for tiles, e.g. ₦12.5K
String moneyCompact(int minor, String symbol) {
  final f = NumberFormat.compactCurrency(
    symbol: symbol,
    decimalDigits: minor.abs() >= 100000 ? 1 : 0,
  );
  return f.format(minor / 100);
}

/// Parses user input like "1,500.50" into minor units. Returns null if invalid.
int? parseMoney(String input) {
  final cleaned = input.replaceAll(RegExp(r'[^0-9.]'), '');
  if (cleaned.isEmpty) return null;
  final v = double.tryParse(cleaned);
  if (v == null || v < 0) return null;
  return (v * 100).round();
}

/// Minor units -> editable text, e.g. 150050 -> "1500.50"
String moneyInput(int minor) => (minor / 100).toStringAsFixed(2);

String dateShort(DateTime d) => DateFormat('d MMM yyyy').format(d);
String dateTime(DateTime d) => DateFormat('d MMM yyyy, h:mm a').format(d);
String timeOnly(DateTime d) => DateFormat('h:mm a').format(d);
String weekday(DateTime d) => DateFormat('E').format(d);

String relativeDay(DateTime d, [DateTime? now]) {
  now ??= DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(d.year, d.month, d.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'Today, ${timeOnly(d)}';
  if (diff == 1) return 'Yesterday, ${timeOnly(d)}';
  return dateTime(d);
}
