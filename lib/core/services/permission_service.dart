import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';

class PermissionService {
  /// Obtener versión de Android SDK
  static Future<int> getAndroidSdkVersion() async {
    if (!Platform.isAndroid) return 0;
    
    try {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      final sdkInt = androidInfo.version.sdkInt;
      print('📱 Android SDK Version: $sdkInt (Android ${_getAndroidVersionName(sdkInt)})');
      return sdkInt;
    } catch (e) {
      print('⚠️ Error obteniendo versión Android: $e');
      return 0;
    }
  }

  /// Obtener nombre de versión Android
  static String _getAndroidVersionName(int sdkInt) {
    switch (sdkInt) {
      case 35: return '15';
      case 34: return '14';
      case 33: return '13';
      case 32:
      case 31: return '12';
      case 30: return '11';
      case 29: return '10';
      default: return sdkInt.toString();
    }
  }

  /// Verificar todos los permisos necesarios según versión de Android
  static Future<PermissionCheckResult> checkAllPermissions() async {
    if (!Platform.isAndroid) {
      return PermissionCheckResult(
        hasAll: true,
        missing: [],
        message: 'iOS no requiere estos permisos',
      );
    }

    final sdkInt = await getAndroidSdkVersion();
    final missing = <PermissionType>[];

    // ========================================
    // ANDROID 12 (SDK 31-32)
    // ========================================
    if (sdkInt >= 31 && sdkInt <= 32) {
      print('🔵 Android 12 detectado - Verificando permisos...');
      
      // Ubicación precisa (requerida para WiFi en Android 12)
      final locationStatus = await Permission.locationWhenInUse.status;
      print('📍 Ubicación: $locationStatus');
      if (!locationStatus.isGranted) {
        missing.add(PermissionType.location);
      }
      
      // Ubicación en segundo plano (opcional pero recomendado)
      final backgroundLocationStatus = await Permission.locationAlways.status;
      print('📍 Ubicación en segundo plano: $backgroundLocationStatus');
      if (!backgroundLocationStatus.isGranted) {
        missing.add(PermissionType.backgroundLocation);
      }
    }
    
    // ========================================
    // ANDROID 13-15 (SDK 33-35)
    // ========================================
    else if (sdkInt >= 33) {
      print('🟢 Android ${_getAndroidVersionName(sdkInt)} detectado - Verificando permisos...');
      
      // WiFi cercano (reemplaza ubicación en Android 13+)
      try {
        final nearbyStatus = await Permission.nearbyWifiDevices.status;
        print('📶 WiFi cercano: $nearbyStatus');
        
        if (!nearbyStatus.isGranted) {
          missing.add(PermissionType.nearbyWifi);
        }
      } catch (e) {
        print('❌ Error verificando NEARBY_WIFI_DEVICES: $e');
        missing.add(PermissionType.nearbyWifi);
      }
      
      // Ubicación precisa (OPCIONAL en Android 13+, pero algunos dispositivos lo requieren)
      final locationStatus = await Permission.locationWhenInUse.status;
      print('📍 Ubicación (opcional): $locationStatus');
      if (!locationStatus.isGranted) {
        // Solo agregarlo como warning, no bloqueante
        print('⚠️ Ubicación no concedida, pero puede no ser necesaria en Android 13+');
      }
    }
    
    // ========================================
    // ANDROID < 12 (NO SOPORTADO)
    // ========================================
    else {
      return PermissionCheckResult(
        hasAll: false,
        missing: [],
        message: 'Android ${_getAndroidVersionName(sdkInt)} no está soportado. Se requiere Android 12 o superior.',
      );
    }

    final hasAll = missing.isEmpty;
    print(hasAll ? '✅ Todos los permisos concedidos' : '❌ Faltan ${missing.length} permiso(s)');
    
    return PermissionCheckResult(
      hasAll: hasAll,
      missing: missing,
      message: hasAll
          ? 'Todos los permisos concedidos'
          : 'Faltan ${missing.length} permiso(s)',
    );
  }

  /// Solicitar permisos faltantes según versión de Android
  static Future<bool> requestMissingPermissions(
    BuildContext context,
    List<PermissionType> missing,
  ) async {
    final sdkInt = await getAndroidSdkVersion();
    
    for (final permType in missing) {
      print('🔄 Solicitando permiso: $permType');
      
      // Mostrar explicación
      final shouldRequest = await _showPermissionExplanation(context, permType, sdkInt);
      
      if (!shouldRequest) {
        print('❌ Usuario canceló solicitud de $permType');
        return false;
      }

      // Solicitar el permiso
      final granted = await _requestPermission(permType, sdkInt);
      
      print('📋 Resultado $permType: $granted');
      
      if (!granted) {
        // Verificar si fue denegado permanentemente
        final isPermanentlyDenied = await _isPermissionPermanentlyDenied(permType);
        
        if (isPermanentlyDenied && context.mounted) {
          print('🚫 Permiso $permType denegado permanentemente');
          final retry = await _showPermissionDenied(context, permType, sdkInt);
          
          if (retry) {
            await openAppSettings();
          }
          
          return false;
        } else {
          print('⚠️ Permiso $permType denegado (no permanente)');
          return false;
        }
      }
    }

    return true;
  }

