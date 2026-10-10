/// "~2 min", "45 s"…
String formatDuration(Duration d) {
  if (d.inSeconds < 60) return '${d.inSeconds} s';
  final minutes = d.inMinutes;
  final seconds = d.inSeconds % 60;
  if (minutes < 10 && seconds >= 15) {
    return '$minutes min ${seconds.toString().padLeft(2, '0')} s';
  }
  return '${(d.inSeconds / 60).round()} min';
}

/// "hace 5 min", "ayer", "12 mar"…
String formatRelative(DateTime date, {DateTime? now}) {
  now ??= DateTime.now();
  final diff = now.difference(date);
  if (diff.inSeconds < 45) return 'ahora mismo';
  if (diff.inMinutes < 60) return 'hace ${diff.inMinutes.clamp(1, 59)} min';
  if (diff.inHours < 24 && now.day == date.day) return 'hace ${diff.inHours} h';
  final yesterday = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 1));
  if (!date.isBefore(yesterday)) return 'ayer';
  if (diff.inDays < 7) return 'hace ${diff.inDays} días';
  const months = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
  final base = '${date.day} ${months[date.month - 1]}';
  return date.year == now.year ? base : '$base ${date.year}';
}

String pluralWords(int n) => n == 1 ? '1 palabra' : '$n palabras';
