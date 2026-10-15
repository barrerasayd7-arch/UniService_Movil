import 'package:flutter_test/flutter_test.dart';

import 'package:app_uniservice/data/servicios_repository.dart';
import 'package:app_uniservice/data/solicitudes_repository.dart';
import 'package:app_uniservice/models/mi_servicio.dart';
import 'package:app_uniservice/models/servicio.dart';
import 'package:app_uniservice/models/servicio_detalle.dart';
import 'package:app_uniservice/models/solicitud.dart';
import 'package:app_uniservice/screens/service_detail/detail_screen.dart'
    show numeroWhatsApp;

import 'fakes/api_falsa.dart';

void main() {
  test('Servicio.fromJson lee decimales, unidad y portada', () {
    final s = Servicio.fromJson(
      filaServicio(
        5,
        'Habitación',
        categoria: 6,
        nombreCategoria: 'Arriendo de habitaciones',
        precio: 650000.00,
        resenas: 2,
        promedio: 4.5,
        imagen: 'https://ejemplo.test/a.jpg',
      ),
    );
    expect(s.id, 5);
    expect(s.precio, 650000);
    expect(s.unidadPrecio, 'mes');
    expect(s.estrellas, 4.5);
    expect(s.numResenas, 2);
    expect(s.imagenUrl, 'https://ejemplo.test/a.jpg');
    expect(s.fechaPublicacion.isUtc, isFalse); // se muestra en hora local
  });

  test('PaginaServicios sabe si hay más páginas', () {
    final p = PaginaServicios.fromJson({
      'servicios': [filaServicio(1, 'A')],
      'pagina': 1,
      'por_pagina': 1,
      'total': 2,
      'total_paginas': 2,
    });
    expect(p.servicios, hasLength(1));
    expect(p.hayMas, isTrue);
  });

  test('ServicioDetalle.fromJson para invitado: sin contacto, con estadísticas', () {
    final d = ServicioDetalle.fromJson(detalleInvitado());
    expect(d.servicio.titulo, 'Pensión cerca de la UPC');
    expect(d.servicio.precio, 450000);
    expect(d.contacto, isNull);
    expect(d.tieneUbicacion, isTrue);
    expect(d.lat, isNull);
    expect(d.esArriendo, isTrue);
    expect(d.numResenas, 3);
    expect(d.promedio, 4.67);
    expect(d.proveedor.nombre, 'Said');
    expect(d.proveedor.serviciosPublicados, 1);
    expect(d.imagenes.single.id, 131);
    expect(d.servicio.imagenUrl, 'https://ejemplo.test/69/1.jpg');
    expect(d.resenas.single.editada, isTrue);
    expect(d.resenas.single.estrellas, 4);
  });

  test('MiServicio.fromJson y acciones según el estado', () {
    final m = MiServicio.fromJson({
      'id_servicio': 7,
      'titulo': 'Clases',
      'estado': 'pausado',
      'motivo_rechazo': null,
      'precio': 25000.00,
      'unidad_precio': 'hora',
      'categoria': 'Tutorías',
      'fecha_publicacion': '2026-10-01T10:00:00Z',
      'imagen': null,
      'num_imagenes': 0,
      'num_resenas': 0,
      'promedio': 0,
      'solicitudes_pendientes': 2,
    });
    expect(m.precio, 25000);
    expect(m.puedeReanudar, isTrue);
    expect(m.puedePausar, isFalse);
    expect(m.solicitudesPendientes, 2);
  });

  test('Solicitud.fromJson: rol, acciones permitidas y campos', () {
    Map<String, dynamic> fila(String estado, String rol) => {
      'id_solicitud': 40,
      'estado': estado,
      'rol': rol,
      'descripcion': 'Necesito repasar dinámica',
      'presupuesto': 40000.00,
      'contraoferta': null,
      'motivo_rechazo': null,
      'fecha_deseada': '2026-11-20',
      'hora_deseada': '14:30',
      'campos': {'cantidad_paginas': '4-6 páginas'},
      'fecha_creacion': '2026-10-14T15:00:00Z',
      'fecha_actualizacion': null,
      'servicio': {
        'id_servicio': 10,
        'titulo': 'Física',
        'categoria': 'Tutorías',
        'imagen': null,
      },
      'cliente': {'id_usuario': 1, 'nombre': 'Ana', 'avatar': null},
      'proveedor': {'id_usuario': 2, 'nombre': 'Luis', 'avatar': null},
      'puede_calificar': estado == 'Completada' && rol == 'cliente',
      'id_calificacion': null,
    };

    final recibida = Solicitud.fromJson(fila('Pendiente', 'proveedor'));
    expect(recibida.presupuesto, 40000);
    expect(recibida.fechaDeseada, DateTime(2026, 11, 20));
    expect(recibida.campos['cantidad_paginas'], '4-6 páginas');
    expect(recibida.contraparte.nombre, 'Ana');
    expect(recibida.puedeAceptar && recibida.puedeRechazar, isTrue);
    expect(recibida.puedeCancelar, isFalse);

    final enviada = Solicitud.fromJson(fila('Aceptada', 'cliente'));
    expect(enviada.puedeCancelar, isTrue);
    expect(enviada.puedeCompletar, isFalse);

    final completada = Solicitud.fromJson(fila('Completada', 'cliente'));
    expect(completada.puedeCalificar, isTrue);
    expect(completada.activa, isFalse);
  });

  test('DatosServicio.toJson recorta textos y omite la dirección vacía', () {
    const d = DatosServicio(
      titulo: '  Clases de física ',
      descripcion: 'Cinemática y dinámica con talleres tipo parcial.',
      idCategoria: 1,
      precio: 25000,
      unidadPrecio: 'hora',
      modalidad: 'virtual',
      disponibilidad: 'fines_de_semana',
      contacto: ' 3001234567 ',
      direccion: '   ',
    );
    final j = d.toJson();
    expect(j['titulo'], 'Clases de física');
    expect(j['contacto'], '3001234567');
    expect(j['direccion'], isNull);
  });

  test('fechaIso da la fecha sin hora que espera la API', () {
    expect(fechaIso(DateTime(2026, 3, 5, 18, 40)), '2026-03-05');
  });

  test('numeroWhatsApp agrega el indicativo de Colombia', () {
    expect(numeroWhatsApp('300 123 4567'), '573001234567');
    expect(numeroWhatsApp('+57 300-123-4567'), '573001234567');
    expect(numeroWhatsApp('12345'), isNull);
  });

  test('textoUniversidad trata "Sin universidad" como independiente', () {
    expect(textoUniversidad('Sin universidad'), 'Independiente');
    expect(textoUniversidad(null), 'Comunidad académica');
    expect(textoUniversidad('UPC'), 'UPC');
  });
}
