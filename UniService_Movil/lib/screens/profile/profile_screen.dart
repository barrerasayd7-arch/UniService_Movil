// Archivo: profile_screen.dart
// Responsabilidad: perfil propio y público con carga desde la API, seguimiento,
//   estadísticas, navegación y acciones de edición o reporte.
// Se usa desde: main.dart para '/perfil' y '/perfil-externo'.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_colors.dart';
import '../../data/auth_repository.dart';
import '../../core/app_text.dart';
import '../../core/categorias.dart' show formatearFecha;
import '../../data/api_client.dart';
import '../../data/perfil_repository.dart';
import '../../data/servicios_repository.dart';
import '../../models/usuario.dart';
import '../../widgets/app_buttons.dart' show HoverBuilder;
import '../login/auth_widgets.dart' show mostrarNotificacion;
import 'navbar_perfil.dart';
import 'profile_background.dart';
import 'profile_modals.dart';
import '../../widgets/animacion_ambiental.dart';
import 'profile_widgets.dart';

/// Vista de Perfil (Perfil.jsx).
/// [externo] = false: el perfil propio (GET /api/perfil/me, con correo y teléfono).
/// [externo] = true: el perfil público de [idUsuario] (GET /api/perfil/{id}), con
/// Seguir / Chatear / Compartir y "Reportar usuario", sin datos de contacto.
class ProfileScreen extends StatefulWidget {
  final bool externo;
  final int? idUsuario;
  const ProfileScreen({super.key, this.externo = false, this.idUsuario});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _menuAbierto = false;
  bool _guardandoSeguir = false;

  // _perfil null dispara la carga o el reintento; _error guarda el mensaje del fallo.
  Usuario? _perfil;
  String? _error;

  int _totalServicios = 0;

  bool get _externo => widget.externo;
  Usuario get _usuario => _perfil!;

  // Nombre de la sesión actual para el navbar, aunque se vea otro perfil.
  String get _nombreSesion =>
      (AuthRepository.instance.usuario.value?.nombre ?? '').split(' ').first;

  @override
  void initState() {
    super.initState();
    // Carga inicial y, sólo en el perfil propio, el conteo de servicios.
    _cargar();
    if (!_externo) _contarServicios();
  }

