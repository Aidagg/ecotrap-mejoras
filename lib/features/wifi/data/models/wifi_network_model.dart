import 'package:hive/hive.dart';
import '../../domain/entities/wifi_network.dart';

part 'wifi_network_model.g.dart';

@HiveType(typeId: 0)
class WiFiNetworkModel extends WiFiNetwork {
  @HiveField(0)
  @override
  final String id;

  @HiveField(1)
  @override
  final String ssid;

  @HiveField(2)
  @override
  final String password;

  @HiveField(3)
  @override
  final DateTime createdAt;

  @HiveField(4)
  @override
  final DateTime? updatedAt;

  @HiveField(5)
  @override
  final String? bssid;

  /// Nombre amigable del trap (last_cycle.id_trap). HiveField(6) — nunca reutilizar índices anteriores.
  @HiveField(6)
  @override
  final String? name;

  const WiFiNetworkModel({
    required this.id,
    required this.ssid,
    required this.password,
    this.bssid,
    this.name,
    required this.createdAt,
    this.updatedAt,
  }) : super(
          id: id,
          ssid: ssid,
          password: password,
          bssid: bssid,
          name: name,
          createdAt: createdAt,
          updatedAt: updatedAt,
        );

  factory WiFiNetworkModel.fromEntity(WiFiNetwork entity) {
    return WiFiNetworkModel(
      id: entity.id,
      ssid: entity.ssid,
      password: entity.password,
      bssid: entity.bssid,
      name: entity.name,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
    );
  }

  factory WiFiNetworkModel.fromJson(Map<String, dynamic> json) {
    return WiFiNetworkModel(
      id: json['id'] as String,
      ssid: json['ssid'] as String,
      password: json['password'] as String,
      bssid: json['bssid'] as String?,
      name: json['name'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'ssid': ssid,
      'password': password,
      'bssid': bssid,
      'name': name,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  WiFiNetworkModel copyWithModel({
    String? id,
    String? ssid,
    String? password,
    String? bssid,
    String? name,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return WiFiNetworkModel(
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