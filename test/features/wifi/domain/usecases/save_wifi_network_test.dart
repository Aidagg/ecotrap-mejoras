import 'package:dartz/dartz.dart';
import 'package:ecotrap/core/errors/failures.dart';
import 'package:ecotrap/features/wifi/domain/entities/wifi_network.dart';
import 'package:ecotrap/features/wifi/domain/repositories/wifi_repository.dart';
import 'package:ecotrap/features/wifi/domain/usecases/save_wifi_network.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'save_wifi_network_test.mocks.dart';

@GenerateMocks([WiFiRepository])
void main() {
  late SaveWiFiNetwork usecase;
  late MockWiFiRepository mockRepository;

  setUp(() {
    mockRepository = MockWiFiRepository();
    usecase = SaveWiFiNetwork(mockRepository);
  });

  const tSsid = 'Test WiFi';
  const tPassword = 'password123';
  final tWiFiNetwork = WiFiNetwork(
    id: '1',
    ssid: tSsid,
    password: tPassword,
    createdAt: DateTime(2024, 1, 1),
  );

  group('SaveWiFiNetwork', () {
    test('should save WiFi network through repository', () async {
      // Arrange
      when(mockRepository.saveWiFiNetwork(
        ssid: anyNamed('ssid'),
        password: anyNamed('password'),
      )).thenAnswer((_) async => Right(tWiFiNetwork));

      // Act
      final result = await usecase(const SaveWiFiNetworkParams(
        ssid: tSsid,
        password: tPassword,
      ));

      // Assert
      expect(result, Right(tWiFiNetwork));
      verify(mockRepository.saveWiFiNetwork(
        ssid: tSsid,
        password: tPassword,
      ));
      verifyNoMoreInteractions(mockRepository);
    });

    test('should return ValidationFailure when SSID is empty', () async {
      // Act
      final result = await usecase(const SaveWiFiNetworkParams(
        ssid: '',
        password: tPassword,
      ));

      // Assert
      expect(result, isA<Left>());
      result.fold(
        (failure) {
          expect(failure, isA<ValidationFailure>());
          expect(
            failure.message,
            'El nombre de la red (SSID) no puede estar vacío',
          );
        },
        (_) => fail('Should return failure'),
      );
      verifyZeroInteractions(mockRepository);
    });

    test('should return ValidationFailure when SSID is only whitespace',
        () async {
      // Act
      final result = await usecase(const SaveWiFiNetworkParams(
        ssid: '   ',
        password: tPassword,
      ));

      // Assert
      expect(result, isA<Left>());
      result.fold(
        (failure) => expect(failure, isA<ValidationFailure>()),
        (_) => fail('Should return failure'),
      );
      verifyZeroInteractions(mockRepository);
    });

    test('should return ValidationFailure when SSID exceeds 32 characters',
        () async {
      // Act
      final result = await usecase(SaveWiFiNetworkParams(
        ssid: 'A' * 33,
        password: tPassword,
      ));

      // Assert
      expect(result, isA<Left>());
      result.fold(
        (failure) {
          expect(failure, isA<ValidationFailure>());
          expect(
            failure.message,
            'El SSID no puede tener más de 32 caracteres',
          );
        },
        (_) => fail('Should return failure'),
      );
      verifyZeroInteractions(mockRepository);
    });

    test('should return ValidationFailure when password is empty', () async {
      // Act
      final result = await usecase(const SaveWiFiNetworkParams(
        ssid: tSsid,
        password: '',
      ));

      // Assert
      expect(result, isA<Left>());
      result.fold(
        (failure) {
          expect(failure, isA<ValidationFailure>());
          expect(
            failure.message,
            'La contraseña no puede estar vacía',
          );
        },
        (_) => fail('Should return failure'),
      );
      verifyZeroInteractions(mockRepository);
    });

    test('should return ValidationFailure when password is less than 8 chars',
        () async {
      // Act
      final result = await usecase(const SaveWiFiNetworkParams(
        ssid: tSsid,
        password: '1234567',
      ));

      // Assert
      expect(result, isA<Left>());
      result.fold(
        (failure) {
          expect(failure, isA<ValidationFailure>());
          expect(
            failure.message,
            'La contraseña debe tener al menos 8 caracteres',
          );
        },
        (_) => fail('Should return failure'),
      );
      verifyZeroInteractions(mockRepository);
    });

    test('should return ValidationFailure when password exceeds 63 chars',
        () async {
      // Act
      final result = await usecase(SaveWiFiNetworkParams(
        ssid: tSsid,
        password: 'A' * 64,
      ));

      // Assert
      expect(result, isA<Left>());
      result.fold(
        (failure) {
          expect(failure, isA<ValidationFailure>());
          expect(
            failure.message,
            'La contraseña no puede tener más de 63 caracteres',
          );
        },
        (_) => fail('Should return failure'),
      );
      verifyZeroInteractions(mockRepository);
    });

    test('should trim SSID before saving', () async {
      // Arrange
      when(mockRepository.saveWiFiNetwork(
        ssid: anyNamed('ssid'),
        password: anyNamed('password'),
      )).thenAnswer((_) async => Right(tWiFiNetwork));

      // Act
      await usecase(const SaveWiFiNetworkParams(
        ssid: '  Test WiFi  ',
        password: tPassword,
      ));

      // Assert
      verify(mockRepository.saveWiFiNetwork(
        ssid: 'Test WiFi',
        password: tPassword,
      ));
    });
  });
}