import 'package:dartz/dartz.dart';
import 'package:ecotrap/core/errors/failures.dart';
import 'package:ecotrap/features/wifi/domain/entities/wifi_network.dart';
import 'package:ecotrap/features/wifi/domain/repositories/wifi_repository.dart';
import 'package:ecotrap/features/wifi/domain/usecases/get_wifi_networks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'get_wifi_networks_test.mocks.dart';

/// Generar mocks:
/// flutter pub run build_runner build --delete-conflicting-outputs
@GenerateMocks([WiFiRepository])
void main() {
  late GetWiFiNetworks usecase;
  late MockWiFiRepository mockRepository;

  setUp(() {
    mockRepository = MockWiFiRepository();
    usecase = GetWiFiNetworks(mockRepository);
  });

  const tPage = 1;
  const tPageSize = 10;
  final tWiFiNetworks = [
    WiFiNetwork(
      id: '1',
      ssid: 'Test WiFi 1',
      password: 'password123',
      createdAt: DateTime(2024, 1, 1),
    ),
    WiFiNetwork(
      id: '2',
      ssid: 'Test WiFi 2',
      password: 'password456',
      createdAt: DateTime(2024, 1, 2),
    ),
  ];

  group('GetWiFiNetworks', () {
    test('should get WiFi networks from repository', () async {
      // Arrange
      when(mockRepository.getWiFiNetworks(
        page: anyNamed('page'),
        pageSize: anyNamed('pageSize'),
      )).thenAnswer((_) async => Right(tWiFiNetworks));

      // Act
      final result = await usecase(const GetWiFiNetworksParams(
        page: tPage,
        pageSize: tPageSize,
      ));

      // Assert
      expect(result, Right(tWiFiNetworks));
      verify(mockRepository.getWiFiNetworks(
        page: tPage,
        pageSize: tPageSize,
      ));
      verifyNoMoreInteractions(mockRepository);
    });

    test('should return ValidationFailure when page is less than 1', () async {
      // Act
      final result = await usecase(const GetWiFiNetworksParams(
        page: 0,
        pageSize: tPageSize,
      ));

      // Assert
      expect(result, isA<Left>());
      result.fold(
        (failure) {
          expect(failure, isA<ValidationFailure>());
          expect(
            failure.message,
            'El número de página debe ser mayor a 0',
          );
        },
        (_) => fail('Should return failure'),
      );
      verifyZeroInteractions(mockRepository);
    });

    test('should return ValidationFailure when pageSize is less than 1',
        () async {
      // Act
      final result = await usecase(const GetWiFiNetworksParams(
        page: tPage,
        pageSize: 0,
      ));

      // Assert
      expect(result, isA<Left>());
      result.fold(
        (failure) {
          expect(failure, isA<ValidationFailure>());
          expect(
            failure.message,
            'El tamaño de página debe estar entre 1 y 100',
          );
        },
        (_) => fail('Should return failure'),
      );
      verifyZeroInteractions(mockRepository);
    });

    test('should return ValidationFailure when pageSize is greater than 100',
        () async {
      // Act
      final result = await usecase(const GetWiFiNetworksParams(
        page: tPage,
        pageSize: 101,
      ));

      // Assert
      expect(result, isA<Left>());
      result.fold(
        (failure) {
          expect(failure, isA<ValidationFailure>());
          expect(
            failure.message,
            'El tamaño de página debe estar entre 1 y 100',
          );
        },
        (_) => fail('Should return failure'),
      );
      verifyZeroInteractions(mockRepository);
    });

    test('should return CacheFailure when repository fails', () async {
      // Arrange
      const tFailure = CacheFailure('Error de caché');
      when(mockRepository.getWiFiNetworks(
        page: anyNamed('page'),
        pageSize: anyNamed('pageSize'),
      )).thenAnswer((_) async => const Left(tFailure));

      // Act
      final result = await usecase(const GetWiFiNetworksParams(
        page: tPage,
        pageSize: tPageSize,
      ));

      // Assert
      expect(result, const Left(tFailure));
      verify(mockRepository.getWiFiNetworks(
        page: tPage,
        pageSize: tPageSize,
      ));
    });
  });
}