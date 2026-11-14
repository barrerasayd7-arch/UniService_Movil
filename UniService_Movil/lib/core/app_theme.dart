import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';

abstract final class AppTheme {
  static final oscuro = crear(oscuro: true);
  static final claro = crear(oscuro: false);

  static ThemeData crear({required bool oscuro}) {
    final p = AppPalette(oscuro: oscuro);
    final scheme =
        ColorScheme.fromSeed(
          seedColor: p.teal,
          brightness: oscuro ? Brightness.dark : Brightness.light,
        ).copyWith(
          primary: p.teal,
          onPrimary: p.sobreAcento,
          secondary: p.amarillo,
          onSecondary: p.sobreAcento,
          surface: p.card,
          onSurface: p.texto,
          onSurfaceVariant: p.texto2,
          error: p.errorTexto,
          onError: Colors.white,
          outline: p.bordeCampo,
          outlineVariant: p.borde,
          surfaceContainerHighest: p.bg3,
        );
    final base = ThemeData(useMaterial3: true, colorScheme: scheme);
    return base.copyWith(
      scaffoldBackgroundColor: p.bg,
      canvasColor: p.card,
      dividerColor: p.borde,
      textTheme: base.textTheme.apply(
        bodyColor: p.texto,
        displayColor: p.texto,
      ),
      iconTheme: IconThemeData(color: p.texto2),
      appBarTheme: AppBarTheme(
        backgroundColor: p.bg,
        foregroundColor: p.texto,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: oscuro
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
      ),
      cardTheme: CardThemeData(
        color: p.card,
        surfaceTintColor: Colors.transparent,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.card,
        surfaceTintColor: Colors.transparent,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.card,
        surfaceTintColor: Colors.transparent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: TextStyle(color: p.placeholder),
        labelStyle: TextStyle(color: p.texto2),
        errorStyle: TextStyle(color: p.errorTexto),
        fillColor: p.bg2,
      ),
    );
  }
}
