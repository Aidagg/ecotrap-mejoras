import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/wifi_repository.dart';

/// UseCase: Obtener total de redes WiFi
/// 
/// Útil para calcular paginación en la UI
class GetTotalCount implements UseCase<int, NoParams> {
  final WiFiRepository repository;

  GetTotalCount(this.repository);

  @override
  Future<Either<Failure, int>> call(NoParams params) async {
    return await repository.getTotalCount();
  }
}