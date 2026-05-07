String formatBytes(int bytes) {
  if (bytes <= 0) return '0 MB';
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var size = bytes.toDouble();
  var unit = 0;

  while (size >= 1024 && unit < units.length - 1) {
    size /= 1024;
    unit++;
  }

  final decimals = unit <= 1 || size >= 10 ? 0 : 1;
  return '${size.toStringAsFixed(decimals)} ${units[unit]}';
}

String formatPercent(double value) {
  return '${(value * 100).round()}%';
}
