import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../core/network/api_service.dart';
import '../../../../core/network/sync_service.dart';
import '../../../../core/utils/app_colors.dart';
import '../../../files/presentation/pages/api_config_screen.dart';

class UploadPage extends StatefulWidget {
  const UploadPage({super.key});

  @override
  State<UploadPage> createState() => _UploadPageState();
}

class _UploadPageState extends State<UploadPage> {
  final SyncService _syncService = SyncService();

  List<_JsonFileInfo> _files = [];
  bool _isLoading = true;
  String? _error;
  String _appDirPath = '';

  // ── Selección múltiple ────────────────────────
  bool _isSelectionMode = false;
  final Set<String> _selected = {};

  // ── Cortina de carga ──────────────────────────
  _OverlayState? _overlay;

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  // ─────────────────────────────────────────────
  // CARGA DE ARCHIVOS
  // ─────────────────────────────────────────────

  Future<void> _loadFiles() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _selected.clear();
      _isSelectionMode = false;
    });

    try {
      final dir = await ApiService.getAppDirectory();
      _appDirPath = dir.path;

      final syncedSet = SyncService.loadSyncedFiles(_appDirPath);

      final jsonFiles = dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.toLowerCase().endsWith('.json'))
          .map((f) {
            final name = f.path.split('/').last;
            final stat = f.statSync();
            return _JsonFileInfo(
              name: name,
              path: f.path,
              size: stat.size,
              modified: stat.modified,
              isSynced: syncedSet.contains(name),
            );
          })
          .toList()
        ..sort((a, b) {
            // Pendientes primero, luego por fecha descendente
            if (a.isSynced != b.isSynced) {
              return a.isSynced ? 1 : -1;
            }
            return b.modified.compareTo(a.modified);
          });

      setState(() {
        _files = jsonFiles;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error cargando archivos: $e';
        _isLoading = false;
      });
    }
  }

  // ─────────────────────────────────────────────
  // SELECCIÓN
  // ─────────────────────────────────────────────

  void _enterSelectionMode(String firstName) {
    setState(() {
      _isSelectionMode = true;
      _selected.add(firstName);
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selected.clear();
    });
  }

  void _toggleFile(String name) {
    setState(() {
      if (_selected.contains(name)) {
        _selected.remove(name);
        if (_selected.isEmpty) _isSelectionMode = false;
      } else {
        _selected.add(name);
      }
    });
  }

  void _selectAll() {
    // Solo selecciona los que aún no se han sincronizado
    setState(() => _selected
      ..clear()
      ..addAll(
          _files.where((f) => !f.isSynced).map((f) => f.name)));
  }

  void _selectNone() => setState(() => _selected.clear());

  // ─────────────────────────────────────────────
  // CORTINA DE CARGA
  // ─────────────────────────────────────────────

  void _showOverlay(_OverlayState state) =>
      setState(() => _overlay = state);

  void _updateOverlay(_OverlayState state) =>
      setState(() => _overlay = state);

  void _hideOverlay() => setState(() => _overlay = null);

  // ─────────────────────────────────────────────
  // SINCRONIZACIÓN
  // ─────────────────────────────────────────────

  Future<void> _syncSingle(_JsonFileInfo file) async {
    _showOverlay(_OverlayState(
      message: 'Subiendo archivo...',
      fileName: file.name,
    ));

    final error =
        await _syncService.syncJson(_appDirPath, file.name);

    _hideOverlay();
    if (!mounted) return;

    if (error == null) {
      _showSnackbar(
        '${file.name} subido correctamente',
        AppColors.secondary,
        Icons.check_circle,
      );
      await _loadFiles();
    } else {
      _handleSyncError(error);
    }
  }

  Future<void> _syncSelected() async {
    final toUpload = _files
        .where((f) => _selected.contains(f.name))
        .toList();

    if (toUpload.isEmpty) return;

    final errors = <String>[];
    int done = 0;

    _showOverlay(_OverlayState(
      message: 'Preparando subida...',
      current: 0,
      total: toUpload.length,
    ));

    for (final file in toUpload) {
      done++;
      _updateOverlay(_OverlayState(
        message: 'Subiendo archivo...',
        fileName: file.name,
        current: done,
        total: toUpload.length,
      ));

      final error =
          await _syncService.syncJson(_appDirPath, file.name);
      if (error != null) {
        errors.add('${file.name}: $error');
      }
    }

    _hideOverlay();
    if (!mounted) return;

    _exitSelectionMode();

    final uploaded = toUpload.length - errors.length;

    if (errors.isEmpty) {
      _showSnackbar(
        '$uploaded archivo${uploaded != 1 ? 's' : ''} subido${uploaded != 1 ? 's' : ''} correctamente',
        AppColors.secondary,
        Icons.cloud_done,
      );
    } else {
      _showUploadResultDialog(uploaded, errors);
    }

    await _loadFiles();
  }

  void _handleSyncError(String error) {
    final isAuth = error.contains('credenciales') ||
        error.contains('sesión') ||
        error.contains('Configura');

    if (isAuth) {
      _showAuthErrorDialog(error);
    } else {
      _showSnackbar(error, AppColors.burnt, Icons.error_outline);
    }
  }

  // ─────────────────────────────────────────────
  // DIÁLOGOS
  // ─────────────────────────────────────────────

  Future<void> _onFileTap(_JsonFileInfo file) async {
    if (_isSelectionMode) {
      _toggleFile(file.name);
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Icon(
            file.isSynced
                ? Icons.cloud_sync
                : Icons.cloud_upload,
            color: AppColors.primary,
          ),
          const SizedBox(width: 12),
          const Expanded(child: Text('Subir archivo')),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _fileNameChip(file.name),
            const SizedBox(height: 12),
            if (file.isSynced)
              _infoBox(
                '¿Deseas volver a subir este archivo? Ya fue sincronizado.',
                AppColors.secondary,
                Icons.check_circle,
              )
            else
              const Text(
                '¿Deseas subir este archivo al servidor de Ecotrap?',
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.cloud_upload, size: 18),
            label: const Text('Subir'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
            ),
          ),
        ],
      ),
    );

    if (confirm == true) await _syncSingle(file);
  }

  void _showUploadResultDialog(int ok, List<String> errors) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Icon(Icons.summarize,
              color: errors.isEmpty
                  ? AppColors.secondary
                  : AppColors.golden),
          const SizedBox(width: 12),
          const Text('Resultado'),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (ok > 0)
              _infoBox(
                '$ok archivo${ok != 1 ? 's' : ''} subido${ok != 1 ? 's' : ''} correctamente.',
                AppColors.secondary,
                Icons.cloud_done,
              ),
            if (errors.isNotEmpty) ...[
              const SizedBox(height: 10),
              _infoBox(
                '${errors.length} error${errors.length != 1 ? 'es' : ''}:',
                AppColors.burnt,
                Icons.error_outline,
              ),
              const SizedBox(height: 6),
              ...errors.map((e) => Padding(
                    padding: const EdgeInsets.only(
                        bottom: 4, left: 8),
                    child: Text('• $e',
                        style: const TextStyle(
                            fontSize: 12)),
                  )),
            ],
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  void _showAuthErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.lock_outline, color: AppColors.golden),
          SizedBox(width: 12),
          Text('Credenciales requeridas'),
        ]),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final result = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        const ApiConfigScreen()),
              );
              if (result == true && mounted) {
                _showSnackbar(
                  'Configuración guardada. Inténtalo de nuevo.',
                  AppColors.primary,
                  Icons.check,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
            ),
            child: const Text('Ir a Configuración'),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // HELPERS UI
  // ─────────────────────────────────────────────

  void _showSnackbar(
      String msg, Color bg, IconData icon) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(icon, color: Colors.white),
        const SizedBox(width: 12),
        Expanded(child: Text(msg)),
      ]),
      backgroundColor: bg,
    ));
  }

  Widget _fileNameChip(String name) => Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.primarySurface,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(children: [
          const Icon(Icons.insert_drive_file,
              color: AppColors.primary, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(name,
                style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13)),
          ),
        ]),
      );

  Widget _infoBox(String text, Color color, IconData icon) =>
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Expanded(
              child: Text(text,
                  style: TextStyle(
                      fontSize: 12, color: color.withOpacity(0.9)))),
        ]),
      );

  // ─────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final hasSelection = _selected.isNotEmpty;

    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: _isSelectionMode
                ? Text('${_selected.length} seleccionado${_selected.length != 1 ? 's' : ''}')
                : const Text('Subir datos a Ecotrap'),
            leading: _isSelectionMode
                ? IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: _exitSelectionMode,
                  )
                : null,
            actions: _isSelectionMode
                ? [
                    TextButton(
                      onPressed: _selected.length ==
                              _files
                                  .where((f) => !f.isSynced)
                                  .length
                          ? _selectNone
                          : _selectAll,
                      child: Text(
                        _selected.length ==
                                _files
                                    .where((f) => !f.isSynced)
                                    .length
                            ? 'Ninguno'
                            : 'Pendientes',
                        style: const TextStyle(
                            color: Colors.white),
                      ),
                    ),
                  ]
                : [
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: _isLoading ? null : _loadFiles,
                      tooltip: 'Recargar',
                    ),
                  ],
          ),
          body: _buildBody(),
          // ── FAB de subida múltiple ──────────────
          floatingActionButton: (_isSelectionMode && hasSelection)
              ? FloatingActionButton.extended(
                  onPressed: _syncSelected,
                  icon: const Icon(Icons.cloud_upload),
                  label: Text(
                      'Subir ${_selected.length} archivo${_selected.length != 1 ? 's' : ''}'),
                  backgroundColor: AppColors.primary,
                )
              : null,
        ),

        // ── Cortina de carga ──────────────────────
        if (_overlay != null)
          _LoadingCurtain(state: _overlay!),
      ],
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _ErrorState(
          message: _error!, onRetry: _loadFiles);
    }

    if (_files.isEmpty) {
      return _EmptyState(dirPath: _appDirPath);
    }

    final syncedCount = _files.where((f) => f.isSynced).length;
    final pendingCount = _files.length - syncedCount;

    return Column(
      children: [
        // ── Banner resumen ────────────────────────
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.symmetric(
              horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: AppColors.gradientPrimary,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment:
                MainAxisAlignment.spaceAround,
            children: [
              _SummaryChip(
                  value: _files.length,
                  label: 'Total',
                  icon: Icons.folder_open),
              _SummaryChip(
                  value: syncedCount,
                  label: 'Sincronizados',
                  icon: Icons.cloud_done),
              _SummaryChip(
                  value: pendingCount,
                  label: 'Pendientes',
                  icon: Icons.pending_actions),
            ],
          ),
        ),

        // ── Barra de selección ────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 4),
          child: _isSelectionMode
              ? Row(children: [
                  const Icon(Icons.checklist_rounded,
                      size: 16, color: AppColors.primaryDark),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${_selected.length} de ${_files.length} seleccionados',
                      style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.primaryDark,
                          fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton(
                    onPressed: _selected.length ==
                            _files.where((f) => !f.isSynced).length
                        ? _selectNone
                        : _selectAll,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      tapTargetSize:
                          MaterialTapTargetSize.shrinkWrap,
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                    child: Text(
                      _selected.length ==
                              _files
                                  .where((f) => !f.isSynced)
                                  .length
                          ? 'Ninguno'
                          : 'Pendientes',
                    ),
                  ),
                ])
              : Row(children: [
                  Expanded(
                    child: Row(children: [
                      Icon(Icons.touch_app,
                          size: 14, color: Colors.grey[400]),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          'Toca · Mantén para seleccionar',
                          style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[400]),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () {
                      setState(() => _isSelectionMode = true);
                      _selectAll();
                    },
                    icon: const Icon(Icons.checklist, size: 15),
                    label: const Text('Seleccionar todo'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      tapTargetSize:
                          MaterialTapTargetSize.shrinkWrap,
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                  ),
                ]),
        ),

        const SizedBox(height: 8),

        // ── Lista ─────────────────────────────────
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 4),
            itemCount: _files.length,
            itemBuilder: (context, index) {
              final f = _files[index];
              final isSelected = _selected.contains(f.name);
              return _FileCard(
                fileInfo: f,
                isSelectionMode: _isSelectionMode,
                isSelected: isSelected,
                onTap: () => _onFileTap(f),
                onLongPress: _isSelectionMode
                    ? null
                    : () => _enterSelectionMode(f.name),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────
// Cortina de carga
// ─────────────────────────────────────────────────

class _OverlayState {
  final String message;
  final String? fileName;
  final int? current;
  final int? total;

  const _OverlayState({
    required this.message,
    this.fileName,
    this.current,
    this.total,
  });
}

class _LoadingCurtain extends StatelessWidget {
  final _OverlayState state;
  const _LoadingCurtain({required this.state});

  @override
  Widget build(BuildContext context) {
    final hasProgress =
        state.current != null && state.total != null;
    final progress = hasProgress
        ? state.current! / state.total!
        : null;

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
              // Spinner con gradiente
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

              // Mensaje principal
              Text(
                state.message,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryDark,
                ),
                textAlign: TextAlign.center,
              ),

              // Nombre del archivo
              if (state.fileName != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    state.fileName!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.primaryDark,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],

              // Barra de progreso múltiple
              if (hasProgress) ...[
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: AppColors.primarySurface,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${state.current} de ${state.total}',
                  style: TextStyle(
                    fontSize: 13,
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

// ─────────────────────────────────────────────────
// Modelo local
// ─────────────────────────────────────────────────

class _JsonFileInfo {
  final String name;
  final String path;
  final int size;
  final DateTime modified;
  final bool isSynced;

  const _JsonFileInfo({
    required this.name,
    required this.path,
    required this.size,
    required this.modified,
    required this.isSynced,
  });

  String get sizeLabel {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) {
      return '${(size / 1024).toStringAsFixed(1)} KB';
    }
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

// ─────────────────────────────────────────────────
// Widgets
// ─────────────────────────────────────────────────

class _FileCard extends StatelessWidget {
  final _JsonFileInfo fileInfo;
  final bool isSelectionMode;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _FileCard({
    required this.fileInfo,
    required this.isSelectionMode,
    required this.isSelected,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSelected
              ? AppColors.primary
              : Colors.transparent,
          width: 2,
        ),
        color: isSelected
            ? AppColors.primary.withOpacity(0.06)
            : null,
      ),
      child: Card(
        margin: EdgeInsets.zero,
        elevation: isSelected ? 0 : 2,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 6),
          onTap: onTap,
          onLongPress: onLongPress,
          // ── Leading: checkbox o icono de estado ──
          leading: isSelectionMode
              ? AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: Container(
                    key: ValueKey(isSelected),
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary
                          : Colors.grey[100],
                      borderRadius:
                          BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary
                            : Colors.grey[300]!,
                      ),
                    ),
                    child: isSelected
                        ? const Icon(Icons.check,
                            color: Colors.white, size: 20)
                        : null,
                  ),
                )
              : Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: fileInfo.isSynced
                        ? AppColors.secondarySurface
                        : AppColors.primarySurface,
                    borderRadius:
                        BorderRadius.circular(12),
                  ),
                  child: Icon(
                    fileInfo.isSynced
                        ? Icons.cloud_done_rounded
                        : Icons.insert_drive_file_rounded,
                    color: fileInfo.isSynced
                        ? AppColors.secondary
                        : AppColors.primary,
                    size: 24,
                  ),
                ),
          title: Text(
            fileInfo.name,
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            '${fileInfo.sizeLabel} · ${_formatDate(fileInfo.modified)}',
            style: TextStyle(
                fontSize: 11, color: Colors.grey[600]),
          ),
          // ── Trailing: estado sync ─────────────────
          trailing: isSelectionMode
              ? null
              : fileInfo.isSynced
                  ? const Tooltip(
                      message: 'Sincronizado',
                      child: Icon(Icons.check_circle,
                          color: AppColors.secondary, size: 22),
                    )
                  : const Tooltip(
                      message: 'Pendiente',
                      child: Icon(Icons.cloud_upload_outlined,
                          color: AppColors.primary, size: 22),
                    ),
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/'
      '${dt.month.toString().padLeft(2, '0')}/'
      '${dt.year} '
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}';
}

class _SummaryChip extends StatelessWidget {
  final int value;
  final String label;
  final IconData icon;

  const _SummaryChip(
      {required this.value,
      required this.label,
      required this.icon});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        const SizedBox(height: 4),
        Text('$value',
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20)),
        Text(label,
            style: const TextStyle(
                color: Colors.white70, fontSize: 11)),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String dirPath;
  const _EmptyState({required this.dirPath});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.folder_open_rounded,
                size: 80, color: AppColors.primaryLight),
            const SizedBox(height: 16),
            const Text('Sin archivos JSON',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              'No se encontraron archivos JSON en el dispositivo.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.grey[600], fontSize: 14),
            ),
            const SizedBox(height: 8),
            Text(dirPath,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState(
      {required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline,
                size: 64, color: AppColors.burnt),
            const SizedBox(height: 16),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
