import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_text.dart';

/// `.label-seccion`: chip pequeño en mayúsculas sobre los títulos.
class SectionLabel extends StatelessWidget {
  final String text;
  final IconData? icon;
  const SectionLabel({super.key, required this.text, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.a(AppColors.teal, 0.10),
            AppColors.a(AppColors.teal, 0.05),
          ],
        ),
        border: Border.all(color: AppColors.a(AppColors.teal, 0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: AppColors.teal),
            const SizedBox(width: 6),
          ],
          Text(
            text.toUpperCase(),
            style: AppText.poppins(
              11.52,
              weight: FontWeight.w700,
              color: AppColors.teal,
              spacing: 2.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// `.acento`: palabra en cursiva teal con subrayado degradado.
/// Se usa dentro de un Text.rich mediante WidgetSpan.
class AcentoText extends StatelessWidget {
  final String text;
  final double fontSize;
  const AcentoText(this.text, {super.key, required this.fontSize});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Text(
          text,
          style: AppText.serif(
            fontSize,
            color: AppColors.teal2,
            style: FontStyle.italic,
            height: 1.15,
            shadows: [
              Shadow(
                color: AppColors.a(AppColors.teal, 0.3),
                blurRadius: 20,
              ),
              Shadow(
                color: AppColors.a(AppColors.teal, 0.1),
                blurRadius: 60,
              ),
            ],
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: -2,
          child: Container(
            height: 2,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              gradient: const LinearGradient(
                colors: [Colors.transparent, AppColors.teal2, Colors.transparent],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
