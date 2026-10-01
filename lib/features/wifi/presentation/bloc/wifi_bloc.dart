import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:wifi_iot/wifi_iot.dart' as wifi_iot;

import '../../../../core/usecases/usecase.dart';
import '../../domain/entities/wifi_network.dart';
import '../../domain/usecases/delete_wifi_network.dart';
import '../../domain/usecases/get_total_count.dart';
import '../../domain/usecases/get_wifi_networks.dart';
import '../../domain/usecases/save_wifi_network.dart';
import '../../domain/usecases/update_wifi_network.dart';
import 'wifi_event.dart';
import 'wifi_state.dart';

class WiFiBloc extends Bloc<WiFiEvent, WiFiState> {
  final GetWiFiNetworks getWiFiNetworks;
  final SaveWiFiNetwork saveWiFiNetwork;
  final UpdateWiFiNetwork updateWiFiNetwork;
  final DeleteWiFiNetwork deleteWiFiNetwork;
  final GetTotalCount getTotalCount;

  static const int _pageSize = 10;
  static const String _entomoPrefix = 'ENTOMO';

  WiFiBloc({
    required this.getWiFiNetworks,
    required this.saveWiFiNetwork,
    required this.updateWiFiNetwork,
    required this.deleteWiFiNetwork,
    required this.getTotalCount,
  }) : super(const WiFiInitial()) {
    on<LoadWiFiNetworksEvent>(_onLoadWiFiNetworks);
    on<LoadMoreWiFiNetworksEvent>(_onLoadMoreWiFiNetworks);
    on<RefreshWiFiNetworksEvent>(_onRefreshWiFiNetworks);
    on<SaveWiFiNetworkEvent>(_onSaveWiFiNetwork);
    on<UpdateWiFiNetworkEvent>(_onUpdateWiFiNetwork);
    on<DeleteWiFiNetworkEvent>(_onDeleteWiFiNetwork);
    on<ScanNearbyNetworksEvent>(_onScanNearbyNetworks);
    on<BackToSavedNetworksEvent>(_onBackToSavedNetworks);
    on<SaveAndConnectNearbyEvent>(_onSaveAndConnectNearby);
  }

  Future<void> _onLoadWiFiNetworks(
    LoadWiFiNetworksEvent event,
    Emitter<WiFiState> emit,
  ) async {
    emit(const WiFiLoading());

    final countResult = await getTotalCount(const NoParams());
    int totalCount = 0;
    countResult.fold(
      (failure) => totalCount = 0,
      (count) => totalCount = count,
    );

    final result = await getWiFiNetworks(
      GetWiFiNetworksParams(page: event.page, pageSize: event.pageSize),
    );

    result.fold(
      (failure) => emit(WiFiError(failure.message)),
      (networks) {
        final hasMore = (event.page * event.pageSize) < totalCount;
        emit(WiFiLoaded(
          networks: networks,
          currentPage: event.page,
          totalCount: totalCount,
          hasMorePages: hasMore,
        ));
      },
    );
  }

  Future<void> _onLoadMoreWiFiNetworks(
    LoadMoreWiFiNetworksEvent event,
    Emitter<WiFiState> emit,
  ) async {
    if (state is! WiFiLoaded) return;
    final currentState = state as WiFiLoaded;
    if (!currentState.hasMorePages) return;

    emit(WiFiLoadingMore(currentState.networks));

    final nextPage = currentState.currentPage + 1;
    final result = await getWiFiNetworks(
      GetWiFiNetworksParams(page: nextPage, pageSize: _pageSize),
    );

    result.fold(
      (failure) => emit(WiFiError(failure.message)),
      (newNetworks) {
        final allNetworks = [...currentState.networks, ...newNetworks];
        final hasMore = (nextPage * _pageSize) < currentState.totalCount;
        emit(WiFiLoaded(
          networks: allNetworks,
          currentPage: nextPage,
          totalCount: currentState.totalCount,
          hasMorePages: hasMore,
        ));
      },
    );
  }

