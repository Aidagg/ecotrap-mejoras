import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:wifi_iot/wifi_iot.dart';
import '../../../../core/network/api_service.dart';
import '../../../../core/network/wifi_network_client.dart';
import '../../../../core/utils/app_colors.dart';
import 'api_config_screen.dart';

class FilesListScreen extends StatefulWidget {
  const FilesListScreen({super.key});

  @override
  State<FilesListScreen> createState() => _FilesListScreenState();
}

class _FilesListScreenState extends State<FilesListScreen> {
  final ApiService _apiService = ApiService();

  List<FileInfo>? _files;
  bool _isLoading = false;
  String? _errorMessage;

  FileInfo? _downloadingFile;
  double _downloadProgress = 0.0;
  final Set<String> _selectedFiles = {};
  bool _isSelectionMode = false;
  bool _isDownloadingMultiple = false;
  int _multipleDownloadCurrent = 0;
  int _multipleDownloadTotal = 0;

  Set<String> _downloadedFiles = {};
  String _appDirPath = '';

  // ── WiFi binding ──────────────────────────────
  bool _isBindingWifi = true;
  String? _wifiBindError;

  // ── Cortina de carga ──────────────────────────
  String? _overlayMessage;
  String? _overlaySubMessage;
  double? _overlayProgress;

  @override
  void initState() {
    super.initState();
    _loadLocalState();
    _bindWifiThenLoad();
  }

  @override
  void dispose() {
    _disconnectFromTrap();
    super.dispose();
  }

  Future<void> _disconnectFromTrap() async {
    try {
      await WifiNetworkClient.unbindNetwork();
      await WiFiForIoTPlugin.disconnect();
    } catch (e) {
      debugPrint('⚠️ Error al desconectar de la trampa: $e');
    }
  }

  // ─────────────────────────────────────────────
  // WIFI BINDING FORZADO
  // ─────────────────────────────────────────────

  Future<void> _bindWifiThenLoad() async {
    setState(() {
      _isBindingWifi = true;
      _wifiBindError = null;
    });

    const maxAttempts = 12;
    bool bound = false;

    for (int i = 1; i <= maxAttempts; i++) {
      bound = await WifiNetworkClient.bindProcessToWifi();
      if (bound) break;

      if (!mounted) return;
      await Future.delayed(
          Duration(milliseconds: 500 + (i * 300)));
    }

    if (!mounted) return;

    if (!bound) {
      setState(() {
        _isBindingWifi = false;
        _wifiBindError =
            'No se pudo conectar a la red WiFi de la trampa.\n\n'
            'Asegurate de estar conectado al WiFi correcto e intentalo de nuevo.';
      });
      return;
    }

    setState(() => _isBindingWifi = false);
    await _loadFiles();
  }

  Future<void> _loadLocalState() async {
    try {
      final dir = await ApiService.getAppDirectory();
      final path = dir.path;
      final files =
          dir.listSync().whereType<File>().toList();

      setState(() {
        _appDirPath = path;
        _downloadedFiles =
            files.map((f) => f.path.split('/').last).toSet();
      });
    } catch (e) {
      debugPrint('Error cargando estado local: $e');
    }
  }

  Future<void> _loadDownloadedFiles() async {
    await _loadLocalState();
  }

