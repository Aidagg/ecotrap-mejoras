import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import 'api_config_service.dart';
import 'wifi_network_client.dart';

class ApiService {
  static const int timeoutSeconds = 10;
  static const int maxRetries = 3;
  static const String _folderName = 'EntomoLab-EcoTrap';

  Dio? _dio;

  // ✅ Registrar callback para resetear _dio cuando
  // WiFi se re-vincule después de usar internet
  ApiService() {
    WifiNetworkClient.onWifiRebound = () {
      print('🔄 Reseteando _dio por re-vinculación WiFi');
      _dio = null;
    };
  }

  static Future<Directory> getAppDirectory() async {
    final dir = Directory(
        '/storage/emulated/0/Download/$_folderName');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static Future<Directory> _getFallbackDirectory() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/$_folderName');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<Dio> _getDio() async {
    if (_dio != null) {
      // ✅ Verificar WiFi binding antes de reutilizar
      await WifiNetworkClient.ensureWifiBinding();
      return _dio!;
    }

    final config = await ApiConfigService.getConfig();

    if (!config.isConfigured) {
      throw Exception(
          'API Key no configurada. Por favor configura la API Key primero.');
    }

    print('🔍 Asegurando WiFi en _getDio...');
    // ✅ ensureWifiBinding maneja verificación y binding
    await WifiNetworkClient.ensureWifiBinding();

    print(
        '🔑 Usando API Key: ${config.apiKey!.substring(0, 4)}***');
    print('🌐 URL Base: ${config.baseUrl}');

    _dio = Dio(
      BaseOptions(
        baseUrl: config.baseUrl,
        connectTimeout:
            const Duration(seconds: timeoutSeconds),
        receiveTimeout:
            const Duration(seconds: timeoutSeconds),
        headers: {
          if (config.apiKey != null &&
              config.apiKey!.isNotEmpty)
            'x-api-key': config.apiKey!,
        },
      ),
    );

    await WifiNetworkClient.bindDioToWifi(_dio!);

    _dio!.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          print(
              '🌐 [REQUEST] ${options.method} ${options.uri}');
          return handler.next(options);
        },
        onResponse: (response, handler) {
          print(
              '✅ [RESPONSE] ${response.statusCode} ${response.requestOptions.uri}');
          return handler.next(response);
        },
        onError: (error, handler) {
          print(
              '❌ [ERROR] ${error.response?.statusCode} ${error.message}');
          return handler.next(error);
        },
      ),
    );

    return _dio!;
  }

  void reset() {
    _dio = null;
    print('🔄 ApiService reseteado');
  }

  Future<ApiResponse<List<FileInfo>>> getFiles() async {
    // ✅ Garantizar WiFi antes de empezar
    await WifiNetworkClient.ensureWifiBinding();

    int attempts = 0;

    while (attempts < maxRetries) {
      attempts++;

      try {
        print(
            '📡 Intento $attempts/$maxRetries - Obteniendo lista de archivos...');

        final dio = await _getDio();
        final response = await dio.get('/files');

        if (response.statusCode == 200 &&
            response.data != null) {
          final dynamic raw = response.data;

          // El servidor puede devolver String si no incluye
          // Content-Type: application/json
          Map<String, dynamic> data;
          if (raw is String) {
            try {
              data = jsonDecode(raw) as Map<String, dynamic>;
            } on FormatException {
              // Respuesta de texto plano: endpoint no configurado
              // o API Key incorrecta en el servidor
              return ApiResponse.error(
                'El servidor no está configurado correctamente. '
                'Verifica la URL base y la API Key en Configuración.',
                errorType: ErrorType.unauthorized,
              );
            }
          } else {
            data = raw as Map<String, dynamic>;
          }

          final filesJson = data['files'] as List;

          final files = filesJson
              .map((json) => FileInfo.fromJson(json))
              .toList();

          print('✅ ${files.length} archivos obtenidos');
          return ApiResponse.success(files);
        } else {
          return ApiResponse.error(
            'Respuesta inesperada del servidor',
            statusCode: response.statusCode,
          );
        }
      } on DioException catch (e) {
        print(
            '⚠️ Error en intento $attempts: ${e.message}');

        final shouldNotRetry =
            e.response?.statusCode != null &&
                [400, 401, 403, 404]
                    .contains(e.response!.statusCode);

        if (shouldNotRetry || attempts >= maxRetries) {
          return _handleDioError(e);
        }

        await Future.delayed(
            Duration(seconds: attempts * 2));
      } catch (e) {
        print(
            '🔍 Exception capturada en getFiles: ${e.toString()}');
        if (e
            .toString()
            .contains('API Key no configurada')) {
          return ApiResponse.error(
            'API Key no configurada. Ve a Configuración para configurarla.',
            errorType: ErrorType.unauthorized,
          );
        }
        if (e
            .toString()
            .contains('WIFI_NOT_AVAILABLE')) {
          return ApiResponse.error(
            'Esta app requiere conexión WiFi. Activa el WiFi e intenta de nuevo.',
            errorType: ErrorType.connectionError,
          );
        }
        return ApiResponse.error('Error inesperado: $e');
      }
    }

    return ApiResponse.error(
        'No se pudo obtener la lista de archivos');
  }

  Future<ApiResponse<String>> downloadFile({
    required String fileName,
    required Function(double progress) onProgress,
  }) async {
    // ✅ Garantizar WiFi antes de descargar
    await WifiNetworkClient.ensureWifiBinding();

    try {
      print('📥 Descargando archivo: $fileName');

      Directory directory;
      try {
        directory = await getAppDirectory();
        print(
            '📂 Usando carpeta pública: ${directory.path}');
      } catch (e) {
        print(
            '⚠️ Carpeta pública no disponible, usando privada: $e');
        directory = await _getFallbackDirectory();
      }

      final filePath = '${directory.path}/$fileName';
      print('📂 Guardando en: $filePath');

      final dio = await _getDio();

      final response = await dio.download(
        '/download',
        filePath,
        queryParameters: {'file': fileName},
        onReceiveProgress: (received, total) {
          if (total != -1) {
            final progress = received / total;
            onProgress(progress);
            print(
                '📊 Progreso: ${(progress * 100).toStringAsFixed(0)}%');
          }
        },
      );

      if (response.statusCode == 200) {
        print('✅ Archivo descargado: $filePath');
        return ApiResponse.success(filePath);
      } else {
        return ApiResponse.error(
          'Error al descargar archivo',
          statusCode: response.statusCode,
        );
      }
    } on DioException catch (e) {
      return _handleDioError(e);
    } catch (e) {
      if (e
          .toString()
          .contains('API Key no configurada')) {
        return ApiResponse.error(
          'API Key no configurada. Ve a Configuración para configurarla.',
          errorType: ErrorType.unauthorized,
        );
      }
      print('❌ Error inesperado: $e');
      return ApiResponse.error(
          'Error inesperado al descargar: $e');
    }
  }

  ApiResponse<T> _handleDioError<T>(DioException e) {
    print('🔍 DioException type: ${e.type}');
    print('🔍 statusCode: ${e.response?.statusCode}');
    print('🔍 response data: ${e.response?.data}');
    print('🔍 message: ${e.message}');

    final statusCode = e.response?.statusCode;

    switch (statusCode) {
      case 400:
        return ApiResponse.error(
          'Parámetro incorrecto o faltante',
          statusCode: 400,
          errorType: ErrorType.badRequest,
        );
      case 401:
        return ApiResponse.error(
          'API Key incorrecta. Ve a Configuración para actualizarla.',
          statusCode: 401,
          errorType: ErrorType.unauthorized,
        );
      case 403:
        return ApiResponse.error(
          'Acceso prohibido. Verifica tu API Key en Configuración.',
          statusCode: 403,
          errorType: ErrorType.forbidden,
        );
      case 404:
        return ApiResponse.error(
          'Archivo no encontrado en el servidor',
          statusCode: 404,
          errorType: ErrorType.notFound,
        );
      case 500:
      case 502:
      case 503:
        return ApiResponse.error(
          'Error interno del servidor. Intenta nuevamente más tarde.',
          statusCode: statusCode,
          errorType: ErrorType.serverError,
        );
      default:
        if (e.type ==
                DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.receiveTimeout) {
          return ApiResponse.error(
            'Tiempo de espera agotado. Verifica tu conexión.',
            errorType: ErrorType.timeout,
          );
        }
        if (e.type ==
            DioExceptionType.connectionError) {
          return ApiResponse.error(
            'No se pudo conectar al servidor. Verifica que estés conectado a la red WiFi correcta.',
            errorType: ErrorType.connectionError,
          );
        }
        return ApiResponse.error(
          'Error de red: ${e.message ?? "Desconocido"}',
          errorType: ErrorType.unknown,
        );
    }
  }
}

