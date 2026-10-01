import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/wifi_network.dart';

abstract class WiFiRepository {
  Future<Either<Failure, List<WiFiNetwork>>> getWiFiNetworks({
    required int page,
    required int pageSize,
  });

  Future<Either<Failure, WiFiNetwork>> getWiFiNetworkById(String id);

  Future<Either<Failure, WiFiNetwork>> saveWiFiNetwork({
    required String ssid,
    required String password,
    String? bssid,
    String? name,
  });

  Future<Either<Failure, WiFiNetwork>> updateWiFiNetwork({
    required String id,
    required String ssid,
    required String password,
    String? bssid,
    String? name,
  });

  Future<Either<Failure, void>> deleteWiFiNetwork(String id);

  Future<Either<Failure, int>> getTotalCount();
}