  /// Verificar si un permiso fue denegado permanentemente
  static Future<bool> _isPermissionPermanentlyDenied(PermissionType type) async {
    switch (type) {
      case PermissionType.location:
        return await Permission.locationWhenInUse.isPermanentlyDenied;
      case PermissionType.backgroundLocation:
        return await Permission.locationAlways.isPermanentlyDenied;
      case PermissionType.nearbyWifi:
        try {
          return await Permission.nearbyWifiDevices.isPermanentlyDenied;
        } catch (e) {
          return false;
        }
    }
  }

  /// Solicitar un permiso específico según versión de Android
  static Future<bool> _requestPermission(PermissionType type, int sdkInt) async {
    try {
      PermissionStatus status;

      switch (type) {
        case PermissionType.location:
          // Solicitar ubicación precisa
          status = await Permission.locationWhenInUse.request();
          print('📍 Estado después de solicitar ubicación: $status');
          break;
          
        case PermissionType.backgroundLocation:
          // Solo para Android 12
          if (sdkInt >= 31 && sdkInt <= 32) {
            // Primero verificar que ubicación en uso esté concedida
            final whenInUseStatus = await Permission.locationWhenInUse.status;
            if (!whenInUseStatus.isGranted) {
              print('⚠️ Primero se necesita ubicación en uso');
              return false;
            }
            
            status = await Permission.locationAlways.request();
            print('📍 Estado después de solicitar ubicación en segundo plano: $status');
          } else {
            return true; // No necesario en otras versiones
          }
          break;
          
        case PermissionType.nearbyWifi:
          // Solo para Android 13+
          if (sdkInt >= 33) {
            try {
              status = await Permission.nearbyWifiDevices.request();
              print('📶 Estado después de solicitar WiFi cercano: $status');
            } catch (e) {
              print('❌ Error solicitando NEARBY_WIFI_DEVICES: $e');
              
              // Fallback: Intentar con ubicación
              print('🔄 Intentando con ubicación como fallback...');
              status = await Permission.locationWhenInUse.request();
              print('📍 Estado ubicación (fallback): $status');
            }
          } else {
            return true; // No necesario en versiones anteriores
          }
          break;
      }

      return status.isGranted || status.isLimited;
      
    } catch (e) {
      print('❌ Error general solicitando permiso $type: $e');
      return false;
    }
  }

  /// Mostrar explicación del permiso
  static Future<bool> _showPermissionExplanation(
    BuildContext context,
    PermissionType type,
    int sdkInt,
  ) async {
    final info = _getPermissionInfo(type, sdkInt);

    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(info.icon, color: info.color, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                info.title,
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                info.description,
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue[700], size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        info.why,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.blue[900],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Continuar'),
          ),
        ],
      ),
    ) ?? false;
  }

  /// Mostrar mensaje cuando un permiso es denegado
  static Future<bool> _showPermissionDenied(
    BuildContext context,
    PermissionType type,
    int sdkInt,
  ) async {
    final info = _getPermissionInfo(type, sdkInt);

    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.orange, size: 24),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Permiso Denegado',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'El permiso "${info.title}" es necesario para conectar a redes WiFi.',
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              const Text(
                '¿Deseas abrir la configuración para habilitarlo manualmente?',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.settings, size: 18),
            label: const Text('Abrir Configuración'),
          ),
        ],
      ),
    ) ?? false;
  }

  /// Obtener información del permiso según versión de Android
  static PermissionInfo _getPermissionInfo(PermissionType type, int sdkInt) {
    final androidVersion = _getAndroidVersionName(sdkInt);
    
    switch (type) {
      case PermissionType.location:
        return PermissionInfo(
          title: 'Ubicación',
          description: sdkInt >= 33
              ? 'Se necesita acceso a ubicación como respaldo para conexión WiFi.'
              : 'Se necesita acceso a ubicación para escanear y conectar a redes WiFi.',
          why: sdkInt >= 33
              ? 'Algunos dispositivos Android $androidVersion requieren este permiso adicional.'
              : 'Android $androidVersion requiere ubicación para detectar redes WiFi cercanas.',
          icon: Icons.location_on,
          color: Colors.blue,
        );
        
      case PermissionType.backgroundLocation:
        return PermissionInfo(
          title: 'Ubicación en Segundo Plano',
          description: 'Se necesita para mantener la conexión WiFi activa.',
          why: 'Android 12 requiere este permiso para conexiones WiFi estables.',
          icon: Icons.my_location,
          color: Colors.purple,
        );
        
      case PermissionType.nearbyWifi:
        return PermissionInfo(
          title: 'WiFi Cercano',
          description: 'Se necesita acceso a dispositivos WiFi cercanos.',
          why: 'Android $androidVersion usa este permiso en lugar de ubicación para escanear WiFi.',
          icon: Icons.wifi,
          color: Colors.green,
        );
    }
  }
}

enum PermissionType {
  location,
  backgroundLocation,
  nearbyWifi,
}

class PermissionInfo {
  final String title;
  final String description;
  final String why;
  final IconData icon;
  final Color color;

  PermissionInfo({
    required this.title,
    required this.description,
    required this.why,
    required this.icon,
    required this.color,
  });
}

class PermissionCheckResult {
  final bool hasAll;
  final List<PermissionType> missing;
  final String message;

  PermissionCheckResult({
    required this.hasAll,
    required this.missing,
    required this.message,
  });
}