import 'package:dartz/dartz.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/wifi_network.dart';
import '../../domain/repositories/wifi_repository.dart';
import '../datasources/wifi_local_datasource.dart';
import '../models/wifi_network_model.dart';

class WiFiRepositoryImpl implements WiFiRepository {
  final WiFiLocalDataSource localDataSource;
  final Uuid uuid;

  WiFiRepositoryImpl({
    required this.localDataSource,
    required this.uuid,
  });

  @override
  Future<Either<Failure, List<WiFiNetwork>>> getWiFiNetworks({
    required int page,
    required int pageSize,
  }) async {
    try {
      final networks = await localDataSource.getWiFiNetworks(
        page: page,
        pageSize: pageSize,
      );
      return Right(networks);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    } catch (e) {
      return Left(UnexpectedFailure('Error inesperado: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, WiFiNetwork>> getWiFiNetworkById(String id) async {
    try {
      final network = await localDataSource.getWiFiNetworkById(id);
      return Right(network);
    } on NotFoundException catch (e) {
      return Left(NotFoundFailure(e.message));
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    } catch (e) {
      return Left(UnexpectedFailure('Error inesperado: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, WiFiNetwork>> saveWiFiNetwork({
    required String ssid,
    required String password,
    String? bssid,
    String? name,
  }) async {
    try {
      final model = WiFiNetworkModel(
        id: uuid.v4(),
        ssid: ssid,
        password: password,
        bssid: bssid,
        name: name,
        createdAt: DateTime.now(),
      );
      final savedNetwork = await localDataSource.saveWiFiNetwork(model);
      return Right(savedNetwork);
    } on ValidationException catch (e) {
      return Left(ValidationFailure(e.message));
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    } catch (e) {
      return Left(UnexpectedFailure('Error inesperado: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, WiFiNetwork>> updateWiFiNetwork({
    required String id,
    required String ssid,
    required String password,
    String? bssid,
    String? name,
  }) async {
    try {
      final existingNetwork = await localDataSource.getWiFiNetworkById(id);
      final updatedModel = existingNetwork.copyWithModel(
        ssid: ssid,
        password: password,
        bssid: bssid ?? existingNetwork.bssid,
        name: name ?? existingNetwork.name,
      );
      final savedNetwork = await localDataSource.updateWiFiNetwork(updatedModel);
      return Right(savedNetwork);
    } on NotFoundException catch (e) {
      return Left(NotFoundFailure(e.message));
    } on ValidationException catch (e) {
      return Left(ValidationFailure(e.message));
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    } catch (e) {
      return Left(UnexpectedFailure('Error inesperado: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, void>> deleteWiFiNetwork(String id) async {
    try {
      await localDataSource.deleteWiFiNetwork(id);
      return const Right(null);
    } on NotFoundException catch (e) {
      return Left(NotFoundFailure(e.message));
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    } catch (e) {
      return Left(UnexpectedFailure('Error inesperado: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, int>> getTotalCount() async {
    try {
      final count = await localDataSource.getTotalCount();
      return Right(count);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    } catch (e) {
      return Left(UnexpectedFailure('Error inesperado: ${e.toString()}'));
    }
  }
}