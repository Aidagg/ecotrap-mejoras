import 'package:ecotrap/core/errors/exceptions.dart';
import 'package:ecotrap/features/wifi/data/datasources/wifi_local_datasource.dart';
import 'package:ecotrap/features/wifi/data/models/wifi_network_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'wifi_local_datasource_test.mocks.dart';

@GenerateMocks([HiveInterface, Box])
void main() {
  late WiFiLocalDataSourceImpl dataSource;
  late MockHiveInterface mockHive;
  late MockBox<WiFiNetworkModel> mockBox;

  setUp(() {
    mockHive = MockHiveInterface();
    mockBox = MockBox<WiFiNetworkModel>();
    dataSource = WiFiLocalDataSourceImpl(hive: mockHive);

    // Setup default behavior
    when(mockHive.box<WiFiNetworkModel>(any)).thenReturn(mockBox);
  });

  final tNetworkModel1 = WiFiNetworkModel(
    id: '1',
    ssid: 'WiFi 1',
    password: 'password123',
    createdAt: DateTime(2024, 1, 1),
  );

  final tNetworkModel2 = WiFiNetworkModel(
    id: '2',
    ssid: 'WiFi 2',
    password: 'password456',
    createdAt: DateTime(2024, 1, 2),
  );

  group('getWiFiNetworks', () {
    test('should return paginated WiFi networks from Hive', () async {
      // Arrange
      when(mockBox.values).thenReturn([tNetworkModel1, tNetworkModel2]);

      // Act
      final result = await dataSource.getWiFiNetworks(page: 1, pageSize: 10);

      // Assert
      expect(result, [tNetworkModel2, tNetworkModel1]); // Ordenados por fecha
      verify(mockBox.values);
    });

    test('should return empty list when page exceeds available data', () async {
      // Arrange
      when(mockBox.values).thenReturn([tNetworkModel1]);

      // Act
      final result = await dataSource.getWiFiNetworks(page: 2, pageSize: 10);

      // Assert
      expect(result, []);
    });

    test('should return correct page of data', () async {
      // Arrange
      final networks = List.generate(
        25,
        (i) => WiFiNetworkModel(
          id: '$i',
          ssid: 'WiFi $i',
          password: 'password$i',
          createdAt: DateTime(2024, 1, i + 1),
        ),
      );
      when(mockBox.values).thenReturn(networks);

      // Act
      final result = await dataSource.getWiFiNetworks(page: 2, pageSize: 10);

      // Assert
      expect(result.length, 10);
    });

    test('should throw CacheException when box access fails', () async {
      // Arrange
      when(mockHive.box<WiFiNetworkModel>(any))
          .thenThrow(Exception('Box not found'));

      // Act & Assert
      expect(
        () => dataSource.getWiFiNetworks(page: 1, pageSize: 10),
        throwsA(isA<CacheException>()),
      );
    });
  });

  group('saveWiFiNetwork', () {
    test('should save WiFi network to Hive', () async {
      // Arrange
      when(mockBox.values).thenReturn([]);
      when(mockBox.put(any, any)).thenAnswer((_) async => {});

      // Act
      final result = await dataSource.saveWiFiNetwork(tNetworkModel1);

      // Assert
      expect(result, tNetworkModel1);
      verify(mockBox.put(tNetworkModel1.id, tNetworkModel1));
    });

    test('should throw ValidationException when SSID and BSSID already exist',
        () async {
      // Arrange — red existente sin BSSID
      when(mockBox.values).thenReturn([tNetworkModel1]);

      final duplicateNetwork = WiFiNetworkModel(
        id: '3',
        ssid: 'WiFi 1', // Mismo SSID (case insensitive), sin BSSID
        password: 'different',
        createdAt: DateTime(2024, 1, 3),
      );

      // Act & Assert
      expect(
        () => dataSource.saveWiFiNetwork(duplicateNetwork),
        throwsA(isA<ValidationException>()),
      );
    });

    test('should allow same SSID when BSSID is different', () async {
      // Arrange — red existente con BSSID conocido
      final existingWithBssid = WiFiNetworkModel(
        id: '1',
        ssid: 'WiFi 1',
        password: 'password123',
        bssid: 'AA:BB:CC:DD:EE:01',
        createdAt: DateTime(2024, 1, 1),
      );
      when(mockBox.values).thenReturn([existingWithBssid]);
      when(mockBox.put(any, any)).thenAnswer((_) async => {});

      final newNetworkDifferentBssid = WiFiNetworkModel(
        id: '2',
        ssid: 'WiFi 1', // mismo SSID
        password: 'password456',
        bssid: 'AA:BB:CC:DD:EE:02', // BSSID diferente → dispositivo distinto
        createdAt: DateTime(2024, 1, 2),
      );

      // Act & Assert — no debe lanzar excepción
      final result =
          await dataSource.saveWiFiNetwork(newNetworkDifferentBssid);
      expect(result, newNetworkDifferentBssid);
    });

    test('should throw CacheException when save fails', () async {
      // Arrange
      when(mockBox.values).thenReturn([]);
      when(mockBox.put(any, any)).thenThrow(Exception('Save failed'));

      // Act & Assert
      expect(
        () => dataSource.saveWiFiNetwork(tNetworkModel1),
        throwsA(isA<CacheException>()),
      );
    });
  });

  group('getWiFiNetworkById', () {
    test('should return WiFi network when ID exists', () async {
      // Arrange
      when(mockBox.get(any)).thenReturn(tNetworkModel1);

      // Act
      final result = await dataSource.getWiFiNetworkById('1');

      // Assert
      expect(result, tNetworkModel1);
      verify(mockBox.get('1'));
    });

    test('should throw NotFoundException when ID does not exist', () async {
      // Arrange
      when(mockBox.get(any)).thenReturn(null);

      // Act & Assert
      expect(
        () => dataSource.getWiFiNetworkById('999'),
        throwsA(isA<NotFoundException>()),
      );
    });
  });

  group('deleteWiFiNetwork', () {
    test('should delete WiFi network from Hive', () async {
      // Arrange
      when(mockBox.containsKey(any)).thenReturn(true);
      when(mockBox.delete(any)).thenAnswer((_) async => {});

      // Act
      await dataSource.deleteWiFiNetwork('1');

      // Assert
      verify(mockBox.delete('1'));
    });

    test('should throw NotFoundException when ID does not exist', () async {
      // Arrange
      when(mockBox.containsKey(any)).thenReturn(false);

      // Act & Assert
      expect(
        () => dataSource.deleteWiFiNetwork('999'),
        throwsA(isA<NotFoundException>()),
      );
    });
  });

  group('getTotalCount', () {
    test('should return total count of WiFi networks', () async {
      // Arrange
      when(mockBox.length).thenReturn(5);

      // Act
      final result = await dataSource.getTotalCount();

      // Assert
      expect(result, 5);
      verify(mockBox.length);
    });

    test('should return 0 when box is empty', () async {
      // Arrange
      when(mockBox.length).thenReturn(0);

      // Act
      final result = await dataSource.getTotalCount();

      // Assert
      expect(result, 0);
    });
  });
}