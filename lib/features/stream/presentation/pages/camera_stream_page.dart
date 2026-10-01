import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../../core/network/api_config_service.dart';
import '../../../../core/utils/app_colors.dart';

/// Puerto del servicio de stream (independiente del API principal)
const int _kStreamPort = 8081;

/// Construye la base URL para el servicio de stream a partir de la URL guardada.
/// Ejemplo: http://192.168.100.10/api  →  http://192.168.100.10:8081/api
String _buildStreamBase(String configuredBaseUrl) {
  try {
    final uri = Uri.parse(configuredBaseUrl);
    return uri.replace(port: _kStreamPort).toString();
  } catch (_) {
    return configuredBaseUrl;
  }
}

class CameraStreamPage extends StatefulWidget {
  const CameraStreamPage({super.key});

  @override
  State<CameraStreamPage> createState() => _CameraStreamPageState();
}

class _CameraStreamPageState extends State<CameraStreamPage>
    with WidgetsBindingObserver {
  // ── Config ─────────────────────────────────────────────────
  late String _streamBase; // http://host:8081/api
  late String _apiKey;
  bool _configLoaded = false;

  // ── Estado stream ──────────────────────────────────────────
  Uint8List? _currentFrame;
  bool _isConnecting = true;
  String? _error;
  int _framesReceived = 0;

  // ── Dio ────────────────────────────────────────────────────
  final Dio _dio = Dio();
  CancelToken? _cancelToken;
  StreamSubscription<List<int>>? _sub;
  final List<int> _buffer = [];

  // ── Ping ──────────────────────────────────────────────────
  Timer? _pingTimer;

  // ── Timeout 3 min ─────────────────────────────────────────
  static const int _timeoutSeconds = 180;
  Timer? _timeoutTimer;
  Timer? _countdownTimer;
  int _remainingSeconds = _timeoutSeconds;

  // ──────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  Future<void> _init() async {
    final config = await ApiConfigService.getConfig();
    _streamBase = _buildStreamBase(config.baseUrl);
    _apiKey = config.apiKey ?? '';
    setState(() => _configLoaded = true);
    _startStream();
  }

  // ── Ciclo de vida ──────────────────────────────────────────
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _closeAndStop(reason: 'Stream pausado. La app perdió el foco.');
    }
  }

  // ── Endpoints helpers ──────────────────────────────────────
  Map<String, String> get _headers => {'X-API-Key': _apiKey};

  String get _urlStream => '$_streamBase/stream';
  String get _urlPing => '$_streamBase/stream/ping';
  String get _urlClose => '$_streamBase/stream/close';
  String get _urlStreamHealth => '$_streamBase/stream/health';
  String get _urlHealth => '$_streamBase/health';

  /// Llama a /api/stream/close para liberar la cámara en el dispositivo IoT.
  Future<void> _callClose() async {
    try {
      await _dio.post(
        _urlClose,
        options: Options(
          headers: _headers,
          sendTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
        ),
      );
    } catch (_) {
      // Ignorar errores: el dispositivo puede ya estar desconectado
    }
  }

  /// Ping periódico para mantener la cámara activa mientras se ve el stream.
  void _startPing() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      try {
        await _dio.get(
          _urlPing,
          options: Options(
            headers: _headers,
            sendTimeout: const Duration(seconds: 4),
            receiveTimeout: const Duration(seconds: 4),
          ),
        );
      } catch (_) {}
    });
  }

  // ── Stream ─────────────────────────────────────────────────
  Future<void> _startStream() async {
    _stopInternals();
    _buffer.clear();
    if (mounted) {
      setState(() {
        _isConnecting = true;
        _error = null;
        _currentFrame = null;
        _framesReceived = 0;
        _remainingSeconds = _timeoutSeconds;
      });
    }

    try {
      _cancelToken = CancelToken();

      final response = await _dio.get<ResponseBody>(
        _urlStream,
        cancelToken: _cancelToken,
        options: Options(
          responseType: ResponseType.stream,
          headers: _headers,
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(minutes: 4),
        ),
      );

      if (!mounted) return;
      setState(() => _isConnecting = false);
      _startTimers();
      _startPing();

      _sub = response.data!.stream.listen(
        (chunk) {
          _buffer.addAll(chunk);
          _processBuffer();
        },
        onError: (Object e) {
          if (!mounted) return;
          if (e is DioException && e.type == DioExceptionType.cancel) return;
          setState(() => _error = 'Error en el stream: $e');
          _stopInternals();
        },
        onDone: () {
          if (mounted && _error == null) {
            setState(() => _error = 'El stream finalizó.');
          }
          _stopInternals();
        },
        cancelOnError: true,
      );
    } catch (e) {
      if (!mounted) return;
      if (e is DioException && e.type == DioExceptionType.cancel) return;
      setState(() {
        _isConnecting = false;
        _error = 'No se pudo conectar al stream.\n$e';
      });
    }
  }

  /// Detiene el stream y avisa al dispositivo IoT para liberar la cámara.
  Future<void> _closeAndStop({String? reason}) async {
    _stopInternals();
    await _callClose();
    if (reason != null && mounted) {
      setState(() => _error = reason);
    }
  }

  void _stopInternals() {
    _cancelToken?.cancel('disconnected');
    _sub?.cancel();
    _sub = null;
    _pingTimer?.cancel();
    _stopTimers();
  }

  // ── Parser MJPEG ───────────────────────────────────────────
  void _processBuffer() {
    while (true) {
      int start = -1;
      for (int i = 0; i < _buffer.length - 1; i++) {
        if (_buffer[i] == 0xFF && _buffer[i + 1] == 0xD8) {
          start = i;
          break;
        }
      }
      if (start == -1) { _buffer.clear(); return; }
      if (start > 0) _buffer.removeRange(0, start);

      int end = -1;
      for (int i = 2; i < _buffer.length - 1; i++) {
        if (_buffer[i] == 0xFF && _buffer[i + 1] == 0xD9) {
          end = i + 1;
          break;
        }
      }
      if (end == -1) return;

      final frame = Uint8List.fromList(_buffer.sublist(0, end + 1));
      _buffer.removeRange(0, end + 1);
      if (mounted) setState(() { _currentFrame = frame; _framesReceived++; });
    }
  }

  // ── Temporizadores ─────────────────────────────────────────
  void _startTimers() {
    _stopTimers();
    _remainingSeconds = _timeoutSeconds;
    _timeoutTimer = Timer(const Duration(minutes: 3), _onTimeout);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() {
        if (_remainingSeconds > 0) { _remainingSeconds--; } else { t.cancel(); }
      });
    });
  }

  void _stopTimers() {
    _timeoutTimer?.cancel();
    _countdownTimer?.cancel();
  }

  Future<void> _onTimeout() async {
    await _closeAndStop();
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Tiempo agotado'),
        content: const Text(
            'La transmisión se cerró automáticamente tras 3 minutos '
            'y la cámara fue liberada.'),
        actions: [
          ElevatedButton(
            onPressed: () { Navigator.pop(ctx); Navigator.pop(context); },
            child: const Text('Cerrar'),
          ),
          TextButton(
            onPressed: () { Navigator.pop(ctx); _startStream(); },
            child: const Text('Reconectar'),
          ),
        ],
      ),
    );
  }

  // ── Popup salud del dispositivo ────────────────────────────
  Future<void> _showHealthDialog() async {
    showDialog(
      context: context,
      builder: (ctx) => const _HealthLoadingDialog(),
    );

    Map<String, dynamic>? health;
    Map<String, dynamic>? streamHealth;
    String? healthError;

    try {
      final futures = await Future.wait([
        _dio.get<dynamic>(
          _urlHealth,
          options: Options(
            headers: _headers,
            sendTimeout: const Duration(seconds: 5),
            receiveTimeout: const Duration(seconds: 5),
          ),
        ),
        _dio.get<dynamic>(
          _urlStreamHealth,
          options: Options(
            headers: _headers,
            sendTimeout: const Duration(seconds: 5),
            receiveTimeout: const Duration(seconds: 5),
          ),
        ),
      ]);
      health = _parseResponse(futures[0].data);
      streamHealth = _parseResponse(futures[1].data);
    } catch (e) {
      healthError = e.toString();
    }

    if (!mounted) return;
    Navigator.pop(context); // cerrar loading

    showDialog(
      context: context,
      builder: (ctx) => _HealthDialog(
        health: health,
        streamHealth: streamHealth,
        error: healthError,
      ),
    );
  }

  Map<String, dynamic>? _parseResponse(dynamic data) {
    if (data == null) return null;
    if (data is Map<String, dynamic>) return data;
    if (data is String) {
      try { return jsonDecode(data) as Map<String, dynamic>; } catch (_) {}
    }
    return null;
  }

  // ──────────────────────────────────────────────────────────
  @override
  void dispose() {
    _stopInternals();
    _callClose(); // fire-and-forget
    _dio.close(force: true);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  // ── BUILD ──────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (!_configLoaded) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Cámara en tiempo real'),
        backgroundColor: AppColors.primaryDark,
        foregroundColor: Colors.white,
        actions: [
          // ── Contador regresivo ──────────────────────────────
          if (!_isConnecting && _error == null)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.timer_outlined,
                      size: 15,
                      color: _remainingSeconds <= 30
                          ? AppColors.burnt
                          : Colors.white54),
                  const SizedBox(width: 3),
                  Text(
                    _formatTime(_remainingSeconds),
                    style: TextStyle(
                      color: _remainingSeconds <= 30
                          ? AppColors.burnt
                          : Colors.white70,
                      fontFamily: 'monospace',
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          // ── Botón estado del dispositivo ────────────────────
          IconButton(
            icon: const Icon(Icons.monitor_heart_outlined),
            tooltip: 'Estado del dispositivo',
            onPressed: _showHealthDialog,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isConnecting) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 20),
            Text('Conectando al stream...',
                style: TextStyle(color: Colors.white70, fontSize: 14)),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.videocam_off, size: 72, color: AppColors.burnt),
              const SizedBox(height: 20),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _startStream,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    return Stack(
      children: [
        // ── Video ─────────────────────────────────────────────
        Center(
          child: _currentFrame == null
              ? const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.white54),
                    SizedBox(height: 16),
                    Text('Esperando primer frame...',
                        style:
                            TextStyle(color: Colors.white38, fontSize: 13)),
                  ],
                )
              : InteractiveViewer(
                  minScale: 1.0,
                  maxScale: 4.0,
                  child: Image.memory(
                    _currentFrame!,
                    gaplessPlayback: true,
                    fit: BoxFit.contain,
                  ),
                ),
        ),

        // ── Barra inferior ────────────────────────────────────
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            color: Colors.black.withOpacity(0.65),
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                const Icon(Icons.fiber_manual_record,
                    color: Colors.red, size: 12),
                const SizedBox(width: 6),
                const Text('EN VIVO',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        letterSpacing: 1.4)),
                if (_framesReceived > 0) ...[
                  const SizedBox(width: 12),
                  Text('$_framesReceived frames',
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 11)),
                ],
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: () async {
                    await _closeAndStop();
                    if (mounted) Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.burnt,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: const Icon(Icons.stop_circle_outlined, size: 16),
                  label: const Text('Desconectar',
                      style: TextStyle(fontSize: 13)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Widgets del popup de salud
// ─────────────────────────────────────────────────────────────

class _HealthLoadingDialog extends StatelessWidget {
  const _HealthLoadingDialog();

  @override
  Widget build(BuildContext context) {
    return const AlertDialog(
      content: SizedBox(
        height: 80,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 14),
              Text('Obteniendo estado del dispositivo...'),
            ],
          ),
        ),
      ),
    );
  }
}

