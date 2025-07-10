String formatSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  final kb = bytes / 1024;
  if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
  final mb = kb / 1024;
  return '${mb.toStringAsFixed(2)} MB';
}

String formatTime(double seconds) {
  final mins = seconds ~/ 60;
  final secs = (seconds % 60).toStringAsFixed(1);
  return mins > 0 ? '$mins мин $secs сек' : '$secs сек';
}
