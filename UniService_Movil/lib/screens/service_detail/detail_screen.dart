// Archivo: detail_screen.dart
// Responsabilidad: pantalla de detalle de un servicio (galería, info, proveedor,
// reseñas, solicitud y contacto) según sesión y propiedad del servicio.
// Se usa desde: ruta '/servicio' (tarjetas de inicio, mis servicios, solicitudes).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_colors.dart';
import '../../core/app_text.dart';
import '../../core/categorias.dart';
import '../../data/api_client.dart';
import '../../data/auth_repository.dart';
import '../../data/servicios_repository.dart';
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

/// Detalle de un servicio (`GET /api/servicios/{id}`).
///
/// - Invitado: ve todo menos el contacto y la ubicación exacta; se le invita a iniciar sesión.
/// - Con sesión: contacto (WhatsApp o correo), mapa, solicitud y reseña.
/// - Dueño: ve también su servicio en revisión, pausado o rechazado (con el motivo).
class DetailScreen extends StatefulWidget {
  final int? idServicio;

  /// Datos de la tarjeta tocada: no se usan para pintar, sólo dan el id sin esperar.
  final Servicio? servicio;
  final ServiciosRepository? repositorio;

  const DetailScreen({
    super.key,
    this.idServicio,
    this.servicio,
    this.repositorio,
  });

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  late final ServiciosRepository _repo =
      widget.repositorio ?? ServiciosRepository.instance;
  late final int? _id = widget.idServicio ?? widget.servicio?.id;

  bool _cargando = true;
  bool _menuAbierto = false; // menú desplegable del navbar en móvil
  bool _noEncontrado = false; // 404: se muestra estado vacío, no error
  String? _error;
  ServicioDetalle? _detalle;

