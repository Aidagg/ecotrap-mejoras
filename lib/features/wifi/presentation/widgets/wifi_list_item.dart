import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wifi_iot/wifi_iot.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/network/api_config_service.dart';
import '../../../../core/services/wifi_connection_service.dart';
import '../../../../core/utils/app_colors.dart';
import '../../domain/entities/wifi_network.dart';
import '../bloc/wifi_bloc.dart';
import '../bloc/wifi_event.dart';

class WiFiListItem extends StatefulWidget {
  final WiFiNetwork network;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  /// Label for the connect button/menu item. Default: 'Conectar a Trampa'
  final String connectLabel;
  /// Route to push after a successful connection. Default: '/files-list'
  final String connectRoute;

  const WiFiListItem({
    super.key,
    required this.network,
    required this.onEdit,
    required this.onDelete,
    this.connectLabel = 'Ver archivos',
    this.connectRoute = '/files-list',
  });

  @override
  State<WiFiListItem> createState() => _WiFiListItemState();
}

class _WiFiListItemState extends State<WiFiListItem> {
  bool _isPasswordVisible = false;
  bool _isConnecting = false;
  bool _isConnected = false;

  // ✅ Señal WiFi
  int? _signalLevel; // RSSI en dBm
  Timer? _signalTimer;

