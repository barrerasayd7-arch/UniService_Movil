import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_text.dart';
import '../../core/categorias.dart' show formatearFecha, iconosPorCategoria, iconoPorDefecto;
import '../../data/detalle_mock.dart';
import '../../models/servicio.dart';
import '../../models/servicio_detalle.dart';
import '../../widgets/app_buttons.dart' show BtnVerde, HoverBuilder;
import '../../widgets/star_rating.dart';
import 'detail_widgets.dart';
import 'form_calificacion.dart';
import 'form_solicitud.dart';
import 'galeria_servicio.dart';
import 'navbar_servicio.dart';
import 'proveedor_card.dart';
import 'skeleton_servicio.dart';

/// Vista de detalle de un servicio (DetalleServicio.jsx).
/// Si [servicio] es null muestra el estado "Servicio no encontrado".
class DetailScreen extends StatefulWidget {
  final Servicio? servicio;
  const DetailScreen({super.key, required this.servicio});

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  bool _cargando = true;
  bool _menuAbierto = false;
  ServicioDetalle? _detalle;

  @override
  void initState() {
    super.initState();
    
    // para que se vea el esqueleto, igual que en la web.
    final s = widget.servicio;
    if (s != null) _detalle = detalleMock(s);
    Future<void>.delayed(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _cargando = false);
    });
  }

  // ── Navegación ──
  void _irA(String enlace) {
    setState(() => _menuAbierto = false);
    final nav = Navigator.of(context);
    switch (enlace) {
      case 'inicio':
        nav.pushNamedAndRemoveUntil('/home', (_) => false);
      case 'perfil':
        nav.pushNamed('/perfil');
      default: // buscar | publicar
        nav.pushNamedAndRemoveUntil('/home', (_) => false, arguments: enlace);
    }
  }

  void _cerrarSesion() {
    
    Navigator.of(context).pushNamedAndRemoveUntil('/home-guest', (_) => false);
  }

  void _aviso(String texto) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(texto),
          backgroundColor: AppColors.card,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  void _agregarResena(int estrellas, String comentario) {
    final d = _detalle;
    if (d == null) return;
    const meses = [
      'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
      'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
    ];
    final h = DateTime.now();
    setState(() {
      _detalle = d.conResenas([
        Resena(
          autor: 'Tú',
          fecha: '${h.day} de ${meses[h.month - 1]} de ${h.year}',
          estrellas: estrellas,
          comentario: comentario,
        ),
        ...d.resenas,
      ]);
    });
  }

  @override
  Widget build(BuildContext context) {
    final ancho = MediaQuery.of(context).size.width;
    final movilNav = ancho <= 900;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          Column(
            children: [
              NavbarServicio(
                movil: movilNav,
                menuAbierto: _menuAbierto,
                onToggleMenu: () => setState(() => _menuAbierto = !_menuAbierto),
                onEnlace: _irA,
                onCerrarSesion: _cerrarSesion,
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _cuerpo(ancho),
                      _footer(),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (movilNav && _menuAbierto)
            Positioned(
              top: 62,
              right: 16,
              child: MenuMovilServicio(onEnlace: _irA, onCerrarSesion: _cerrarSesion),
            ),
        ],
      ),
    );
  }

  Widget _cuerpo(double ancho) {
    // Cargando -> esqueleto
    if (_cargando) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 40),
            child: SkeletonServicio(),
          ),
        ),
      );
    }

    // Sin servicio -> "no encontrado"
    final d = _detalle;
    if (d == null) return _noEncontrado();

    final izquierda = _columnaIzquierda(d, ancho);
    final derecha = _columnaDerecha(d);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 60),
          child: ancho > 1024
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 2, child: izquierda),
                    const SizedBox(width: 40),
                    Expanded(flex: 1, child: derecha),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [izquierda, const SizedBox(height: 0), derecha],
                ),
        ),
      ),
    );
  }

  // ═════════════ COLUMNA IZQUIERDA ═════════════
  Widget _columnaIzquierda(ServicioDetalle d, double ancho) {
    final s = d.servicio;
    final movil = ancho <= 768;
    final icono = iconosPorCategoria[s.categoria] ?? iconoPorDefecto;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GaleriaServicio(imagenes: d.imagenes, icono: icono),

        if (d.esArriendo && d.tieneUbicacion)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: BtnDetalle(
              label: 'Ver ubicación en el mapa',
              icono: Icons.location_on,
              estilo: EstiloBtn.mapa,
              ancho: false,
              margenInferior: false,
              onTap: () => _mostrarMapa(d),
            ),
          ),

        // ── Info principal ──
        Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _tituloYReportar(s, movil),
              const SizedBox(height: 20),
              Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      StarRating(rating: d.promedio, size: 22),
                      const SizedBox(height: 4),
                      Text.rich(
                        TextSpan(
                          style: AppText.poppins(14.4, color: AppColors.texto2, height: 1.6),
                          children: [
                            TextSpan(
                              text: d.promedio.toStringAsFixed(1),
                              style: AppText.poppins(14.4,
                                  weight: FontWeight.w700, height: 1.6),
                            ),
                            const TextSpan(text: ' de 5.0'),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 20),
                  Text(
                    '${d.resenas.length} reseñas',
                    style: AppText.poppins(14.4, color: AppColors.texto2, height: 1.6),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.borde),
                ),
                child: Text(
                  s.descripcion.isEmpty ? 'Sin descripción disponible.' : s.descripcion,
                  style: AppText.poppins(15.2, height: 1.8),
                ),
              ),
            ],
          ),
        ),

        // ── Detalles del servicio ──
        SeccionInfo(
          icono: Icons.checklist,
          titulo: 'Detalles del Servicio',
          margen: const EdgeInsets.only(top: 0, bottom: 24),
          child: Column(
            children: [
              InfoRow(label: 'Modalidad', value: d.modalidad),
              InfoRow(label: 'Disponibilidad', value: d.disponibilidad),
              InfoRow(label: 'Precio por hora', value: '\$${s.precioHora} COP'),
              InfoRow(label: 'Universidad', value: d.universidadTexto),
              InfoRow(
                label: 'Publicado',
                value: formatearFecha(s.fechaPublicacion),
                ultima: !(d.contacto != null) && !(d.esArriendo && d.direccion != null),
              ),
              if (d.contacto != null)
                InfoRow(
                  label: 'Contacto',
                  value: d.contacto!,
                  ultima: !(d.esArriendo && d.direccion != null),
                ),
              if (d.esArriendo && d.direccion != null)
                InfoRow(
                  label: 'Dirección',
                  value: d.direccion!,
                  iconoValor: Icons.location_on_outlined,
                  ultima: true,
                ),
            ],
          ),
        ),

        // ── Reseñas ──
        SeccionInfo(
          icono: Icons.star_rounded,
          titulo: 'Reseñas de Clientes',
          child: d.resenas.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Text(
                      'Aún no hay reseñas para este servicio.',
                      style: AppText.poppins(14, color: AppColors.texto2),
                    ),
                  ),
                )
              : Column(
                  children: [
                    for (var i = 0; i < d.resenas.length; i++)
                      Padding(
                        padding: EdgeInsets.only(bottom: i < d.resenas.length - 1 ? 16 : 0),
                        child: _ResenaCard(resena: d.resenas[i]),
                      ),
                  ],
                ),
        ),

        // ── Dejar reseña ──
        FormCalificacion(onNuevaResena: _agregarResena),
      ],
    );
  }

  Widget _tituloYReportar(Servicio s, bool movil) {
    final titulo = Text(
      s.titulo.isEmpty ? 'Sin título' : s.titulo,
      style: AppText.serif(movil ? 24 : 30.4, height: 1.2),
    );
    final reportar = _BtnReportar(onTap: () => _aviso('Reportar: próxima vista por implementar'));

    if (movil) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [titulo, const SizedBox(height: 12), reportar],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: titulo),
        const SizedBox(width: 12),
        reportar,
      ],
    );
  }

  // ═════════════ COLUMNA DERECHA ═════════════
  Widget _columnaDerecha(ServicioDetalle d) {
    final s = d.servicio;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ProveedorCard(
          detalle: d,
          onTap: () => Navigator.of(context).pushNamed('/perfil-externo'),
        ),
        if (d.contacto != null)
          ContactoBotones(
            contacto: d.contacto!,
            onContactar: () => _aviso(
              d.contacto!.contains('@')
                  ? 'Aquí se abriría Gmail para escribir a ${d.contacto} (url_launcher)'
                  : 'Aquí se abriría WhatsApp con ${d.contacto} (url_launcher)',
            ),
            onMensaje: () => _aviso('Chat: próxima vista por implementar'),
          ),
        SeccionInfo(
          icono: Icons.person,
          titulo: 'Información del Proveedor',
          child: Column(
            children: [
              const InfoRow(label: 'Publicaciones', value: '1 servicio'),
              InfoRow(label: 'Reseñas totales', value: '${d.resenas.length}'),
              InfoRow(
                label: 'Calificación',
                value: '${d.promedio.toStringAsFixed(1)} ★',
                ultima: true,
              ),
            ],
          ),
        ),
        FormSolicitud(
          categoria: s.categoria,
          proveedorNombre: s.proveedor,
        ),
      ],
    );
  }

  // ═════════════ Estado "no encontrado" ═════════════
  Widget _noEncontrado() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 80),
      child: Center(
        child: Column(
          children: [
            const Text('😕', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 8),
            Text('Servicio no encontrado', style: AppText.serif(32)),
            const SizedBox(height: 12),
            Text(
              'El servicio que buscas no existe o fue eliminado.',
              textAlign: TextAlign.center,
              style: AppText.poppins(14.4, color: AppColors.texto2),
            ),
            const SizedBox(height: 24),
            BtnVerde(
              label: '← Volver al inicio',
              onTap: () => _irA('inicio'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _footer() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(bottom: 20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const Divider(color: AppColors.borde, height: 1),
                const SizedBox(height: 16),
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  children: [
                    Text(
                      '© 2026 UniService — Hecho por y para estudiantes',
                      textAlign: TextAlign.center,
                      style: AppText.poppins(13, color: AppColors.texto3),
                    ),
                    const Icon(Icons.school, size: 15, color: AppColors.texto3),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ═════════════ Modal del mapa ═════════════
  void _mostrarMapa(ServicioDetalle d) {
    showDialog<void>(
      context: context,
      barrierColor: const Color(0xB3000000),
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.card,
        insetPadding: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.borde),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.location_on, color: AppColors.teal, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        d.direccion ?? 'Ubicación del servicio',
                        style: AppText.poppins(15, weight: FontWeight.w700),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      icon: const Icon(Icons.close, color: AppColors.texto2),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Marcador de posición del mapa (en la web es Google Maps)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    height: 280,
                    color: AppColors.bg2,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Positioned.fill(child: CustomPaint(painter: _MapaPainter())),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.location_on, size: 48, color: Color(0xFFEA4335)),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.card,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Aquí iría el mapa (google_maps_flutter)',
                                style: AppText.poppins(12, color: AppColors.texto2),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Tarjeta de reseña (.resena) ──
class _ResenaCard extends StatelessWidget {
  final Resena resena;
  const _ResenaCard({required this.resena});

  @override
  Widget build(BuildContext context) {
    return HoverBuilder(
      cursor: SystemMouseCursors.basic,
      builder: (context, hover) => AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.bg2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: hover ? AppColors.borde2 : AppColors.borde),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.teal, AppColors.teal2],
                    ),
                  ),
                  child: Text(
                    iniciales(resena.autor),
                    style: AppText.poppins(13.6, weight: FontWeight.w700, color: AppColors.bg),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        resena.autor.isEmpty ? 'Anónimo' : resena.autor,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.poppins(14.7, weight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        resena.fecha,
                        style: AppText.poppins(12.5, color: AppColors.texto3),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                StarRating(rating: resena.estrellas.toDouble(), size: 14),
              ],
            ),
            if (resena.comentario.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                resena.comentario,
                style: AppText.poppins(14.08, color: AppColors.texto2, height: 1.6),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Botón "Reportar" junto al título ──
class _BtnReportar extends StatelessWidget {
  final VoidCallback onTap;
  const _BtnReportar({required this.onTap});

  @override
  Widget build(BuildContext context) {
    const rojo = Color(0xFFEF4444);
    return HoverBuilder(
      builder: (context, hover) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.a(rojo, hover ? 0.18 : 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.a(rojo, hover ? 0.6 : 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.flag, size: 14, color: Color(0xFFFF6B6B)),
              const SizedBox(width: 6),
              Text(
                'Reportar',
                style: AppText.poppins(
                  13.1,
                  weight: FontWeight.w600,
                  color: const Color(0xFFFF6B6B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Calles dibujadas de forma simple para el marcador del mapa
class _MapaPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final calle = Paint()
      ..color = AppColors.a(AppColors.teal, 0.10)
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;
    final fina = Paint()
      ..color = AppColors.a(AppColors.teal, 0.06)
      ..strokeWidth = 4;
    for (double x = 40; x < size.width; x += 90) {
      canvas.drawLine(Offset(x, 0), Offset(x + 30, size.height), x % 180 < 90 ? calle : fina);
    }
    for (double y = 30; y < size.height; y += 70) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y - 20), y % 140 < 70 ? calle : fina);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