  bool get _haySesion => AuthRepository.instance.haySesion;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  /// Carga el detalle; diferencia un 404 (no encontrado) de un fallo de red.
  Future<void> _cargar() async {
    final id = _id;
    if (id == null) {
      setState(() {
        _cargando = false;
        _noEncontrado = true;
      });
      return;
    }
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final d = await _repo.detalle(id);
      if (!mounted) return;
      setState(() {
        _detalle = d;
        _noEncontrado = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        if (e.status == 404) {
          _noEncontrado = true;
        } else {
          _error = e.mensaje;
        }
      });
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  // --- Navegación ---

  /// Enlaces del navbar; sin sesión, los enlaces privados mandan al login.
  void _irA(String enlace) {
    setState(() => _menuAbierto = false);
    final nav = Navigator.of(context);
    if (!_haySesion) {
      if (enlace == 'inicio' || enlace == 'buscar') {
        nav.pushNamedAndRemoveUntil('/home-guest', (_) => false);
      } else {
        nav.pushNamed('/login');
      }
      return;
    }
    switch (enlace) {
      case 'inicio':
      case 'buscar':
        nav.pushNamedAndRemoveUntil('/home', (_) => false);
      case 'perfil':
        nav.pushNamed('/perfil');
      case 'publicar':
        nav.pushNamed('/publicar');
    }
  }

  Future<void> _cerrarSesion() async {
    await AuthRepository.instance.cerrarSesion();
    if (!mounted) return;
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

  // --- Contacto y mapa ---

  /// Abre una app externa; si no hay ninguna disponible avisa con [siFalla].
  Future<void> _abrir(Uri uri, String siFalla) async {
    var abierto = false;
    try {
      abierto = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
    if (!abierto && mounted) _aviso(siFalla);
  }

  /// Abre correo si el contacto tiene '@'; si no, intenta WhatsApp y, si el
  /// número no es válido, copia el contacto al portapapeles.
  Future<void> _contactar(ServicioDetalle d) async {
    final contacto = d.contacto!.trim();
    final titulo = d.servicio.titulo;
    if (contacto.contains('@')) {
      return _abrir(
        Uri(
          scheme: 'mailto',
          path: contacto,
          query: 'subject=${Uri.encodeComponent('UniService: $titulo')}',
        ),
        'No encontramos una app de correo. Escribe a $contacto',
      );
    }
    final numero = numeroWhatsApp(contacto);
    if (numero == null) {
      await Clipboard.setData(ClipboardData(text: contacto));
      if (mounted) _aviso('Contacto copiado: $contacto');
      return;
    }
    final texto = Uri.encodeComponent(
      'Hola, vi tu servicio "$titulo" en UniService.',
    );
    return _abrir(
      Uri.parse('https://wa.me/$numero?text=$texto'),
      'No se pudo abrir WhatsApp. El número es $contacto',
    );
  }

  /// Prefiere coordenadas exactas y usa la dirección como respaldo.
  void _abrirMapa(ServicioDetalle d) {
    final consulta = d.lat != null && d.lng != null
        ? '${d.lat},${d.lng}'
        : d.direccion!;
    _abrir(
      Uri.https('www.google.com', '/maps/search/', {
        'api': '1',
        'query': consulta,
      }),
      'No se pudo abrir el mapa.',
    );
  }

  void _iniciarSesion() => Navigator.of(context).pushNamed('/login');

  @override
  Widget build(BuildContext context) {
    final ancho = MediaQuery.of(context).size.width;
    final movilNav = ancho <= 900;

    return Scaffold(
      backgroundColor: AppColors.bg,
      // SafeArea: la barra superior no queda bajo la hora/batería del celular.
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Column(
              children: [
                NavbarServicio(
                  movil: movilNav,
                  menuAbierto: _menuAbierto,
                  invitado: !_haySesion,
                  onToggleMenu: () =>
                      setState(() => _menuAbierto = !_menuAbierto),
                  onEnlace: _irA,
                  onCerrarSesion: _cerrarSesion,
                ),
                Expanded(
                  child: RefreshIndicator(
                    color: AppColors.teal,
                    backgroundColor: AppColors.card,
                    onRefresh: _cargar,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Column(children: [_cuerpo(ancho), _footer()]),
                    ),
                  ),
                ),
              ],
            ),
            if (movilNav && _menuAbierto)
              Positioned(
                top: 62,
                right: 16,
                child: MenuMovilServicio(
                  invitado: !_haySesion,
                  onEnlace: _irA,
                  onCerrarSesion: _cerrarSesion,
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Decide entre esqueleto, estados vacíos o el contenido; en pantallas anchas
  /// usa dos columnas y en móvil apila la información.
  Widget _cuerpo(double ancho) {
    final d = _detalle;
    if (_cargando && d == null) {
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
    if (_noEncontrado) return _estadoVacio();
    if (d == null) return _estadoError();

    final izquierda = _columnaIzquierda(d, ancho);
    final derecha = _columnaDerecha(d);
    final movil = ancho <= 540;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            movil ? 16 : 24,
            movil ? 20 : 32,
            movil ? 16 : 24,
            60,
          ),
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
                  children: [izquierda, derecha],
                ),
        ),
      ),
    );
  }

  // === Columna izquierda: galería, datos, reseñas y formulario de reseña ===
  Widget _columnaIzquierda(ServicioDetalle d, double ancho) {
    final s = d.servicio;
    final movil = ancho <= 768;
    final icono = iconosPorCategoria[s.categoria] ?? iconoPorDefecto;
    final hayUbicacion =
        (d.lat != null && d.lng != null) || (d.direccion?.isNotEmpty ?? false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (d.esPropio && d.estado != 'aprobado')
          _BannerEstado(estado: d.estado, motivo: d.motivoRechazo),

        GaleriaServicio(imagenes: d.imagenes, icono: icono),

        if (hayUbicacion)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: BtnDetalle(
              label: 'Ver ubicación en el mapa',
              icono: Icons.location_on,
              estilo: EstiloBtn.mapa,
              ancho: false,
              margenInferior: false,
              onTap: () => _abrirMapa(d),
            ),
          )
        else if (d.tieneUbicacion && !_haySesion)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              'Inicia sesión para ver la ubicación.',
              style: AppText.poppins(13.5, color: AppColors.texto2),
            ),
          ),
        const SizedBox(height: 16),

        // --- Info principal ---
        Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _tituloYReportar(d, movil),
              const SizedBox(height: 16),
              Row(
                children: [
                  StarRating(rating: d.promedio, size: 22),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text.rich(
                      TextSpan(
                        style: AppText.poppins(
                          14.4,
                          color: AppColors.texto2,
                          height: 1.6,
                        ),
                        children: d.numResenas == 0
                            ? const [TextSpan(text: 'Sin reseñas todavía')]
                            : [
                                TextSpan(
                                  text: formatearDecimal(d.promedio),
                                  style: AppText.poppins(
                                    14.4,
                                    weight: FontWeight.w700,
                                    height: 1.6,
                                  ),
                                ),
                                TextSpan(
                                  text:
                                      ' · ${d.numResenas} ${d.numResenas == 1 ? 'reseña' : 'reseñas'}',
                                ),
                              ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.borde),
                ),
                child: Text(
                  s.descripcion.isEmpty
                      ? 'Sin descripción disponible.'
                      : s.descripcion,
                  style: AppText.poppins(15.2, height: 1.7),
                ),
              ),
            ],
          ),
        ),

