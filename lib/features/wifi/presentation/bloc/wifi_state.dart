import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart' show IconData, Icons;
import '../../domain/entities/wifi_network.dart';

abstract class WiFiState extends Equatable {
  const WiFiState();

  @override
  List<Object?> get props => [];
}

class WiFiInitial extends WiFiState {
  const WiFiInitial();
}

class WiFiLoading extends WiFiState {
  const WiFiLoading();
}

class WiFiLoadingMore extends WiFiState {
  final List<WiFiNetwork> currentNetworks;
  const WiFiLoadingMore(this.currentNetworks);

  @override
  List<Object?> get props => [currentNetworks];
}

class WiFiLoaded extends WiFiState {
  final List<WiFiNetwork> networks;
  final int currentPage;
  final int totalCount;
  final bool hasMorePages;

  const WiFiLoaded({
    required this.networks,
    required this.currentPage,
    required this.totalCount,
    required this.hasMorePages,
  });

  @override
  List<Object?> get props => [networks, currentPage, totalCount, hasMorePages];

  bool get canLoadMore => hasMorePages;
  bool get isEmpty => networks.isEmpty;

  WiFiLoaded copyWith({
    List<WiFiNetwork>? networks,
    int? currentPage,
    int? totalCount,
    bool? hasMorePages,
  }) {
    return WiFiLoaded(
      networks: networks ?? this.networks,
      currentPage: currentPage ?? this.currentPage,
      totalCount: totalCount ?? this.totalCount,
      hasMorePages: hasMorePages ?? this.hasMorePages,
    );
  }
}

class WiFiError extends WiFiState {
  final String message;
  const WiFiError(this.message);

  @override
  List<Object?> get props => [message];
}

class WiFiSaving extends WiFiState {
  const WiFiSaving();
}

class WiFiSaved extends WiFiState {
  final WiFiNetwork network;
  const WiFiSaved(this.network);

  @override
  List<Object?> get props => [network];
}

class WiFiDeleting extends WiFiState {
  final String networkId;
  const WiFiDeleting(this.networkId);

  @override
  List<Object?> get props => [networkId];
}

class WiFiDeleted extends WiFiState {
  final String networkId;
  const WiFiDeleted(this.networkId);

  @override
  List<Object?> get props => [networkId];
}

// ✅ Estado especial para guardar desde escaneo
// No interrumpe el flujo de la pantalla de escaneo
class WiFiSavedFromNearby extends WiFiState {
  final WiFiNetwork network;
  final List<NearbyWiFiNetwork> nearbyNetworks;
  final List<WiFiNetwork> savedNetworks;
  final int savedTotalCount;
  final int savedCurrentPage;
  final bool savedHasMorePages;
  final String? connectedSsid;
  final String? connectedBssid;

  const WiFiSavedFromNearby({
    required this.network,
    required this.nearbyNetworks,
    required this.savedNetworks,
    required this.savedTotalCount,
    required this.savedCurrentPage,
    required this.savedHasMorePages,
    this.connectedSsid,
    this.connectedBssid,
  });

  @override
  List<Object?> get props => [
        network,
        nearbyNetworks,
        savedNetworks,
        savedTotalCount,
        savedCurrentPage,
        savedHasMorePages,
        connectedSsid,
        connectedBssid,
      ];
}

class NearbyWiFiNetwork extends Equatable {
  final String ssid;
  final String bssid;
  final int signalStrength;
  final bool isEntomo;

  const NearbyWiFiNetwork({
    required this.ssid,
    required this.bssid,
    required this.signalStrength,
    required this.isEntomo,
  });

  int get signalPercent {
    if (signalStrength >= -50) return 100;
    if (signalStrength <= -100) return 0;
    return (2 * (signalStrength + 100)).clamp(0, 100);
  }

  IconData get signalIcon {
    final p = signalPercent;
    if (p >= 75) return Icons.signal_wifi_4_bar;
    if (p >= 50) return Icons.network_wifi_3_bar;
    if (p >= 25) return Icons.network_wifi_2_bar;
    return Icons.network_wifi_1_bar;
  }

  @override
  List<Object?> get props => [ssid, bssid, signalStrength];
}

class WiFiScanning extends WiFiState {
  const WiFiScanning();
}

class WiFiNearbyLoaded extends WiFiState {
  final List<NearbyWiFiNetwork> nearbyNetworks;
  final List<WiFiNetwork> savedNetworks;
  final int savedTotalCount;
  final int savedCurrentPage;
  final bool savedHasMorePages;
  final String? connectedSsid;
  final String? connectedBssid;

  const WiFiNearbyLoaded({
    required this.nearbyNetworks,
    required this.savedNetworks,
    required this.savedTotalCount,
    required this.savedCurrentPage,
    required this.savedHasMorePages,
    this.connectedSsid,
    this.connectedBssid,
  });

  @override
  List<Object?> get props => [
        nearbyNetworks,
        savedNetworks,
        savedTotalCount,
        savedCurrentPage,
        savedHasMorePages,
        connectedSsid,
        connectedBssid,
      ];
}