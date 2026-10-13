using System.ComponentModel.DataAnnotations;

namespace UniserviceAPI.DTOs;

public sealed record AdminMotivoRequest(
    [Required(ErrorMessage = "Indica el motivo"), StringLength(500, MinimumLength = 5, ErrorMessage = "El motivo debe tener entre 5 y 500 caracteres")]
    string motivo);

public sealed record AdminRechazoRequest([StringLength(500)] string? razon);

public sealed record AdminReporteRequest(
    [Required, RegularExpression("^(Pendiente|En_revision|Resuelto|Rechazado|Cerrado)$", ErrorMessage = "Estado no válido")]
    string estado,
    [StringLength(2000)] string? resolucion_notas);