        // --- Detalles del servicio ---
        SeccionInfo(
          icono: Icons.checklist,
          titulo: 'Detalles del servicio',
          margen: const EdgeInsets.only(top: 0, bottom: 24),
          child: Column(
            children: [
              InfoRow(
                label: 'Precio ${unidadesPrecio[s.unidadPrecio] ?? ''}'.trim(),
                value: '${formatearPrecio(s.precio)} COP',
              ),
              InfoRow(
                label: 'Modalidad',
                value: modalidades[s.modalidad] ?? s.modalidad,
              ),
              InfoRow(
                label: 'Disponibilidad',
                value: disponibilidades[s.disponibilidad] ?? s.disponibilidad,
              ),
              InfoRow(label: 'Universidad', value: d.universidadTexto),
              InfoRow(
                label: 'Publicado',
                value: formatearFecha(s.fechaPublicacion),
                ultima: d.contacto == null && d.direccion == null,
              ),
              if (d.contacto != null)
                InfoRow(
                  label: 'Contacto',
                  value: d.contacto!,
                  ultima: d.direccion == null,
                ),
              if (d.direccion != null)
                InfoRow(
                  label: 'Dirección',
                  value: d.direccion!,
                  iconoValor: Icons.location_on_outlined,
                  ultima: true,
                ),
            ],
          ),
        ),

        // --- Reseñas ---
        SeccionInfo(
          icono: Icons.star_rounded,
          titulo: 'Reseñas de clientes',
          child: d.resenas.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Text(
                      'Aún no hay reseñas para este servicio.',
                      textAlign: TextAlign.center,
                      style: AppText.poppins(14, color: AppColors.texto2),
                    ),
                  ),
                )
              : Column(
                  children: [
                    for (var i = 0; i < d.resenas.length; i++)
                      Padding(
                        padding: EdgeInsets.only(
                          bottom: i < d.resenas.length - 1 ? 16 : 0,
                        ),
                        child: _ResenaCard(resena: d.resenas[i]),
                      ),
                  ],
                ),
        ),

        // --- Dejar reseña (sólo quien tuvo una solicitud completada) ---
        if (_haySesion && !d.esPropio)
          FormCalificacion(idServicio: s.id, onGuardada: _cargar),
      ],
    );
  }

  /// Título con el botón de reportar; invitados y dueños no lo ven.
  Widget _tituloYReportar(ServicioDetalle d, bool movil) {
    final s = d.servicio;
    final titulo = Text(
      s.titulo.isEmpty ? 'Sin título' : s.titulo,
      style: AppText.serif(movil ? 26 : 30.4, height: 1.2),
    );
    if (!_haySesion || d.esPropio) return titulo;

    final reportar = _BtnReportar(
      onTap: () => _aviso('Reportar: próxima vista por implementar'),
    );
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

  // === Columna derecha: proveedor, acciones y formulario de solicitud ===
  Widget _columnaDerecha(ServicioDetalle d) {
    final s = d.servicio;
    final p = d.proveedor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ProveedorCard(
          detalle: d,
          onTap: _haySesion
              ? () => Navigator.of(context).pushNamed('/perfil-externo', arguments: p.id)
              : _iniciarSesion,
        ),
        if (d.esPropio)
          _AccionesDueno(
            onEditar: () =>
                Navigator.of(context).pushNamed('/publicar', arguments: s.id),
            onMisServicios: () =>
                Navigator.of(context).pushNamed('/mis-servicios'),
          )
        else if (!_haySesion)
          _InvitaSesion(onIniciarSesion: _iniciarSesion)
        else if (d.contacto != null)
          ContactoBotones(
            contacto: d.contacto!,
            onContactar: () => _contactar(d),
            onMensaje: () => _aviso('Chat: próxima vista por implementar'),
          ),
        SeccionInfo(
          icono: Icons.person,
          titulo: 'Información del proveedor',
          child: Column(
            children: [
              InfoRow(
                label: 'Publicaciones',
                value:
                    '${p.serviciosPublicados} ${p.serviciosPublicados == 1 ? 'servicio' : 'servicios'}',
              ),
              InfoRow(label: 'Reseñas totales', value: '${p.numResenas}'),
              InfoRow(
                label: 'Calificación',
                value: p.numResenas == 0
                    ? 'Sin calificaciones'
                    : '${formatearDecimal(p.promedio)} ★',
                ultima: true,
              ),
            ],
          ),
        ),
        if (_haySesion && !d.esPropio && d.estado == 'aprobado')
          FormSolicitud(
            idServicio: s.id,
            categoria: s.categoria,
            proveedorNombre: s.proveedor.isEmpty ? 'el proveedor' : s.proveedor,
            onVerSolicitudes: () =>
                Navigator.of(context).pushNamed('/solicitudes'),
          ),
      ],
    );
  }

  // === Estados sin datos: no encontrado y error de red ===
  Widget _estadoVacio() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 80),
      child: Center(
        child: Column(
          children: [
            const Icon(
              Icons.search_off_rounded,
              size: 48,
              color: AppColors.texto2,
            ),
            const SizedBox(height: 12),
            Text(
              'Servicio no encontrado',
              textAlign: TextAlign.center,
              style: AppText.serif(30),
            ),
            const SizedBox(height: 12),
            Text(
              'El servicio que buscas no existe, fue retirado o está en revisión.',
              textAlign: TextAlign.center,
              style: AppText.poppins(14.4, color: AppColors.texto2),
            ),
            const SizedBox(height: 24),
            BtnVerde(label: 'Volver al inicio', onTap: () => _irA('inicio')),
          ],
        ),
      ),
    );
  }

  Widget _estadoError() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 80),
      child: Center(
        child: Column(
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 48,
              color: AppColors.texto2,
            ),
            const SizedBox(height: 12),
            Text(
              'No pudimos cargar el servicio',
              textAlign: TextAlign.center,
              style: AppText.serif(28),
            ),
            const SizedBox(height: 12),
            Text(
              _error ?? '',
              textAlign: TextAlign.center,
              style: AppText.poppins(14.4, color: AppColors.texto2),
            ),
            const SizedBox(height: 24),
            BtnVerde(label: 'Reintentar', onTap: _cargar),
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
}

