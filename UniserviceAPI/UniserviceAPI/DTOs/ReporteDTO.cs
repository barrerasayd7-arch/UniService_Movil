public class CrearReporteDTO
{
    public int id_usuario { get; set; }
    public int? id_servicio { get; set; }
    public int? id_solicitud { get; set; }
    public int? id_usuario_reportado { get; set; }
    public string tipo_reporte { get; set; } = "";
    public string titulo { get; set; } = "";
    public string descripcion { get; set; } = "";
    public string? evidencia { get; set; }
}

public class ActualizarReporteDTO
{
    public string estado { get; set; } = "";
    public string? resolucion_notas { get; set; }
    public int id_admin { get; set; }
}