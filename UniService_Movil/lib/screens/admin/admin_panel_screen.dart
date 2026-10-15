import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_text.dart';
import '../../data/admin_repository.dart';
import '../../data/api_client.dart';
import '../../data/auth_repository.dart';
import '../login/auth_widgets.dart';
import 'admin_widgets.dart';

/// Inicio del panel de administración: resumen de /api/admin/dashboard.
class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  final _repo = AdminRepository.instance;
  Map<String, dynamic>? _resumen;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _error = null);
    try {
      final data = await _repo.dashboard();
      if (!mounted) return;
      setState(() => _resumen = data['resumen'] as Map<String, dynamic>?);
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.requiereElevacion) {
        // Venció la hora de acceso o cambió la contraseña de admin: volver a pedirla.
        _repo.salir();
        Navigator.of(context).pushReplacementNamed('/admin');
        return;
      }
      setState(() => _error = e.mensaje);
    }
  }

  void _salir() {
    _repo.salir();
    Navigator.of(context).pushNamedAndRemoveUntil('/home', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final nombre =
        AuthRepository.instance.usuario.value?.nombre.trim().split(' ').first ??
        '';
    final vence = _repo.vence;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 20,
        title: Text('Panel de administración', style: AppText.serif(22)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton.icon(
              onPressed: _salir,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.texto2,
                minimumSize: const Size(48, 44),
              ),
              icon: const Icon(Icons.logout_rounded, size: 20),
              label: Text(
                'Salir del panel',
                style: AppText.poppins(
                  14,
                  weight: FontWeight.w600,
                  color: AppColors.texto2,
                ),
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.admin,
        backgroundColor: AppColors.card,
        onRefresh: _cargar,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const InsigniaAdmin(),
                    const SizedBox(height: 16),
                    Text(
                      nombre.isEmpty ? 'Hola' : 'Hola, $nombre',
                      style: AppText.serif(30),
                    ),
                    if (vence != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Tu acceso de administrador dura hasta las ${horaCorta(vence)}. '
                        'Después te pediremos la contraseña otra vez.',
                        style: AppText.poppins(
                          14,
                          color: AppColors.texto2,
                          height: 1.5,
                        ),
                      ),
                    ],
                    const SizedBox(height: 28),
                    Semantics(
                      header: true,
                      child: Text(
                        'Resumen',
                        style: AppText.poppins(
                          13,
                          weight: FontWeight.w600,
                          color: AppColors.texto2,
                          spacing: 0.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _cuerpo(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cuerpo() {
    if (_error != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthAviso(mensaje: _error),
          AuthPrimaryButton(
            label: 'Reintentar',
            color: AppColors.admin,
            colorHover: AppColors.adminHover,
            onTap: _cargar,
          ),
        ],
      );
    }
    final r = _resumen;
    int n(String k) => (r?[k] as num?)?.toInt() ?? 0;
    final datos = [
      ('Usuarios activos', 'usuarios_activos', Icons.people_outline_rounded),
      ('Cuentas suspendidas', 'usuarios_suspendidos', Icons.block_rounded),
      (
        'Nuevos esta semana',
        'usuarios_nuevos_7d',
        Icons.person_add_alt_rounded,
      ),
      (
        'Servicios publicados',
        'servicios_publicados',
        Icons.storefront_outlined,
      ),
      (
        'Servicios por revisar',
        'servicios_pendientes',
        Icons.pending_actions_rounded,
      ),
      ('Reportes abiertos', 'reportes_abiertos', Icons.flag_outlined),
    ];
    return LayoutBuilder(
      builder: (context, c) {
        final columnas = c.maxWidth >= 560 ? 3 : 2;
        const espacio = 12.0;
        final ancho = (c.maxWidth - espacio * (columnas - 1)) / columnas;
        return Wrap(
          spacing: espacio,
          runSpacing: espacio,
          children: [
            for (final (label, clave, icono) in datos)
              SizedBox(
                width: ancho,
                child: _Dato(
                  label: label,
                  valor: r == null ? null : n(clave),
                  icono: icono,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Dato extends StatelessWidget {
  final String label;
  final int? valor; // null = cargando
  final IconData icono;
  const _Dato({required this.label, required this.valor, required this.icono});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: valor == null ? '$label, cargando' : '$label: $valor',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.borde),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icono, size: 20, color: AppColors.texto2),
            const SizedBox(height: 12),
            SizedBox(
              height: 38,
              child: valor == null
                  ? Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        width: 48,
                        height: 22,
                        decoration: BoxDecoration(
                          color: AppColors.bg3,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    )
                  : Text('$valor', style: AppText.serif(32, height: 1.1)),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: AppText.poppins(
                13.5,
                color: AppColors.texto2,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