class FileInfo {
  final String name;
  final int size;

  FileInfo({required this.name, required this.size});

  factory FileInfo.fromJson(Map<String, dynamic> json) {
    return FileInfo(
      name: json['name'] as String,
      size: json['size'] as int,
    );
  }

  String get sizeFormatted {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024)
      return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String get extension {
    final parts = name.split('.');
    return parts.length > 1
        ? parts.last.toUpperCase()
        : 'DESCONOCIDO';
  }

  bool get isImage {
    final ext = extension.toLowerCase();
    return ['jpg', 'jpeg', 'png', 'gif', 'webp']
        .contains(ext);
  }

  bool get isJson => extension.toLowerCase() == 'json';
}

class ApiResponse<T> {
  final bool success;
  final T? data;
  final String? errorMessage;
  final int? statusCode;
  final ErrorType? errorType;

  ApiResponse._({
    required this.success,
    this.data,
    this.errorMessage,
    this.statusCode,
    this.errorType,
  });

  factory ApiResponse.success(T data) =>
      ApiResponse._(success: true, data: data);

  factory ApiResponse.error(
    String message, {
    int? statusCode,
    ErrorType? errorType,
  }) =>
      ApiResponse._(
        success: false,
        errorMessage: message,
        statusCode: statusCode,
        errorType: errorType ?? ErrorType.unknown,
      );
}

enum ErrorType {
  badRequest,
  unauthorized,
  forbidden,
  notFound,
  serverError,
  timeout,
  connectionError,
  permissionDenied,
  storageError,
  unknown,
}