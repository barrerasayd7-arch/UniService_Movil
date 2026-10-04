import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Fuentes de la web: Poppins (cuerpo) y DM Serif Display (títulos).
class AppText {
  AppText._();

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