  Future<void> _onRefreshWiFiNetworks(
    RefreshWiFiNetworksEvent event,
    Emitter<WiFiState> emit,
  ) async {
    add(const LoadWiFiNetworksEvent(page: 1, pageSize: _pageSize));
  }

  Future<void> _onSaveWiFiNetwork(
    SaveWiFiNetworkEvent event,
    Emitter<WiFiState> emit,
  ) async {
    emit(const WiFiSaving());
    final result = await saveWiFiNetwork(
      SaveWiFiNetworkParams(
        ssid: event.ssid,
        password: event.password,
        bssid: event.bssid, // ✅ NUEVO
      ),
    );
    result.fold(
      (failure) => emit(WiFiError(failure.message)),
      (network) {
        emit(WiFiSaved(network));
        add(const LoadWiFiNetworksEvent(page: 1, pageSize: _pageSize));
      },
    );
  }

  Future<void> _onUpdateWiFiNetwork(
    UpdateWiFiNetworkEvent event,
    Emitter<WiFiState> emit,
  ) async {
    emit(const WiFiSaving());
    final result = await updateWiFiNetwork(
      UpdateWiFiNetworkParams(
        id: event.id,
        ssid: event.ssid,
        password: event.password,
        bssid: event.bssid,
        name: event.name,
      ),
    );
    result.fold(
      (failure) => emit(WiFiError(failure.message)),
      (network) {
        emit(WiFiSaved(network));
        add(const LoadWiFiNetworksEvent(page: 1, pageSize: _pageSize));
      },
    );
  }

  Future<void> _onDeleteWiFiNetwork(
    DeleteWiFiNetworkEvent event,
    Emitter<WiFiState> emit,
  ) async {
    emit(WiFiDeleting(event.id));
    final result = await deleteWiFiNetwork(event.id);
    result.fold(
      (failure) => emit(WiFiError(failure.message)),
      (_) {
        emit(WiFiDeleted(event.id));
        add(const LoadWiFiNetworksEvent(page: 1, pageSize: _pageSize));
      },
    );
  }

  Future<void> _onScanNearbyNetworks(
    ScanNearbyNetworksEvent event,
    Emitter<WiFiState> emit,
  ) async {
    emit(const WiFiScanning());

    try {
      final countResult = await getTotalCount(const NoParams());
      int totalCount = 0;
      countResult.fold(
        (failure) => totalCount = 0,
        (count) => totalCount = count,
      );

      final savedResult = await getWiFiNetworks(
        const GetWiFiNetworksParams(page: 1, pageSize: 100),
      );

      List<WiFiNetwork> savedNetworks = [];
      bool savedHasMore = false;

      savedResult.fold(
        (failure)  {
    // ✅ AGREGA ESTO
    print('❌ [BLOC] Error cargando redes: ${failure.message}');
    savedNetworks = [];
  },
        (networks) {
          savedNetworks = networks;
          savedHasMore = networks.length < totalCount;
        },
      );
      // ✅ AGREGA ESTO
print('🔍 [BLOC] savedNetworks cargadas: ${savedNetworks.length}');
for (final n in savedNetworks) {
  print('  → SSID: ${n.ssid} | BSSID: ${n.bssid}');
}
print('🔍 [BLOC] totalCount: $totalCount');

      final canScan = await wifi_iot.WiFiForIoTPlugin.isEnabled();
      if (!canScan) {
        emit(WiFiError('El WiFi está desactivado. Actívalo para escanear.'));
        return;
      }

      String? connectedSsid;
      String? connectedBssid;
      try {
        final isConn = await wifi_iot.WiFiForIoTPlugin.isConnected();
        if (isConn) {
          connectedSsid = (await wifi_iot.WiFiForIoTPlugin.getSSID())
              ?.replaceAll('"', '')
              .trim();
          connectedBssid =
              (await wifi_iot.WiFiForIoTPlugin.getBSSID())?.trim();
        }
      } catch (e) {
        print('⚠️ No se pudo obtener red conectada: $e');
      }

      // ignore: deprecated_member_use
      final results = await wifi_iot.WiFiForIoTPlugin.loadWifiList();

      if (results.isEmpty) {
        emit(WiFiNearbyLoaded(
          nearbyNetworks: [],
          savedNetworks: savedNetworks,
          savedTotalCount: totalCount,
          savedCurrentPage: 1,
          savedHasMorePages: savedHasMore,
          connectedSsid: connectedSsid,
          connectedBssid: connectedBssid,
        ));
        return;
      }

      final nearby = results
          .where((ap) =>
              ap.ssid != null &&
              ap.ssid!
                  .toUpperCase()
                  .startsWith(_entomoPrefix.toUpperCase()))
          .map((ap) => NearbyWiFiNetwork(
                ssid: ap.ssid ?? '',
                bssid: ap.bssid ?? '',
                signalStrength: ap.level ?? -100,
                isEntomo: true,
              ))
          .toList()
        ..sort((a, b) => b.signalStrength.compareTo(a.signalStrength));

      emit(WiFiNearbyLoaded(
        nearbyNetworks: nearby,
        savedNetworks: savedNetworks,
        savedTotalCount: totalCount,
        savedCurrentPage: 1,
        savedHasMorePages: savedHasMore,
        connectedSsid: connectedSsid,
        connectedBssid: connectedBssid,
      ));
    } catch (e) {
      emit(WiFiError('Error al escanear redes: $e'));
    }
  }

