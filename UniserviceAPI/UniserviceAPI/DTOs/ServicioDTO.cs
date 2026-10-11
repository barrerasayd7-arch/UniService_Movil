using System.ComponentModel.DataAnnotations;

public class ServicioDTO
{
    [Required(ErrorMessage = "El id_proveedor es requerido")]
    [Range(1, int.MaxValue, ErrorMessage = "El id_proveedor debe ser válido")]
    public int id_proveedor { get; set; }

    [Required(ErrorMessage = "El título es requerido")]
    [StringLength(100, MinimumLength = 3, ErrorMessage = "El título debe tener entre 3 y 100 caracteres")]
    public string titulo { get; set; }

    [Required(ErrorMessage = "La descripción es requerida")]
    [StringLength(2000, MinimumLength = 10, ErrorMessage = "La descripción debe tener entre 10 y 2000 caracteres")]
    public string descripcion { get; set; }

    [Required(ErrorMessage = "La categoría es requerida")]
    [Range(1, 20, ErrorMessage = "La categoría debe ser válida")]
    public int id_categoria { get; set; }

    [Required(ErrorMessage = "El precio es requerido")]
    [Range(1000, 99999999, ErrorMessage = "El precio debe ser entre $1,000 y $99,999,999")]
    public decimal precio_hora { get; set; }

    [StringLength(150, ErrorMessage = "El contacto no puede exceder 150 caracteres")]
    public string contacto { get; set; }

    [Range(0, 2, ErrorMessage = "La modalidad debe ser 0 (Presencial), 1 (Virtual) o 2 (Mixta)")]
    public int modalidad { get; set; }

    public string icono { get; set; }

    [Range(0, 2, ErrorMessage = "La disponibilidad debe ser 0, 1 o 2")]
    public int disponibilidad { get; set; }
    
    // Google Maps - solo para categoría Arriendo
    [Range(-90, 90, ErrorMessage = "Latitud inválida")]
    public decimal? ubicacion_lat { get; set; }
    
    [Range(-180, 180, ErrorMessage = "Longitud inválida")]
    public decimal? ubicacion_lng { get; set; }
    
    [StringLength(500, ErrorMessage = "La dirección no puede exceder 500 caracteres")]
    public string? direccion { get; set; }
}

public class EditarServicioDTO
{
    [Required(ErrorMessage = "El id_proveedor es requerido")]
    [Range(1, int.MaxValue, ErrorMessage = "El id_proveedor debe ser válido")]
    public int id_proveedor { get; set; }

    [Required(ErrorMessage = "El título es requerido")]
    [StringLength(100, MinimumLength = 3, ErrorMessage = "El título debe tener entre 3 y 100 caracteres")]
    public string titulo { get; set; }

    [Required(ErrorMessage = "La descripción es requerida")]
    [StringLength(2000, MinimumLength = 10, ErrorMessage = "La descripción debe tener entre 10 y 2000 caracteres")]
    public string descripcion { get; set; }

    [Required(ErrorMessage = "El precio es requerido")]
    [Range(1000, 99999999, ErrorMessage = "El precio debe ser entre $1,000 y $99,999,999")]
    public decimal precio_hora { get; set; }

    [StringLength(150, ErrorMessage = "El contacto no puede exceder 150 caracteres")]
    public string contacto { get; set; }

    public string icono { get; set; }
    
    [Range(-90, 90, ErrorMessage = "Latitud inválida")]
    public decimal? ubicacion_lat { get; set; }
    
    [Range(-180, 180, ErrorMessage = "Longitud inválida")]
    public decimal? ubicacion_lng { get; set; }
    
    [StringLength(500, ErrorMessage = "La dirección no puede exceder 500 caracteres")]
    public string? direccion { get; set; }
}
