import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/wifi_network.dart';
import '../bloc/wifi_bloc.dart';
import '../bloc/wifi_event.dart';

/// Diálogo: Agregar/Editar Red WiFi
/// 
/// Formulario para crear o editar una red WiFi
/// - Validaciones en tiempo real
/// - Mostrar/ocultar contraseña
/// - Modo edición con datos precargados
class AddWiFiDialog extends StatefulWidget {
  final WiFiNetwork? network; // null = modo crear, !null = modo editar

  const AddWiFiDialog({
    super.key,
    this.network,
  });

  @override
  State<AddWiFiDialog> createState() => _AddWiFiDialogState();
}

class _AddWiFiDialogState extends State<AddWiFiDialog> {
  final _formKey = GlobalKey<FormState>();
  final _ssidController = TextEditingController();
  final _passwordController = TextEditingController();
  
  bool _isPasswordVisible = false;
  bool _isLoading = false;

  bool get _isEditMode => widget.network != null;

  @override
  void initState() {
    super.initState();
    
    // Precargar datos en modo edición
    if (_isEditMode) {
      _ssidController.text = widget.network!.ssid;
      _passwordController.text = widget.network!.password;
    }
  }

  @override
  void dispose() {
    _ssidController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _isEditMode ? Icons.edit : Icons.wifi,
                        color: Theme.of(context).primaryColor,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        _isEditMode ? 'Editar Red WiFi' : 'Nueva Red WiFi',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),
                
                // Campo: SSID (Nombre de la red)
                TextFormField(
                  controller: _ssidController,
                  decoration: InputDecoration(
                    labelText: 'Nombre de la Red (SSID)',
                    hintText: 'Ej: Mi_WiFi_Casa',
                    prefixIcon: const Icon(Icons.wifi),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                    helperText: 'Máximo 32 caracteres',
                  ),
                  maxLength: 32,
                  textCapitalization: TextCapitalization.none,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Por favor ingresa el nombre de la red';
                    }
                    if (value.trim().length < 2) {
                      return 'El nombre debe tener al menos 2 caracteres';
                    }
                    if (value.length > 32) {
                      return 'El nombre no puede tener más de 32 caracteres';
                    }
                    return null;
                  },
                ),
                
                const SizedBox(height: 20),
                
                // Campo: Contraseña
                TextFormField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: 'Contraseña',
                    hintText: 'Ingresa la contraseña',
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isPasswordVisible
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() {
                          _isPasswordVisible = !_isPasswordVisible;
                        });
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                    helperText: 'Entre 8 y 63 caracteres',
                  ),
                  obscureText: !_isPasswordVisible,
                  maxLength: 63,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Por favor ingresa la contraseña';
                    }
                    if (value.length < 8) {
                      return 'La contraseña debe tener al menos 8 caracteres';
                    }
                    if (value.length > 63) {
                      return 'La contraseña no puede tener más de 63 caracteres';
                    }
                    return null;
                  },
                ),
                
                const SizedBox(height: 24),
                
                // Información adicional
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.blue[700],
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Tus datos se guardan de forma segura en tu dispositivo',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue[900],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Botones de acción
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isLoading ? null : () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Cancelar'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleSave,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : Text(_isEditMode ? 'Actualizar' : 'Guardar'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Manejar guardado
  void _handleSave() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final ssid = _ssidController.text.trim();
    final password = _passwordController.text;

    if (_isEditMode) {
      // Modo edición
      context.read<WiFiBloc>().add(
        UpdateWiFiNetworkEvent(
          id: widget.network!.id,
          ssid: ssid,
          password: password,
        ),
      );
    } else {
      // Modo crear
      context.read<WiFiBloc>().add(
        SaveWiFiNetworkEvent(
          ssid: ssid,
          password: password,
        ),
      );
    }

    // Cerrar diálogo
    Navigator.pop(context);
  }
}