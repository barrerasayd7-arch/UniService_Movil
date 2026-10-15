import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_text.dart';
import '../login/auth_widgets.dart';

/// Avisa que la cuenta entra con privilegios de administrador.
/// Devuelve true si elige ir al panel; false si sigue usando la app como usuario.
Future<bool> mostrarAvisoAdmin(BuildContext context) async {
  final irAlPanel = await showDialog<bool>(
    context: context,
    barrierColor: const Color(0xB3000000),
    builder: (_) => const _AvisoAdmin(),
  );
  return irAlPanel ?? false;
}

class _AvisoAdmin extends StatelessWidget {
  const _AvisoAdmin();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Material(
          color: Colors.transparent,
          child: Semantics(
            scopesRoute: true,
            namesRoute: true,
            label: 'Vas a entrar como administrador',
            child: Container(
              constraints: const BoxConstraints(maxWidth: 360),
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 14),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.a(AppColors.admin, 0.35)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: _IconoAdmin(tamano: 56)),
                  const SizedBox(height: 16),
                  Text(
                    'Vas a entrar como administrador',
                    textAlign: TextAlign.center,
                    style: AppText.serif(25, height: 1.15),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Podrás suspender cuentas, moderar servicios y responder '
                    'reportes. Cada acción queda registrada a tu nombre.',
                    textAlign: TextAlign.center,
                    style: AppText.poppins(
                      14.5,
                      color: AppColors.texto2,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 22),
                  AuthPrimaryButton(
                    label: 'Continuar al panel',
                    color: AppColors.admin,
                    colorHover: AppColors.adminHover,
                    onTap: () => Navigator.of(context).pop(true),
                  ),
                  const SizedBox(height: 6),
                  Center(
                    child: AuthTextButton(
                      label: 'Seguir como usuario',
                      color: AppColors.texto2,
                      onTap: () => Navigator.of(context).pop(false),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Escudo del modo administrador (decorativo: el texto de al lado ya lo nombra).
class _IconoAdmin extends StatelessWidget {
  final double tamano;
  const _IconoAdmin({required this.tamano});

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: tamano,
        height: tamano,
        decoration: BoxDecoration(
          color: AppColors.a(AppColors.admin, 0.12),
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.a(AppColors.admin, 0.3)),
        ),
        child: Icon(
          Icons.admin_panel_settings_outlined,
          color: AppColors.admin,
          size: tamano * 0.5,
        ),
      ),
    );
  }
}

/// Etiqueta "Modo administrador": marca cada pantalla con privilegios.
class InsigniaAdmin extends StatelessWidget {
  const InsigniaAdmin({super.key});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.a(AppColors.admin, 0.10),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.a(AppColors.admin, 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.admin_panel_settings_outlined,
              size: 16,
              color: AppColors.admin,
            ),
            const SizedBox(width: 6),
            Text(
              'Modo administrador',
              style: AppText.poppins(
                12.5,
                weight: FontWeight.w600,
                color: AppColors.admin,
                spacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Hora local "14:05" para avisos de bloqueo y vencimiento.
String horaCorta(DateTime t) {
  final l = t.toLocal();
  return '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
}
