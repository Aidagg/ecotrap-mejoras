import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/services.dart';

class WiFiReconnectService {
  static const _keyLastSsid = 'last_wifi_ssid';
  static const _keyLastPassword = 'last_wifi_password';
  static const _keyLastBssid = 'last_wifi_bssid';

  static const _androidOptions = AndroidOptions(
    encryptedSharedPreferences: true,
    sharedPreferencesName: 'ecotrap_wifi_prefs',
  );

  static const _channel =
      MethodChannel('es.ecotrap.ecotrap/wifi_network');

  static final _storage = const FlutterSecureStorage(
    aOptions: _androidOptions,
  );

  // ✅ Guardar credenciales de la última WiFi conectada
  static Future<void> saveLastWifi({
    required String ssid,
    required String password,
    String? bssid,
  }) async {
    await _storage.write(
        key: _keyLastSsid,
        value: ssid,
        aOptions: _androidOptions);
    await _storage.write(
        key: _keyLastPassword,
        value: password,
        aOptions: _androidOptions);
    if (bssid != null && bssid.isNotEmpty) {
      await _storage.write(
          key: _keyLastBssid,
          value: bssid,
          aOptions: _androidOptions);
    }
    print('💾 Última WiFi guardada: $ssid');
  }

  static Future<Map<String, String>?> getLastWifi() async {
    final ssid = await _storage.read(
        key: _keyLastSsid, aOptions: _androidOptions);
    final password = await _storage.read(
        key: _keyLastPassword, aOptions: _androidOptions);
    final bssid = await _storage.read(
        key: _keyLastBssid, aOptions: _androidOptions);

    if (ssid == null || password == null) return null;
    return {
      'ssid': ssid,
      'password': password,
      if (bssid != null) 'bssid': bssid,
    };
  }

  // ✅ Reconectar a la última WiFi conocida
  static Future<bool> reconnectToLastWifi() async {
    try {
      final creds = await getLastWifi();
      if (creds == null) {
        print('⚠️ No hay credenciales WiFi guardadas');
        return false;
      }

      print('🔄 Reconectando a: ${creds['ssid']}...');

      final resultMap =
          await _channel.invokeMapMethod<String, dynamic>(
        'connectToWifi',
        {
          'ssid': creds['ssid']!,
          'password': creds['password']!,
          if (creds['bssid'] != null) 'bssid': creds['bssid']!,
        },
      );

      final success = resultMap?['success'] as bool? ?? false;
      print(success
          ? '✅ Reconectado a ${creds['ssid']}'
          : '❌ No se pudo reconectar a ${creds['ssid']}');
      return success;
    } catch (e) {
      print('❌ Error en reconexión: $e');
      return false;
    }
  }
}