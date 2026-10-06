import 'package:shared_preferences/shared_preferences.dart';

class DownloadConfigService {
  static const String _keyDownloadPath = 'download_path';
  
  static const String pathDownloads = '/storage/emulated/0/Download';
  static const String pathDocuments = '/storage/emulated/0/Documents';
  static const String pathPictures  = '/storage/emulated/0/Pictures';

  static const List<DownloadPathOption> predefinedPaths = [
    DownloadPathOption(
      label: 'Descargas',
      path: pathDownloads,
      icon: 'download',
    ),
    DownloadPathOption(
      label: 'Documentos',
      path: pathDocuments,
      icon: 'description',
    ),
    DownloadPathOption(
      label: 'Imágenes',
      path: pathPictures,
      icon: 'image',
    ),
  ];

  /// Obtener la ruta de descarga guardada
  static Future<String> getDownloadPath() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyDownloadPath) ?? pathDownloads;
  }

  /// Guardar la ruta de descarga
  static Future<bool> saveDownloadPath(String path) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.setString(_keyDownloadPath, path);
  }

  /// Verificar si la ruta es una de las predefinidas
  static bool isPredefinedPath(String path) {
    return predefinedPaths.any((p) => p.path == path);
  }
}

class DownloadPathOption {
  final String label;
  final String path;
  final String icon;

  const DownloadPathOption({
    required this.label,
    required this.path,
    required this.icon,
  });
}