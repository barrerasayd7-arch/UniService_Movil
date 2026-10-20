import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_text.dart';
import '../../data/admin_repository.dart';
import 'admin_widgets.dart';

/// (id, etiqueta, ruta, ícono) de cada sección del panel.
const seccionesAdmin = <(String, String, String, IconData)>[
  ('dashboard', 'Resumen', '/admin', Icons.grid_view_rounded),
  ('usuarios', 'Usuarios', '/admin/usuarios', Icons.people_outline_rounded),
  ('servicios', 'Servicios', '/admin/servicios', Icons.checklist_rounded),
  (
    'pendientes',
    'Pendientes',
    '/admin/pendientes',
    Icons.hourglass_empty_rounded,
  ),
  ('reportes', 'Reportes', '/admin/reportes', Icons.flag_outlined),
  ('categorias', 'Categorías', '/admin/categorias', Icons.sell_outlined),
  ('actividad', 'Actividad', '/admin/actividad', Icons.history_rounded),
];

/// Menú lateral del panel. [actual] es el id de la sección que está abierta.
class AdminDrawer extends StatelessWidget {
  final String actual;
  const AdminDrawer({super.key, required this.actual});

  void _ir(BuildContext context, String ruta, bool esActual) {
    final nav = Navigator.of(context);
    nav.pop(); // cierra el drawer
    if (!esActual) nav.pushReplacementNamed(ruta);
  }

  void _salir(BuildContext context) {
    AdminRepository.instance.salir();
    Navigator.of(context).pushNamedAndRemoveUntil('/home', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.bg2,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const InsigniaAdmin(),
                  const SizedBox(height: 10),
                  Text('UniAdmin', style: AppText.serif(26)),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.borde),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                children: [
                  for (final (id, etiqueta, ruta, icono) in seccionesAdmin)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: ListTile(
                        selected: id == actual,
                        selectedTileColor: AppColors.a(AppColors.admin, 0.12),
                        selectedColor: AppColors.admin,
                        iconColor: AppColors.texto2,
                        textColor: AppColors.texto2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        leading: Icon(icono, size: 22),
                        title: Text(
                          etiqueta,
                          style: AppText.poppins(
                            14.5,
                            weight: FontWeight.w600,
                            color: id == actual
                                ? AppColors.admin
                                : AppColors.texto2,
                          ),
                        ),
                        onTap: () => _ir(context, ruta, id == actual),
                      ),
                    ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.borde),
            Padding(
              padding: const EdgeInsets.all(12),
              child: ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                iconColor: AppColors.texto2,
                leading: const Icon(Icons.logout_rounded, size: 22),
                title: Text(
                  'Salir del panel',
                  style: AppText.poppins(
                    14.5,
                    weight: FontWeight.w600,
                    color: AppColors.texto2,
                  ),
                ),
                onTap: () => _salir(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