  Future<void> _cargar() async {
    setState(() => _error = null);
    final id = widget.idUsuario;
    if (_externo && id == null) {
      setState(() => _error = 'Perfil no encontrado');
      return;
    }
    // Abrir "mi" perfil como externo lleva a la vista propia.
    if (_externo && id == AuthRepository.instance.usuario.value?.id) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pushReplacementNamed('/perfil');
      });
      return;
    }
    try {
      final perfil = _externo
          ? await PerfilRepository.instance.perfil(id!)
          : await PerfilRepository.instance.miPerfil();
      if (mounted) setState(() => _perfil = perfil);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.status == 404 ? 'Este perfil no existe o no está disponible.' : e.mensaje);
    }
  }

  Future<void> _alternarSeguir() async {
    // Bloquea el botón mientras el servidor confirma y luego actualiza contadores.
    if (_guardandoSeguir) return;
    final seguir = !_usuario.loSigo;
    setState(() => _guardandoSeguir = true);
    try {
      final total = await PerfilRepository.instance.seguir(_usuario.id, seguir: seguir);
      if (mounted) setState(() => _perfil = _usuario.copyWith(loSigo: seguir, totalSeguidores: total));
    } on ApiException catch (e) {
      if (mounted) mostrarNotificacion(context, e.mensaje);
    } finally {
      if (mounted) setState(() => _guardandoSeguir = false);
    }
  }

  Future<void> _contarServicios() async {
    try {
      final mios = await ServiciosRepository.instance.mios();
      if (mounted) setState(() => _totalServicios = mios.length);
    } on ApiException {
      // El contador es informativo; si falla se queda en 0.
    }
  }

  // ── Navegación ──
  // Vuelve al home conservando el enlace como argumento para saltar a su ancla.
  void _irA(String enlace) {
    setState(() => _menuAbierto = false);
    if (enlace == 'inicio') {
      Navigator.of(context).pushNamedAndRemoveUntil('/home', (_) => false);
    } else {
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil('/home', (_) => false, arguments: enlace);
    }
  }

  void _irAMiPerfil() {
    setState(() => _menuAbierto = false);
    if (_externo) {
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil('/perfil', ModalRoute.withName('/home'));
    }
  }

  Future<void> _cerrarSesion() async {
    await AuthRepository.instance.cerrarSesion();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/home-guest', (_) => false);
  }

  void _proximamente(String que) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('$que: próxima vista por implementar'),
          backgroundColor: AppColors.card,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  Future<void> _compartir() async {
    await Clipboard.setData(
      ClipboardData(text: 'https://uniservice.app/perfil/${_usuario.id}'),
    );
    if (!mounted) return;
    mostrarNotificacion(context, 'Enlace del perfil copiado', exito: true);
  }

  void _abrirPerfil(PersonaResumen p) =>
      Navigator.of(context).pushNamed('/perfil-externo', arguments: p.id);

  void _abrirSeguidores() => mostrarListaPersonas(
    context,
    titulo: 'Seguidores',
    icono: Icons.people,
    personas: PerfilRepository.instance.seguidores(_usuario.id),
    vacio: _externo ? 'Aún no tiene seguidores.' : 'Aún no tienes seguidores.',
    onTapPersona: _abrirPerfil,
  );

  void _abrirSiguiendo() => mostrarListaPersonas(
    context,
    titulo: 'Siguiendo',
    icono: Icons.how_to_reg,
    personas: PerfilRepository.instance.siguiendo(_usuario.id),
    vacio: _externo ? 'Aún no sigue a nadie.' : 'Aún no sigues a nadie.',
    onTapPersona: _abrirPerfil,
  );

  // Botón flotante: problema general. En perfiles ajenos: "Reportar usuario".
  void _reportarProblema() => mostrarReportar(context);
  void _reportarUsuario() =>
      mostrarReportar(context, idUsuario: _usuario.id, nombreUsuario: _usuario.nombre);

  @override
  Widget build(BuildContext context) {
    final ancho = MediaQuery.of(context).size.width;
    // En pantallas medianas se usa el mismo menú desplegable que en el home.
    final movil = ancho <= 1100;

    return Scaffold(
      backgroundColor: AppColors.bg,
      // SafeArea: la barra superior no queda bajo la hora/batería del celular.
      body: SafeArea(
        bottom: false,
        // Stack: fondo animado, contenido, menú móvil y botón de reporte.
        child: Stack(
          children: [
            const Positioned.fill(
              child: AnimacionAmbiental(child: ProfileBackground()),
            ),
            Column(
              children: [
                NavbarPerfil(
                  movil: movil,
                  menuAbierto: _menuAbierto,
                  nombreUsuario: _nombreSesion,
                  onToggleMenu: () =>
                      setState(() => _menuAbierto = !_menuAbierto),
                  onEnlace: _irA,
                  onPerfil: _irAMiPerfil,
                  onCerrarSesion: _cerrarSesion,
                ),
                Expanded(
                  child: _perfil != null
                      ? RefreshIndicator(
                          color: AppColors.teal,
                          onRefresh: _cargar,
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            child: _contenido(ancho),
                          ),
                        )
                      : _estadoCarga(),
                ),
              ],
            ),
            if (movil && _menuAbierto)
              Positioned(
                top: 62,
                right: 16,
                child: MenuMovilPerfil(
                  nombreUsuario: _nombreSesion,
                  onEnlace: _irA,
                  onPerfil: _irAMiPerfil,
                  onCerrarSesion: _cerrarSesion,
                ),
              ),
            _BotonReportar(onTap: _reportarProblema),
          ],
        ),
      ),
    );
  }

  // Spinner mientras no hay perfil; si falló, mensaje con reintento.
  Widget _estadoCarga() {
    if (_error == null) {
      return const Center(child: CircularProgressIndicator(color: AppColors.teal));
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.person_off_outlined, size: 48, color: AppColors.texto3),
            const SizedBox(height: 12),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: AppText.poppins(14.4, color: AppColors.texto2),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: _cargar,
              icon: const Icon(Icons.refresh, color: AppColors.teal),
              label: Text('Reintentar', style: AppText.poppins(14, color: AppColors.teal)),
            ),
          ],
        ),
      ),
    );
  }

  // Distribuye tarjeta y panel: lado a lado en pantallas anchas, apilados si no.
  Widget _contenido(double ancho) {
    final pad = ancho <= 480
        ? const EdgeInsets.fromLTRB(8, 10, 8, 0)
        : ancho <= 640
        ? const EdgeInsets.fromLTRB(12, 12, 12, 0)
        : ancho <= 768
        ? const EdgeInsets.fromLTRB(16, 15, 16, 0)
        : const EdgeInsets.fromLTRB(20, 19, 20, 0);

    final tarjeta = FadeInUp(
      child: _TarjetaPerfil(
        usuario: _usuario,
        externo: _externo,
        siguiendo: _usuario.loSigo,
        onAvatar: () => mostrarCambiarAvatar(
          context,
          tieneAvatar: _usuario.avatarUrl != null,
          onCambio: (url) => setState(
            () => _perfil = _usuario.copyWith(avatarUrl: url, quitarAvatar: url == null),
          ),
        ),
        onSeguidores: _abrirSeguidores,
        onSiguiendo: _abrirSiguiendo,
        onEditar: () => mostrarEditarPerfil(
          context,
          _usuario,
          onActualizado: (u) => setState(() => _perfil = u),
        ),
        onCompartir: _compartir,
        onSeguir: _alternarSeguir,
        onChatear: () => _proximamente('Chat'),
      ),
    );

    final panel = _PanelDerecho(
      usuario: _usuario,
      externo: _externo,
      totalServicios: _totalServicios,
      onSeguridad: () => mostrarSeguridad(context),
      onReportarUsuario: _reportarUsuario,
      onMisServicios: () => Navigator.of(context)
          .pushNamed('/mis-servicios')
          .then((_) => _contarServicios()),
    );

    return Padding(
      padding: pad.copyWith(bottom: 40),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: ancho > 900
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 380, child: tarjeta),
                    const SizedBox(width: 30),
                    Expanded(child: panel),
                  ],
                )
              : Column(children: [tarjeta, const SizedBox(height: 30), panel]),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════
