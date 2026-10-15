import 'package:flutter_test/flutter_test.dart';
import 'package:app_uniservice/models/usuario.dart';

// Formato real de GET /api/perfil/me y GET /api/perfil/{id} (ver PerfilController).
void main() {
  test('Mi perfil trae correo, teléfono y estadísticas', () {
    final u = Usuario.fromJson({
      'id': 20,
      'nombre': 'Pedro Perfil',
      'descripcion': null,
      'avatar': 'https://x.supabase.co/storage/v1/object/public/imagenes-servicios/avatares/20/a.jpg',
      'universidad': 'Universidad Popular del Cesar',
      'fecha_registro': '2026-09-01T10:00:00Z',
      'correo': 'pedro@unicesar.edu.co',
      'telefono': '3001112233',
      'id_rol': 2,
      'correo_verificado': true,
      'perfil_academico': {'programa': 'Sistemas', 'semestre': 6, 'sede': '', 'disponibilidad': '', 'portafolio_url': null},
      'estadisticas': {'seguidores': 1200, 'siguiendo': 3, 'servicios': 2, 'calificacion_promedio': 4.5, 'total_calificaciones': 8},
      'habilidades': [],
    });
    expect(u.correo, 'pedro@unicesar.edu.co');
    expect(u.telefono, '3001112233');
    expect(u.descripcion, '');
    expect(u.semestre, 6);
    expect(formatearNumero(u.totalSeguidores), '1.2k');
    expect(u.reputacionTexto, '4.5/5.0 (8)');
  });

  test('El perfil público no trae datos de contacto', () {
    final u = Usuario.fromJson({
      'id': 21,
      'nombre': 'Laura Perfil',
      'avatar': null,
      'universidad': 'Universidad Popular del Cesar',
      'fecha_registro': '2026-09-01T10:00:00Z',
      'perfil_academico': {'programa': '', 'semestre': null, 'sede': '', 'disponibilidad': '', 'portafolio_url': null},
      'estadisticas': {'seguidores': 0, 'siguiendo': 0, 'servicios': 0, 'calificacion_promedio': null, 'total_calificaciones': 0},
      'es_mio': false,
      'lo_sigo': true,
      'habilidades': [],
    });
    expect(u.correo, isNull);
    expect(u.telefono, isNull);
    expect(u.loSigo, isTrue);
    expect(u.reputacionTexto, 'Sin calificaciones');
    final dejado = u.copyWith(loSigo: false, totalSeguidores: 0);
    expect(dejado.loSigo, isFalse);
  });
}
