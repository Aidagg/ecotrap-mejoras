import 'package:flutter/material.dart';
import '../../../../core/network/api_config_service.dart';
import '../../../../core/utils/app_colors.dart';
import 'api_config_screen.dart';
import 'files_list_screen.dart'; // Tu pantalla de archivos existente

/// Pantalla inicial que verifica la configuración de API
class ApiCheckScreen extends StatefulWidget {
  const ApiCheckScreen({super.key});

  @override
  State<ApiCheckScreen> createState() => _ApiCheckScreenState();
}

class _ApiCheckScreenState extends State<ApiCheckScreen> {
  bool _isLoading = true;
  bool _isConfigured = false;

  @override
  void initState() {
    super.initState();
    _checkConfiguration();
  }

  /// Verificar si la API está configurada
  Future<void> _checkConfiguration() async {
    setState(() => _isLoading = true);
    
    final hasApiKey = await ApiConfigService.hasApiKey();
    
    setState(() {
      _isConfigured = hasApiKey;
      _isLoading = false;
    });

    // Si está configurada, navegar automáticamente a la lista de archivos
    if (_isConfigured && mounted) {
      // Esperar un momento para mostrar el estado
      await Future.delayed(const Duration(milliseconds: 500));
      
      if (!mounted) return;
      
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const FilesListScreen(),
        ),
      );
    }
  }

  /// Ir a configuración
  void _goToConfig() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => const ApiConfigScreen(),
      ),
    );

    // Si se guardó la configuración, volver a verificar
    if (result == true) {
      _checkConfiguration();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sistema de Archivos'),
      ),
      body: Center(
        child: _isLoading
            ? const CircularProgressIndicator()
            : Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.vpn_key_off,
                      size: 100,
                      color: AppColors.golden,
                    ),
                    
                    const SizedBox(height: 24),
                    
                    Text(
                      'Configuración Requerida',
                      style: Theme.of(context).textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    
                    const SizedBox(height: 16),
                    
                    Text(
                      'Para acceder al sistema de archivos necesitas configurar tu API Key.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    
                    const SizedBox(height: 32),
                    
                    ElevatedButton.icon(
                      onPressed: _goToConfig,
                      icon: const Icon(Icons.settings),
                      label: const Text('Configurar API Key'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}