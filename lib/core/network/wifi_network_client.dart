import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/services.dart';
import 'wifi_reconnect_service.dart';

class WifiNetworkClient {
  static const _channel =
      MethodChannel('es.ecotrap.ecotrap/wifi_network');

  static bool _isRunningWithInternet = false;
  static Function()? onWifiRebound;

  static Future<bool> isWifiAvailable() async {
    if (!Platform.isAndroid) return true;
    try {
      final success = await bindProcessToWifi();
      if (success) return true;
    } catch (_) {}

    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );
      return interfaces.any(
        (iface) =>
            iface.name.toLowerCase().contains('wlan') ||
            iface.name.toLowerCase().contains('wifi') ||
            iface.name.toLowerCase().contains('wl'),
      );
    } catch (e) {
      print('⚠️ Error verificando interfaces: $e');
      return true;
    }
  }

  static Future<bool> bindProcessToWifi() async {
    if (!Platform.isAndroid) return true;
    try {
      final success =
          await _channel.invokeMethod<bool>('bindToWifi') ??
              false;
      print(success
          ? '✅ Proceso vinculado a WiFi exitosamente'
          : '❌ No se pudo vincular a WiFi');
      return success;
    } on PlatformException catch (e) {
      print('⚠️ Error en bindToWifi: ${e.message}');
      return false;
    }
  }

  static Future<void> unbindNetwork() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('unbindNetwork');
      print('🔓 Red desvinculada');
    } on PlatformException catch (e) {
      print('⚠️ Error desvinculando red: ${e.message}');
    }
  }

  static Future<String?> _getWifiIpAddress() async {
    for (int attempt = 0; attempt < 3; attempt++) {
      try {
        final ip = await _channel
            .invokeMethod<String>('getWifiIpAddress');
        if (ip != null && ip.isNotEmpty) return ip;
      } on PlatformException catch (e) {
        print('⚠️ Canal nativo falló: ${e.message}');
      }

      try {
        final interfaces = await NetworkInterface.list(
          type: InternetAddressType.IPv4,
          includeLinkLocal: false,
        );
        final wifiInterface = interfaces.firstWhere(
          (iface) =>
              iface.name.toLowerCase().contains('wlan') ||
              iface.name.toLowerCase().contains('wifi') ||
              iface.name.toLowerCase().contains('wl'),
        );
        return wifiInterface.addresses.first.address;
      } catch (_) {}

      if (attempt < 2) {
        await Future.delayed(
            const Duration(milliseconds: 600));
      }
    }
    return null;
  }

  static Future<void> bindDioToWifi(Dio dio) async {
    if (!Platform.isAndroid) return;

    int retries = 0;
    while (_isRunningWithInternet && retries < 20) {
      await Future.delayed(
          const Duration(milliseconds: 300));
      retries++;
    }

    await bindProcessToWifi();

    final wifiIp = await _getWifiIpAddress();
    print('📶 IP WiFi: $wifiIp');

    dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () {
        final client = HttpClient();
        client.connectionTimeout =
            const Duration(seconds: 10);
        return client;
      },
    );

    print('✅ Dio configurado para WiFi');
  }

  // ✅ Intentar binding con auto-reconexión si falla
  static Future<bool> _bindWithAutoReconnect() async {
    // Intento 1: binding directo
    final direct = await bindProcessToWifi();
    if (direct) return true;

    print('📶 Binding directo falló, intentando reconexión WiFi...');

    // Intento 2: reconectar a última WiFi conocida
    final reconnected =
        await WiFiReconnectService.reconnectToLastWifi();
    if (!reconnected) {
      print('❌ Reconexión automática falló');
      return false;
    }

    // Esperar a que Android establezca la red
    await Future.delayed(const Duration(seconds: 2));

    // Intento 3: binding después de reconexión
    for (int i = 0; i < 5; i++) {
      final bound = await bindProcessToWifi();
      if (bound) {
        print('✅ Binding exitoso tras reconexión');
        return true;
      }
      await Future.delayed(
          Duration(milliseconds: 500 + (i * 300)));
    }

    return false;
  }

  static Future<T> runWithInternet<T>(
      Future<T> Function() action) async {
    if (!Platform.isAndroid) return action();

    int retries = 0;
    while (_isRunningWithInternet && retries < 30) {
      await Future.delayed(
          const Duration(milliseconds: 200));
      retries++;
    }

    _isRunningWithInternet = true;
    print('🌐 Desvinculando WiFi para usar internet...');

    try {
      await unbindNetwork();
      await Future.delayed(
          const Duration(milliseconds: 800));
      print('🌐 Ejecutando petición con internet...');
      final result = await action();
      return result;
    } catch (e) {
      print('❌ Error durante petición de internet: $e');
      rethrow;
    } finally {
      print(
          '📶 Re-vinculando a WiFi después de internet...');

      // ✅ Usar auto-reconexión en el rebind
      bool rebindSuccess = await _bindWithAutoReconnect();

      if (rebindSuccess) {
        // Verificar que hay IP real
        final ip = await _getWifiIpAddress();
        if (ip != null) {
          print('✅ WiFi re-vinculado con IP: $ip');
        } else {
          // Esperar más y reintentar IP
          await Future.delayed(const Duration(seconds: 1));
          final ip2 = await _getWifiIpAddress();
          print(ip2 != null
              ? '✅ IP WiFi obtenida: $ip2'
              : '⚠️ Sin IP pero binding activo');
        }
      } else {
        print('❌ No se pudo re-vincular a WiFi');
      }

      try {
        onWifiRebound?.call();
        print('🔄 ApiService notificado para resetear _dio');
      } catch (e) {
        print('⚠️ Error notificando reset: $e');
      }

      _isRunningWithInternet = false;
    }
  }

  static Future<void> ensureWifiBinding() async {
    if (!Platform.isAndroid) return;

    int retries = 0;
    while (_isRunningWithInternet && retries < 20) {
      await Future.delayed(
          const Duration(milliseconds: 300));
      retries++;
    }

    // ✅ Usar auto-reconexión en ensureWifiBinding también
    final success = await _bindWithAutoReconnect();

    if (success) {
      final ip = await _getWifiIpAddress();
      print(ip != null
          ? '✅ WiFi binding asegurado con IP: $ip'
          : '⚠️ WiFi binding activo sin IP confirmada');
    } else {
      print('❌ No se pudo asegurar WiFi binding');
    }
  }
}