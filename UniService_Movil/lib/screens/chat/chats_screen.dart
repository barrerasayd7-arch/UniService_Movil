import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_text.dart';
import '../../data/api_client.dart';
import '../../data/chat_repository.dart';
import '../../models/chat.dart';
import 'chat_session.dart';
import 'chat_widgets.dart';

class ChatsScreen extends StatefulWidget {
  const ChatsScreen({super.key, this.repositorio});
  final ChatRepository? repositorio;
  @override
  State<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen>
    with WidgetsBindingObserver, ChatVisible<ChatsScreen> {
  late final _repo = widget.repositorio ?? ChatRepository.instance;
  StreamSubscription<int?>? _cambios;
  Timer? _debounce;
  List<Conversacion>? _chats;
  String? _error;
  String _busqueda = '';
  bool _soloNoLeidos = false;
  bool _cargando = false;
  bool _pendiente = false;

  @override
  void initState() {
    super.initState();
    iniciarVisibilidad();
    _cambios = _repo.cambios.listen((_) {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 200), () {
        if (chatVisible) _cargar();
      });
    });
    _cargar();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    observarRuta();
  }

  @override
  void refrescarChat() => _cargar();

  Future<void> _cargar() async {
    if (_cargando) {
      _pendiente = true;
      return;
    }
    _cargando = true;
    try {
      final chats = await _repo.listar();
      if (mounted) {
        setState(() {
          _chats = chats;
          _error = null;
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    } finally {
      _cargando = false;
      if (_pendiente && chatVisible) {
        _pendiente = false;
        _cargar();
      }
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _cambios?.cancel();
    terminarVisibilidad();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chats = (_chats ?? [])
        .where(
          (c) =>
              (!_soloNoLeidos || c.noLeidos > 0) &&
              c.otro.nombre.toLowerCase().contains(
                _busqueda.toLowerCase().trim(),
              ),
        )
        .toList();
    return Scaffold(
      backgroundColor: AppColors.of(context).bg,
      appBar: AppBar(
        backgroundColor: AppColors.of(context).bg,
        surfaceTintColor: Colors.transparent,
        title: Text('Mis chats', style: AppText.serif(25)),
        actions: [
          IconButton(
            onPressed: _cargar,
            tooltip: 'Actualizar conversaciones',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 850),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: TextField(
                    onChanged: (v) => setState(() => _busqueda = v),
                    decoration: InputDecoration(
                      hintText: 'Buscar una conversación',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: AppColors.of(context).card,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: AppColors.of(context).borde,
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FilterChip(
                      label: const Text('No leídos'),
                      selected: _soloNoLeidos,
                      onSelected: (v) => setState(() => _soloNoLeidos = v),
                    ),
                  ),
                ),
                if (_error != null)
                  AvisoChat(texto: _error!, onReintentar: _cargar),
                Expanded(
                  child: _chats == null && _error == null
                      ? const Center(child: CircularProgressIndicator())
                      : RefreshIndicator(
                          onRefresh: _cargar,
                          child: ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(16),
                            itemCount: chats.isEmpty ? 1 : chats.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, i) {
                              if (chats.isEmpty) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 64,
                                    horizontal: 16,
                                  ),
                                  child: Column(
                                    children: [
                                      Icon(
                                        Icons.forum_outlined,
                                        size: 56,
                                        color: AppColors.of(context).teal,
                                      ),
                                      const SizedBox(height: 20),
                                      Text(
                                        _error != null
                                            ? 'No pudimos cargar tus chats'
                                            : _busqueda.isNotEmpty ||
                                                  _soloNoLeidos
                                            ? 'No hay conversaciones con este filtro'
                                            : 'Tu próxima conversación empieza aquí',
                                        textAlign: TextAlign.center,
                                        style: AppText.serif(23),
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        'Abre un perfil, un servicio o una solicitud y toca Chatear para conversar.',
                                        textAlign: TextAlign.center,
                                        style: AppText.poppins(
                                          14,
                                          color: AppColors.of(context).texto2,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }
                              final c = chats[i];
                              return Material(
                                color: AppColors.of(context).card,
                                borderRadius: BorderRadius.circular(16),
                                clipBehavior: Clip.antiAlias,
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 10,
                                  ),
                                  leading: AvatarChat(contacto: c.otro),
                                  title: Text(
                                    c.otro.nombre,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppText.poppins(
                                      15,
                                      weight: c.noLeidos > 0
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                    ),
                                  ),
                                  subtitle: Text(
                                    c.ultimoMensaje == null
                                        ? 'Saluda para comenzar'
                                        : '${c.ultimoTipo == 'sistema'
                                              ? 'Solicitud: '
                                              : c.ultimoEsMio
                                              ? 'Tú: '
                                              : ''}${c.ultimoMensaje}',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppText.poppins(
                                      12,
                                      color: AppColors.of(context).texto2,
                                    ),
                                  ),
                                  trailing: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        fechaChat(c.fecha),
                                        style: AppText.poppins(
                                          10,
                                          color: AppColors.of(context).texto2,
                                        ),
                                      ),
                                      if (c.noLeidos > 0) ...[
                                        const SizedBox(height: 5),
                                        Badge(
                                          label: Text(
                                            c.noLeidos > 99
                                                ? '99+'
                                                : '${c.noLeidos}',
                                          ),
                                          backgroundColor: AppColors.of(
                                            context,
                                          ).teal,
                                          textColor: AppColors.of(context).bg,
                                        ),
                                      ],
                                    ],
                                  ),
                                  onTap: () => Navigator.of(context).pushNamed(
                                    '/chat',
                                    arguments: DestinoChat(
                                      idChat: c.id,
                                      contacto: c.otro,
                                    ),
                                  ),
                                ),
                              );
                            },
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
