// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'wifi_network_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class WiFiNetworkModelAdapter extends TypeAdapter<WiFiNetworkModel> {
  @override
  final int typeId = 0;

  @override
  WiFiNetworkModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return WiFiNetworkModel(
      id: fields[0] as String,
      ssid: fields[1] as String,
      password: fields[2] as String,
      bssid: fields[5] as String?,
      name: fields[6] as String?,
      createdAt: fields[3] as DateTime,
      updatedAt: fields[4] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, WiFiNetworkModel obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.ssid)
      ..writeByte(2)
      ..write(obj.password)
      ..writeByte(3)
      ..write(obj.createdAt)
      ..writeByte(4)
      ..write(obj.updatedAt)
      ..writeByte(5)
      ..write(obj.bssid)
      ..writeByte(6)
      ..write(obj.name);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WiFiNetworkModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
