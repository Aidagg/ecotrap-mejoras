import 'package:flutter/material.dart';

/// Widget: Estado vacío
/// 
/// Se muestra cuando no hay redes WiFi guardadas
class EmptyStateWidget extends StatelessWidget {
  const EmptyStateWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 60),
        Icon(
          Icons.wifi_off,
          size: 120,
          color: Colors.grey[300],
        ),
        const SizedBox(height: 32),
        Text(
          'No hay redes guardadas',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Comienza agregando tu primera red WiFi\npresionando el botón "Agregar Red"',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 40),
        _buildFeatureItem(
          context,
          Icons.security,
          'Seguro',
          'Tus contraseñas se guardan de forma local',
        ),
        const SizedBox(height: 16),
        _buildFeatureItem(
          context,
          Icons.offline_bolt,
          'Sin conexión',
          'Accede a tus redes sin internet',
        ),
        const SizedBox(height: 16),
        _buildFeatureItem(
          context,
          Icons.edit,
          'Fácil de usar',
          'Edita y elimina redes cuando quieras',
        ),
      ],
    );
  }

  Widget _buildFeatureItem(
    BuildContext context,
    IconData icon,
    String title,
    String description,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: Theme.of(context).primaryColor,
            size: 24,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                description,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}