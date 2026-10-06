import 'package:flutter/material.dart';

/// Paleta de colores corporativa de EcoTrap / EntomoLab
///
/// Colors corporatius:
///   Verd fosc  → #006633  (color principal)
///   Verd clar  → #3AAA35  (color secundari)
///
/// Colors secundaris – Gama natura terra 2:
///   Forest     → #597D60
///   Olive      → #949644
///   Golden     → #E3B947
///   Burnt      → #D45219
///   Brown      → #63442B
class AppColors {
  AppColors._();

  // ── Corporativos ──────────────────────────────────────────────────────────

  /// Verde oscuro — color principal de marca
  static const Color primary = Color(0xFF006633);

  /// Verde oscuro más profundo (hover / pressed)
  static const Color primaryDark = Color(0xFF004D22);

  /// Verde oscuro más claro (iconos sobre fondo claro)
  static const Color primaryLight = Color(0xFF33885A);

  /// Superficie muy clara del primario (fondos de cards)
  static const Color primarySurface = Color(0xFFE8F4EE);

  /// Verde claro — color secundario de marca
  static const Color secondary = Color(0xFF3AAA35);

  /// Verde claro más oscuro (hover / pressed)
  static const Color secondaryDark = Color(0xFF2A8A25);

  /// Verde claro más suave
  static const Color secondaryLight = Color(0xFF6FBF6B);

  /// Superficie muy clara del secundario
  static const Color secondarySurface = Color(0xFFEDF7EC);

  // ── Gama natura terra 2 ───────────────────────────────────────────────────

  /// Verde bosque apagado
  static const Color forest = Color(0xFF597D60);

  /// Verde oliva
  static const Color olive = Color(0xFF949644);

  /// Amarillo dorado
  static const Color golden = Color(0xFFE3B947);

  /// Naranja quemado
  static const Color burnt = Color(0xFFD45219);

  /// Marrón tierra
  static const Color brown = Color(0xFF63442B);

  // ── Utilitarios UI ────────────────────────────────────────────────────────

  /// Fondo general de pantallas
  static const Color surface = Color(0xFFF4FAF6);

  /// Texto sobre fondo primario
  static const Color onPrimary = Colors.white;

  /// Texto principal de la app
  static const Color textPrimary = Color(0xFF1A2E22);

  /// Texto secundario / hints
  static const Color textSecondary = Color(0xFF4A6B52);

  // ── Degradados predefinidos ───────────────────────────────────────────────

  /// Degradado principal (botón IoT / splash)
  static const List<Color> gradientPrimary = [
    primary,
    primaryDark,
  ];

  /// Degradado secundario (botón Upload)
  static const List<Color> gradientSecondary = [
    secondary,
    secondaryDark,
  ];

  /// Degradado de fondo de pantalla Home
  static const List<Color> gradientBackground = [
    Color(0xFFE8F4EE),
    Color(0xFFD4EDD9),
    Color(0xFFEDF7EC),
  ];
}
