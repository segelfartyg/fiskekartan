const _months = [
  'januari', 'februari', 'mars', 'april', 'maj', 'juni', //
  'juli', 'augusti', 'september', 'oktober', 'november', 'december',
];

/// "27 september 2026"
String formatDate(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

/// "27 september 2026, 15:09"
String formatDateTime(DateTime d) =>
    '${formatDate(d)}, ${_twoDigits(d.hour)}:${_twoDigits(d.minute)}';

/// At most one decimal, with a Swedish decimal comma and no trailing ",0".
/// The backend stores weather values as float32, so they arrive as e.g.
/// 16.200000762939453.
String formatNumber(double value) {
  final rounded = (value * 10).round() / 10;
  final text = rounded == rounded.roundToDouble()
      ? rounded.round().toString()
      : rounded.toStringAsFixed(1);
  return text.replaceAll('.', ',');
}

String _twoDigits(int n) => n.toString().padLeft(2, '0');