/// Teléfono colombiano en formato de wa.me ("300 123 4567" -> "573001234567").
/// Devuelve null si no parece un teléfono.
String? numeroWhatsApp(String contacto) {
  final digitos = contacto.replaceAll(RegExp(r'\D'), '');
  if (digitos.length == 10 && digitos.startsWith('3')) return '57$digitos';
  if (digitos.length == 12 && digitos.startsWith('573')) return digitos;
  if (digitos.length >= 11 && digitos.length <= 15) return digitos;
  return null;
}

/// Aviso para el dueño cuando su servicio no es público.
class _BannerEstado extends StatelessWidget {
  final String estado;
  final String? motivo;
  const _BannerEstado({required this.estado, this.motivo});

  @override
  Widget build(BuildContext context) {
    final (etiqueta, color) = estadoServicio(estado);
    final texto = switch (estado) {
      'pendiente' =>
        'Un administrador lo revisará pronto. Mientras tanto sólo tú puedes verlo.',
      'pausado' =>
        'Lo pausaste: no aparece en las búsquedas. Puedes reanudarlo desde Mis servicios.',
      'rechazado' =>
        motivo == null || motivo!.isEmpty
            ? 'No fue aprobado. Edítalo y vuelve a enviarlo a revisión.'
            : 'Motivo: $motivo\nEdítalo y vuelve a enviarlo a revisión.',
      _ => '',
    };
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.a(color, 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.a(color, 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: color, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tu servicio: $etiqueta',
                  style: AppText.poppins(
                    14.5,
                    weight: FontWeight.w600,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  texto,
                  style: AppText.poppins(
                    13.5,
                    color: AppColors.texto2,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Accesos rápidos del dueño: editar el servicio o volver a su lista.
class _AccionesDueno extends StatelessWidget {
  final VoidCallback onEditar;
  final VoidCallback onMisServicios;
  const _AccionesDueno({required this.onEditar, required this.onMisServicios});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          BtnDetalle(
            label: 'Editar servicio',
            icono: Icons.edit_outlined,
            onTap: onEditar,
          ),
          BtnDetalle(
            label: 'Mis servicios',
            icono: Icons.inventory_2_outlined,
            estilo: EstiloBtn.secundario,
            onTap: onMisServicios,
          ),
        ],
      ),
    );
  }
}

/// Para invitados: el contacto y la solicitud piden sesión.
class _InvitaSesion extends StatelessWidget {
  final VoidCallback onIniciarSesion;
  const _InvitaSesion({required this.onIniciarSesion});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.a(AppColors.teal, 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.lock_outline, color: AppColors.teal, size: 28),
          const SizedBox(height: 10),
          Text(
            '¿Te interesa este servicio?',
            textAlign: TextAlign.center,
            style: AppText.poppins(16, weight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'Inicia sesión con tu correo institucional para ver el contacto y enviar una solicitud.',
            textAlign: TextAlign.center,
            style: AppText.poppins(13.5, color: AppColors.texto2, height: 1.5),
          ),
          const SizedBox(height: 16),
          BtnDetalle(
            label: 'Iniciar sesión',
            icono: Icons.login,
            margenInferior: false,
            onTap: onIniciarSesion,
          ),
        ],
      ),
    );
  }
}


/// Tarjeta de una reseña con avatar de iniciales, fecha y estrellas.
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
                    style: AppText.poppins(
                      13.6,
                      weight: FontWeight.w700,
                      color: AppColors.bg,
                    ),
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
                        '${formatearFecha(resena.fecha)}${resena.editada ? ' · editada' : ''}',
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
                style: AppText.poppins(
                  14.08,
                  color: AppColors.texto2,
                  height: 1.6,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Botón "Reportar" junto al título; por ahora sólo muestra un aviso.
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
