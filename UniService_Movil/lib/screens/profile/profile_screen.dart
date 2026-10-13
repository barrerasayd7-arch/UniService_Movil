import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_colors.dart';
import '../../core/app_text.dart';
import '../../core/categorias.dart' show formatearFecha;
import '../../data/servicios_mock.dart';
import '../../data/usuarios_mock.dart';
import '../../models/usuario.dart';
import '../../widgets/app_buttons.dart' show HoverBuilder;
import '../login/auth_widgets.dart' show mostrarNotificacion;
import 'navbar_perfil.dart';
import 'profile_background.dart';
import 'profile_modals.dart';
import 'profile_widgets.dart';

/// Vista de Perfil (Perfil.jsx).
/// [externo] = true muestra el perfil de OTRA persona (Seguir / Chatear /
/// Compartir y "Reportar usuario"); false muestra el perfil propio.
class ProfileScreen extends StatefulWidget {
  final bool externo;
  const ProfileScreen({super.key, this.externo = false});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _menuAbierto = false;
  bool _siguiendo = false;

  //  GET /api/users/{id}
  late final Usuario _usuario = widget.externo ? perfilExternoMock : miPerfilMock;

 
  final _misServicios = serviciosMock.take(4).toList();

  bool get _externo => widget.externo;

  // ── Navegación ──
  void _irA(String enlace) {
    setState(() => _menuAbierto = false);
    if (enlace == 'inicio') {
      Navigator.of(context).pushNamedAndRemoveUntil('/home', (_) => false);
    } else {
      Navigator.of(context).pushNamedAndRemoveUntil('/home', (_) => false, arguments: enlace);
    }
  }

  void _irAMiPerfil() {
    setState(() => _menuAbierto = false);
    if (_externo) {
      Navigator.of(context).pushNamedAndRemoveUntil('/perfil', ModalRoute.withName('/home'));
    }
  }

  void _cerrarSesion() {
    //  /api/auth/logout y limpiar el token
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
    await Clipboard.setData(ClipboardData(text: 'https://uniservice.app/perfil/${_usuario.id}'));
    if (!mounted) return;
    mostrarNotificacion(context, 'Enlace del perfil copiado', exito: true);
  }

  void _abrirSeguidores() => mostrarListaPersonas(
        context,
        titulo: 'Seguidores',
        icono: Icons.people,
        personas: personasMock,
        vacio: 'Aún no tienes seguidores.',
        onTapPersona: (_) => Navigator.of(context).pushNamed('/perfil-externo'),
      );

  void _abrirSiguiendo() => mostrarListaPersonas(
        context,
        titulo: 'Siguiendo',
        icono: Icons.how_to_reg,
        personas: personasMock.take(3).toList(),
        vacio: 'Aún no sigues a nadie.',
        onTapPersona: (_) => Navigator.of(context).pushNamed('/perfil-externo'),
      );

  void _reportar() {
    
    _proximamente('Reportar');
  }

