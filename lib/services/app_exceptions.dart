/// Erro de negócio exibível direto ao usuário.
class AppException implements Exception {
  AppException(this.message);
  final String message;

  @override
  String toString() => message;
}