  @override
  void initState() {
    super.initState();
    _checkIfConnected();
    _updateSignalStrength();
    // ✅ Actualizar señal cada 5 segundos
    _signalTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _updateSignalStrength(),
    );
  }

  @override
  void dispose() {
    _signalTimer?.cancel();
    super.dispose();
  }

  /// ✅ Obtener intensidad de señal escaneando redes cercanas
  Future<void> _updateSignalStrength() async {
    try {
      // ignore: deprecated_member_use
      final networks = await WiFiForIoTPlugin.loadWifiList();
      if (!mounted) return;

      // Buscar por BSSID primero, luego por SSID
      final match = networks.firstWhere(
        (n) {
          if (widget.network.bssid != null &&
              widget.network.bssid!.isNotEmpty &&
              n.bssid != null) {
            return n.bssid!.toLowerCase() ==
                widget.network.bssid!.toLowerCase();
          }
          return n.ssid?.toLowerCase() ==
              widget.network.ssid.toLowerCase();
        },
        orElse: () => WifiNetwork.fromJson({}),
      );

      if (mounted && match.level != null) {
        setState(() => _signalLevel = match.level);
      }
    } catch (e) {
      debugPrint('⚠️ Error obteniendo señal: $e');
    }
  }

  /// Convierte RSSI a porcentaje
  int get _signalPercent {
    if (_signalLevel == null) return 0;
    if (_signalLevel! >= -50) return 100;
    if (_signalLevel! <= -100) return 0;
    return (2 * (_signalLevel! + 100)).clamp(0, 100);
  }

  /// Color según intensidad
  Color get _signalColor {
    if (_signalLevel == null) return Colors.grey;
    final p = _signalPercent;
    if (p >= 75) return AppColors.secondary;
    if (p >= 50) return AppColors.golden;
    return AppColors.burnt;
  }

  /// Icono según intensidad
  IconData get _signalIcon {
    if (_signalLevel == null) return Icons.wifi_off;
    final p = _signalPercent;
    if (p >= 75) return Icons.signal_wifi_4_bar;
    if (p >= 50) return Icons.network_wifi_3_bar;
    if (p >= 25) return Icons.network_wifi_2_bar;
    return Icons.network_wifi_1_bar;
  }

  /// Texto descriptivo de señal
  String get _signalLabel {
    if (_signalLevel == null) return 'Sin señal';
    final p = _signalPercent;
    if (p >= 75) return 'Excelente';
    if (p >= 50) return 'Buena';
    if (p >= 25) return 'Regular';
    return 'Débil';
  }

  Future<void> _checkIfConnected() async {
    try {
      final isConnected = await WiFiForIoTPlugin.isConnected();
      if (!isConnected) {
        if (mounted) setState(() => _isConnected = false);
        return;
      }

      final currentSsid = await WiFiForIoTPlugin.getSSID();
      final currentBssid = await WiFiForIoTPlugin.getBSSID();

      if (!mounted) return;

      final cleanSsid = currentSsid?.replaceAll('"', '') ?? '';
      final cleanBssid = currentBssid?.replaceAll('"', '') ?? '';

      final bool connected;
      if (widget.network.bssid != null &&
          widget.network.bssid!.isNotEmpty &&
          cleanBssid.isNotEmpty) {
        connected = cleanBssid.toLowerCase() ==
            widget.network.bssid!.toLowerCase();
      } else {
        connected = cleanSsid == widget.network.ssid;
      }

      setState(() {
        _isConnected = connected;
      });
    } catch (e) {
      debugPrint('⚠️ Error verificando conexión: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cardColor = _isConnected ? AppColors.primarySurface : null;
    final borderColor = _isConnected ? AppColors.secondary : Colors.transparent;
    final accentColor =
        _isConnected ? AppColors.secondary : Theme.of(context).primaryColor;

    return Slidable(
      key: ValueKey(widget.network.id),
      endActionPane: ActionPane(
        motion: const ScrollMotion(),
        children: [
          SlidableAction(
            onPressed: (_) => widget.onEdit(),
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            icon: Icons.edit,
            label: 'Editar',
          ),
          SlidableAction(
            onPressed: (_) => widget.onDelete(),
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            icon: Icons.delete,
            label: 'Eliminar',
          ),
        ],
      ),
      child: Card(
        elevation: _isConnected ? 4 : 2,
        color: cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: borderColor, width: 2),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──────────────────────────────────────
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      _isConnected ? Icons.wifi : Icons.wifi,
                      color: accentColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                widget.network.displayName,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            if (_isConnected)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.secondary,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'Conectado',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        // ── BSSID — identificador único del dispositivo ──
                        if (widget.network.bssid != null &&
                            widget.network.bssid!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          GestureDetector(
                            onTap: () {
                              Clipboard.setData(ClipboardData(
                                  text: widget.network.bssid!));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('BSSID copiado'),
                                  duration: Duration(seconds: 1),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.primarySurface,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                    color: AppColors.forest.withOpacity(0.3)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.router_outlined,
                                      size: 12,
                                      color: AppColors.forest),
                                  const SizedBox(width: 4),
                                  Text(
                                    widget.network.bssid!.toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.forest,
                                      fontFamily: 'monospace',
                                      letterSpacing: 0.8,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 4),
                        Text(
                          _formatDate(widget.network.createdAt),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.more_vert),
                    onPressed: () => _showOptionsMenu(context),
                  ),
                ],
              ),

              // ✅ Señal WiFi
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(_signalIcon, size: 18, color: _signalColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _signalLevel != null
                                  ? 'Señal: $_signalLabel'
                                  : 'Señal: no detectada',
                              style: TextStyle(
                                fontSize: 12,
                                color: _signalColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (_signalLevel != null)
                              Text(
                                '$_signalPercent% (${_signalLevel}dBm)',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[500],
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: _signalLevel != null
                                ? _signalPercent / 100
                                : 0,
                            backgroundColor: Colors.grey[200],
                            valueColor: AlwaysStoppedAnimation<Color>(
                              _signalLevel != null
                                  ? _signalColor
                                  : Colors.grey,
                            ),
                            minHeight: 6,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const Divider(height: 24),

              // ── Contraseña ───────────────────────────────────
              Row(
                children: [
                  Icon(Icons.lock, size: 20, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _isPasswordVisible
                          ? widget.network.password
                          : '•' * widget.network.password.length,
                      style:
                          const TextStyle(fontSize: 16, letterSpacing: 2),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      _isPasswordVisible
                          ? Icons.visibility_off
                          : Icons.visibility,
                      color: accentColor,
                    ),
                    onPressed: () => setState(
                        () => _isPasswordVisible = !_isPasswordVisible),
                    tooltip: _isPasswordVisible ? 'Ocultar' : 'Mostrar',
                  ),
                  IconButton(
                    icon: Icon(Icons.copy, color: accentColor),
                    onPressed: _copyPassword,
                    tooltip: 'Copiar contraseña',
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // ── Botón conectar ───────────────────────────────
              SizedBox(
                width: double.infinity,
                child: Tooltip(
                  message: _signalLevel == null && !_isConnected
                      ? 'Red fuera de alcance'
                      : '',
                  child: ElevatedButton.icon(
                    onPressed: (_isConnecting ||
                            (_signalLevel == null && !_isConnected))
                        ? null
                        : _connectToWiFi,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isConnected ? AppColors.secondary : null,
                      disabledBackgroundColor:
                          Colors.grey[200],
                      disabledForegroundColor:
                          Colors.grey[500],
                      padding:
                          const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: _isConnecting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white),
                            ),
                          )
                        : Icon(_signalLevel == null && !_isConnected
                            ? Icons.wifi_off
                            : Icons.sensors),
                    label: Text(
                      _isConnecting
                          ? 'Conectando...'
                          : _isConnected
                              ? widget.connectLabel
                              : _signalLevel == null
                                  ? 'Fuera de alcance'
                                  : widget.connectLabel,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays == 0) return 'Hoy';
    if (diff.inDays == 1) return 'Ayer';
    if (diff.inDays < 7) return 'Hace ${diff.inDays} días';
    return '${date.day}/${date.month}/${date.year}';
  }

  void _copyPassword() {
    Clipboard.setData(ClipboardData(text: widget.network.password));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Contraseña copiada al portapapeles'),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _connectToWiFi() async {
    setState(() => _isConnecting = true);

    try {
      final wifiService = sl<WiFiConnectionService>();

      if (!mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text('Conectando a ${widget.network.displayName}...',
                  textAlign: TextAlign.center),
              const SizedBox(height: 8),
              const Text('Esto puede tardar hasta 30 segundos...',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
        ),
      );

      final result = await wifiService.connect(
        context: context,
        ssid: widget.network.ssid,
        password: widget.network.password,
        bssid: widget.network.bssid,
      );

      if (mounted) Navigator.of(context).pop();

      if (mounted) {
        if (result.requiresSettings) {
          final shouldOpen = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Acción Requerida'),
              content:
                  SingleChildScrollView(child: Text(result.message)),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cerrar'),
                ),
                ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context, true),
                  icon: const Icon(Icons.settings),
                  label: const Text('Ir a Configuración'),
                ),
              ],
            ),
          );
          if (shouldOpen == true) await openAppSettings();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(
                      result.success
                          ? Icons.check_circle
                          : Icons.error,
                      color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(child: Text(result.message)),
                ],
              ),
              backgroundColor:
                  result.success ? AppColors.secondary : AppColors.golden,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 4),
            ),
          );

          if (result.success) {
            await _checkIfConnected();
            await _updateSignalStrength();

            // Si es la primera vez que se conecta (sin nombre), obtener nombre del trap
            if (widget.network.name == null) {
              await _fetchAndSaveTrapName();
            }

            if (mounted) {
              await Future.delayed(
                  const Duration(milliseconds: 800));
              if (mounted) {
                Navigator.of(context)
                    .pushNamed(widget.connectRoute);
              }
            }
          }
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isConnecting = false);
    }
  }

  /// Llama a GET /api/health en el trap recién conectado y guarda
  /// last_cycle.id_trap como nombre amigable de la red.
  Future<void> _fetchAndSaveTrapName() async {
    try {
      final config = await ApiConfigService.getConfig();
      // Replicar la misma lógica que CameraStreamPage: reemplazar puerto → 8081
      final baseUri = Uri.parse(config.baseUrl); // ej. http://192.168.100.10/api
      final streamBase = baseUri.replace(port: 8081).toString(); // http://…:8081/api
      final healthUrl = '$streamBase/health'; // http://…:8081/api/health

      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 8),
        headers: {
          if (config.apiKey != null && config.apiKey!.isNotEmpty)
            'x-api-key': config.apiKey!,
        },
      ));

      final response = await dio.get(healthUrl);
      if (response.statusCode == 200) {
        final data = response.data is String
            ? jsonDecode(response.data as String)
            : response.data as Map<String, dynamic>;

        final trapId = data['last_cycle']?['id_trap'] as String?;
        if (trapId != null && trapId.isNotEmpty && mounted) {
          context.read<WiFiBloc>().add(UpdateWiFiNetworkEvent(
                id: widget.network.id,
                ssid: widget.network.ssid,
                password: widget.network.password,
                bssid: widget.network.bssid,
                name: trapId,
              ));
          debugPrint('✅ Nombre del trap guardado: $trapId');
        }
      }
    } catch (e) {
      debugPrint('⚠️ No se pudo obtener nombre del trap desde /api/health: $e');
    }
  }

  void _showOptionsMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            enabled: _signalLevel != null || _isConnected,
            leading: Icon(
              Icons.sensors,
              color: (_signalLevel != null || _isConnected)
                  ? AppColors.secondary
                  : Colors.grey,
            ),
            title: Text(widget.connectLabel),
            subtitle: (_signalLevel == null && !_isConnected)
                ? const Text('Red fuera de alcance',
                    style:
                        TextStyle(fontSize: 11, color: Colors.grey))
                : null,
            onTap: (_signalLevel == null && !_isConnected)
                ? null
                : () {
                    Navigator.pop(context);
                    _connectToWiFi();
                  },
          ),
          ListTile(
            leading: const Icon(Icons.edit, color: Colors.blue),
            title: const Text('Editar'),
            onTap: () {
              Navigator.pop(context);
              widget.onEdit();
            },
          ),
          ListTile(
            leading: const Icon(Icons.copy, color: AppColors.golden),
            title: const Text('Copiar contraseña'),
            onTap: () {
              Navigator.pop(context);
              _copyPassword();
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete, color: Colors.red),
            title: const Text('Eliminar'),
            onTap: () {
              Navigator.pop(context);
              widget.onDelete();
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}