// Botón flotante rojo "Reportar problema" (.btn-reportar-flotante)
// ═════════════════════════════════════════════════════════════
/// Botón flotante que abre el reporte de un problema general.
class _BotonReportar extends StatelessWidget {
  final VoidCallback onTap;
  const _BotonReportar({required this.onTap});

  @override
  Widget build(BuildContext context) {
    // Tamaño, margen e icono crecen con el ancho de la pantalla.
    final w = MediaQuery.of(context).size.width;
    final size = w <= 480
        ? 42.0
        : w <= 768
        ? 48.0
        : w <= 1024
        ? 55.0
        : 66.0;
    final margen = w <= 480
        ? 16.0
        : w <= 768
        ? 20.0
        : 30.0;
    final icono = w <= 480
        ? 16.0
        : w <= 768
        ? 19.0
        : w <= 1024
        ? 21.0
        : 24.0;

    return Positioned(
      right: margen,
      bottom: margen,
      child: Tooltip(
        message: 'Reportar problema',
        child: HoverBuilder(
          builder: (context, hover) => GestureDetector(
            onTap: onTap,
            child: AnimatedScale(
              duration: const Duration(milliseconds: 250),
              scale: hover ? 1.1 : 1,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.a(
                    const Color(0xFFEF4444),
                    hover ? 0.25 : 0.15,
                  ),
                  border: Border.all(
                    color: AppColors.a(
                      const Color(0xFFEF4444),
                      hover ? 0.5 : 0.3,
                    ),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.a(
                        const Color(0xFFEF4444),
                        hover ? 0.25 : 0.15,
                      ),
                      blurRadius: hover ? 24 : 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.bug_report,
                  size: icono,
                  color: const Color(0xFFF87171),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════
// Tarjeta izquierda (.profile-card)
// ═════════════════════════════════════════════════════════════
/// Tarjeta izquierda del perfil: avatar, identidad, estadísticas y acciones
/// (editar/compartir en el propio, seguir/chatear/compartir en el ajeno).
class _TarjetaPerfil extends StatelessWidget {
  final Usuario usuario;
  final bool externo;
  final bool siguiendo;
  final VoidCallback onAvatar;
  final VoidCallback onSeguidores;
  final VoidCallback onSiguiendo;
  final VoidCallback onEditar;
  final VoidCallback onCompartir;
  final VoidCallback onSeguir;
  final VoidCallback onChatear;

  const _TarjetaPerfil({
    required this.usuario,
    required this.externo,
    required this.siguiendo,
    required this.onAvatar,
    required this.onSeguidores,
    required this.onSiguiendo,
    required this.onEditar,
    required this.onCompartir,
    required this.onSeguir,
    required this.onChatear,
  });

  @override
  Widget build(BuildContext context) {
    final ancho = MediaQuery.of(context).size.width;
    final avatar = ancho <= 640
        ? 92.0
        : ancho <= 768
        ? 100.0
        : 120.0;
    final nombreSize = ancho <= 640
        ? 25.6
        : ancho <= 768
        ? 27.2
        : 28.8;
    final headerPad = ancho <= 640
        ? const EdgeInsets.fromLTRB(22, 35, 22, 30)
        : ancho <= 768
        ? const EdgeInsets.fromLTRB(26, 38, 26, 34)
        : const EdgeInsets.fromLTRB(30, 60, 30, 50);

    // El cursor no cambia fuera de los botones; la tarjeta sólo se eleva.
    return HoverBuilder(
      cursor: SystemMouseCursors.basic,
      builder: (context, hover) => AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        transform: Matrix4.translationValues(0, hover ? -4 : 0, 0),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: hover ? AppColors.teal2 : AppColors.borde),
          boxShadow: [
            BoxShadow(
              color: AppColors.a(AppColors.teal, hover ? 0.25 : 0.10),
              blurRadius: hover ? 60 : 32,
              offset: Offset(0, hover ? 20 : 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Cabecera con degradado ──
            Container(
              padding: headerPad,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  stops: [0, 0.25, 0.5, 1],
                  colors: [
                    Color(0xFF00D4D4),
                    Color(0xFF0EA5A0),
                    Color(0xFF0D7F7C),
                    Color(0xFF0A5F5C),
                  ],
                ),
              ),
              child: Column(
                children: [
                  _Avatar(
                    size: avatar,
                    url: usuario.avatarUrl,
                    onTap: externo ? null : onAvatar,
                  ),
                  SizedBox(
                    height: ancho <= 640
                        ? 14
                        : ancho <= 768
                        ? 16
                        : 20,
                  ),
                  Text(
                    usuario.nombre,
                    textAlign: TextAlign.center,
                    style: AppText.serif(
                      nombreSize,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          color: Colors.black.withAlpha(77),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    usuario.username,
                    style: AppText.poppins(
                      14.4,
                      weight: FontWeight.w500,
                      color: const Color(0xFFF0F9FF),
                    ),
                  ),
                ],
              ),
            ),

            // ── Cuerpo ──
            Padding(
              padding: const EdgeInsets.all(25),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text(
                      usuario.descripcion.isEmpty
                          ? (externo ? 'Sin descripción.' : 'Aún no tienes descripción. Toca "Editar Perfil" para agregarla.')
                          : usuario.descripcion,
                      textAlign: TextAlign.center,
                      style: AppText.poppins(
                        14.4,
                        weight: FontWeight.w500,
                        height: 1.7,
                      ),
                    ),
                  ),
                  const SizedBox(height: 25),
                  Container(
                    padding: const EdgeInsets.only(bottom: 25),
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: AppColors.borde),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: StatItem(
                            value: '${usuario.totalPublicaciones}',
                            label: 'Publicaciones',
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: StatItem(
                            value: formatearNumero(usuario.totalSeguidores),
                            label: 'Seguidores',
                            onTap: onSeguidores,
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: StatItem(
                            value: formatearNumero(usuario.totalSiguiendo),
                            label: 'Siguiendo',
                            onTap: onSiguiendo,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 25),
                  // Las acciones dependen de si el perfil es propio o ajeno.
                  Row(
                    children: externo
                        ? [
                            Expanded(
                              child: BtnAction(
                                label: siguiendo ? 'Siguiendo' : 'Seguir',
                                icono: siguiendo ? Icons.check : Icons.add,
                                estilo: siguiendo
                                    ? EstiloAccion.outline
                                    : EstiloAccion.solido,
                                onTap: onSeguir,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: BtnAction(
                                label: 'Chatear',
                                icono: Icons.chat_bubble,
                                estilo: EstiloAccion.oscuro,
                                onTap: onChatear,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: BtnAction(
                                label: 'Compartir',
                                icono: Icons.link,
                                estilo: EstiloAccion.sutil,
                                onTap: onCompartir,
                              ),
                            ),
                          ]
                        : [
                            Expanded(
                              child: BtnAction(
                                label: 'Editar Perfil',
                                icono: Icons.edit_outlined,
                                onTap: onEditar,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: BtnAction(
                                label: 'Compartir',
                                icono: Icons.link,
                                estilo: EstiloAccion.sutil,
                                onTap: onCompartir,
                              ),
                            ),
                          ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Avatar con anillo dorado/teal giratorio ──
/// Avatar con anillo giratorio; el tap sólo se habilita en el perfil propio.
class _Avatar extends StatefulWidget {
  final double size;
  final String? url;
  final VoidCallback? onTap;
  const _Avatar({required this.size, required this.url, required this.onTap});

  @override
  State<_Avatar> createState() => _AvatarState();
}

class _AvatarState extends State<_Avatar> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 4))
      ..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    return MouseRegion(
      cursor: widget.onTap == null
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: SizedBox(
          width: s,
          height: s,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // El anillo gira de forma continua con un SweepGradient.
              Positioned(
                left: -4,
                top: -4,
                right: -4,
                bottom: -4,
                child: AnimacionAmbiental(
                  child: AnimatedBuilder(
                    animation: _c,
                    builder: (context, _) => Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: SweepGradient(
                          transform: GradientRotation(_c.value * 2 * math.pi),
                          colors: const [
                            Color(0xFFF5C842),
                            Color(0xFF00D4D4),
                            Color(0xFFF5C842),
                            Color(0xFF00D4D4),
                            Color(0xFFF5C842),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.a(AppColors.amarillo, 0.3),
                            blurRadius: 20,
                          ),
                          BoxShadow(
                            color: const Color(0x4D00D4D4),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // Foto
              Container(
                width: s,
                height: s,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.bg, width: 4),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.a(AppColors.teal, 0.3),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipOval(child: fotoPerfil(widget.url, size: s)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════
// Panel derecho (.right-panel)
// ═════════════════════════════════════════════════════════════
/// Panel derecho: información de la cuenta y acceso a servicios, seguridad
/// o reporte según el tipo de perfil.
class _PanelDerecho extends StatelessWidget {
  final Usuario usuario;
  final bool externo;
  final int totalServicios;
  final VoidCallback onSeguridad;
  final VoidCallback onReportarUsuario;
  final VoidCallback onMisServicios;

  const _PanelDerecho({
    required this.usuario,
    required this.externo,
    required this.totalServicios,
    required this.onSeguridad,
    required this.onReportarUsuario,
    required this.onMisServicios,
  });

  @override
  Widget build(BuildContext context) {
    final ancho = MediaQuery.of(context).size.width;
    final gap = ancho <= 640
        ? 20.0
        : ancho <= 768
        ? 24.0
        : 28.0;

    final fecha = usuario.fechaRegistro;
    final celdas = <Widget>[
      // Correo y teléfono sólo existen en el perfil propio: la API no los envía en perfiles ajenos.
      if (!externo)
        InfoItem(label: 'Correo', value: usuario.correo ?? '')
      else
        InfoItem(
          label: 'Programa',
          value: usuario.programa.isEmpty ? 'No indicado' : usuario.programa,
        ),
      InfoItem(
        label: 'Miembro desde',
        value: fecha == null ? 'No disponible' : formatearFecha(fecha),
      ),
      InfoItem(
        label: 'Universidad',
        value: usuario.universidad.isEmpty
            ? 'Sin universidad'
            : usuario.universidad,
      ),
      InfoItem(label: 'Reputación', value: usuario.reputacionTexto),
      if (!externo)
        InfoItem(
          label: 'Teléfono (solo tú lo ves)',
          value: (usuario.telefono ?? '').isEmpty ? 'No disponible' : usuario.telefono!,
        )
      else
        InfoItem(
          label: 'Sede',
          value: usuario.sede.isEmpty ? 'No indicada' : usuario.sede,
        ),
      // La web pone esta opción en la sexta celda de la cuadrícula
      if (!externo)
        MenuItem(
          icono: Icons.lock,
          title: 'Seguridad',
          desc: 'Gestiona tu cuenta',
          onTap: onSeguridad,
        )
      else
        MenuItem(
          icono: Icons.flag,
          colorIcono: const Color(0xFFFF6B6B),
          title: 'Reportar usuario',
          desc: 'Acoso, fraude, abuso u otro motivo',
          onTap: onReportarUsuario,
        ),
    ];

    return Column(
      children: [
        FadeInUp(
          delayMs: 100,
          child: MenuSection(
            icono: Icons.assignment_outlined,
            titulo: 'Información',
            child: LayoutBuilder(
              builder: (context, box) {
                // En paneles estrechos la cuadrícula pasa a una sola columna.
                final dosColumnas = box.maxWidth >= 420;
                if (!dosColumnas) {
                  return Column(
                    children: [
                      for (var i = 0; i < celdas.length; i++) ...[
                        if (i > 0) SizedBox(height: gap),
                        celdas[i],
                      ],
                    ],
                  );
                }
                final colW = (box.maxWidth - gap) / 2;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    for (final c in celdas) SizedBox(width: colW, child: c),
                  ],
                );
              },
            ),
          ),
        ),
        if (!externo) ...[
          const SizedBox(height: 24),
          FadeInUp(
            delayMs: 200,
            child: MenuSection(
              icono: Icons.inventory_2,
              titulo: 'Todos mis servicios',
              child: MenuItem(
                icono: Icons.inventory_2,
                title: 'Mis servicios ($totalServicios)',
                desc: 'Administra tus servicios publicados',
                onTap: onMisServicios,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
