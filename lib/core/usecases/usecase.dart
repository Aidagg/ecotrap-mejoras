import 'package:dartz/dartz.dart';
import '../errors/failures.dart';

/// Abstract UseCase
/// 
/// Patrón Command: Cada caso de uso encapsula una operación de negocio
/// Todos los casos de uso heredan de esta clase para mantener consistencia
/// 
/// Tipo genérico:
/// - Type: El tipo de dato que retorna el caso de uso
/// - Params: Los parámetros que necesita el caso de uso
abstract class UseCase<Type, Params> {
  /// Método call permite usar la instancia como función
  /// Ejemplo: final result = await useCase(params);
  Future<Either<Failure, Type>> call(Params params);
}

/// Clase para casos de uso sin parámetros
/// Evita usar dynamic o null
class NoParams {
  const NoParams();
}