using System.ComponentModel.DataAnnotations;

public class CalificacionDTO
{
    public int id_calificacion { get; set; }

    [Required]
    [Range(1, int.MaxValue)]
    public int id_solicitud { get; set; }

    [Required]
    [Range(1, int.MaxValue)]
    public int id_cliente { get; set; }

    [Required]
    [Range(1, int.MaxValue)]
    public int id_servicio { get; set; }

    [Required]
    [Range(1, 5, ErrorMessage = "La puntuación debe ser entre 1 y 5")]
    public byte puntuacion { get; set; }

    [StringLength(1000, ErrorMessage = "El comentario no puede exceder 1000 caracteres")]
    public string? comentario { get; set; }
}
