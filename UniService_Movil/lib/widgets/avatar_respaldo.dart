import 'package:flutter/material.dart';

import '../core/app_colors.dart';

/// `errorBuilder` para avatares: si la imagen no existe o no carga, muestra
/// un ícono de persona en lugar del error de Flutter.
Widget avatarRespaldo(BuildContext context, Object error, StackTrace? stack) {
  return LayoutBuilder(
    builder: (context, box) {
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