  Future<void> _onBackToSavedNetworks(
    BackToSavedNetworksEvent event,
    Emitter<WiFiState> emit,
  ) async {
    if (state is WiFiNearbyLoaded) {
      final s = state as WiFiNearbyLoaded;
      if (s.savedNetworks.isNotEmpty) {
        emit(WiFiLoaded(
          networks: s.savedNetworks,
          currentPage: s.savedCurrentPage,
          totalCount: s.savedTotalCount,
          hasMorePages: s.savedHasMorePages,
        ));
      }
    } else if (state is WiFiSavedFromNearby) {
      final s = state as WiFiSavedFromNearby;
      if (s.savedNetworks.isNotEmpty) {
        emit(WiFiLoaded(
          networks: s.savedNetworks,
          currentPage: s.savedCurrentPage,
          totalCount: s.savedTotalCount,
          hasMorePages: s.savedHasMorePages,
        ));
      }
    }

    final countResult = await getTotalCount(const NoParams());
    int totalCount = 0;
    countResult.fold(
      (failure) => totalCount = 0,
      (count) => totalCount = count,
    );

    final result = await getWiFiNetworks(
      const GetWiFiNetworksParams(page: 1, pageSize: 10),
    );

    result.fold(
      (failure) => null,
      (networks) {
        final hasMore = (1 * 10) < totalCount;
        emit(WiFiLoaded(
          networks: networks,
          currentPage: 1,
          totalCount: totalCount,
          hasMorePages: hasMore,
        ));
      },
    );
  }

  Future<void> _onSaveAndConnectNearby(
    SaveAndConnectNearbyEvent event,
    Emitter<WiFiState> emit,
  ) async {
    WiFiNearbyLoaded? nearbyState;
    if (state is WiFiNearbyLoaded) {
      nearbyState = state as WiFiNearbyLoaded;
    }

    final result = await saveWiFiNetwork(
      SaveWiFiNetworkParams(
        ssid: event.ssid,
        password: event.password,
        bssid: event.bssid,
        name: event.name,
      ),
    );

    result.fold(
      (failure) => print('⚠️ Error guardando red: ${failure.message}'),
      (network) {
        if (nearbyState != null) {
          final updatedSaved = [...nearbyState.savedNetworks, network];
          emit(WiFiSavedFromNearby(
            network: network,
            nearbyNetworks: nearbyState.nearbyNetworks,
            savedNetworks: updatedSaved,
            savedTotalCount: nearbyState.savedTotalCount + 1,
            savedCurrentPage: nearbyState.savedCurrentPage,
            savedHasMorePages: nearbyState.savedHasMorePages,
            connectedSsid: nearbyState.connectedSsid,
            connectedBssid: nearbyState.connectedBssid,
          ));
        }
      },
    );
  }
}