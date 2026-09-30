String initials(String value) => value
    .trim()
    .split(RegExp(r'\s+'))
    .take(2)
    .map((part) => part.isEmpty ? '' : part[0].toUpperCase())
    .join();

String formatDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

String formatTime(DateTime date) =>
    '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

String formatDateTime(DateTime date) => '${formatDate(date)} às ${formatTime(date)}';

double? parseNumber(String value) => double.tryParse(value.trim().replaceAll(',', '.'));
