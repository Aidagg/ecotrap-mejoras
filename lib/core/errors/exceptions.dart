/// Exception personalizada para errores de caché
/// 
/// Las Exceptions son para la capa de datos,
/// se convierten en Failures en el Repository
class CacheException implements Exception {
  final String message;
  
  CacheException([this.message = 'Error al acceder al almacenamiento local']);
  
  @override
  String toString() => 'CacheException: $message';
}

/// Exception para validaciones
class ValidationException implements Exception {
  final String message;
  
  ValidationException(this.message);
  
  @override
  String toString() => 'ValidationException: $message';
}

/// Exception para recursos no encontrados
class NotFoundException implements Exception {
  final String message;
  
  NotFoundException([this.message = 'Recurso no encontrado']);
  
  @override
  String toString() => 'NotFoundException: $message';
}