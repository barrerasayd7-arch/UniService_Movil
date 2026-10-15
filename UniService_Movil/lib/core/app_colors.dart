import 'package:flutter/material.dart';

/// Equivalente a las variables `:root` de styleHome.css / StyleLogin.css
/// (tema oscuro, que es el tema por defecto de la web).
class AppColors {
  AppColors._();

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

  static Color get tealDim => a(teal, 0.12);
}

/// Puntos de quiebre usados en los @media del CSS original.
class Breakpoints {
  Breakpoints._();

  static const double mobile = 640; // hero, labels, cantidad por página
  static const double authStack = 680; // login: una columna
  static const double tablet = 768; // navbar hamburguesa, carrusel top
}
