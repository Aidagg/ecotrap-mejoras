import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/wifi_network.dart';
import '../repositories/wifi_repository.dart';

class SaveWiFiNetwork implements UseCase<WiFiNetwork, SaveWiFiNetworkParams> {
  final WiFiRepository repository;

  SaveWiFiNetwork(this.repository);

  @override
  Future<Either<Failure, WiFiNetwork>> call(SaveWiFiNetworkParams params) async {
    final trimmedSsid = params.ssid.trim();

    if (trimmedSsid.isEmpty) {
      return const Left(
          ValidationFailure('El nombre de la red (SSID) no puede estar vacío'));
    }
    if (trimmedSsid.length > 32) {
      return const Left(
          ValidationFailure('El SSID no puede tener más de 32 caracteres'));
    }
    if (params.password.trim().isEmpty) {
      return const Left(
          ValidationFailure('La contraseña no puede estar vacía'));
    }
    if (params.password.length < 8) {
      return const Left(
          ValidationFailure('La contraseña debe tener al menos 8 caracteres'));
    }
    if (params.password.length > 63) {
      return const Left(
          ValidationFailure('La contraseña no puede tener más de 63 caracteres'));
    }

    return await repository.saveWiFiNetwork(
      ssid: trimmedSsid,
      password: params.password,
      bssid: params.bssid,
      name: params.name,
    );
  }
}

class SaveWiFiNetworkParams extends Equatable {
  final String ssid;
  final String password;
  final String? bssid;
  final String? name;

  const SaveWiFiNetworkParams({
    required this.ssid,
    required this.password,
    this.bssid,
    this.name,
  });

  @override
  List<Object?> get props => [ssid, password, bssid, name];
}