import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiConfigService {
  // ✅ Nombre específico para evitar colisiones con otros storages
  static const _androidOptions = AndroidOptions(
    encryptedSharedPreferences: true,
    sharedPreferencesName: 'ecotrap_api_prefs',
    preferencesKeyPrefix: 'api_',
  );

  static const _storage = FlutterSecureStorage(
    aOptions: _androidOptions,
  );

  static const String _apiKeyKey = 'api_key_encrypted';
  static const String _baseUrlKey = 'base_url_encrypted';

  static const String defaultBaseUrl = 'http://192.168.100.10/api';

  static Future<bool> saveApiKey(String apiKey) async {
    try {
      await _storage.delete(key: _apiKeyKey, aOptions: _androidOptions);
      await _storage.write(
          key: _apiKeyKey,
          value: apiKey,
          aOptions: _androidOptions);
      print('🔐 API Key guardada de forma encriptada: ✅');
      return true;
    } catch (e) {
      print('❌ Error guardando API Key: $e');
      return false;
    }
  }

  static Future<String?> getApiKey() async {
    try {
      final apiKey = await _storage.read(
          key: _apiKeyKey, aOptions: _androidOptions);
      if (apiKey != null) {
        print(
            '🔐 API Key obtenida: ✅ (${apiKey.isEmpty ? "vacía" : "${apiKey.length} caracteres"})');
      } else {
        print('🔐 API Key: ❌ No configurada');
      }
      return apiKey;
    } catch (e) {
      print('❌ Error obteniendo API Key: $e');
      return null;
    }
  }

  static Future<bool> hasApiKey() async {
    final apiKey = await getApiKey();
    return apiKey != null;
  }

  static Future<bool> deleteApiKey() async {
    try {
      await _storage.delete(
          key: _apiKeyKey, aOptions: _androidOptions);
      print('🔐 API Key eliminada: ✅');
      return true;
    } catch (e) {
      print('❌ Error eliminando API Key: $e');
      return false;
    }
  }

  static Future<bool> saveBaseUrl(String baseUrl) async {
    try {
      await _storage.delete(key: _baseUrlKey, aOptions: _androidOptions);
      await _storage.write(
          key: _baseUrlKey,
          value: baseUrl,
          aOptions: _androidOptions);
      print('🔐 URL base guardada de forma encriptada: ✅');
      return true;
    } catch (e) {
      print('❌ Error guardando URL base: $e');
      return false;
    }
  }

  static Future<String> getBaseUrl() async {
    try {
      final baseUrl = await _storage.read(
          key: _baseUrlKey, aOptions: _androidOptions);
      return baseUrl ?? defaultBaseUrl;
    } catch (e) {
      print('❌ Error obteniendo URL base: $e');
      return defaultBaseUrl;
    }
  }

  static bool isValidApiKey(String apiKey) {
    if (apiKey.isEmpty) return false;
    if (apiKey.length < 16) return false;
    final regex = RegExp(r'^[a-zA-Z0-9]+$');
    if (!regex.hasMatch(apiKey)) return false;
    return true;
  }

  static bool isValidBaseUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme &&
          (uri.scheme == 'http' || uri.scheme == 'https');
    } catch (e) {
      return false;
    }
  }

  static Future<ApiConfig> getConfig() async {
    final apiKey = await getApiKey();
    final baseUrl = await getBaseUrl();
    return ApiConfig(apiKey: apiKey, baseUrl: baseUrl);
  }

  static Future<bool> saveConfig({
    required String apiKey,
    String? baseUrl,
  }) async {
    final keySaved = await saveApiKey(apiKey);
    if (!keySaved) {
      print('❌ Falló al guardar API Key');
      return false;
    }
    if (baseUrl != null && baseUrl.isNotEmpty) {
      final urlSaved = await saveBaseUrl(baseUrl);
      if (!urlSaved) {
        print('❌ Falló al guardar URL base');
        return false;
      }
    } else {
      // Campo vacío → borrar clave para que getBaseUrl() devuelva defaultBaseUrl
      await _storage.delete(key: _baseUrlKey, aOptions: _androidOptions);
    }
    print('🔐 Configuración completa guardada de forma encriptada: ✅');
    return true;
  }

  static Future<bool> clearConfig() async {
    try {
      await _storage.delete(
          key: _apiKeyKey, aOptions: _androidOptions);
      await _storage.delete(
          key: _baseUrlKey, aOptions: _androidOptions);
      print('🧹 Configuración limpiada');
      return true;
    } catch (e) {
      print('❌ Error limpiando configuración: $e');
      return false;
    }
  }

  static Future<void> deleteAll() async {
    try {
      await _storage.deleteAll(aOptions: _androidOptions);
      print('🧹 Todo el almacenamiento seguro limpiado');
    } catch (e) {
      print('❌ Error limpiando almacenamiento: $e');
    }
  }
}

class ApiConfig {
  final String? apiKey;
  final String baseUrl;

  ApiConfig({
    this.apiKey,
    required this.baseUrl,
  });

  bool get isConfigured => apiKey != null && apiKey!.isNotEmpty;

  @override
  String toString() =>
      'ApiConfig(apiKey: ${apiKey != null ? (apiKey!.isEmpty ? '""' : '***') : 'null'}, baseUrl: $baseUrl)';
}