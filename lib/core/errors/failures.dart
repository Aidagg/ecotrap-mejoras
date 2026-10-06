import 'package:equatable/equatable.dart';

/// Abstract Failure class
/// 
/// Siguiendo el patrón Either de programación funcional,
/// los Failures representan errores del dominio de negocio
abstract class Failure extends Equatable {
  final String message;
  
  const Failure(this.message);
  
  @override
  List<Object> get props => [message];
}

/// Failure de caché/storage
class CacheFailure extends Failure {
  const CacheFailure(super.message);
}

/// Failure de validación
class ValidationFailure extends Failure {
  const ValidationFailure(super.message);
}

/// Failure genérico
class UnexpectedFailure extends Failure {
  const UnexpectedFailure(super.message);
}

/// Failure de red no encontrada
class NotFoundFailure extends Failure {
  const NotFoundFailure(super.message);
}