using System.ComponentModel.DataAnnotations;

public class RegisterDTO
{
    [Required(ErrorMessage = "El correo es requerido")]
    [EmailAddress(ErrorMessage = "El correo no es válido")]
    [StringLength(100, ErrorMessage = "El correo no puede exceder 100 caracteres")]
    public string correo { get; set; }

    [Required(ErrorMessage = "La contraseña es requerida")]
    [StringLength(100, MinimumLength = 8, ErrorMessage = "La contraseña debe tener al menos 8 caracteres")]
    public string password { get; set; }

    [Required(ErrorMessage = "El nombre es requerido")]
    [StringLength(50, MinimumLength = 2, ErrorMessage = "El nombre debe tener entre 2 y 50 caracteres")]
    public string nombre { get; set; }

    [Required(ErrorMessage = "El código de verificación es requerido")]
    public string codigo { get; set; }
}