  Future<void> _loadFiles() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _selectedFiles.clear();
      _isSelectionMode = false;
    });

    final response = await _apiService.getFiles();

    setState(() {
      _isLoading = false;
      if (response.success) {
        _files = response.data;
      } else {
        _errorMessage = response.errorMessage;
        if (response.errorType == ErrorType.unauthorized) {
          _showConfigDialog();
        } else {
          _showErrorDialog(response);
        }
      }
    });
  }

  void _showConfigDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.vpn_key, color: AppColors.golden, size: 28),
          SizedBox(width: 12),
          Expanded(child: Text('API Key Requerida')),
        ]),
        content: const Text(
            'Necesitas configurar tu API Key para acceder al sistema de archivos.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _goToConfig();
            },
            icon: const Icon(Icons.settings),
            label: const Text('Configurar'),
          ),
        ],
      ),
    );
  }

  void _goToConfig() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
          builder: (context) => const ApiConfigScreen()),
    );
    if (result == true) {
      _apiService.reset();
      _loadFiles();
    }
  }

  Future<void> _downloadFile(FileInfo file) async {
    setState(() {
      _downloadingFile = file;
      _downloadProgress = 0.0;
    });

    final response = await _apiService.downloadFile(
      fileName: file.name,
      onProgress: (progress) {
        setState(() => _downloadProgress = progress);
      },
    );

    setState(() {
      _downloadingFile = null;
      _downloadProgress = 0.0;
    });

    if (response.success) {
      await _loadDownloadedFiles();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(children: [
              const Icon(Icons.check_circle,
                  color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                  child: Text('${file.name} descargado')),
            ]),
            backgroundColor: AppColors.secondary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else {
      _showErrorDialog(response);
    }
  }

  Future<void> _downloadSelected() async {
    final toDownload = _selectedFiles
        .where((name) => !_downloadedFiles.contains(name))
        .map((name) =>
            _files!.firstWhere((f) => f.name == name))
        .toList();

    if (toDownload.isEmpty) {
      setState(() {
        _selectedFiles.clear();
        _isSelectionMode = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Todos los archivos seleccionados ya estan descargados'),
          backgroundColor: AppColors.golden,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _isDownloadingMultiple = true;
      _multipleDownloadTotal = toDownload.length;
      _multipleDownloadCurrent = 0;
      _selectedFiles.clear();
      _isSelectionMode = false;
    });

    for (final file in toDownload) {
      setState(() {
        _downloadingFile = file;
        _downloadProgress = 0.0;
        _multipleDownloadCurrent++;
      });

      await _apiService.downloadFile(
        fileName: file.name,
        onProgress: (progress) {
          setState(() => _downloadProgress = progress);
        },
      );
    }

    setState(() {
      _isDownloadingMultiple = false;
      _downloadingFile = null;
      _downloadProgress = 0.0;
    });

    await _loadDownloadedFiles();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(children: [
            const Icon(Icons.check_circle,
                color: Colors.white),
            const SizedBox(width: 12),
            Text(
                '${toDownload.length} archivo${toDownload.length != 1 ? 's' : ''} descargado${toDownload.length != 1 ? 's' : ''}'),
          ]),
          backgroundColor: AppColors.secondary,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ─────────────────────────────────────────────
  // CONTADORES PARA APPBAR
  // ─────────────────────────────────────────────

  int get _pendingDownloadCount => _selectedFiles
      .where((name) => !_downloadedFiles.contains(name))
      .length;

  // ─────────────────────────────────────────────
  // VER ARCHIVOS
  // ─────────────────────────────────────────────

  void _viewImage(FileInfo file) async {
    final filePath = '$_appDirPath/${file.name}';
    final localFile = File(filePath);
    if (!await localFile.exists()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Descarga el archivo primero para verlo'),
            backgroundColor: AppColors.golden,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _ImageViewerScreen(
          filePath: filePath,
          fileName: file.name,
        ),
      ),
    );
  }

  void _viewJson(FileInfo file) async {
    final filePath = '$_appDirPath/${file.name}';
    final localFile = File(filePath);
    if (!await localFile.exists()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Descarga el archivo primero para verlo'),
            backgroundColor: AppColors.golden,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }
    final content = await localFile.readAsString();
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _JsonViewerScreen(
          content: content,
          fileName: file.name,
        ),
      ),
    );
  }

  void _toggleSelection(FileInfo file) {
    setState(() {
      if (_selectedFiles.contains(file.name)) {
        _selectedFiles.remove(file.name);
        if (_selectedFiles.isEmpty)
          _isSelectionMode = false;
      } else {
        _selectedFiles.add(file.name);
      }
    });
  }

  void _selectAll() {
    setState(() {
      if (_selectedFiles.length == _files!.length) {
        _selectedFiles.clear();
        _isSelectionMode = false;
      } else {
        _isSelectionMode = true;
        _selectedFiles
            .addAll(_files!.map((f) => f.name));
      }
    });
  }

  void _showErrorDialog(ApiResponse response) {
    final errorInfo = _getErrorInfo(response.errorType);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Icon(errorInfo.icon,
              color: errorInfo.color, size: 28),
          const SizedBox(width: 12),
          const Expanded(child: Text('Error')),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (response.statusCode != null)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color:
                      errorInfo.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Codigo HTTP: ${response.statusCode}',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: errorInfo.color),
                ),
              ),
            const SizedBox(height: 12),
            Text(
                response.errorMessage ??
                    'Error desconocido',
                style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primarySurface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lightbulb_outline,
                      color: AppColors.forest, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(errorInfo.suggestion,
                        style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.primaryDark)),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (response.errorType ==
                  ErrorType.unauthorized ||
              response.errorType == ErrorType.forbidden)
            TextButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _goToConfig();
              },
              icon: const Icon(Icons.settings),
              label: const Text('Configurar'),
            ),
          if (response.errorType ==
                  ErrorType.connectionError ||
              response.errorType == ErrorType.timeout)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _loadFiles();
              },
              child: const Text('Reintentar'),
            ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  ErrorInfo _getErrorInfo(ErrorType? type) {
    switch (type) {
      case ErrorType.badRequest:
        return ErrorInfo(
            icon: Icons.error_outline,
            color: AppColors.golden,
            suggestion:
                'Verifica que los parametros enviados sean correctos.');
      case ErrorType.unauthorized:
      case ErrorType.forbidden:
        return ErrorInfo(
            icon: Icons.lock,
            color: AppColors.burnt,
            suggestion:
                'Ve a Configuracion para actualizar tu API Key.');
      case ErrorType.notFound:
        return ErrorInfo(
            icon: Icons.search_off,
            color: AppColors.golden,
            suggestion:
                'El archivo solicitado no existe en el servidor.');
      case ErrorType.serverError:
        return ErrorInfo(
            icon: Icons.dns,
            color: AppColors.burnt,
            suggestion:
                'El servidor esta experimentando problemas. Intenta mas tarde.');
      case ErrorType.timeout:
        return ErrorInfo(
            icon: Icons.timer_off,
            color: AppColors.golden,
            suggestion:
                'La conexion es muy lenta. Intenta nuevamente.');
      case ErrorType.connectionError:
        return ErrorInfo(
            icon: Icons.wifi_off,
            color: AppColors.burnt,
            suggestion:
                'Verifica que estes conectado a la red WiFi correcta.');
      case ErrorType.permissionDenied:
        return ErrorInfo(
            icon: Icons.block,
            color: AppColors.burnt,
            suggestion:
                'Necesitas dar permiso de almacenamiento en Configuracion.');
      case ErrorType.storageError:
        return ErrorInfo(
            icon: Icons.sd_storage,
            color: AppColors.golden,
            suggestion:
                'No se pudo acceder al almacenamiento del dispositivo.');
      default:
        return ErrorInfo(
            icon: Icons.error,
            color: AppColors.forest,
            suggestion: 'Ocurrio un error inesperado.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final showCurtain = _overlayMessage != null ||
        _isBindingWifi ||
        _downloadingFile != null ||
        _isDownloadingMultiple;

    String curtainTitle = _overlayMessage ?? '';
    String? curtainSub = _overlaySubMessage;
    double? curtainProgress = _overlayProgress;

    if (_isBindingWifi) {
      curtainTitle = 'Conectando a la trampa...';
      curtainSub = 'Estableciendo enlace WiFi';
    } else if (_isDownloadingMultiple) {
      curtainTitle =
          'Descargando $_multipleDownloadCurrent de $_multipleDownloadTotal';
      curtainSub = _downloadingFile?.name;
      curtainProgress = _multipleDownloadTotal > 0
          ? (_multipleDownloadCurrent - 1 + _downloadProgress) /
              _multipleDownloadTotal
          : null;
    } else if (_downloadingFile != null) {
      curtainTitle = 'Descargando archivo...';
      curtainSub = _downloadingFile!.name;
      curtainProgress = _downloadProgress > 0
          ? _downloadProgress
          : null;
    }

    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: Text(
              _isSelectionMode
                  ? '${_selectedFiles.length} seleccionado${_selectedFiles.length != 1 ? 's' : ''}'
                  : 'Lista de Archivos',
            ),
            actions: [
              if (_isSelectionMode) ...[
                IconButton(
                  icon: Icon(
                    _selectedFiles.length == _files?.length
                        ? Icons.deselect
                        : Icons.select_all,
                  ),
                  onPressed: _selectAll,
                  tooltip: 'Seleccionar todos',
                ),
                if (_pendingDownloadCount > 0)
                  IconButton(
                    icon: Badge(
                      label: Text('$_pendingDownloadCount'),
                      child: const Icon(Icons.download),
                    ),
                    onPressed: _downloadSelected,
                    tooltip:
                        'Descargar $_pendingDownloadCount archivo${_pendingDownloadCount != 1 ? 's' : ''}',
                  ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() {
                    _selectedFiles.clear();
                    _isSelectionMode = false;
                  }),
                  tooltip: 'Cancelar',
                ),
              ] else ...[
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color:
                            Colors.white.withOpacity(0.2),
                        borderRadius:
                            BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.settings,
                          size: 20),
                    ),
                    onPressed: _goToConfig,
                    tooltip: 'Configuracion',
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _isLoading ? null : _loadFiles,
                  tooltip: 'Recargar',
                ),
              ],
            ],
          ),
          body: _buildBody(),
        ),

        if (showCurtain)
          _FilesLoadingCurtain(
            title: curtainTitle,
            subtitle: curtainSub,
            progress: curtainProgress,
          ),
      ],
    );
  }

  Widget _buildBody() {
    if (_isBindingWifi) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Conectando a la trampa...'),
          ],
        ),
      );
    }

    if (_wifiBindError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.wifi_off,
                  size: 80, color: AppColors.burnt),
              const SizedBox(height: 24),
              Text(
                _wifiBindError!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _bindWifiThenLoad,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar conexion'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 14),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () =>
                    Navigator.pushReplacementNamed(
                        context, '/wifi-list'),
                child:
                    const Text('Ir a redes WiFi guardadas'),
              ),
            ],
          ),
        ),
      );
    }

    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Cargando archivos...'),
          ],
        ),
      );
    }

    if (_errorMessage != null && _files == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline,
                  size: 64, color: AppColors.burnt),
              const SizedBox(height: 16),
              Text(_errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadFiles,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    if (_files == null || _files!.isEmpty) {
      return const Center(
        child: Text('No hay archivos disponibles',
            style: TextStyle(
                fontSize: 16, color: Colors.grey)),
      );
    }

    return Column(
      children: [
        if (_downloadingFile != null)
          Container(
            padding: const EdgeInsets.all(16),
            color: AppColors.primarySurface,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _isDownloadingMultiple
                            ? '$_multipleDownloadCurrent/$_multipleDownloadTotal: ${_downloadingFile!.name}'
                            : 'Descargando: ${_downloadingFile!.name}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${(_downloadProgress * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: _downloadProgress,
                  backgroundColor: Colors.grey[300],
                ),
              ],
            ),
          ),

        Expanded(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _buildFilesTable(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilesTable() {
    return Card(
      elevation: 2,
      child: Column(
        children: [
          Container(
            color: Theme.of(context).primaryColor,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  vertical: 12, horizontal: 12),
              child: Row(
                children: [
                  SizedBox(
                    width: 24,
                    child: Checkbox(
                      value: _files != null &&
                          _selectedFiles.length ==
                              _files!.length &&
                          _files!.isNotEmpty,
                      tristate: true,
                      onChanged: (_) {
                        setState(() =>
                            _isSelectionMode = true);
                        _selectAll();
                      },
                      fillColor:
                          WidgetStateProperty.all(
                              Colors.white),
                      checkColor:
                          Theme.of(context).primaryColor,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    flex: 3,
                    child: Text('Nombre',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontSize: 13)),
                  ),
                  const Expanded(
                    flex: 1,
                    child: Text('Tipo',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontSize: 13)),
                  ),
                  const SizedBox(
                    width: 48,
                    child: Text('KB',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontSize: 13),
                        textAlign: TextAlign.right),
                  ),
                  const SizedBox(width: 32),
                ],
              ),
            ),
          ),

          ...List.generate(_files!.length, (index) {
            final file = _files![index];
            final isEven = index % 2 == 0;
            final isSelected =
                _selectedFiles.contains(file.name);
            final isDownloaded =
                _downloadedFiles.contains(file.name);
            final isCurrentlyDownloading =
                _downloadingFile?.name == file.name;

            return InkWell(
              onTap: isCurrentlyDownloading
                  ? null
                  : () {
                      if (_isSelectionMode) {
                        _toggleSelection(file);
                      } else {
                        if (isDownloaded) {
                          if (file.isImage) {
                            _viewImage(file);
                          } else if (file.isJson) {
                            _viewJson(file);
                          }
                        } else {
                          _downloadFile(file);
                        }
                      }
                    },
              onLongPress: () {
                setState(() {
                  _isSelectionMode = true;
                  _selectedFiles.add(file.name);
                });
              },
              child: Container(
                color: isSelected
                    ? Theme.of(context)
                        .primaryColor
                        .withOpacity(0.1)
                    : isEven
                        ? Colors.grey[50]
                        : Colors.white,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      vertical: 12, horizontal: 12),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 24,
                        child: Checkbox(
                          value: isSelected,
                          onChanged: (_) {
                            setState(() =>
                                _isSelectionMode = true);
                            _toggleSelection(file);
                          },
                          activeColor: Theme.of(context)
                              .primaryColor,
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Nombre
                      Expanded(
                        flex: 3,
                        child: Row(
                          children: [
                            Icon(
                              file.isImage
                                  ? Icons.image
                                  : file.isJson
                                      ? Icons.code
                                      : Icons
                                          .insert_drive_file,
                              color: file.isImage
                                  ? AppColors.primary
                                  : file.isJson
                                      ? AppColors.secondary
                                      : Colors.grey,
                              size: 18,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                file.name,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDownloaded
                                      ? Colors.grey[500]
                                      : null,
                                ),
                                overflow:
                                    TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Tipo
                      Expanded(
                        flex: 1,
                        child: Container(
                          padding:
                              const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 3),
                          decoration: BoxDecoration(
                            color: file.isImage
                                ? AppColors.primarySurface
                                : file.isJson
                                    ? AppColors.secondarySurface
                                    : Colors.grey[200],
                            borderRadius:
                                BorderRadius.circular(4),
                          ),
                          child: Text(
                            file.extension,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: file.isImage
                                  ? AppColors.primaryDark
                                  : file.isJson
                                      ? AppColors.secondaryDark
                                      : Colors.grey[700],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),

                      // Tamaño
                      SizedBox(
                        width: 48,
                        child: Text(
                          file.sizeFormatted,
                          style:
                              const TextStyle(fontSize: 11),
                          textAlign: TextAlign.right,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),

                      // Estado
                      SizedBox(
                        width: 32,
                        child: Center(
                          child: isCurrentlyDownloading
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child:
                                      CircularProgressIndicator(
                                          strokeWidth: 2),
                                )
                              : isDownloaded
                                  ? GestureDetector(
                                      onTap: () {
                                        if (file.isImage) {
                                          _viewImage(file);
                                        } else if (file
                                            .isJson) {
                                          _viewJson(file);
                                        }
                                      },
                                      child: Tooltip(
                                        message:
                                            'Ver archivo',
                                        child: Icon(
                                          (file.isImage ||
                                                  file.isJson)
                                              ? Icons
                                                  .visibility
                                              : Icons
                                                  .check_circle,
                                          color:
                                              AppColors.secondary,
                                          size: 20,
                                        ),
                                      ),
                                    )
                                  : Icon(
                                      Icons
                                          .download_outlined,
                                      color:
                                          Colors.grey[400],
                                      size: 20,
                                    ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ── Cortina de carga ──────────────────────────────────────
class _FilesLoadingCurtain extends StatelessWidget {
  final String title;
  final String? subtitle;
  final double? progress;

  const _FilesLoadingCurtain({
    required this.title,
    this.subtitle,
    this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 40),
          padding: const EdgeInsets.symmetric(
              horizontal: 28, vertical: 32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  shape: BoxShape.circle,
                ),
                child: const Padding(
                  padding: EdgeInsets.all(14),
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryDark,
                ),
                textAlign: TextAlign.center,
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
              if (progress != null) ...[
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progress!.clamp(0.0, 1.0),
                    minHeight: 8,
                    backgroundColor: AppColors.primarySurface,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${(progress! * 100).clamp(0, 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Visor de imagenes ──────────────────────────────────────
class _ImageViewerScreen extends StatelessWidget {
  final String filePath;
  final String fileName;

  const _ImageViewerScreen({
    required this.filePath,
    required this.fileName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(fileName,
            style: const TextStyle(fontSize: 14),
            overflow: TextOverflow.ellipsis),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 5.0,
          child: Image.file(
            File(filePath),
            fit: BoxFit.contain,
            errorBuilder: (context, error, _) =>
                const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.broken_image,
                    color: Colors.white54, size: 64),
                SizedBox(height: 16),
                Text('No se pudo cargar la imagen',
                    style:
                        TextStyle(color: Colors.white54)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Visor de JSON ─────────────────────────────────────────
class _JsonViewerScreen extends StatefulWidget {
  final String content;
  final String fileName;

  const _JsonViewerScreen({
    required this.content,
    required this.fileName,
  });

  @override
  State<_JsonViewerScreen> createState() =>
      _JsonViewerScreenState();
}

class _JsonViewerScreenState
    extends State<_JsonViewerScreen> {
  bool _prettyPrint = true;

  String get _formattedContent {
    try {
      final parsed = jsonDecode(widget.content);
      return _prettyPrint
          ? const JsonEncoder.withIndent('  ')
              .convert(parsed)
          : jsonEncode(parsed);
    } catch (_) {
      return widget.content;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.fileName,
            style: const TextStyle(fontSize: 14),
            overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: Icon(_prettyPrint
                ? Icons.compress
                : Icons.format_align_left),
            onPressed: () => setState(
                () => _prettyPrint = !_prettyPrint),
            tooltip:
                _prettyPrint ? 'Compacto' : 'Formateado',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SelectableText(
            _formattedContent,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

class ErrorInfo {
  final IconData icon;
  final Color color;
  final String suggestion;

  ErrorInfo({
    required this.icon,
    required this.color,
    required this.suggestion,
  });
}
