// Archivo: app_text.dart
// Responsabilidad: helpers de tipografía (Poppins para cuerpo, DM Serif Display para títulos).
// Se usa desde: pantallas y widgets que necesitan estilos de texto del tema.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Fuentes de la web: Poppins (cuerpo) y DM Serif Display (títulos).
class AppText {
  AppText._();

  /// Texto de cuerpo con Poppins; centraliza tamaño, peso, color, interlineado y sombras.
  static TextStyle poppins(
    double size, {
    FontWeight weight = FontWeight.w400,
    Color color = AppColors.texto,
    double? spacing,
    double? height,
    FontStyle? style,
    List<Shadow>? shadows,
  }) {
    return GoogleFonts.poppins(
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: spacing,
      height: height,
      fontStyle: style,
      shadows: shadows,
    );
  }

  /// Título con DM Serif Display; no acepta peso porque la familia solo trae un estilo.
  static TextStyle serif(
    double size, {
    Color color = AppColors.texto,
    FontStyle? style,
    double? height,
    List<Shadow>? shadows,
  }) {
    return GoogleFonts.dmSerifDisplay(
      fontSize: size,
      color: color,
      fontStyle: style,
      height: height,
      shadows: shadows,
    );
  }
}
