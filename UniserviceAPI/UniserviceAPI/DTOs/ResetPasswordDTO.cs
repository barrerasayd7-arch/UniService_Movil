namespace UniserviceAPI.DTOs;

public class ResetPasswordDTO
{
    public string correo { get; set; } = "";
    public string codigo { get; set; } = "";
    public string nuevaPassword { get; set; } = "";
}
