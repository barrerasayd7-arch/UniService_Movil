using System;
using System.Collections.Generic;
using System.Text.Json;
using System.ComponentModel.DataAnnotations;

public class CrearSolicitudDTO
{
    [Required]
    [Range(1, int.MaxValue)]
    public int id_cliente { get; set; }

    [Required]
    [Range(1, int.MaxValue)]
    public int id_proveedor { get; set; }

    [Required]
    [Range(1, int.MaxValue)]
    public int id_servicio { get; set; }

    public string? tipo_servicio { get; set; }
    public string? tema { get; set; }

    [StringLength(2000, ErrorMessage = "La descripción no puede exceder 2000 caracteres")]
    public string? descripcion { get; set; }

    public DateTime? fecha_deseada { get; set; }
    public string? hora_deseada { get; set; }

    public string? duracion { get; set; }
    public string? modalidad { get; set; }
    public string? metodo_pago { get; set; }

    [Range(0, 99999999, ErrorMessage = "El presupuesto debe ser válido")]
    public decimal presupuesto { get; set; }

    public bool pago_anticipado { get; set; }

    [StringLength(50, ErrorMessage = "La urgencia no puede exceder 50 caracteres")]
    public string? urgencia { get; set; }

    [StringLength(500, ErrorMessage = "La ruta del archivo no puede exceder 500 caracteres")]
    public string? archivo { get; set; }
    
    public string? campos_personalizados { get; set; }
}

public class ResponderSolicitudDTO
{
    [Required]
    [Range(1, int.MaxValue)]
    public int id_solicitud { get; set; }

    [Required]
    [RegularExpression("^(aceptar|rechazar)$", ErrorMessage = "La acción debe ser 'aceptar' o 'rechazar'")]
    public string? accion { get; set; }

    [StringLength(1000, ErrorMessage = "El motivo no puede exceder 1000 caracteres")]
    public string? motivo_rechazo { get; set; }

    [Range(0, 99999999, ErrorMessage = "La contraoferta debe ser válida")]
    public decimal? contraoferta { get; set; }
}

public class CompletarSolicitudDTO
{
    [Required]
    [Range(1, int.MaxValue)]
    public int id_solicitud { get; set; }
}
