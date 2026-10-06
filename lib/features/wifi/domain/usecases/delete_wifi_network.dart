import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/wifi_repository.dart';

/// UseCase: Eliminar red WiFi
/// 
/// Parámetro simple: solo necesita el ID (String)
class DeleteWiFiNetwork implements UseCase<void, String> {
  final WiFiRepository repository;

  DeleteWiFiNetwork(this.repository);

  @override
  Future<Either<Failure, void>> call(String id) async {
    // Validación
    if (id.trim().isEmpty) {
      return const Left(ValidationFailure('El ID no puede estar vacío'));
    }

    return await repository.deleteWiFiNetwork(id.trim());
  }
}