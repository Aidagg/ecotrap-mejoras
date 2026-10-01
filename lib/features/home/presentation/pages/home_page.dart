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
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
                horizontal: 24, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ───────────────────────────────────
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.bug_report,
                        color: AppColors.onPrimary,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          'EcoTrap',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                        ),
                        Text(
                          'Panel de control',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                  color: AppColors.forest),
                        ),
                      ],
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(
                          Icons.settings_outlined,
                          color: AppColors.primary),
                      onPressed: () => Navigator.pushNamed(
                          context, '/api-config'),
                      tooltip: 'Configuracion',
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // ── Saludo ───────────────────────────────────
                Text(
                  'Que deseas hacer?',
                  style: Theme.of(context)
                      .textTheme
                      .headlineMedium
                      ?.copyWith(
                        color: AppColors.primaryDark,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Selecciona una accion para continuar',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(
                          color: AppColors.textSecondary),
                ),

                const SizedBox(height: 40),

                // ── Botón 1: Conectar IoT ─────────────────────
                _HeroButton(
                  icon: Icons.sensors,
                  label: 'Conectar a dispositivo IoT',
                  sublabel:
                      'Gestiona y conecta a trampas guardadas',
                  gradientColors: AppColors.gradientPrimary,
                  iconBackground: AppColors.primaryDark,
                  onTap: () => Navigator.pushNamed(
                      context, '/wifi-list'),
                ),

                const SizedBox(height: 20),

                // ── Botón 2: Subir datos ──────────────────────
                _HeroButton(
                  icon: Icons.cloud_upload_rounded,
                  label: 'Subir datos a Ecotrap',
                  sublabel:
                      'Sincroniza los archivos JSON del dispositivo',
                  gradientColors: AppColors.gradientSecondary,
                  iconBackground: AppColors.secondaryDark,
                  onTap: () =>
                      Navigator.pushNamed(context, '/upload'),
                ),

                const SizedBox(height: 20),

                // ── Botón 3: Ver cámara ───────────────────────
                _HeroButton(
                  icon: Icons.videocam_rounded,
                  label: 'Ver cámara en tiempo real',
                  sublabel:
                      'Conecta y visualiza el stream de la trampa',
                  gradientColors: const [
                    AppColors.forest,
                    AppColors.brown,
                  ],
                  iconBackground: AppColors.brown,
                  onTap: () =>
                      Navigator.pushNamed(context, '/camera-wifi'),
                ),

                const SizedBox(height: 24),

                // ── Footer ───────────────────────────────────
                Center(
                  child: Text(
                    '${AppConstants.company} · ${AppConstants.appName} v${AppConstants.version}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.forest,
                      letterSpacing: 0.8,
                    ),
                  ),
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
// Widget reutilizable: botón hero con gradiente
// ─────────────────────────────────────────────────

class _HeroButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sublabel;
  final List<Color> gradientColors;
  final Color iconBackground;
  final VoidCallback onTap;

  const _HeroButton({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.gradientColors,
    required this.iconBackground,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradientColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: gradientColors.last.withOpacity(0.4),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 24, vertical: 28),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: iconBackground.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon,
                      size: 36,
                      color: AppColors.onPrimary),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          color: AppColors.onPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        sublabel,
                        style: TextStyle(
                          color: AppColors.onPrimary
                              .withOpacity(0.8),
                          fontSize: 12,
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
