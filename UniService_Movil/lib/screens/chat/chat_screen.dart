import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_colors.dart';
import '../../core/app_text.dart';
import '../../data/api_client.dart';
import '../../data/auth_repository.dart';
import '../../data/chat_realtime.dart';
import '../../data/chat_repository.dart';
import '../../data/conversacion_controller.dart';
import '../../models/chat.dart';
import 'chat_session.dart';
import 'chat_widgets.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.destino,
    this.repositorio,
    this.miId,
  });
  final DestinoChat destino;
  final ChatRepository? repositorio;
  final int? miId;
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen>
    with WidgetsBindingObserver, ChatVisible<ChatScreen> {
  late final _repo = widget.repositorio ?? ChatRepository.instance;
  late final ContactoChat _contacto = widget.destino.contacto;
  late int? _idChat = widget.destino.idChat;
  final _texto = TextEditingController();
  final _scroll = ScrollController();
  final _foco = FocusNode();
  ConversacionController? _control;
  StreamSubscription<int?>? _cambios;
  StreamSubscription<int>? _lecturas;
  Timer? _debounce;
  String? _errorInicio;
  bool _abriendo = false;
  bool _hayNuevos = false;
  int? _ultimoId;

  @override
  void initState() {
    super.initState();
    iniciarVisibilidad();
    _lecturas = _repo.lecturas.listen((id) {
      if (id == _idChat) _control?.confirmarLectura();
    });
    _cambios = _repo.cambios.listen((id) {
      if (id != null && id != _idChat) return;
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 120), () {
        if (chatVisible) _control?.actualizar();
      });
    });
    _abrir();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    observarRuta();
  }

  @override
  void cambioVisibilidad(bool visible) {
    _control?.visible = visible;
  }

  @override
  void refrescarChat() {
    if (_control == null) {
      _abrir();
    } else {
      _control!.visible = chatVisible;
      _control!.actualizar();
    }
  }

  Future<void> _abrir() async {
    if (_abriendo || _control != null) return;
    _abriendo = true;
    setState(() => _errorInicio = null);
    try {
      final yo = widget.miId ?? AuthRepository.instance.usuario.value?.id;
      if (yo == null) {
        throw const ApiException(401, 'Inicia sesión para abrir tus mensajes.');
      }
      _idChat ??= await _repo.iniciar(_contacto.id);
      if (!mounted) return;
      final control = ConversacionController(_repo, _idChat!, yo)
        ..disponible = _contacto.disponible
        ..visible = chatVisible;
      _control = control;
      control.addListener(_alCambiar);
      setState(() {});
      await control.actualizar();
    } on ApiException catch (e) {
      if (mounted) setState(() => _errorInicio = e.mensaje);
    } finally {
      _abriendo = false;
    }
  }

  void _alCambiar() {
    if (!mounted) return;
    final mensajes = _control!.mensajes;
    final nuevoId = mensajes.isEmpty ? null : mensajes.last.id;
    final cambio = nuevoId != null && nuevoId != _ultimoId;
    final cercaDelFinal = !_scroll.hasClients || _scroll.offset < 100;
    setState(() {
      if (cambio && !cercaDelFinal) _hayNuevos = true;
      _ultimoId = nuevoId;
    });
    if (cambio && cercaDelFinal) _irAlFinal();
  }

  void _irAlFinal() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      _scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
      if (_hayNuevos) setState(() => _hayNuevos = false);
    });
  }

  Future<void> _enviar() async {
    final control = _control;
    if (control == null ||
        !control.iniciado ||
        control.enviando ||
        _texto.text.trim().isEmpty) {
      return;
    }
    final borrador = _texto.text;
    final enviado = await control.enviar(borrador);
    if (!mounted) return;
    if (enviado) {
      if (_texto.text == borrador) _texto.clear();
      _irAlFinal();
      _foco.requestFocus();
    }
  }

  @override
  void dispose() {
    terminarVisibilidad();
    _debounce?.cancel();
    _cambios?.cancel();
    _lecturas?.cancel();
    _control?.removeListener(_alCambiar);
    _control?.dispose();
    _texto.dispose();
    _scroll.dispose();
    _foco.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final control = _control;
    final disponible = _contacto.disponible && (control?.disponible ?? true);
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 0,
        title: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: disponible
              ? () => Navigator.of(
                  context,
                ).pushNamed('/perfil-externo', arguments: _contacto.id)
              : null,
          child: Row(
            children: [
              AvatarChat(contacto: _contacto, radio: 19),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      disponible ? _contacto.nombre : 'Usuario no disponible',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.poppins(15, weight: FontWeight.w600),
                    ),
                    ValueListenableBuilder<bool>(
                      valueListenable: ChatRealtime.instance.conectado,
                      builder: (_, conectado, _) => Text(
                        !disponible
                            ? 'Conversación de solo lectura'
                            : conectado
                            ? 'Chat conectado'
                            : 'Reconectando…',
                        style: AppText.poppins(11, color: AppColors.texto2),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            onPressed: refrescarChat,
            tooltip: 'Actualizar mensajes',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              children: [
                if (_errorInicio != null)
                  AvisoChat(texto: _errorInicio!, onReintentar: _abrir),
                if (control?.error != null)
                  AvisoChat(
                    texto: control!.error!,
                    onReintentar: refrescarChat,
                  ),
                if (control?.cargando == true && control!.iniciado)
                  const LinearProgressIndicator(minHeight: 2),
                Expanded(child: _historial()),
                if (_hayNuevos)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: FilledButton.tonalIcon(
                      onPressed: _irAlFinal,
                      icon: const Icon(Icons.arrow_downward),
                      label: const Text('Ir al último mensaje'),
                    ),
                  ),
                if (!disponible)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Esta cuenta no está disponible. Puedes consultar el historial.',
                      style: AppText.poppins(13, color: AppColors.texto2),
                    ),
                  )
                else
                  _redactor(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _historial() {
    final c = _control;
    if (c == null) {
      return Center(
        child: _errorInicio == null
            ? const CircularProgressIndicator()
            : const Icon(
                Icons.chat_bubble_outline,
                size: 48,
                color: AppColors.texto2,
              ),
      );
    }
    if (!c.iniciado) {
      return Center(
        child: c.error == null
            ? const CircularProgressIndicator()
            : const Text('No pudimos cargar los mensajes.'),
      );
    }
    final mensajes = c.mensajes;
    if (mensajes.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.waving_hand_outlined,
                size: 48,
                color: AppColors.teal,
              ),
              const SizedBox(height: 16),
              Text(
                'Saluda a ${_contacto.nombre}',
                textAlign: TextAlign.center,
                style: AppText.serif(24),
              ),
              const SizedBox(height: 10),
              Text(
                'Acuerden aquí los detalles del servicio.',
                textAlign: TextAlign.center,
                style: AppText.poppins(14, color: AppColors.texto2),
              ),
            ],
          ),
        ),
      );
    }
    return ListView.builder(
      key: const ValueKey('historial-chat'),
      controller: _scroll,
      reverse: true,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: mensajes.length + (c.hayAnteriores ? 1 : 0),
      itemBuilder: (context, indice) {
        if (indice == mensajes.length) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: c.cargandoAnteriores
                  ? const CircularProgressIndicator()
                  : TextButton.icon(
                      onPressed: c.anteriores,
                      icon: const Icon(Icons.history),
                      label: const Text('Cargar mensajes anteriores'),
                    ),
            ),
          );
        }
        final i = mensajes.length - 1 - indice;
        final m = mensajes[i];
        final fecha = m.fecha;
        final anterior = i > 0 ? mensajes[i - 1].fecha : null;
        final nuevoDia =
            fecha != null &&
            (anterior == null ||
                fecha.year != anterior.year ||
                fecha.month != anterior.month ||
                fecha.day != anterior.day);
        return Column(
          key: ValueKey('mensaje-${m.id}'),
          children: [
            if (nuevoDia)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Text(
                  '${fecha.day}/${fecha.month}/${fecha.year}',
                  style: AppText.poppins(11, color: AppColors.texto2),
                ),
              ),
            BurbujaMensaje(mensaje: m, esMio: m.idRemitente == c.miId),
          ],
        );
      },
    );
  }

  Widget _redactor() {
    final c = _control;
    final habilitado = c?.iniciado == true && c?.enviando == false;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      decoration: const BoxDecoration(
        color: AppColors.bg2,
        border: Border(top: BorderSide(color: AppColors.borde)),
      ),
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.enter, control: true):
              _enviar,
          const SingleActivator(LogicalKeyboardKey.enter, meta: true): _enviar,
        },
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                key: const ValueKey('borrador-chat'),
                controller: _texto,
                focusNode: _foco,
                enabled: habilitado,
                minLines: 1,
                maxLines: 5,
                maxLength: 2000,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                textCapitalization: TextCapitalization.sentences,
                style: AppText.poppins(14),
                decoration: InputDecoration(
                  hintText: 'Escribe un mensaje…',
                  filled: true,
                  fillColor: AppColors.card,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: const BorderSide(color: AppColors.borde),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _texto,
              builder: (_, valor, _) => IconButton.filled(
                key: const ValueKey('enviar-chat'),
                tooltip: 'Enviar mensaje (Ctrl+Enter)',
                onPressed: habilitado && valor.text.trim().isNotEmpty
                    ? _enviar
                    : null,
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.teal,
                  foregroundColor: AppColors.bg,
                  minimumSize: const Size(48, 48),
                ),
                icon: c?.enviando == true
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
