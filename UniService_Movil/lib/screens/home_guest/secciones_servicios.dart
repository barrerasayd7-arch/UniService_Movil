import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_text.dart';
import '../../models/servicio.dart';
import '../../widgets/section_backgrounds.dart';
import '../../widgets/section_label.dart';
import '../../widgets/tarjeta_servicio.dart';

Widget _encabezado({
  required String label,
  required IconData icono,
  required String antes,
  required String acento,
  String? descripcion,
  required bool movil,
}) {
  final t = movil ? 28.0 : 38.4;
  return Column(
    children: [
      SectionLabel(text: label, icon: icono),
      const SizedBox(height: 14),
      Text.rich(
        textAlign: TextAlign.center,
        TextSpan(
          style: AppText.serif(t, height: 1.2),
          children: [
            TextSpan(text: '$antes '),
            TextSpan(
              text: acento,
              style: AppText.serif(
                t,
                color: AppColors.teal2,
                style: FontStyle.italic,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
      if (descripcion != null) ...[
        const SizedBox(height: 10),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Text(
            descripcion,
            textAlign: TextAlign.center,
            style: AppText.poppins(15, color: AppColors.texto2, height: 1.6),
          ),
        ),
      ],
      const SizedBox(height: 32),
    ],
  );
}

/// "Servicios recientes": los 4 más nuevos (SeccionRecientes.jsx).
class SeccionRecientes extends StatelessWidget {
  final List<Servicio> servicios;
  final void Function(Servicio) onTapServicio;
  const SeccionRecientes({super.key, required this.servicios, required this.onTapServicio});

  @override
  Widget build(BuildContext context) {
    final movil = MediaQuery.of(context).size.width <= Breakpoints.mobile;
    final recientes = ([...servicios]
          ..sort((a, b) => b.fechaPublicacion.compareTo(a.fechaPublicacion)))
        .take(4)
        .toList();

    return SeccionFondo(
      oscura: true,
      fondo: FondoSeccion.circuito,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                _encabezado(
                  label: 'Novedades',
                  icono: Icons.bolt,
                  antes: 'Servicios',
                  acento: 'recientes',
                  descripcion: 'Lo último que publicó la comunidad universitaria.',
                  movil: movil,
                ),
                RejillaServicios(servicios: recientes, onTapServicio: onTapServicio),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "Mejor calificados": top 3 por estrellas (SeccionDestacados.jsx).
/// En escritorio van en fila; en móvil se vuelve un carrusel automático.
class SeccionDestacados extends StatefulWidget {
  final List<Servicio> servicios;
  final void Function(Servicio) onTapServicio;
  const SeccionDestacados({super.key, required this.servicios, required this.onTapServicio});

  @override
  State<SeccionDestacados> createState() => _SeccionDestacadosState();
}

class _SeccionDestacadosState extends State<SeccionDestacados> {
  final _page = PageController(viewportFraction: 0.92);
  Timer? _timer;
  int _actual = 0;

  List<Servicio> get _top => ([...widget.servicios]
        ..sort((a, b) => b.estrellas.compareTo(a.estrellas)))
      .take(3)
      .toList();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!_page.hasClients || _top.isEmpty) return;
      final sig = (_actual + 1) % _top.length;
      _page.animateToPage(
        sig,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _page.dispose();
    super.dispose();
  }

  Widget _conBadge(int i, Servicio s) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        TarjetaServicio(servicio: s, onTap: () => widget.onTapServicio(s)),
        Positioned(
          top: -12,
          left: 15,
          child: Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.amarillo,
              boxShadow: [
                BoxShadow(
                  color: AppColors.a(AppColors.amarillo, 0.4),
                  blurRadius: 14,
                ),
              ],
            ),
            child: Text(
              '${i + 1}',
              style: AppText.poppins(14, weight: FontWeight.w800, color: AppColors.bg),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final ancho = MediaQuery.of(context).size.width;
    final carrusel = ancho <= Breakpoints.tablet;
    final top = _top;

    return SeccionFondo(
      fondo: FondoSeccion.estrellas,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _encabezado(
                  label: 'Top destacados',
                  icono: Icons.star_rounded,
                  antes: 'Mejor',
                  acento: 'calificados',
                  descripcion: 'Los servicios con mejores reseñas de la plataforma.',
                  movil: ancho <= Breakpoints.mobile,
                ),
              ),
              if (carrusel) ...[
                SizedBox(
                  height: 530,
                  child: PageView.builder(
                    controller: _page,
                    itemCount: top.length,
                    onPageChanged: (i) => setState(() => _actual = i),
                    itemBuilder: (context, i) => Padding(
                      padding: const EdgeInsets.fromLTRB(8, 14, 8, 8),
                      child: _conBadge(i, top[i]),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < top.length; i++)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: i == _actual ? 22 : 8,
                        height: 8,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: i == _actual ? AppColors.teal : AppColors.borde2,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                  ],
                ),
              ] else
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < top.length; i++) ...[
                        if (i > 0) const SizedBox(width: 20),
                        Expanded(child: _conBadge(i, top[i])),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