class _HealthDialog extends StatelessWidget {
  final Map<String, dynamic>? health;
  final Map<String, dynamic>? streamHealth;
  final String? error;

  const _HealthDialog({this.health, this.streamHealth, this.error});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(children: [
        Icon(Icons.monitor_heart_outlined, color: AppColors.primary, size: 20),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            'Estado del dispositivo',
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 16),
          ),
        ),
      ]),
      content: SizedBox(
        width: double.maxFinite,
        height: 380,
        child: SingleChildScrollView(
          child: error != null
              ? _ErrorBox(error!)
              : health != null
                  ? _DeviceStatusTable(health!)
                  : const SizedBox.shrink(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }
}

class _ErrorBox extends StatelessWidget {
  final String message;
  const _ErrorBox(this.message);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.burnt.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.burnt.withOpacity(0.3)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.error_outline, color: AppColors.burnt, size: 18),
        const SizedBox(width: 8),
        Expanded(
            child: Text(message,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.primaryDark))),
      ]),
    );
  }
}

/// Tabla de estado del dispositivo con campos fijos y etiquetas amigables.
/// Solo usa el mapa `health` (GET /api/health). El stream/health se oculta.
class _DeviceStatusTable extends StatelessWidget {
  final Map<String, dynamic> data;
  const _DeviceStatusTable(this.data);

