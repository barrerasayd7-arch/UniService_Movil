import 'servicio.dart';

/// Participante visible en GET /api/chat/mis-chats.
class ContactoChat {
  final int id;
  final String nombre;
  final String? avatar;
  final bool disponible;
  final bool enLinea;

  const ContactoChat({
    required this.id,
    required this.nombre,
    this.avatar,
    this.disponible = true,
    this.enLinea = false,
  });

  factory ContactoChat.fromJson(Map<String, dynamic> j) => ContactoChat(
    id: leerInt(j['id']),
    nombre: j['nombre'] as String? ?? 'Usuario',
    avatar: j['avatar'] as String?,
    disponible: j['disponible'] == true,
    enLinea: j['en_linea'] == true,
  );
}

class Conversacion {
  final int id;
  final ContactoChat otro;
  final String? ultimoMensaje;
  final String? ultimoTipo;
  final DateTime? fecha;
  final bool ultimoEsMio;
  final int noLeidos;

  const Conversacion({
    required this.id,
    required this.otro,
    this.ultimoMensaje,
    this.ultimoTipo,
    this.fecha,
    this.ultimoEsMio = false,
    this.noLeidos = 0,
  });

  factory Conversacion.fromJson(Map<String, dynamic> j) => Conversacion(
    id: leerInt(j['id_chat']),
    otro: ContactoChat.fromJson(j['otro'] as Map<String, dynamic>),
    ultimoMensaje: j['ultimo_mensaje'] as String?,
    ultimoTipo: j['ultimo_tipo'] as String?,
    fecha: leerFecha(j['ultimo_fecha'] ?? j['fecha_creacion']),
    ultimoEsMio: j['ultimo_es_mio'] == true,
    noLeidos: leerInt(j['no_leidos']),
  );
}

class MensajeChat {
  final int id;
  final int idChat;
  final int idRemitente;
  final String texto;
  final String tipo;
  final bool leido;
  final DateTime? fecha;

  const MensajeChat({
    required this.id,
    required this.idChat,
    required this.idRemitente,
    required this.texto,
    required this.tipo,
    required this.leido,
    this.fecha,
  });

  bool get esSistema => tipo == 'sistema';

  factory MensajeChat.fromJson(Map<String, dynamic> j) => MensajeChat(
    id: leerInt(j['id_mensaje']),
    idChat: leerInt(j['id_chat']),
    idRemitente: leerInt(j['id_remitente']),
    texto: j['mensaje'] as String? ?? '',
    tipo: j['tipo'] as String? ?? 'texto',
    leido: j['leido'] == true,
    fecha: leerFecha(j['fecha_envio']),
  );

  MensajeChat comoLeido() => MensajeChat(
    id: id,
    idChat: idChat,
    idRemitente: idRemitente,
    texto: texto,
    tipo: tipo,
    leido: true,
    fecha: fecha,
  );
}

/// Argumentos tipados de /chat. Abrir desde un perfil crea/reutiliza el chat;
/// desde la bandeja usa directamente su id, incluso si el otro fue suspendido.
class DestinoChat {
  final int? idChat;
  final ContactoChat contacto;
  const DestinoChat({this.idChat, required this.contacto});
}
