String formatLocalDateLabel(String value) {
  final date = DateTime.tryParse(value);
  if (date == null) {
    return value;
  }

  return _formatDate(date.toLocal());
}

String formatLocalDateTimeLabel(String value) {
  final date = DateTime.tryParse(value);
  if (date == null) {
    return value;
  }

  final localDate = date.toLocal();
  return '${_formatDate(localDate)} ${_twoDigits(localDate.hour)}:${_twoDigits(localDate.minute)}';
}

String _formatDate(DateTime date) {
  return '${_twoDigits(date.day)}/${_twoDigits(date.month)}/${date.year}';
}

String _twoDigits(int value) {
  return value.toString().padLeft(2, '0');
}
