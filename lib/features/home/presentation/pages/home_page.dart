import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/utils/app_colors.dart';
import '../../../../core/utils/app_constants.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: AppColors.gradientBackground,
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Cabecera ─────────────────────────
                          Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(
                                  Icons.eco_rounded,
                                  color: AppColors.onPrimary,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'EcoTrap',
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineSmall
                                          ?.copyWith(
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0.6,
                                          ),
                                    ),
                                    Text(
                                      'Panel de control',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                              color: AppColors.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: 'Configuración',
                                onPressed: () =>
                                    Navigator.pushNamed(context, '/api-config'),
                                style: IconButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  minimumSize: const Size(48, 48),
                                  side: BorderSide(
                                    color: AppColors.primary
                                        .withValues(alpha: 0.2),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.settings_outlined,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),

                          const Spacer(flex: 2),

                          // ── Saludo ───────────────────────────
                          Text(
                            '¿Qué deseas hacer?',
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Elige una acción para continuar',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: AppColors.textSecondary),
                          ),

                          const Spacer(flex: 2),

                          // ── Acción principal: conectar ───────
                          _PrimaryActionCard(
                            icon: Icons.sensors,
                            label: 'Conectar a la trampa',
                            sublabel:
                                'Gestiona y conecta tus trampas guardadas',
                            onTap: () =>
                                Navigator.pushNamed(context, '/wifi-list'),
                          ),

                          const SizedBox(height: 16),

                          // ── Acciones secundarias ─────────────
                          IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  child: _SecondaryActionCard(
                                    icon: Icons.cloud_upload_rounded,
                                    iconColor: AppColors.primary,
                                    iconBackground: AppColors.primarySurface,
                                    label: 'Subir datos',
                                    sublabel:
                                        'Sincroniza los archivos JSON del dispositivo',
                                    onTap: () =>
                                        Navigator.pushNamed(context, '/upload'),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: _SecondaryActionCard(
                                    icon: Icons.videocam_rounded,
                                    iconColor: AppColors.brown,
                                    iconBackground:
                                        AppColors.brown.withValues(alpha: 0.12),
                                    label: 'Ver cámara',
                                    sublabel: 'Imagen en directo de la trampa',
                                    onTap: () => Navigator.pushNamed(
                                        context, '/camera-wifi'),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const Spacer(flex: 3),

                          // ── Pie de página ────────────────────
                          Center(
                            child: Text(
                              '${AppConstants.company} · ${AppConstants.appName} v${AppConstants.version}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────
// Tarjeta principal (ancho completo)
// ─────────────────────────────────────────────────

class _PrimaryActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sublabel;
  final VoidCallback onTap;

  const _PrimaryActionCard({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.3),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, size: 30, color: AppColors.onPrimary),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          color: AppColors.onPrimary,
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        sublabel,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.white70,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────
// Tarjeta secundaria (mitad de ancho)
// ─────────────────────────────────────────────────

class _SecondaryActionCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String label;
  final String sublabel;
  final VoidCallback onTap;

  const _SecondaryActionCard({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.label,
    required this.sublabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: AppColors.primary.withValues(alpha: 0.12)),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: iconBackground,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, size: 26, color: iconColor),
              ),
              const SizedBox(height: 18),
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                sublabel,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
