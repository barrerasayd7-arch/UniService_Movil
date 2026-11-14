// Archivo: app_colors.dart
// Responsabilidad: paletas claro/oscuro basadas en la web y breakpoints.
// Se usa desde: pantallas y widgets para mantener colores y cortes responsive consistentes.

import 'package:flutter/material.dart';

/// Equivalente a las variables `:root` de styleHome.css / StyleLogin.css
/// (tema oscuro, que es el tema por defecto de la web).
class AppColors {
  AppColors._();

  /// Registra la dependencia del tema para actualizar incluso widgets const.
  static AppPalette of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? const AppPalette(oscuro: true)
      : const AppPalette(oscuro: false);

  static const bg = Color(0xFF070D16);
  static const bg2 = Color(0xFF0B1420);
  static const bg3 = Color(0xFF0F1C2E);
  static const card = Color(0xFF0E1929);
  static const cardHover = Color(0xFF111F33);
  static const borde = Color(0xFF1A2E48);
  static const borde2 = Color(0xFF243D5C);
  static const teal = Color(0xFF0EA5A0);
  static const teal2 = Color(0xFF14C7C1);
  static const amarillo = Color(0xFFF5C842);
  static const texto = Color(0xFFE8EEF8);
  static const texto2 = Color(0xFF8FA3BF);
  static const texto3 = Color(0xFF4A6080);

  static const error = Color(0xFFF0292C);

  // Formularios (contraste medido sobre bg2 #0B1420 / bg #070D16):
  static const placeholder = Color(0xFF6B82A3); // 4.7:1

  // Borde visible del campo en reposo.
  static const bordeCampo = Color(0xFF2B4466);

  // 7.0:1 (el rojo de marca da 4.7:1).
  static const errorTexto = Color(0xFFFF6B6B);
  static const verificado = Color(0xFF00C851);
  static const tealBrillante = Color(0xFF2DD4BF); // iconos / tesseract del hero
  static const estrella = Color(0xFFF5A623);
  static const violeta = Color(0xFF8B5CF6);

  // Modo administrador: color exclusivo del acceso y del panel (el ámbar ya es "solicitudes"
  // y estrellas). 7.2:1 sobre bg y 7.2:1 con texto bg encima.
  static const admin = Color(0xFFA78BFA);
  static const adminHover = Color(0xFFC4B5FD);

  /// Color con opacidad (equivale a rgba(r,g,b,o) del CSS).
  static Color a(Color c, double opacity) =>
      c.withAlpha((opacity.clamp(0.0, 1.0) * 255).round());

  /// Fondo translúcido del teal (12 %) para chips y estados seleccionados.
  static Color get tealDim => a(teal, 0.12);
}

/// Paleta clara basada en styles/light_theme/B_styleHome.css del proyecto web.
/// Los acentos usados como texto se oscurecen para conservar el contraste.
class AppPalette {
  final bool oscuro;
  const AppPalette({required this.oscuro});

  Color get bg => oscuro ? AppColors.bg : const Color(0xFFF8F9FC);
  Color get bg2 => oscuro ? AppColors.bg2 : const Color(0xFFF0F4F9);
  Color get bg3 => oscuro ? AppColors.bg3 : const Color(0xFFE8ECF3);
  Color get card => oscuro ? AppColors.card : Colors.white;
  Color get cardHover => oscuro ? AppColors.cardHover : const Color(0xFFF3F7FC);
  Color get borde => oscuro ? AppColors.borde : const Color(0xFFD4E4F0);
  Color get borde2 => oscuro ? AppColors.borde2 : const Color(0xFFC0D9EB);
  Color get teal => oscuro ? AppColors.teal : const Color(0xFF067A76);
  Color get teal2 => oscuro ? AppColors.teal2 : const Color(0xFF087F7B);
  Color get amarillo => oscuro ? AppColors.amarillo : const Color(0xFF806000);
  Color get texto => oscuro ? AppColors.texto : const Color(0xFF0D1B2A);
  Color get texto2 => oscuro ? AppColors.texto2 : const Color(0xFF3D5A73);
  Color get texto3 => oscuro ? AppColors.texto3 : const Color(0xFF526D85);
  Color get placeholder =>
      oscuro ? AppColors.placeholder : const Color(0xFF526D85);
  Color get bordeCampo =>
      oscuro ? AppColors.bordeCampo : const Color(0xFF7B93A8);
  Color get error => oscuro ? AppColors.error : const Color(0xFFB42326);
  Color get errorTexto =>
      oscuro ? AppColors.errorTexto : const Color(0xFFB42326);
  Color get verificado =>
      oscuro ? AppColors.verificado : const Color(0xFF16713D);
  Color get tealBrillante => oscuro ? AppColors.tealBrillante : teal;
  Color get estrella => oscuro ? AppColors.estrella : const Color(0xFF946000);
  Color get violeta => oscuro ? AppColors.violeta : const Color(0xFF6D3AC7);
  Color get admin => oscuro ? AppColors.admin : const Color(0xFF6D3AC7);
  Color get adminHover =>
      oscuro ? AppColors.adminHover : const Color(0xFF5525AB);
  Color get tealDim => AppColors.a(teal, 0.12);
  Color get sobreAcento => oscuro ? AppColors.bg : Colors.white;
  Color get mensajePropio =>
      oscuro ? const Color(0xFF104A4D) : const Color(0xFFDDF3EF);

  Color elegir(Color noche, Color dia) => oscuro ? noche : dia;

  /// Los chips conservan su matiz; en claro requieren un tono más oscuro.
  Color legible(Color color) {
    if (oscuro) return color;
    var hsl = HSLColor.fromColor(color);
    var resultado = color;
    while ((card.computeLuminance() + 0.05) /
                (resultado.computeLuminance() + 0.05) <
            5 &&
        hsl.lightness > 0.1) {
      hsl = hsl.withLightness((hsl.lightness - 0.025).clamp(0.0, 1.0));
      resultado = hsl.toColor();
    }
    return resultado;
  }
}

/// Puntos de quiebre usados en los @media del CSS original.
class Breakpoints {
  Breakpoints._();

  static const double mobile = 640; // hero, labels, cantidad por página
  static const double authStack = 680; // login: una columna
  static const double tablet = 768; // navbar hamburguesa, carrusel top
  static const double navbarInvitado = 1024;
  static const double navbarUsuario = 1400;
}
