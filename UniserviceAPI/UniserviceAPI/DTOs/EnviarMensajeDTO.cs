namespace UniserviceAPI.DTOs;

public class EnviarMensajeDTO
{
    public int id_chat { get; set; }
    public int id_remitente { get; set; }
    public int id_destinatario { get; set; }
    public string mensaje { get; set; } = string.Empty;
    public string tipo { get; set; } = "texto";
}
