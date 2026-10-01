import 'package:equatable/equatable.dart';

class WiFiNetwork extends Equatable {
  final String id;
  final String ssid;
  final String password;
  final String? bssid;
  /// Nombre amigable obtenido de last_cycle.id_trap al conectar por primera vez
  final String? name;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const WiFiNetwork({
    required this.id,
    required this.ssid,
    required this.password,
    this.bssid,
    this.name,
    required this.createdAt,
    this.updatedAt,
  });

  /// Etiqueta visible: nombre del trap si existe, SSID como fallback
  String get displayName => name ?? ssid;

  @override
  List<Object?> get props => [id, ssid, password, bssid, name, createdAt, updatedAt];

  @override
  bool get stringify => true;

  WiFiNetwork copyWith({
    String? id,
    String? ssid,
    String? password,
    String? bssid,
    String? name,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return WiFiNetwork(
      id: id ?? this.id,
      ssid: ssid ?? this.ssid,
      password: password ?? this.password,
      bssid: bssid ?? this.bssid,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}