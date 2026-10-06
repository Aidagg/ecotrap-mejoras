import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/wifi_network.dart';
import '../repositories/wifi_repository.dart';

/// UseCase: Obtener redes WiFi paginadas
/// 
/// Responsabilidad Única (SOLID): 
/// Solo se encarga de obtener y validar la obtención de redes WiFi
class GetWiFiNetworks implements UseCase<List<WiFiNetwork>, GetWiFiNetworksParams> {
  final WiFiRepository repository;

  GetWiFiNetworks(this.repository);

  @override
  Future<Either<Failure, List<WiFiNetwork>>> call(GetWiFiNetworksParams params) async {
    // Validación de reglas de negocio
    if (params.page < 1) {
      return const Left(
        ValidationFailure('El número de página debe ser mayor a 0')
      );
    }
    
    if (params.pageSize < 1 || params.pageSize > 100) {
      return const Left(
        ValidationFailure('El tamaño de página debe estar entre 1 y 100')
      );
    }

    // Delegar al repositorio
    return await repository.getWiFiNetworks(
      page: params.page,
      pageSize: params.pageSize,
    );
  }
}

/// Parámetros para GetWiFiNetworks
/// 
/// Value Object: Encapsula los parámetros relacionados
class GetWiFiNetworksParams extends Equatable {
  final int page;
  final int pageSize;

  const GetWiFiNetworksParams({
    required this.page,
    required this.pageSize,
  });

  @override
  List<Object> get props => [page, pageSize];
}