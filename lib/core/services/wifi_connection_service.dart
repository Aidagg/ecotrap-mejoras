import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../network/wifi_reconnect_service.dart';
import 'permission_service.dart';

class WiFiConnectionService {
  static const _channel =
      MethodChannel('es.ecotrap.ecotrap/wifi_network');

  Future<WiFiConnectionResult> connect({
    required BuildContext context,
    required String ssid,
    required String password,
    String? bssid,
  }) async {
    try {
      final checkResult =
          await PermissionService.checkAllPermissions();
      if (!checkResult.hasAll) {
        final granted =
            await PermissionService.requestMissingPermissions(
          context,
          checkResult.missing,
        );
        if (!granted) {
          return WiFiConnectionResult(
            success: false,
            message:
                'Se requieren permisos para conectar a WiFi.',
            requiresSettings: false,
          );
        }
      }

      if (!Platform.isAndroid) {
        return WiFiConnectionResult(
          success: false,
          message:
              'Conexión automática solo disponible en Android.',
          requiresSettings: true,
        );
      }

      print('🔄 Conectando a: $ssid (BSSID: $bssid)');

      final resultMap =
          await _channel.invokeMapMethod<String, dynamic>(
        'connectToWifi',
        {
          'ssid': ssid,
          'password': password,
          if (bssid != null && bssid.isNotEmpty)
            'bssid': bssid,
        },
      );

      final success =
          resultMap?['success'] as bool? ?? false;
      final message = resultMap?['message'] as String? ??
          'Error desconocido';

      // ✅ Guardar credenciales si la conexión fue exitosa
      if (success) {
        await WiFiReconnectService.saveLastWifi(
          ssid: ssid,
          password: password,
          bssid: bssid,
        );
        print('💾 Credenciales WiFi guardadas para reconexión automática');
      }

      print(success ? '✅ $message' : '❌ $message');

      return WiFiConnectionResult(
        success: success,
        message: message,
        connectedSSID: success ? ssid : null,
        requiresSettings: false,
      );
    } on PlatformException catch (e) {
      print('❌ PlatformException: ${e.message}');
      return WiFiConnectionResult(
        success: false,
        message: 'Error nativo: ${e.message}',
        requiresSettings: true,
      );
    } catch (e) {
      print('❌ Error conectando a WiFi: $e');
      return WiFiConnectionResult(
        success: false,
        message: 'Error inesperado: $e',
      );
    }
  }

  Future<String?> getConnectedSSID() async {
    try {
      final ssid =
          await _channel.invokeMethod<String>('getConnectedSsid');
      return ssid?.replaceAll('"', '').trim();
    } catch (e) {
      print('⚠️ Error obteniendo SSID: $e');
      return null;
    }
  }

  Future<bool> isWiFiEnabled() async {
    try {
      final result =
          await _channel.invokeMethod<bool>('bindToWifi') ??
              false;
      return result;
    } catch (_) {
      return false;
    }
  }

  Future<bool> disconnect() async {
    try {
      await _channel.invokeMethod('unbindNetwork');
      return true;
    } catch (e) {
      print('⚠️ Error desconectando: $e');
      return false;
    }
  }
}

class WiFiConnectionResult {
  final bool success;
  final String message;
  final String? connectedSSID;
  final bool requiresSettings;

  WiFiConnectionResult({
    required this.success,
    required this.message,
    this.connectedSSID,
    this.requiresSettings = false,
  });
}