  // Extrae un valor anidado de forma segura: _get(data, ['battery','batterypct'])
  static dynamic _get(Map<String, dynamic> map, List<String> path) {
    dynamic cur = map;
    for (final key in path) {
      if (cur is Map<String, dynamic> && cur.containsKey(key)) {
        cur = cur[key];
      } else {
        return null;
      }
    }
    return cur;
  }

  static String _str(dynamic v) => v == null ? '—' : '$v';

  @override
  Widget build(BuildContext context) {
    final general = <_StatusRow>[
      _StatusRow('Trampa',          _str(_get(data, ['last_cycle', 'id_trap']))),
      _StatusRow('Última Marca',    _str(_get(data, ['last_cycle', 'last_key']))),
      _StatusRow('Último Archivo',  _str(_get(data, ['last_cycle', 'last_run']))),
      _StatusRow('Hora Local',      _str(_get(data, ['time_local']))),
    ];
    final sensores = <_StatusRow>[
      _StatusRow('Batería',                  _str(_get(data, ['sensors', 'battery', 'battery_pct']))),
      _StatusRow('Humedad',                  _str(_get(data, ['sensors', 'dht22', 'hum_pct']))),
      _StatusRow('Temperatura Externa (°C)', _str(_get(data, ['sensors', 'dht22', 'temp_c']))),
      _StatusRow('Temp. Interna (°C)',       _str(_get(data, ['sensors', 'ds18b20', 'temp_c']))),
    ];
    final offline = <_StatusRow>[
      _StatusRow('Imágenes', _str(_get(data, ['offline_queue', 'jpg']))),
      _StatusRow('JSON',     _str(_get(data, ['offline_queue', 'json']))),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Section(title: 'GENERAL',  rows: general),
        const SizedBox(height: 12),
        _Section(title: 'SENSORES', rows: sensores),
        const SizedBox(height: 12),
        _Section(title: 'OFFLINE',  rows: offline),
      ],
    );
  }
}

