import 'package:equatable/equatable.dart';

abstract class WiFiEvent extends Equatable {
  const WiFiEvent();

  @override
  List<Object?> get props => [];
}

class LoadWiFiNetworksEvent extends WiFiEvent {
  final int page;
  final int pageSize;

  const LoadWiFiNetworksEvent({
    this.page = 1,
    this.pageSize = 10,
  });

  @override
  List<Object?> get props => [page, pageSize];
}

class LoadMoreWiFiNetworksEvent extends WiFiEvent {
  const LoadMoreWiFiNetworksEvent();
}

class RefreshWiFiNetworksEvent extends WiFiEvent {
  const RefreshWiFiNetworksEvent();
}

class SaveWiFiNetworkEvent extends WiFiEvent {
  final String ssid;
  final String password;
  final String? bssid; // ✅ NUEVO

  const SaveWiFiNetworkEvent({
    required this.ssid,
    required this.password,
    this.bssid,
  });

  @override
  List<Object?> get props => [ssid, password, bssid];
}

class UpdateWiFiNetworkEvent extends WiFiEvent {
  final String id;
  final String ssid;
  final String password;
  final String? bssid;
  final String? name;

  const UpdateWiFiNetworkEvent({
    required this.id,
    required this.ssid,
    required this.password,
    this.bssid,
    this.name,
  });

  @override
  List<Object?> get props => [id, ssid, password, bssid, name];
}

class DeleteWiFiNetworkEvent extends WiFiEvent {
  final String id;
  const DeleteWiFiNetworkEvent(this.id);

  @override
  List<Object?> get props => [id];
}

class ScanNearbyNetworksEvent extends WiFiEvent {
  const ScanNearbyNetworksEvent();
}

class BackToSavedNetworksEvent extends WiFiEvent {
  const BackToSavedNetworksEvent();
}

class SaveAndConnectNearbyEvent extends WiFiEvent {
  final String ssid;
  final String bssid;
  final String password;
  final String? name;

  const SaveAndConnectNearbyEvent({
    required this.ssid,
    required this.bssid,
    required this.password,
    this.name,
  });

  @override
  List<Object?> get props => [ssid, bssid, password, name];
}