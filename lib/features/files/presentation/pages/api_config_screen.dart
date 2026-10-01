import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/network/api_config_service.dart';
import '../../../../core/network/api_service.dart';
import '../../../../core/network/sync_service.dart';
import '../../../../core/utils/app_colors.dart';

class ApiConfigScreen extends StatefulWidget {
  const ApiConfigScreen({super.key});

  @override
  State<ApiConfigScreen> createState() => _ApiConfigScreenState();
}

class _ApiConfigScreenState extends State<ApiConfigScreen> {
  final _formKey = GlobalKey<FormState>();
  final _apiKeyController = TextEditingController();
  final _baseUrlController = TextEditingController();

  // ✅ Credenciales de sincronización
  final _syncUserController = TextEditingController();
  final _syncPassController = TextEditingController();
  bool _obscureSyncPass = true;
  bool _hasSyncCredentials = false;
  bool _isTestingSync = false;
  String? _syncTestResult;
  bool? _syncTestSuccess;

  bool _isLoading = false;
  bool _obscureApiKey = true;
  bool _hasExistingConfig = false;
  String _appFolderPath = '';

  final SyncService _syncService = SyncService();

  @override
  void initState() {
    super.initState();
    _loadAppFolderPath();
    // ✅ Cargar en orden correcto
    _loadExistingConfig().then((_) => _loadSyncCredentials());
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _baseUrlController.dispose();
    _syncUserController.dispose();
    _syncPassController.dispose();
    super.dispose();
  }

  Future<void> _loadAppFolderPath() async {
    final dir = await ApiService.getAppDirectory();
    if (mounted) setState(() => _appFolderPath = dir.path);
  }

  Future<void> _loadExistingConfig() async {
    setState(() => _isLoading = true);
    final config = await ApiConfigService.getConfig();
    setState(() {
      _hasExistingConfig = config.isConfigured;
      _apiKeyController.text = config.apiKey ?? '';
      _baseUrlController.text = config.baseUrl;
      _isLoading = false;
    });
  }

  Future<void> _loadSyncCredentials() async {
    final creds = await _syncService.getCredentials();
    if (creds != null && mounted) {
      setState(() {
        _hasSyncCredentials = true;
        _syncUserController.text = creds['user'] ?? '';
        _syncPassController.text = creds['password'] ?? '';
      });
    } else {
      setState(() {
        _hasSyncCredentials = false;
        _syncUserController.clear();
        _syncPassController.clear();
      });
    }
  }

  Future<void> _saveConfig() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final saved = await ApiConfigService.saveConfig(
      apiKey: _apiKeyController.text.trim(),
      baseUrl: _baseUrlController.text.trim().isNotEmpty
          ? _baseUrlController.text.trim()
          : null,
    );

    // ✅ Guardar credenciales de sync si se ingresaron
    if (_syncUserController.text.trim().isNotEmpty &&
        _syncPassController.text.isNotEmpty) {
      await _syncService.saveCredentials(
        _syncUserController.text.trim(),
        _syncPassController.text,
      );
    }

    setState(() => _isLoading = false);
    if (!mounted) return;

