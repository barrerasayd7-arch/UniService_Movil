using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.SignalR;
using Npgsql;
using UniserviceAPI.DTOs;
using UniserviceAPI.Hubs;

namespace UniserviceAPI.Controllers;

[ApiController]
[Route("api/chat")]
public class ChatController : ControllerBase
{
    private readonly IConfiguration _config;
    private readonly IHubContext<ChatHub> _hubContext;

    public ChatController(IConfiguration config, IHubContext<ChatHub> hubContext)
    {
        _config = config;
        _hubContext = hubContext;
    }

    // Obtener o crear un chat entre dos usuarios
    [HttpPost("iniciar")]
    public async Task<IActionResult> IniciarChat([FromBody] CrearChatDTO dto)
    {
        if (dto.id_usuario1 == dto.id_usuario2)
            return BadRequest(new { error = "No puedes chatear contigo mismo" });

        int u1 = Math.Min(dto.id_usuario1, dto.id_usuario2);
        int u2 = Math.Max(dto.id_usuario1, dto.id_usuario2);

        using var conn = new NpgsqlConnection(_config.GetConnectionString("DefaultConnection"));
        await conn.OpenAsync();

        var check = new NpgsqlCommand("SELECT id_chat FROM chats WHERE id_usuario1 = @u1 AND id_usuario2 = @u2", conn);
        check.Parameters.AddWithValue("@u1", u1);
        check.Parameters.AddWithValue("@u2", u2);
        var result = await check.ExecuteScalarAsync();

        if (result != null)
            return Ok(new { id_chat = Convert.ToInt32(result) });

        var insert = new NpgsqlCommand("INSERT INTO chats (id_usuario1, id_usuario2) VALUES (@u1, @u2) RETURNING id_chat", conn);
        insert.Parameters.AddWithValue("@u1", u1);
        insert.Parameters.AddWithValue("@u2", u2);
        var newId = await insert.ExecuteScalarAsync();

        return Ok(new { id_chat = Convert.ToInt32(newId) });
    }

    // Lista de chats de un usuario con info del otro usuario y último mensaje
    [HttpGet("mis-chats/{idUsuario}")]
    public async Task<IActionResult> MisChats(int idUsuario)
    {
        using var conn = new NpgsqlConnection(_config.GetConnectionString("DefaultConnection"));
        await conn.OpenAsync();

        var cmd = new NpgsqlCommand(@"
            SELECT 
                c.id_chat,
                c.ultimo_mensaje,
                c.fecha_creacion,
                u.id_usuario AS id_otro_usuario,
                u.nombre AS nombre_otro,
                u.avatar AS avatar_otro,
                u.ultima_actividad,
                (SELECT COUNT(*) FROM mensajes m WHERE m.id_chat = c.id_chat AND m.id_destinatario = @id AND m.leido = false) AS no_leidos,
                (SELECT mensaje FROM mensajes m2 WHERE m2.id_chat = c.id_chat ORDER BY m2.fecha_envio DESC LIMIT 1) AS ultimo_mensaje_texto,
                (SELECT fecha_envio FROM mensajes m3 WHERE m3.id_chat = c.id_chat ORDER BY m3.fecha_envio DESC LIMIT 1) AS ultimo_mensaje_fecha
            FROM chats c
            JOIN usuarios u ON (CASE WHEN c.id_usuario1 = @id THEN c.id_usuario2 ELSE c.id_usuario1 END) = u.id_usuario
            WHERE c.id_usuario1 = @id OR c.id_usuario2 = @id
            ORDER BY c.ultimo_mensaje DESC NULLS LAST, c.fecha_creacion DESC", conn);
        cmd.Parameters.AddWithValue("@id", idUsuario);

        var chats = new List<object>();
        using var reader = await cmd.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            var ultimaActividad = reader["ultima_actividad"] as DateTime?;
            var enLinea = ultimaActividad.HasValue && (DateTime.UtcNow - ultimaActividad.Value).TotalMinutes < 2;

            chats.Add(new
            {
                id_chat = reader["id_chat"],
                id_otro_usuario = reader["id_otro_usuario"],
                nombre_otro = reader["nombre_otro"].ToString(),
                avatar_otro = reader["avatar_otro"].ToString(),
                en_linea = enLinea,
                ultima_actividad = ultimaActividad,
                no_leidos = Convert.ToInt32(reader["no_leidos"]),
                ultimo_mensaje_texto = reader["ultimo_mensaje_texto"]?.ToString(),
                ultimo_mensaje_fecha = reader["ultimo_mensaje_fecha"] as DateTime?,
                fecha_creacion = reader["fecha_creacion"]
            });
        }

        return Ok(chats);
    }

    // Historial de mensajes de un chat
    [HttpGet("{idChat}/mensajes")]
    public async Task<IActionResult> GetMensajes(int idChat)
    {
        using var conn = new NpgsqlConnection(_config.GetConnectionString("DefaultConnection"));
        await conn.OpenAsync();

        var cmd = new NpgsqlCommand(@"
            SELECT m.*, u.nombre AS nombre_remitente, u.avatar AS avatar_remitente
            FROM mensajes m
            JOIN usuarios u ON m.id_remitente = u.id_usuario
            WHERE m.id_chat = @idChat
            ORDER BY m.fecha_envio ASC", conn);
        cmd.Parameters.AddWithValue("@idChat", idChat);

        var mensajes = new List<object>();
        using var reader = await cmd.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            mensajes.Add(new
            {
                id_mensaje = reader["id_mensaje"],
                id_chat = reader["id_chat"],
                id_remitente = reader["id_remitente"],
                id_destinatario = reader["id_destinatario"],
                mensaje = reader["mensaje"].ToString(),
                fecha_envio = reader["fecha_envio"],
                leido = reader["leido"],
                tipo = reader["tipo"].ToString(),
                nombre_remitente = reader["nombre_remitente"].ToString(),
                avatar_remitente = reader["avatar_remitente"].ToString()
            });
        }

        return Ok(mensajes);
    }