class _StatusRow {
  final String label;
  final String value;
  const _StatusRow(this.label, this.value);
}

/// Sección con título y lista de filas dentro de un contenedor.
class _Section extends StatelessWidget {
  final String title;
  final List<_StatusRow> rows;
  const _Section({required this.title, required this.rows});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(title,
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  color: AppColors.primary,
                  letterSpacing: 1.2)),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.primarySurface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.primaryLight),
          ),
          child: Column(
            children: List.generate(rows.length, (i) {
              final row = rows[i];
              final isLast = i == rows.length - 1;
              return _RowWidget(
                label: row.label,
                value: row.value,
                showDivider: !isLast,
              );
            }),
          ),
        ),
      ],
    );
  }
}

class _RowWidget extends StatelessWidget {
  final String label;
  final String value;
  final bool showDivider;

  const _RowWidget({
    required this.label,
    required this.value,
    this.showDivider = true,
  });

  Color _valueColor() {
    final v = value.toLowerCase();
    if (v == 'true' || v == 'ok' || v == 'active' || v == 'running') {
      return AppColors.secondary;
    }
    if (v == 'false' || v == 'error' || v == 'inactive' || v == 'stopped' || v == '—') {
      return AppColors.textSecondary;
    }
    return AppColors.textPrimary;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Row(
            children: [
              Expanded(
                flex: 5,
                child: Text(label,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 5,
                child: Text(value,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _valueColor())),
              ),
            ],
          ),
        ),
        if (showDivider)
          const Divider(height: 1, indent: 12, endIndent: 12),
      ],
    );
  }
}