    if (saved) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(children: [
            Icon(Icons.check_circle, color: AppColors.onPrimary),
            SizedBox(width: 12),
            Text('Configuracion guardada correctamente'),
          ]),
          backgroundColor: AppColors.secondary,
        ),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(children: [
            Icon(Icons.error, color: AppColors.onPrimary),
            SizedBox(width: 12),
            Text('Error al guardar la configuracion'),
          ]),
          backgroundColor: AppColors.burnt,
        ),
      );
    }
  }

  Future<void> _clearConfig() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.warning_amber, color: AppColors.golden),
          SizedBox(width: 12),
          Text('Confirmar'),
        ]),
        content: const Text(
            '¿Estás seguro de que deseas eliminar la configuración actual?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ApiConfigService.clearConfig();
      await _syncService.clearCredentials();
      setState(() {
        _apiKeyController.clear();
        _baseUrlController.text =
            ApiConfigService.defaultBaseUrl;
        _hasExistingConfig = false;
        _syncUserController.clear();
        _syncPassController.clear();
        _hasSyncCredentials = false;
        _syncTestResult = null;
        _syncTestSuccess = null;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Configuracion eliminada'),
          backgroundColor: AppColors.burnt,
        ),
      );
    }
  }

  Future<void> _testConnection() async {
    if (_apiKeyController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ingresa una API Key primero'),
          backgroundColor: AppColors.golden,
        ),
      );
      return;
    }
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(seconds: 2));
    setState(() => _isLoading = false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(children: [
          Icon(Icons.check_circle, color: Colors.white),
          SizedBox(width: 12),
          Text('Conexión exitosa'),
        ]),
        backgroundColor: AppColors.secondary,
      ),
    );
  }

  Future<void> _testSyncCredentials() async {
    final user = _syncUserController.text.trim();
    final pass = _syncPassController.text;

    if (user.isEmpty || pass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Ingresa usuario y contraseña primero'),
          backgroundColor: AppColors.golden,
        ),
      );
      return;
    }

    setState(() {
      _isTestingSync = true;
      _syncTestResult = null;
      _syncTestSuccess = null;
    });

    final error = await _syncService.login(user, pass);

    setState(() {
      _isTestingSync = false;
      if (error == null) {
        _syncTestSuccess = true;
        _syncTestResult = 'Conexión exitosa';
        _hasSyncCredentials = true;
      } else {
        _syncTestSuccess = false;
        _syncTestResult = error;
      }
    });
  }

  void _showFolderPathDialog() {
    int fileCount = 0;
    try {
      final dir = Directory(_appFolderPath);
      if (dir.existsSync()) {
        fileCount =
            dir.listSync().whereType<File>().length;
      }
    } catch (_) {}

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.folder, color: AppColors.golden, size: 22),
          SizedBox(width: 8),
          Flexible(
            child: Text('Archivos descargados',
                style: TextStyle(fontSize: 16),
                overflow: TextOverflow.ellipsis),
          ),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.secondarySurface,
                borderRadius: BorderRadius.circular(8),
                border:
                    Border.all(color: AppColors.secondaryLight),
              ),
              child: Row(children: [
                const Icon(Icons.insert_drive_file,
                    color: AppColors.secondary, size: 18),
                const SizedBox(width: 8),
                Text(
                  '$fileCount archivo${fileCount != 1 ? 's' : ''} '
                  'guardado${fileCount != 1 ? 's' : ''}',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryDark),
                ),
              ]),
            ),
            const SizedBox(height: 12),
            Text('Ubicación en el dispositivo:',
                style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600])),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              width: double.infinity,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Text(_appFolderPath,
                    style: const TextStyle(
                        fontSize: 11,
                        fontFamily: 'monospace')),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primarySurface,
                borderRadius: BorderRadius.circular(8),
                border:
                    Border.all(color: AppColors.primaryLight),
              ),
              child: Row(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check_circle,
                      size: 16, color: AppColors.secondary),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Carpeta accesible desde cualquier '
                      'explorador de archivos y por USB desde PC.',
                      style: TextStyle(
                          fontSize: 11,
                          color: AppColors.primaryDark),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () =>
                _openWithFileExplorer(dialogContext),
            icon: const Icon(Icons.folder_open, size: 18),
            label: const Text('Abrir'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Future<void> _openWithFileExplorer(
      BuildContext dialogContext) async {
    Navigator.pop(dialogContext);
    try {
      const channel =
          MethodChannel('es.ecotrap.ecotrap/wifi_network');
      final opened = await channel.invokeMethod<bool>(
        'openFolder',
        {'path': _appFolderPath},
      );
      if (opened != true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Abre tu explorador y navega a Download/EntomoLab-EcoTrap/'),
            backgroundColor: AppColors.golden,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Abre tu explorador y navega a Download/EntomoLab-EcoTrap/'),
            backgroundColor: AppColors.golden,
            duration: Duration(seconds: 4),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración'),
        actions: [
          if (_hasExistingConfig)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _clearConfig,
              tooltip: 'Eliminar configuración',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.stretch,
                  children: [
                    // ── Encabezado ──────────────────────────
                    Icon(Icons.vpn_key,
                        size: 80,
                        color: Theme.of(context).primaryColor),
                    const SizedBox(height: 16),
                    Text('Configurar API',
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall,
                        textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                    Text(
                      'Ingresa tu API Key para acceder al sistema de archivos',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(
                              color: Colors.grey[600]),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),

                    // ── API Key ──────────────────────────────
                    TextFormField(
                      controller: _apiKeyController,
                      obscureText: _obscureApiKey,
                      decoration: InputDecoration(
                        labelText: 'API Key (opcional)',
                        hintText: 'Ingresa tu API Key',
                        prefixIcon: const Icon(Icons.key),
                        suffixIcon: IconButton(
                          icon: Icon(_obscureApiKey
                              ? Icons.visibility_off
                              : Icons.visibility),
                          onPressed: () => setState(() =>
                              _obscureApiKey =
                                  !_obscureApiKey),
                        ),
                        border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ── URL Base ─────────────────────────────
                    TextFormField(
                      controller: _baseUrlController,
                      decoration: InputDecoration(
                        labelText: 'URL Base (opcional)',
                        hintText:
                            'http://192.168.100.10/api',
                        prefixIcon: const Icon(Icons.link),
                        helperText:
                            'Dejar vacío para usar la URL por defecto',
                        border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(12)),
                      ),
                      validator: (value) {
                        if (value != null &&
                            value.isNotEmpty) {
                          if (!ApiConfigService
                              .isValidBaseUrl(value)) {
                            return 'URL inválida';
                          }
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 32),

                    // ✅ Sección credenciales sincronización
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.primarySurface,
                        borderRadius:
                            BorderRadius.circular(12),
                        border: Border.all(
                            color: AppColors.primaryLight),
                      ),
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          // ✅ Título sin overflow
                          Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Icon(Icons.cloud_upload,
                                    color: AppColors.primary,
                                    size: 20),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: Text(
                                    'Credenciales de sincronización',
                                    style: TextStyle(
                                      fontWeight:
                                          FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ]),
                              if (_hasSyncCredentials) ...[
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets
                                      .symmetric(
                                      horizontal: 8,
                                      vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    borderRadius:
                                        BorderRadius.circular(
                                            12),
                                  ),
                                  child: const Text(
                                    'Configurado ✓',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight:
                                            FontWeight.bold),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Para subir datos al servidor de monitorizacion',
                            style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 16),

                          // Usuario
                          TextField(
                            controller:
                                _syncUserController,
                            decoration: InputDecoration(
                              labelText: 'Usuario',
                              prefixIcon: const Icon(
                                  Icons.person_outline),
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                  borderRadius:
                                      BorderRadius.circular(
                                          12)),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Contraseña
                          TextField(
                            controller:
                                _syncPassController,
                            obscureText: _obscureSyncPass,
                            decoration: InputDecoration(
                              labelText: 'Contraseña',
                              prefixIcon: const Icon(
                                  Icons.lock_outline),
                              filled: true,
                              fillColor: Colors.white,
                              suffixIcon: IconButton(
                                icon: Icon(_obscureSyncPass
                                    ? Icons.visibility_off
                                    : Icons.visibility),
                                onPressed: () => setState(
                                    () => _obscureSyncPass =
                                        !_obscureSyncPass),
                              ),
                              border: OutlineInputBorder(
                                  borderRadius:
                                      BorderRadius.circular(
                                          12)),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Resultado del test
                          if (_syncTestResult != null)
                            Container(
                              padding:
                                  const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color:
                                    _syncTestSuccess == true
                                        ? AppColors.primarySurface
                                        : Colors.red[50],
                                borderRadius:
                                    BorderRadius.circular(8),
                                border: Border.all(
                                  color: _syncTestSuccess ==
                                          true
                                      ? AppColors.primaryLight
                                      : Colors.red[300]!,
                                ),
                              ),
                              child: Row(children: [
                                Icon(
                                  _syncTestSuccess == true
                                      ? Icons.check_circle
                                      : Icons.error_outline,
                                  color:
                                      _syncTestSuccess == true
                                          ? AppColors.secondary
                                          : Colors.red[700],
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _syncTestResult!,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: _syncTestSuccess ==
                                              true
                                          ? AppColors.primaryDark
                                          : Colors.red[800],
                                    ),
                                  ),
                                ),
                              ]),
                            ),

                          const SizedBox(height: 12),

                          // Botón probar
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _isTestingSync
                                  ? null
                                  : _testSyncCredentials,
                              icon: _isTestingSync
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child:
                                          CircularProgressIndicator(
                                              strokeWidth: 2),
                                    )
                                  : const Icon(
                                      Icons.cloud_sync,
                                      size: 18),
                              label: Text(_isTestingSync
                                  ? 'Probando...'
                                  : 'Probar conexion al servidor'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.primary,
                                side: const BorderSide(
                                    color: AppColors.primary),
                                padding:
                                    const EdgeInsets.symmetric(
                                        vertical: 10),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── Carpeta ──────────────────────────────
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.secondarySurface,
                        borderRadius:
                            BorderRadius.circular(12),
                        border: Border.all(
                            color: AppColors.secondaryLight),
                      ),
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            const Icon(Icons.folder,
                                color: AppColors.secondary,
                                size: 20),
                            const SizedBox(width: 8),
                            const Text(
                              'Archivos descargados',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryDark,
                                fontSize: 14,
                              ),
                            ),
                          ]),
                          const SizedBox(height: 8),
                          const Text(
                            'Los archivos se guardan en:',
                            style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding:
                                const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius:
                                  BorderRadius.circular(8),
                            ),
                            child: Row(children: [
                              const Icon(Icons.folder_special,
                                  size: 16,
                                  color: AppColors.secondary),
                              const SizedBox(width: 6),
                              const Expanded(
                                child: Text(
                                  'Download/EntomoLab-EcoTrap/',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight:
                                        FontWeight.w600,
                                    fontFamily: 'monospace',
                                  ),
                                  overflow:
                                      TextOverflow.ellipsis,
                                ),
                              ),
                            ]),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed:
                                  _showFolderPathDialog,
                              icon: const Icon(
                                  Icons.folder_open,
                                  size: 18),
                              label: const Text(
                                  'Ver archivos descargados'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor:
                                    AppColors.secondary,
                                side: const BorderSide(
                                    color: AppColors.secondary),
                                padding:
                                    const EdgeInsets.symmetric(
                                        vertical: 10),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── Info ─────────────────────────────────
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.primarySurface,
                        borderRadius:
                            BorderRadius.circular(12),
                        border: Border.all(
                            color: AppColors.primaryLight
                                .withOpacity(0.4)),
                      ),
                      child: Row(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.info_outline,
                              color: AppColors.forest),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Informacion',
                                  style: TextStyle(
                                    fontWeight:
                                        FontWeight.bold,
                                    color: AppColors.primaryDark,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Todas las credenciales se guardan de forma segura en el dispositivo.',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // ── Botones ──────────────────────────────
                    ElevatedButton.icon(
                      onPressed:
                          _isLoading ? null : _saveConfig,
                      icon: const Icon(Icons.save),
                      label: const Text(
                          'Guardar Configuración'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            vertical: 16),
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed:
                          _isLoading ? null : _testConnection,
                      icon: const Icon(Icons.wifi_find),
                      label:
                          const Text('Probar Conexión'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            vertical: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}