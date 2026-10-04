import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_text.dart';

/// Detecta hover (web / desktop) y reconstruye el hijo.
class HoverBuilder extends StatefulWidget {
  final Widget Function(BuildContext context, bool hovering) builder;
  final MouseCursor cursor;
  const HoverBuilder({
    super.key,
    required this.builder,
    this.cursor = SystemMouseCursors.click,
  });

  @override
  State<HoverBuilder> createState() => _HoverBuilderState();
}

class _HoverBuilderState extends State<HoverBuilder> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.cursor,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: widget.builder(context, _hover),
    );
  }
}

/// `.btn.btn-verde`
class BtnVerde extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const BtnVerde({super.key, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return HoverBuilder(
      builder: (context, hover) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          transform: Matrix4.translationValues(0, hover ? -2 : 0, 0),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: hover ? AppColors.teal2 : AppColors.teal,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.teal),
            boxShadow: hover
                ? [
                    BoxShadow(
                      color: AppColors.a(AppColors.teal, 0.35),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : const [],
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: AppText.poppins(
              14.08,
              weight: FontWeight.w600,
              color: AppColors.bg,
              spacing: 0.3,
            ),
          ),
        ),
      ),
    );
  }
}

/// `.btn.btn-borde`
class BtnBorde extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const BtnBorde({super.key, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return HoverBuilder(
      builder: (context, hover) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          transform: Matrix4.translationValues(0, hover ? -2 : 0, 0),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: hover ? AppColors.teal : const Color(0x4D000000),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: hover ? AppColors.teal : AppColors.borde2,
              width: 2,
            ),
            boxShadow: hover
                ? [
                    BoxShadow(
                      color: AppColors.a(AppColors.teal, 0.35),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : const [],
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: AppText.poppins(
              14.08,
              weight: FontWeight.w600,
              color: hover ? AppColors.bg : AppColors.texto,
              spacing: 0.3,
            ),
          ),
        ),
      ),
    );
  }
}
