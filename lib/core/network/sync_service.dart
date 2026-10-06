import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'wifi_network_client.dart';

class SyncService {
  static const String _baseUrl =
      'https://backendmonitorizacion.ecotrap.es/api/v1';
  static const String _keyUser = 'sync_user';
  static const String _keyPassword = 'sync_password';
  static const String _keyToken = 'sync_token';
  static const String _syncedSuffix = '.synced';

  // ✅ Opciones Android para garantizar persistencia
  static const _androidOptions = AndroidOptions(
    encryptedSharedPreferences: true,
    sharedPreferencesName: 'ecotrap_sync_prefs',
    preferencesKeyPrefix: 'ecotrap_',
  );

  final _storage = const FlutterSecureStorage(
    aOptions: _androidOptions,
  );

  Dio get _dio => Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        headers: {'Content-Type': 'application/json'},
      ));

  // ─────────────────────────────────────────────
  // CREDENCIALES
  // ─────────────────────────────────────────────

  Future<bool> hasCredentials() async {
    try {
      final user = await _storage.read(
          key: _keyUser, aOptions: _androidOptions);
      print('🔑 hasCredentials: user=$user');
      return user != null && user.isNotEmpty;
    } catch (e) {
      print('⚠️ Error leyendo credenciales: $e');
      return false;
    }
  }

  Future<void> saveCredentials(
      String user, String password) async {
    try {
      await _storage.write(
          key: _keyUser,
          value: user,
          aOptions: _androidOptions);
      await _storage.write(
          key: _keyPassword,
          value: password,
          aOptions: _androidOptions);
      print('✅ Credenciales guardadas: user=$user');
    } catch (e) {
      print('❌ Error guardando credenciales: $e');
    }
  }

  Future<Map<String, String>?> getCredentials() async {
    try {
      final user = await _storage.read(
          key: _keyUser, aOptions: _androidOptions);
      final password = await _storage.read(
          key: _keyPassword, aOptions: _androidOptions);
      print(
          '🔑 getCredentials: user=$user, hasPass=${password != null}');
      if (user == null ||
          user.isEmpty ||
          password == null ||
          password.isEmpty) return null;
      return {'user': user, 'password': password};
    } catch (e) {
      print('⚠️ Error obteniendo credenciales: $e');
      return null;
    }
  }

  Future<void> clearCredentials() async {
    try {
      await _storage.delete(
          key: _keyUser, aOptions: _androidOptions);
      await _storage.delete(
          key: _keyPassword, aOptions: _androidOptions);
      await _storage.delete(
          key: _keyToken, aOptions: _androidOptions);
      print('🗑️ Credenciales eliminadas');
    } catch (e) {
      print('⚠️ Error eliminando credenciales: $e');
    }
  }

  // ─────────────────────────────────────────────
  // LOGIN
  // ─────────────────────────────────────────────

  Future<String?> login(String user, String password) async {
    try {
      final response =
          await WifiNetworkClient.runWithInternet(
              () async {
        return await _dio.post(
          '$_baseUrl/seguridad/auth/login',
          data: {'user': user, 'password': password},
        );
      });

      final data = response.data as Map<String, dynamic>;
      if (data['status'] == true) {
        final resp =
            data['response'] as Map<String, dynamic>;
        final token = resp['token'] as String;
        final keyToken = resp['key_token'] as String;
        final fullToken = '$token@@||@@$keyToken';

        // ✅ Guardar token y credenciales
        await _storage.write(
            key: _keyToken,
            value: fullToken,
            aOptions: _androidOptions);
        await saveCredentials(user, password);

        print('✅ Login exitoso, token guardado');
        return null;
      } else {
        return data['message'] as String? ??
            'Error de autenticación';
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401 ||
          e.response?.statusCode == 403) {
        return 'Usuario o contraseña incorrectos';
      }
      return 'Error de conexión: ${e.message}';
    } catch (e) {
      return 'Error inesperado: $e';
    }
  }

  Future<String?> _getToken() async {
    try {
      final token = await _storage.read(
          key: _keyToken, aOptions: _androidOptions);
      print(
          '🔑 getToken: ${token != null ? 'existe' : 'null'}');
      return token;
    } catch (e) {
      print('⚠️ Error leyendo token: $e');
      return null;
    }
  }

  // ─────────────────────────────────────────────
  // ARCHIVOS SINCRONIZADOS
  // ─────────────────────────────────────────────

  static bool isSynced(
      String appDirPath, String fileName) {
    final syncedFile =
        File('$appDirPath/$fileName$_syncedSuffix');
    return syncedFile.existsSync();
  }

  static Future<void> markAsSynced(
      String appDirPath, String fileName) async {
    final syncedFile =
        File('$appDirPath/$fileName$_syncedSuffix');
    await syncedFile
        .writeAsString(DateTime.now().toIso8601String());
  }

  static Set<String> loadSyncedFiles(String appDirPath) {
    try {
      final dir = Directory(appDirPath);
      if (!dir.existsSync()) return {};
      return dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith(_syncedSuffix))
          .map((f) {
            final name = f.path.split('/').last;
            return name.replaceAll(_syncedSuffix, '');
          })
          .toSet();
    } catch (_) {
      return {};
    }
  }

  // ─────────────────────────────────────────────
  // SINCRONIZACIÓN
  // ─────────────────────────────────────────────

  Future<String?> syncJson(
      String appDirPath, String fileName) async {
    try {
      // ✅ Si no hay token, hacer login automático
      // con credenciales guardadas
      String? token = await _getToken();
      if (token == null) {
        final creds = await getCredentials();
        if (creds == null) {
          return 'No hay sesión activa. Configura las credenciales en Configuración.';
        }
        final loginError =
            await login(creds['user']!, creds['password']!);
        if (loginError != null) return loginError;
        token = await _getToken();
        if (token == null) {
          return 'No se pudo obtener el token de sesión.';
        }
      }

      final file = File('$appDirPath/$fileName');
      if (!await file.exists()) {
        return 'Archivo no encontrado: $fileName';
      }

      final content = await file.readAsString();
      final Map<String, dynamic> jsonData =
          jsonDecode(content);
      final optionMenu =
          jsonData['option_menu'] as String?;

      if (optionMenu == null) {
        return 'El archivo no tiene campo option_menu';
      }

      final headers = {
        'Authorization': token,
        'Content-Type': 'application/json',
      };

      await WifiNetworkClient.runWithInternet(() async {
        if (optionMenu == '0063') {
          await _uploadMonitorizacion(jsonData, headers);
        } else if (optionMenu == '0064') {
          await _uploadMedicion(jsonData, headers);
        } else {
          throw Exception(
              'Tipo no reconocido: option_menu=$optionMenu');
        }
      });

      await markAsSynced(appDirPath, fileName);
      return null;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        // ✅ Token expirado — re-login automático
        await _storage.delete(
            key: _keyToken, aOptions: _androidOptions);
        final creds = await getCredentials();
        if (creds != null) {
          final loginError = await login(
              creds['user']!, creds['password']!);
          if (loginError == null) {
            // Reintentar con nuevo token
            return syncJson(appDirPath, fileName);
          }
        }
        return 'Sesión expirada. Ve a Configuración para actualizar las credenciales.';
      }
      final msg =
          e.response?.data?['message'] as String?;
      return msg ??
          'Error del servidor: ${e.response?.statusCode}';
    } catch (e) {
      return 'Error inesperado: $e';
    }
  }

  Future<void> _uploadMonitorizacion(
      Map<String, dynamic> data,
      Map<String, String> headers) async {
    if (data.containsKey('image_base64')) {
      final base64 = data['image_base64'] as String;
      if (!base64.startsWith('data:image')) {
        data['image_base64'] =
            'data:image/jpg;base64,$base64';
      }
    }
    await _dio.post(
      '$_baseUrl/web/monitorizacion',
      data: data,
      options: Options(headers: headers),
    );
  }

  Future<void> _uploadMedicion(
      Map<String, dynamic> data,
      Map<String, String> headers) async {
    await _dio.post(
      '$_baseUrl/web/monitorizacion/medicion',
      data: data,
      options: Options(headers: headers),
    );
  }
}