  @override
  Widget build(BuildContext context) {
    final ancho = MediaQuery.of(context).size.width;
    final movil = ancho <= 1100;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          const Positioned.fill(child: ProfileBackground()),
          Column(
            children: [
              NavbarPerfil(
                movil: movil,
                menuAbierto: _menuAbierto,
                nombreUsuario: miPerfilMock.nombre.split(' ').first,
                onToggleMenu: () => setState(() => _menuAbierto = !_menuAbierto),
                onEnlace: _irA,
                onPerfil: _irAMiPerfil,
                onCerrarSesion: _cerrarSesion,
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: _contenido(ancho),
                ),
              ),
            ],
          ),
          if (movil && _menuAbierto)
            Positioned(
              top: 62,
              right: 16,
              child: MenuMovilPerfil(
                nombreUsuario: miPerfilMock.nombre.split(' ').first,
                onEnlace: _irA,
                onPerfil: _irAMiPerfil,
                onCerrarSesion: _cerrarSesion,
              ),
            ),
          _BotonReportar(onTap: _reportar),
        ],
      ),
    );
  }

  Widget _contenido(double ancho) {
    final pad = ancho <= 480
        ? const EdgeInsets.fromLTRB(8, 10, 8, 0)
        : ancho <= 640
            ? const EdgeInsets.fromLTRB(12, 12, 12, 0)
            : ancho <= 768
                ? const EdgeInsets.fromLTRB(16, 15, 16, 0)
                : const EdgeInsets.fromLTRB(20, 19, 20, 0);

    final tarjeta = FadeInUp(child: _TarjetaPerfil(
      usuario: _usuario,
      externo: _externo,
      siguiendo: _siguiendo,
      onAvatar: () => mostrarCambiarAvatar(context),
      onSeguidores: _abrirSeguidores,
      onSiguiendo: _abrirSiguiendo,
      onEditar: () => mostrarEditarPerfil(context, _usuario),
      onCompartir: _compartir,
      onSeguir: () => setState(() => _siguiendo = !_siguiendo),
      onChatear: () => _proximamente('Chat'),
    ));

    final panel = _PanelDerecho(
      usuario: _usuario,
      externo: _externo,
      totalServicios: _misServicios.length,
      onSeguridad: () => mostrarSeguridad(context),
      onReportarUsuario: _reportar,
      onMisServicios: () => mostrarMisServicios(context, _misServicios),
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
              : Column(
                  children: [tarjeta, const SizedBox(height: 30), panel],
                ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════
// Botón flotante rojo "Reportar problema" (.btn-reportar-flotante)
// ═════════════════════════════════════════════════════════════
class _BotonReportar extends StatelessWidget {
  final VoidCallback onTap;
  const _BotonReportar({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final size = w <= 480 ? 42.0 : w <= 768 ? 48.0 : w <= 1024 ? 55.0 : 66.0;
    final margen = w <= 480 ? 16.0 : w <= 768 ? 20.0 : 30.0;
    final icono = w <= 480 ? 16.0 : w <= 768 ? 19.0 : w <= 1024 ? 21.0 : 24.0;

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
                  color: AppColors.a(const Color(0xFFEF4444), hover ? 0.25 : 0.15),
                  border: Border.all(
                    color: AppColors.a(const Color(0xFFEF4444), hover ? 0.5 : 0.3),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.a(const Color(0xFFEF4444), hover ? 0.25 : 0.15),
                      blurRadius: hover ? 24 : 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(Icons.bug_report, size: icono, color: const Color(0xFFF87171)),
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
    final avatar = ancho <= 640 ? 92.0 : ancho <= 768 ? 100.0 : 120.0;
    final nombreSize = ancho <= 640 ? 25.6 : ancho <= 768 ? 27.2 : 28.8;
    final headerPad = ancho <= 640
        ? const EdgeInsets.fromLTRB(22, 35, 22, 30)
        : ancho <= 768
            ? const EdgeInsets.fromLTRB(26, 38, 26, 34)
            : const EdgeInsets.fromLTRB(30, 60, 30, 50);

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
                    externo: externo,
                    conectado: usuario.conectado,
                    onTap: externo ? null : onAvatar,
                  ),
                  SizedBox(height: ancho <= 640 ? 14 : ancho <= 768 ? 16 : 20),
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
                      usuario.descripcion,
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
                      border: Border(bottom: BorderSide(color: AppColors.borde)),
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
                            value: '${usuario.totalSiguiendo}',
                            label: 'Siguiendo',
                            onTap: onSiguiendo,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 25),
                  Row(
                    children: externo
                        ? [
                            Expanded(
                              child: BtnAction(
                                label: siguiendo ? 'Siguiendo' : 'Seguir',
                                icono: siguiendo ? Icons.check : Icons.add,
                                estilo: siguiendo ? EstiloAccion.outline : EstiloAccion.solido,
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
class _Avatar extends StatefulWidget {
  final double size;
  final bool externo;
  final bool conectado;
  final VoidCallback? onTap;
  const _Avatar({
    required this.size,
    required this.externo,
    required this.conectado,
    required this.onTap,
  });

  @override
  State<_Avatar> createState() => _AvatarState();
}

class _AvatarState extends State<_Avatar> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
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
      cursor: widget.onTap == null ? SystemMouseCursors.basic : SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: SizedBox(
          width: s,
          height: s,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Anillo animado (inset -4)
              Positioned(
                left: -4,
                top: -4,
                right: -4,
                bottom: -4,
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
                child: ClipOval(
                  child: Image.asset('assets/img/default-avatar.png', fit: BoxFit.cover),
                ),
              ),
              // Indicador conectado / desconectado (solo perfiles externos)
              if (widget.externo)
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.conectado
                          ? const Color(0xFF10B981)
                          : const Color(0xFFEF4444),
                      border: Border.all(color: AppColors.bg, width: 3),
                    ),
                  ),
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
    final gap = ancho <= 640 ? 20.0 : ancho <= 768 ? 24.0 : 28.0;

    final celdas = <Widget>[
      InfoItem(label: 'Correo', value: usuario.correo),
      InfoItem(label: 'Miembro desde', value: formatearFecha(usuario.fechaRegistro)),
      InfoItem(
        label: 'Universidad',
        value: usuario.universidad.isEmpty ? 'Sin universidad' : usuario.universidad,
      ),
      InfoItem(label: 'Reputación', value: usuario.reputacionTexto),
      InfoItem(
        label: 'Teléfono',
        value: usuario.telefono.isEmpty ? 'No disponible' : usuario.telefono,
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
                  children: [for (final c in celdas) SizedBox(width: colW, child: c)],
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
