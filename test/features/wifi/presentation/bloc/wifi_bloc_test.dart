import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:ecotrap/core/errors/failures.dart';
import 'package:ecotrap/features/wifi/domain/entities/wifi_network.dart';
import 'package:ecotrap/features/wifi/domain/usecases/delete_wifi_network.dart';
import 'package:ecotrap/features/wifi/domain/usecases/get_total_count.dart';
import 'package:ecotrap/features/wifi/domain/usecases/get_wifi_networks.dart';
import 'package:ecotrap/features/wifi/domain/usecases/save_wifi_network.dart';
import 'package:ecotrap/features/wifi/domain/usecases/update_wifi_network.dart';
import 'package:ecotrap/features/wifi/presentation/bloc/wifi_bloc.dart';
import 'package:ecotrap/features/wifi/presentation/bloc/wifi_event.dart';
import 'package:ecotrap/features/wifi/presentation/bloc/wifi_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'wifi_bloc_test.mocks.dart';

@GenerateMocks([
  GetWiFiNetworks,
  SaveWiFiNetwork,
  UpdateWiFiNetwork,
  DeleteWiFiNetwork,
  GetTotalCount,
])
void main() {
  late WiFiBloc bloc;
  late MockGetWiFiNetworks mockGetWiFiNetworks;
  late MockSaveWiFiNetwork mockSaveWiFiNetwork;
  late MockUpdateWiFiNetwork mockUpdateWiFiNetwork;
  late MockDeleteWiFiNetwork mockDeleteWiFiNetwork;
  late MockGetTotalCount mockGetTotalCount;

  setUp(() {
    mockGetWiFiNetworks = MockGetWiFiNetworks();
    mockSaveWiFiNetwork = MockSaveWiFiNetwork();
    mockUpdateWiFiNetwork = MockUpdateWiFiNetwork();
    mockDeleteWiFiNetwork = MockDeleteWiFiNetwork();
    mockGetTotalCount = MockGetTotalCount();

    bloc = WiFiBloc(
      getWiFiNetworks: mockGetWiFiNetworks,
      saveWiFiNetwork: mockSaveWiFiNetwork,
      updateWiFiNetwork: mockUpdateWiFiNetwork,
      deleteWiFiNetwork: mockDeleteWiFiNetwork,
      getTotalCount: mockGetTotalCount,
    );
  });

  tearDown(() {
    bloc.close();
  });

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

  group('LoadWiFiNetworksEvent', () {
    blocTest<WiFiBloc, WiFiState>(
      'should emit [WiFiLoading, WiFiLoaded] when data is gotten successfully',
      build: () {
        when(mockGetTotalCount(any)).thenAnswer(
          (_) async => const Right(2),
        );
        when(mockGetWiFiNetworks(any)).thenAnswer(
          (_) async => Right(tWiFiNetworks),
        );
        return bloc;
      },
      act: (bloc) => bloc.add(const LoadWiFiNetworksEvent()),
      expect: () => [
        const WiFiLoading(),
        WiFiLoaded(
          networks: tWiFiNetworks,
          currentPage: 1,
          totalCount: 2,
          hasMorePages: false,
        ),
      ],
      verify: (_) {
        verify(mockGetTotalCount(any));
        verify(mockGetWiFiNetworks(any));
      },
    );

    blocTest<WiFiBloc, WiFiState>(
      'should emit [WiFiLoading, WiFiError] when getting data fails',
      build: () {
        when(mockGetTotalCount(any)).thenAnswer(
          (_) async => const Right(0),
        );
        when(mockGetWiFiNetworks(any)).thenAnswer(
          (_) async => const Left(CacheFailure('Error de caché')),
        );
        return bloc;
      },
      act: (bloc) => bloc.add(const LoadWiFiNetworksEvent()),
      expect: () => [
        const WiFiLoading(),
        const WiFiError('Error de caché'),
      ],
    );

    blocTest<WiFiBloc, WiFiState>(
      'should emit state with hasMorePages=true when there are more pages',
      build: () {
        when(mockGetTotalCount(any)).thenAnswer(
          (_) async => const Right(25),
        );
        when(mockGetWiFiNetworks(any)).thenAnswer(
          (_) async => Right(tWiFiNetworks),
        );
        return bloc;
      },
      act: (bloc) => bloc.add(const LoadWiFiNetworksEvent(
        page: 1,
        pageSize: 10,
      )),
      expect: () => [
        const WiFiLoading(),
        WiFiLoaded(
          networks: tWiFiNetworks,
          currentPage: 1,
          totalCount: 25,
          hasMorePages: true,
        ),
      ],
    );
  });

  group('SaveWiFiNetworkEvent', () {
    final tNetwork = WiFiNetwork(
      id: '3',
      ssid: 'New WiFi',
      password: 'newpassword',
      createdAt: DateTime(2024, 1, 3),
    );

    blocTest<WiFiBloc, WiFiState>(
      'should emit [WiFiSaving, WiFiSaved, WiFiLoading, WiFiLoaded]',
      build: () {
        when(mockSaveWiFiNetwork(any)).thenAnswer(
          (_) async => Right(tNetwork),
        );
        when(mockGetTotalCount(any)).thenAnswer(
          (_) async => const Right(1),
        );
        when(mockGetWiFiNetworks(any)).thenAnswer(
          (_) async => Right([tNetwork]),
        );
        return bloc;
      },
      act: (bloc) => bloc.add(const SaveWiFiNetworkEvent(
        ssid: 'New WiFi',
        password: 'newpassword',
      )),
      expect: () => [
        const WiFiSaving(),
        WiFiSaved(tNetwork),
        const WiFiLoading(),
        WiFiLoaded(
          networks: [tNetwork],
          currentPage: 1,
          totalCount: 1,
          hasMorePages: false,
        ),
      ],
    );

    blocTest<WiFiBloc, WiFiState>(
      'should emit [WiFiSaving, WiFiError] when save fails',
      build: () {
        when(mockSaveWiFiNetwork(any)).thenAnswer(
          (_) async => const Left(ValidationFailure('SSID ya existe')),
        );
        return bloc;
      },
      act: (bloc) => bloc.add(const SaveWiFiNetworkEvent(
        ssid: 'Duplicate',
        password: 'password',
      )),
      expect: () => [
        const WiFiSaving(),
        const WiFiError('SSID ya existe'),
      ],
    );
  });

  group('DeleteWiFiNetworkEvent', () {
    blocTest<WiFiBloc, WiFiState>(
      'should emit [WiFiDeleting, WiFiDeleted, WiFiLoading, WiFiLoaded]',
      build: () {
        when(mockDeleteWiFiNetwork(any)).thenAnswer(
          (_) async => const Right(null),
        );
        when(mockGetTotalCount(any)).thenAnswer(
          (_) async => const Right(0),
        );
        when(mockGetWiFiNetworks(any)).thenAnswer(
          (_) async => const Right([]),
        );
        return bloc;
      },
      act: (bloc) => bloc.add(const DeleteWiFiNetworkEvent('1')),
      expect: () => [
        const WiFiDeleting('1'),
        const WiFiDeleted('1'),
        const WiFiLoading(),
        const WiFiLoaded(
          networks: [],
          currentPage: 1,
          totalCount: 0,
          hasMorePages: false,
        ),
      ],
    );
  });
}