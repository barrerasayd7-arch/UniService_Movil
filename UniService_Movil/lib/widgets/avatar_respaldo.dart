// Archivo: avatar_respaldo.dart
// Responsabilidad: `errorBuilder` compartido para avatares, con ícono de persona
//   cuando la imagen falla.
// Se usa desde: CircleAvatar/Image.network de perfil, chat y listas.
import 'package:flutter/material.dart';

import '../core/app_colors.dart';

/// `errorBuilder` para avatares: si la imagen no existe o no carga, muestra
/// un ícono de persona en lugar del error de Flutter.
Widget avatarRespaldo(BuildContext context, Object error, StackTrace? stack) {
  return LayoutBuilder(
    builder: (context, box) {
      // 44 px es el tamaño típico de avatar en listas; el ícono escala al 60 %.
      final lado = box.maxWidth.isFinite ? box.maxWidth : 44.0;
      return ColoredBox(
        color: AppColors.bg3,
        child: Center(
          child: Icon(
            Icons.person_rounded,
            size: lado * 0.6,
            color: AppColors.texto2,
          ),
        ),
      );
    },
  );
}
