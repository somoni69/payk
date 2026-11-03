class ApiException implements Exception {
  ApiException(this.status, this.message);

  final int status;
  final String message;

  @override
  String toString() => message;
}

String errorText(Object error) {
  if (error is ApiException && error.message.trim().isNotEmpty) return error.message;
  return 'Не удалось загрузить данные';
}
