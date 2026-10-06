import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:wifi_iot/wifi_iot.dart';

import '../../../../core/network/api_config_service.dart';
import '../../../../core/network/wifi_network_client.dart';
import '../../../../core/network/wifi_reconnect_service.dart';
import '../../domain/entities/wifi_network.dart';
import '../../../../core/utils/app_colors.dart';
import '../../../../core/utils/app_constants.dart';
import '../bloc/wifi_bloc.dart';
import '../bloc/wifi_event.dart';
import '../bloc/wifi_state.dart';
import '../widgets/add_wifi_dialog.dart';
import '../widgets/empty_state_widget.dart';
import '../widgets/wifi_list_item.dart';

class WiFiListPage extends StatefulWidget {
  final String pageTitle;
  final String connectLabel;
  final String connectRoute;

  const WiFiListPage({
    super.key,
    this.pageTitle = 'Trampas',
    this.connectLabel = 'Ver archivos',
    this.connectRoute = '/files-list',
  });

  @override
  State<WiFiListPage> createState() => _WiFiListPageState();
}

class _WiFiListPageState extends State<WiFiListPage> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    context.read<WiFiBloc>().add(const LoadWiFiNetworksEvent());
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_isBottom) {
      context.read<WiFiBloc>().add(const LoadMoreWiFiNetworksEvent());
    }
  }

  bool get _isBottom {
    if (!_scrollController.hasClients) return false;
    return _scrollController.offset >=
        (_scrollController.position.maxScrollExtent * 0.9);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.pageTitle),
        elevation: 0,
        actions: [
          // ✅ CORRECTO: solo botones en actions
          BlocBuilder<WiFiBloc, WiFiState>(
            builder: (context, state) {
              final isScanning = state is WiFiScanning;
              final isNearby =
                  state is WiFiNearbyLoaded || state is WiFiSavedFromNearby;

              if (isNearby) {
                return TextButton.icon(
                  onPressed: () => context
                      .read<WiFiBloc>()
                      .add(const BackToSavedNetworksEvent()),
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  label: const Text('Volver',
                      style: TextStyle(color: Colors.white)),
                );
              }

              return IconButton(
                icon: isScanning
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.radar),
                onPressed: isScanning
                    ? null
                    : () => context
                        .read<WiFiBloc>()
                        .add(const ScanNearbyNetworksEvent()),
                tooltip: 'Buscar redes ENTOMOLAB',
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _showInfoDialog,
            tooltip: 'Información',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: BlocConsumer<WiFiBloc, WiFiState>(
              listener: (context, state) {
                if (state is WiFiSaved) {
                  _showSuccessSnackbar('Red WiFi guardada exitosamente');
                } else if (state is WiFiSavedFromNearby) {
                  _showSuccessSnackbar(
                      'Red guardada: ${state.network.ssid}');
                } else if (state is WiFiDeleted) {
                  _showSuccessSnackbar('Red WiFi eliminada');
                } else if (state is WiFiError) {
                  _showErrorSnackbar(state.message);
                }
              },
              builder: (context, state) {
                if (state is WiFiLoading) return _buildLoadingState();
                if (state is WiFiScanning) return _buildScanningState();

                // ✅ WiFiNearbyLoaded — vista de escaneo normal
                if (state is WiFiNearbyLoaded) {
                  return _buildNearbyState(state);
                }

                // ✅ WiFiSavedFromNearby — mantiene vista de escaneo
                // con la red recién guardada ya excluida del listado
                if (state is WiFiSavedFromNearby) {
                  return _buildNearbyState(WiFiNearbyLoaded(
                    nearbyNetworks: state.nearbyNetworks,
                    savedNetworks: state.savedNetworks,
                    savedTotalCount: state.savedTotalCount,
                    savedCurrentPage: state.savedCurrentPage,
                    savedHasMorePages: state.savedHasMorePages,
                    connectedSsid: state.connectedSsid,
                    connectedBssid: state.connectedBssid,
                  ));
                }

                if (state is WiFiLoaded) {
                  return state.isEmpty
                      ? _buildEmptyState()
                      : _buildLoadedState(state);
                }
                if (state is WiFiLoadingMore) {
                  return _buildLoadingMoreState(state);
                }
                if (state is WiFiError) {
                  return _buildErrorState(state.message);
                }
                return _buildEmptyState();
              },
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            Navigator.pushNamed(context, '/api-config'),
                        icon: const Icon(Icons.settings, size: 18),
                        label: const Text('Configuración'),
                        style: OutlinedButton.styleFrom(
                          padding:
                              const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _showAddDialog,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Agregar Red'),
                        style: OutlinedButton.styleFrom(
                          padding:
                              const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),                    
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Builders ──────────────────────────────────────────────

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Cargando redes WiFi...'),
        ],
      ),
    );
  }

  Widget _buildScanningState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 64,
            height: 64,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
          const SizedBox(height: 24),
          Text(
            'Buscando redes ENTOMOLAB...',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Esto puede tardar unos segundos',
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildNearbyState(WiFiNearbyLoaded state) {
    final savedSsids = state.savedNetworks
        .map((n) => n.ssid.toLowerCase().trim())
        .toSet();

    final savedBssids = state.savedNetworks
        .where((n) => n.bssid != null && n.bssid!.isNotEmpty)
        .map((n) => n.bssid!.toLowerCase().trim())
        .toSet();

    print('🔍 savedSsids: $savedSsids');
    print('🔍 savedBssids: $savedBssids');

    final filteredNetworks = state.nearbyNetworks.where((ap) {
      final apSsid = ap.ssid.toLowerCase().trim();
      final apBssid = ap.bssid.toLowerCase().trim();

      print('🔍 ap → ssid: $apSsid | bssid: $apBssid');

      // Si tiene BSSID: excluir solo si ese BSSID ya está guardado
      if (apBssid.isNotEmpty) {
        return !savedBssids.contains(apBssid);
      }
      // Sin BSSID: excluir por SSID (no hay forma de distinguir)
      return !savedSsids.contains(apSsid);
    }).toList();

    print('🔍 filteredNetworks.length: ${filteredNetworks.length}');

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          color: Theme.of(context).primaryColor.withOpacity(0.1),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.radar,
                  size: 16, color: Theme.of(context).primaryColor),
              const SizedBox(width: 8),
              Text(
                filteredNetworks.isEmpty
                    ? 'No hay redes ENTOMOLAB nuevas cercanas'
                    : '${filteredNetworks.length} redes ENTOMOLAB nuevas encontradas',
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).primaryColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: filteredNetworks.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.wifi_off,
                          size: 64, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text(
                        state.nearbyNetworks.isEmpty
                            ? 'Sin redes ENTOMOLAB cercanas'
                            : 'Todas las redes cercanas\nya están guardadas',
                        style: TextStyle(
                            color: Colors.grey[600], fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        state.nearbyNetworks.isEmpty
                            ? 'Asegúrate de estar cerca\nde un dispositivo ENTOMOLAB'
                            : 'No hay redes nuevas que agregar',
                        style: TextStyle(
                            color: Colors.grey[400], fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      OutlinedButton.icon(
                        onPressed: () => context
                            .read<WiFiBloc>()
                            .add(const ScanNearbyNetworksEvent()),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Escanear de nuevo'),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredNetworks.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final ap = filteredNetworks[index];
                    final isConnected = state.connectedBssid != null
                        ? ap.bssid.toLowerCase() ==
                            state.connectedBssid!.toLowerCase()
                        : ap.ssid.toLowerCase() ==
                            state.connectedSsid?.toLowerCase();
                    return _buildNearbyCard(ap, isConnected: isConnected);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildNearbyCard(NearbyWiFiNetwork ap,
      {bool isConnected = false}) {
    final signalColor = ap.signalPercent >= 75
        ? AppColors.secondary
        : ap.signalPercent >= 50
            ? AppColors.golden
            : AppColors.burnt;

    final cardColor = isConnected ? AppColors.primarySurface : null;
    final borderColor = isConnected
        ? AppColors.secondary
        : Theme.of(context).primaryColor.withOpacity(0.4);

    return Card(
      elevation: isConnected ? 4 : 2,
      color: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: borderColor, width: isConnected ? 2 : 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: signalColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child:
                      Icon(ap.signalIcon, color: signalColor, size: 24),
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
                              ap.ssid,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (isConnected)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
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
                      const SizedBox(height: 2),
                      Text(
                        ap.bssid,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[500],
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: signalColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border:
                        Border.all(color: signalColor.withOpacity(0.4)),
                  ),
                  child: Text(
                    '${ap.signalPercent}%',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: signalColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: ap.signalPercent / 100,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(signalColor),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: isConnected
                    ? null
                    : () => _showPasswordDialogAndConnect(ap),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isConnected ? AppColors.secondary : null,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: Icon(
                  isConnected ? Icons.wifi_tethering : Icons.save_alt,
                ),
                label: Text(
                  isConnected ? 'Ya conectado' : 'Guardar y conectar',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

void _showPasswordDialogAndConnect(NearbyWiFiNetwork ap) {
  final passwordController = TextEditingController();
  bool obscure = true;
  String? passwordError;

  showDialog(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.wifi,
                color: Theme.of(dialogContext).primaryColor),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                ap.ssid,
                style: const TextStyle(fontSize: 18),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'BSSID: ${ap.bssid}',
              style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[500],
                  fontFamily: 'monospace'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              obscureText: obscure,
              autofocus: true,
              onChanged: (_) {
                // ✅ Limpiar error al escribir
                if (passwordError != null) {
                  setDialogState(() => passwordError = null);
                }
              },
              decoration: InputDecoration(
                labelText: 'Contraseña',
                prefixIcon: const Icon(Icons.lock),
                // ✅ Error inline visible dentro del diálogo
                errorText: passwordError,
                suffixIcon: IconButton(
                  icon: Icon(obscure
                      ? Icons.visibility_off
                      : Icons.visibility),
                  onPressed: () =>
                      setDialogState(() => obscure = !obscure),
                ),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              final password = passwordController.text;
              if (password.length < 8) {
                setDialogState(() {
                  passwordError = 'Mínimo 8 caracteres';
                });
                return;
              }
              Navigator.pop(dialogContext);
              // Conectar primero → obtener nombre → luego guardar
              _connectAndSaveNearbyNetwork(ap, password);
            },
            icon: const Icon(Icons.save_alt),
            label: const Text('Guardar y conectar'),
          ),
        ],
      ),
    ),
  );
}
  /// Flujo: 1) conectar WiFi  2) GET /api/health → id_trap  3) guardar con nombre
  Future<void> _connectAndSaveNearbyNetwork(
      NearbyWiFiNetwork ap, String password) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Text('Conectando a ${ap.ssid}...'),
        ]),
        duration: const Duration(seconds: 40),
        behavior: SnackBarBehavior.floating,
      ),
    );

    try {
      // ── Paso 1: conectar al WiFi ──────────────────────────────
      const wifiChannel = MethodChannel('es.ecotrap.ecotrap/wifi_network');
      final resultMap = await wifiChannel.invokeMapMethod<String, dynamic>(
        'connectToWifi',
        {
          'ssid': ap.ssid,
          'password': password,
          if (ap.bssid.isNotEmpty) 'bssid': ap.bssid,
        },
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();

      final success = resultMap?['success'] as bool? ?? false;
      final message = resultMap?['message'] as String? ?? 'Error desconocido';

      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ]),
          backgroundColor: AppColors.golden,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ));
        return;
      }

      await WiFiReconnectService.saveLastWifi(
          ssid: ap.ssid, password: password, bssid: ap.bssid);

      // Dar tiempo a Android para propagar el routing de la nueva red
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;

      // ── Paso 2: GET /api/health → last_cycle.id_trap ─────────
      final config = await ApiConfigService.getConfig();

      // Sin API key → no tiene sentido continuar; forzar configuración
      if (!config.isConfigured) {
        if (!mounted) return;
        _showApiKeyRequiredDialog();
        return;
      }

      final baseUri = Uri.parse(config.baseUrl);
      final healthUrl = '${baseUri.replace(port: 8081)}/health';
      debugPrint('🌐 GET /api/health → $healthUrl');

      String trapName;
      try {
        final dio = Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
          headers: {'x-api-key': config.apiKey!},
          validateStatus: (status) => status != null,
        ));
        // Vincular Dio a la interfaz WiFi del trap (igual que ApiService)
        await WifiNetworkClient.bindDioToWifi(dio);
        final response = await dio.get(healthUrl);

        if (response.statusCode == 401) {
          if (!mounted) return;
          _showApiKeyRequiredDialog(invalid: true);
          return;
        }

        if (response.statusCode != 200) {
          if (!mounted) return;
          _showHealthError(
              'El trap respondió con código ${response.statusCode}. Verifica la configuración.');
          return;
        }

        final data = response.data is String
            ? jsonDecode(response.data as String)
            : response.data as Map<String, dynamic>;

        final id = data['last_cycle']?['id_trap'] as String?;
        if (id == null || id.isEmpty) {
          if (!mounted) return;
          _showHealthError('El trap no devolvió un ID válido en last_cycle.id_trap.');
          return;
        }

        trapName = id;
        debugPrint('✅ Nombre del trap: $trapName');
      } on DioException catch (e) {
        debugPrint('❌ Error GET $healthUrl → ${e.type}: ${e.message}');
        if (!mounted) return;
        if (e.response?.statusCode == 401) {
          _showApiKeyRequiredDialog(invalid: true);
        } else {
          _showHealthError(
              'No se pudo comunicar con el trap.\n'
              'URL: $healthUrl\n'
              'Error: ${e.message}');
        }
        return;
      }

      // ── Paso 3: guardar con nombre ya incluido ────────────────
      if (!mounted) return;
      context.read<WiFiBloc>().add(SaveAndConnectNearbyEvent(
            ssid: ap.ssid,
            bssid: ap.bssid,
            password: password,
            name: trapName,
          ));

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(Icons.check_circle, color: Colors.white),
          const SizedBox(width: 12),
          Expanded(
              child: Text('Conectado: $trapName')),
        ]),
        backgroundColor: AppColors.secondary,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ));

      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      context.read<WiFiBloc>().add(const BackToSavedNetworksEvent());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error al conectar: $e'),
          backgroundColor: AppColors.burnt,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  Widget _buildEmptyState() {
    return RefreshIndicator(
      onRefresh: () async =>
          context.read<WiFiBloc>().add(const RefreshWiFiNetworksEvent()),
      child: const EmptyStateWidget(),
    );
  }

  Widget _buildLoadedState(WiFiLoaded state) {
    return RefreshIndicator(
      onRefresh: () async =>
          context.read<WiFiBloc>().add(const RefreshWiFiNetworksEvent()),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            color: Theme.of(context).primaryColor.withOpacity(0.1),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.wifi,
                    size: 16, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Mostrando ${state.networks.length} de ${state.totalCount} redes',
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).primaryColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount:
                  state.networks.length + (state.hasMorePages ? 1 : 0),
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                if (index >= state.networks.length) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }
                return WiFiListItem(
                  network: state.networks[index],
                  onEdit: () => _showEditDialog(state.networks[index]),
                  onDelete: () =>
                      _confirmDelete(state.networks[index]),
                  connectLabel: widget.connectLabel,
                  connectRoute: widget.connectRoute,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingMoreState(WiFiLoadingMore state) {
    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            itemCount: state.currentNetworks.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) => WiFiListItem(
              network: state.currentNetworks[index],
              onEdit: () =>
                  _showEditDialog(state.currentNetworks[index]),
              onDelete: () =>
                  _confirmDelete(state.currentNetworks[index]),
              connectLabel: widget.connectLabel,
              connectRoute: widget.connectRoute,
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(),
        ),
      ],
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 80, color: AppColors.burnt),
            const SizedBox(height: 24),
            Text('Ops! Algo salió mal',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => context
                  .read<WiFiBloc>()
                  .add(const RefreshWiFiNetworksEvent()),
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => BlocProvider.value(
        value: context.read<WiFiBloc>(),
        child: const AddWiFiDialog(),
      ),
    );
  }

  void _showEditDialog(dynamic network) {
    showDialog(
      context: context,
      builder: (dialogContext) => BlocProvider.value(
        value: context.read<WiFiBloc>(),
        child: AddWiFiDialog(network: network),
      ),
    );
  }

  void _confirmDelete(WiFiNetwork network) {
    final bloc = context.read<WiFiBloc>();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar Red'),
        content: const Text(
            '¿Estás seguro de que deseas eliminar esta red WiFi?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              bloc.add(DeleteWiFiNetworkEvent(network.id));
              _disconnectIfConnected(network);
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.burnt),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  /// Desconecta del trap si la red eliminada es la que está conectada actualmente.
  Future<void> _disconnectIfConnected(WiFiNetwork network) async {
    try {
      final isConnected = await WiFiForIoTPlugin.isConnected();
      if (!isConnected) return;

      final currentBssid =
          (await WiFiForIoTPlugin.getBSSID())?.replaceAll('"', '').trim() ?? '';
      final currentSsid =
          (await WiFiForIoTPlugin.getSSID())?.replaceAll('"', '').trim() ?? '';

      final bool isThisNetwork;
      if (network.bssid != null &&
          network.bssid!.isNotEmpty &&
          currentBssid.isNotEmpty) {
        isThisNetwork =
            currentBssid.toLowerCase() == network.bssid!.toLowerCase();
      } else {
        isThisNetwork = currentSsid == network.ssid;
      }

      if (isThisNetwork) {
        await WifiNetworkClient.unbindNetwork();
        await WiFiForIoTPlugin.disconnect();
        debugPrint('✅ Desconectado de ${network.ssid} al eliminar');
      }
    } catch (e) {
      debugPrint('⚠️ Error al desconectar al eliminar: $e');
    }
  }

  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('${AppConstants.appName} v${AppConstants.version}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Gestiona tus redes WiFi de forma segura.',
                style: TextStyle(fontSize: 16)),
            const SizedBox(height: 16),
            _buildInfoRow(Icons.security, 'Almacenamiento local seguro'),
            _buildInfoRow(Icons.offline_bolt, 'Funciona sin conexión'),
            _buildInfoRow(Icons.list, 'Paginación automática'),
            _buildInfoRow(
                Icons.radar, 'Detecta redes ENTOMOLAB cercanas'),
            const SizedBox(height: 16),
            Text('v${AppConstants.version}',
                style:
                    TextStyle(fontSize: 12, color: Colors.grey[600])),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).primaryColor),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }

  void _showApiKeyRequiredDialog({bool invalid = false}) {
    ScaffoldMessenger.of(context).clearSnackBars();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.key_off, color: Colors.red),
          SizedBox(width: 10),
          Expanded(child: Text('API Key requerida')),
        ]),
        content: Text(
          invalid
              ? 'La API Key configurada no es válida (401 Unauthorized).\n\nConfigura una API Key correcta antes de guardar la red.'
              : 'No hay ninguna API Key configurada.\n\nDebe configurar la API Key para poder identificar el trap.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pushNamed(context, '/api-config');
            },
            icon: const Icon(Icons.settings),
            label: const Text('Ir a Configuración'),
          ),
        ],
      ),
    );
  }

  void _showHealthError(String message) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.error_outline, color: Colors.white),
        const SizedBox(width: 12),
        Expanded(child: Text(message)),
      ]),
      backgroundColor: AppColors.burnt,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 5),
    ));
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.check_circle, color: Colors.white),
        const SizedBox(width: 12),
        Expanded(child: Text(message)),
      ]),
      backgroundColor: AppColors.secondary,
      behavior: SnackBarBehavior.floating,
    ));
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.error, color: Colors.white),
        const SizedBox(width: 12),
        Expanded(child: Text(message)),
      ]),
      backgroundColor: AppColors.burnt,
      behavior: SnackBarBehavior.floating,
    ));
  }
}