    // Enviar un mensaje
    [HttpPost("mensaje")]
    public async Task<IActionResult> EnviarMensaje([FromBody] EnviarMensajeDTO dto)
    {
        if (string.IsNullOrWhiteSpace(dto.mensaje))
            return BadRequest(new { error = "El mensaje no puede estar vacío" });

        using var conn = new NpgsqlConnection(_config.GetConnectionString("DefaultConnection"));
        await conn.OpenAsync();

        var cmd = new NpgsqlCommand(@"
            INSERT INTO mensajes (id_chat, id_remitente, id_destinatario, mensaje, tipo)
            VALUES (@chat, @rem, @dest, @msg, @tipo)
            RETURNING id_mensaje", conn);
        cmd.Parameters.AddWithValue("@chat", dto.id_chat);
        cmd.Parameters.AddWithValue("@rem", dto.id_remitente);
        cmd.Parameters.AddWithValue("@dest", dto.id_destinatario);
        cmd.Parameters.AddWithValue("@msg", dto.mensaje);
        cmd.Parameters.AddWithValue("@tipo", dto.tipo);

        var idMensaje = await cmd.ExecuteScalarAsync();

        var updateChat = new NpgsqlCommand("UPDATE chats SET ultimo_mensaje = NOW() WHERE id_chat = @chat", conn);
        updateChat.Parameters.AddWithValue("@chat", dto.id_chat);
        await updateChat.ExecuteNonQueryAsync();

        var getNombre = new NpgsqlCommand("SELECT nombre FROM usuarios WHERE id_usuario = @id", conn);
        getNombre.Parameters.AddWithValue("@id", dto.id_remitente);
        var nombreRemitente = (string)(await getNombre.ExecuteScalarAsync() ?? "");

        var mensajeData = new
        {
            id_mensaje = Convert.ToInt32(idMensaje),
            id_chat = dto.id_chat,
            id_remitente = dto.id_remitente,
            id_destinatario = dto.id_destinatario,
            mensaje = dto.mensaje,
            tipo = dto.tipo,
            fecha_envio = DateTime.UtcNow.ToString("o"),
            leido = false,
            nombre_remitente = nombreRemitente
        };

        await _hubContext.Clients.All.SendAsync("RecibirMensaje", mensajeData);

        Console.WriteLine($"[Chat] Mensaje insertado: chat={dto.id_chat}, remitente={dto.id_remitente}, destinatario={dto.id_destinatario}");
        return Ok(new { id_mensaje = Convert.ToInt32(idMensaje), fecha_envio = DateTime.UtcNow });
    }

    // Marcar mensajes como leídos
    [HttpPut("mensajes/{idChat}/leido")]
    public async Task<IActionResult> MarcarLeido(int idChat, [FromBody] MarcarLeidoDTO dto)
    {
        using var conn = new NpgsqlConnection(_config.GetConnectionString("DefaultConnection"));
        await conn.OpenAsync();

        var cmd = new NpgsqlCommand(
            "UPDATE mensajes SET leido = true WHERE id_chat = @chat AND id_destinatario = @dest AND leido = false", conn);
        cmd.Parameters.AddWithValue("@chat", idChat);
        cmd.Parameters.AddWithValue("@dest", dto.id_destinatario);

        var afectados = await cmd.ExecuteNonQueryAsync();
        Console.WriteLine($"[Chat] Marcados como leídos: {afectados} mensajes en chat {idChat} para usuario {dto.id_destinatario}");
        return Ok(new { marcados = afectados });
    }

    // Cantidad de mensajes no leídos de un usuario
    [HttpGet("no-leidos/{idUsuario}")]
    public async Task<IActionResult> NoLeidos(int idUsuario)
    {
        using var conn = new NpgsqlConnection(_config.GetConnectionString("DefaultConnection"));
        await conn.OpenAsync();

        var cmd = new NpgsqlCommand(
            "SELECT COUNT(*) FROM mensajes WHERE id_destinatario = @id AND leido = false", conn);
        cmd.Parameters.AddWithValue("@id", idUsuario);

        var count = Convert.ToInt32(await cmd.ExecuteScalarAsync());
        Console.WriteLine($"[Chat] No leídos para usuario {idUsuario}: {count}");
        return Ok(new { no_leidos = count });
    }

    // Actualizar ultima_actividad del usuario
    [HttpPut("actividad/{idUsuario}")]
    public async Task<IActionResult> ActualizarActividad(int idUsuario)
    {
        using var conn = new NpgsqlConnection(_config.GetConnectionString("DefaultConnection"));
        await conn.OpenAsync();

        var cmd = new NpgsqlCommand(
            "UPDATE usuarios SET ultima_actividad = NOW() WHERE id_usuario = @id", conn);
        cmd.Parameters.AddWithValue("@id", idUsuario);
        await cmd.ExecuteNonQueryAsync();

        return Ok(new { ok = true });
    }
}

// DTO simple para marcar como leído
public class MarcarLeidoDTO
{
    public int id_destinatario { get; set; }
}
