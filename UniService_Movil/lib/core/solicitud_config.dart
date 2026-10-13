import 'categorias.dart' show normalizar;

/// Port de CONFIGURACION_FORMULARIOS_SOLICITUD (shared/constantes.js):
/// los campos del formulario de solicitud cambian según la categoría.
enum TipoCampo { textarea, date, time, number, select, file }

class CampoSolicitud {
  final String nombre;
  final TipoCampo tipo;
  final bool obligatorio;
  final String label;
  final String? placeholder;
  final List<String> opciones;
  const CampoSolicitud(
    this.nombre,
    this.tipo,
    this.label, {
    this.obligatorio = false,
    this.placeholder,
    this.opciones = const [],
  });
}

class ConfigSolicitud {
  final String titulo;
  final List<CampoSolicitud> campos;
  const ConfigSolicitud(this.titulo, this.campos);
}

const _archivo = TipoCampo.file;

const Map<String, ConfigSolicitud> _config = {
  'tutorias': ConfigSolicitud('Solicitar Tutoría', [
    CampoSolicitud('descripcion', TipoCampo.textarea, '¿Qué tema necesitas?',
        obligatorio: true, placeholder: 'Ej: Necesito ayuda con derivadas parciales...'),
    CampoSolicitud('fecha_deseada', TipoCampo.date, 'Fecha preferida', obligatorio: true),
    CampoSolicitud('hora_deseada', TipoCampo.time, 'Hora preferida', obligatorio: true),
    CampoSolicitud('presupuesto', TipoCampo.number, 'Presupuesto (COP)',
        obligatorio: true, placeholder: 'Ej: 50000'),
    CampoSolicitud('archivo', _archivo, 'Adjuntar documento (opcional)'),
  ]),
  'ensayos': ConfigSolicitud('Solicitar Ensayo', [
    CampoSolicitud('descripcion', TipoCampo.textarea, 'Tema del ensayo',
        obligatorio: true, placeholder: 'Describe el tema y requisitos...'),
    CampoSolicitud('fecha_deseada', TipoCampo.date, 'Fecha de entrega', obligatorio: true),
    CampoSolicitud('presupuesto', TipoCampo.number, 'Presupuesto (COP)',
        obligatorio: true, placeholder: 'Ej: 80000'),
    CampoSolicitud('cantidad_paginas', TipoCampo.select, 'Cantidad de páginas',
        placeholder: 'Selecciona',
        opciones: ['1-3 páginas', '4-6 páginas', '7-10 páginas', 'Más de 10']),
    CampoSolicitud('archivo', _archivo, 'Instrucciones o guía (opcional)'),
  ]),
  'proyectos': ConfigSolicitud('Solicitar Proyecto', [
    CampoSolicitud('descripcion', TipoCampo.textarea, 'Describe el proyecto',
        obligatorio: true, placeholder: '¿Qué necesitas?'),
    CampoSolicitud('fecha_deseada', TipoCampo.date, 'Fecha de entrega', obligatorio: true),
    CampoSolicitud('presupuesto', TipoCampo.number, 'Presupuesto (COP)',
        obligatorio: true, placeholder: 'Ej: 150000'),
    CampoSolicitud('archivo', _archivo, 'Requisitos del proyecto (opcional)'),
  ]),
  'programacion': ConfigSolicitud('Solicitar Programación', [
    CampoSolicitud('descripcion', TipoCampo.textarea, '¿Qué necesitas programar?',
        obligatorio: true, placeholder: 'Describe el proyecto o funcionalidad...'),
    CampoSolicitud('fecha_deseada', TipoCampo.date, 'Fecha de entrega', obligatorio: true),
    CampoSolicitud('presupuesto', TipoCampo.number, 'Presupuesto (COP)',
        obligatorio: true, placeholder: 'Ej: 200000'),
    CampoSolicitud('lenguaje', TipoCampo.select, 'Lenguaje preferido',
        placeholder: 'Selecciona',
        opciones: ['Python', 'JavaScript', 'Java', 'C#', 'C++', 'Otro']),
    CampoSolicitud('archivo', _archivo, 'Documentación o enunciado (opcional)'),
  ]),
  'diseno': ConfigSolicitud('Solicitar Diseño', [
    CampoSolicitud('descripcion', TipoCampo.textarea, 'Describe el diseño que necesitas',
        obligatorio: true, placeholder: 'Logo, banner, presentación...'),
    CampoSolicitud('fecha_deseada', TipoCampo.date, 'Fecha de entrega', obligatorio: true),
    CampoSolicitud('presupuesto', TipoCampo.number, 'Presupuesto (COP)',
        obligatorio: true, placeholder: 'Ej: 100000'),
    CampoSolicitud('archivo', _archivo, 'Referencias o brief (opcional)'),
  ]),
  'arriendo': ConfigSolicitud('Solicitar Arriendo', [
    CampoSolicitud('descripcion', TipoCampo.textarea, '¿Qué necesitas?',
        obligatorio: true,
        placeholder: 'Ej: Habitación cerca a la universidad con baño privado...'),
    CampoSolicitud('fecha_inicio', TipoCampo.date, 'Fecha de inicio', obligatorio: true),
    CampoSolicitud('dias_estadia', TipoCampo.select, 'Duración de estadía',
        obligatorio: true,
        placeholder: 'Selecciona',
        opciones: ['1-7 días', '1-2 semanas', '1 mes', '2-3 meses', 'Semestre completo']),
    CampoSolicitud('presupuesto', TipoCampo.number, 'Presupuesto mensual (COP)',
        obligatorio: true, placeholder: 'Ej: 500000'),
  ]),
  'otros': ConfigSolicitud('Solicitar Servicio', [
    CampoSolicitud('descripcion', TipoCampo.textarea, 'Describe lo que necesitas',
        obligatorio: true, placeholder: 'Cuéntanos...'),
    CampoSolicitud('fecha_deseada', TipoCampo.date, 'Fecha preferida (opcional)'),
    CampoSolicitud('presupuesto', TipoCampo.number, 'Presupuesto (COP)',
        obligatorio: true, placeholder: 'Ej: 50000'),
  ]),
};

/// getConfiguracionSolicitud(categoria)
ConfigSolicitud configSolicitud(String? categoria) {
  final key = normalizar(categoria)
      .replaceAll(' de habitaciones', '')
      .replaceAll(' y redaccion', '')
      .trim();
  return _config[key] ?? _config['otros']!;
}
