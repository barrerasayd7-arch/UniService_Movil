using Microsoft.AspNetCore.Mvc;
using Npgsql;
using Microsoft.Extensions.Configuration;
using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using System.Text.Json;
using UniserviceAPI.Services;
using UniserviceAPI.Hubs;
using Microsoft.AspNetCore.SignalR;

[ApiController]
[Route("api/[controller]")]
public class SolicitudesController : ControllerBase
{
    private readonly IConfiguration _config;
    private readonly EmailService _emailService;
    private readonly IHubContext<ChatHub> _chatHub;

    public SolicitudesController(IConfiguration config, EmailService emailService, IHubContext<ChatHub> chatHub)
    {
        _config = config;
        _emailService = emailService;
        _chatHub = chatHub;
    }

    // 🔹 CREAR SOLICITUD
    [HttpPost]
    public async Task<IActionResult> CrearSolicitud([FromBody] CrearSolicitudDTO dto)
    {
        try
        {
            using var conn = new NpgsqlConnection(_config.GetConnectionString("DefaultConnection"));
            await conn.OpenAsync();

            if (dto.id_cliente == dto.id_proveedor)
                return BadRequest(new { error = "No puedes solicitar tu propio servicio." });

            using var checkCmd = new NpgsqlCommand(@"
                SELECT COUNT(*) FROM solicitudes
                WHERE id_cliente = @id_cliente AND id_servicio = @id_servicio AND estado = 'Pendiente'
            ", conn);
            checkCmd.Parameters.AddWithValue("@id_cliente", dto.id_cliente);
            checkCmd.Parameters.AddWithValue("@id_servicio", dto.id_servicio);
            int pendientes = Convert.ToInt32(await checkCmd.ExecuteScalarAsync());
            if (pendientes > 0)
                return BadRequest(new { error = "Ya tienes una solicitud pendiente para este servicio." });

            // Obtener categoría del servicio para validación
            string categoria = "";
            using var catCmd = new NpgsqlCommand(@"
                SELECT c.nombre_categoria FROM servicios s
                LEFT JOIN categorias c ON s.id_categoria = c.id_categoria
                WHERE s.id_servicio = @id_servicio
            ", conn);
            catCmd.Parameters.AddWithValue("@id_servicio", dto.id_servicio);
            var catResult = await catCmd.ExecuteScalarAsync();
            categoria = catResult?.ToString()?.ToLower() ?? "";

            
            // Validar campos obligatorios según categoría
            var camposRequeridos = GetCamposRequeridosPorCategoria(categoria);
            foreach (var campo in camposRequeridos)
            {
                if (campo == "descripcion")
                {
                    if (string.IsNullOrEmpty(dto.descripcion))
                        return BadRequest(new { error = $"El campo 'descripción' es obligatorio." });
                }
                else if (campo == "presupuesto")
                {
                    if (dto.presupuesto <= 0)
                        return BadRequest(new { error = $"El campo 'presupuesto' es obligatorio y debe ser mayor a 0." });
                }
            }

            // Serializar campos personalizados a JSONB
            string camposJson = dto.campos_personalizados ?? "{}";

            using var insertCmd = new NpgsqlCommand(@"
                INSERT INTO solicitudes (
                    id_cliente, id_proveedor, id_servicio, fue_aceptada,
                    tipo_servicio, tema, descripcion,
                    fecha_deseada, hora_deseada, duracion, modalidad,
                    metodo_pago, presupuesto, pago_anticipado,
                    urgencia, archivo, estado, campos_personalizados
                ) VALUES (
                    @id_cliente, @id_proveedor, @id_servicio, FALSE,
                    @tipo_servicio, @tema, @descripcion,
                    @fecha_deseada, @hora_deseada, @duracion, @modalidad,
                    @metodo_pago, @presupuesto, @pago_anticipado,
                    @urgencia, @archivo, 'Pendiente', @campos_personalizados::jsonb
                )
                RETURNING id_solicitud
            ", conn);

            insertCmd.Parameters.Add(new NpgsqlParameter("@id_cliente", NpgsqlTypes.NpgsqlDbType.Integer) { Value = dto.id_cliente });
            insertCmd.Parameters.Add(new NpgsqlParameter("@id_proveedor", NpgsqlTypes.NpgsqlDbType.Integer) { Value = dto.id_proveedor });
            insertCmd.Parameters.Add(new NpgsqlParameter("@id_servicio", NpgsqlTypes.NpgsqlDbType.Integer) { Value = dto.id_servicio });
            insertCmd.Parameters.Add(new NpgsqlParameter("@tipo_servicio", NpgsqlTypes.NpgsqlDbType.Varchar) { Value = (object?)dto.tipo_servicio ?? "" });
            insertCmd.Parameters.Add(new NpgsqlParameter("@tema", NpgsqlTypes.NpgsqlDbType.Varchar) { Value = (object?)dto.tema ?? "" });
            insertCmd.Parameters.Add(new NpgsqlParameter("@descripcion", NpgsqlTypes.NpgsqlDbType.Text) { Value = (object?)dto.descripcion ?? "" });
            insertCmd.Parameters.Add(new NpgsqlParameter("@fecha_deseada", NpgsqlTypes.NpgsqlDbType.Date) 
            { 
                Value = dto.fecha_deseada.HasValue ? (object)dto.fecha_deseada.Value.Date : DBNull.Value 
            });
            insertCmd.Parameters.Add(new NpgsqlParameter("@hora_deseada", NpgsqlTypes.NpgsqlDbType.Time)
            {
                Value = !string.IsNullOrEmpty(dto.hora_deseada) && TimeSpan.TryParse(dto.hora_deseada, out var horaParseada)
        ? (object)horaParseada
        : DBNull.Value
            });
            insertCmd.Parameters.Add(new NpgsqlParameter("@duracion", NpgsqlTypes.NpgsqlDbType.Varchar) { Value = (object?)dto.duracion ?? DBNull.Value });
            insertCmd.Parameters.Add(new NpgsqlParameter("@modalidad", NpgsqlTypes.NpgsqlDbType.Varchar) { Value = (object?)dto.modalidad ?? DBNull.Value });
            insertCmd.Parameters.Add(new NpgsqlParameter("@metodo_pago", NpgsqlTypes.NpgsqlDbType.Varchar) { Value = (object?)dto.metodo_pago ?? DBNull.Value });
            insertCmd.Parameters.Add(new NpgsqlParameter("@presupuesto", NpgsqlTypes.NpgsqlDbType.Numeric) { Value = dto.presupuesto });
            insertCmd.Parameters.Add(new NpgsqlParameter("@pago_anticipado", NpgsqlTypes.NpgsqlDbType.Boolean) { Value = dto.pago_anticipado });
            insertCmd.Parameters.Add(new NpgsqlParameter("@urgencia", NpgsqlTypes.NpgsqlDbType.Varchar) { Value = (object?)dto.urgencia ?? DBNull.Value });
            insertCmd.Parameters.Add(new NpgsqlParameter("@archivo", NpgsqlTypes.NpgsqlDbType.Varchar)
            {
                Value = string.IsNullOrEmpty(dto.archivo) ? DBNull.Value : (object)dto.archivo
            });
            insertCmd.Parameters.Add(new NpgsqlParameter("@campos_personalizados", NpgsqlTypes.NpgsqlDbType.Jsonb) { Value = camposJson });

            var idSolicitud = await insertCmd.ExecuteScalarAsync();

            // Obtener datos para el mensaje del chat
            string nombreCliente = null, tituloServicio = null, emailProveedor = null, nombreProveedor = null;
            using (var dataCmd = new NpgsqlCommand(@"
                SELECT c.nombre AS nombre_cliente, se.titulo AS titulo_servicio,
                       u.correo AS email_proveedor, u.nombre AS nombre_proveedor
                FROM usuarios c
                INNER JOIN servicios se ON se.id_servicio = @id_servicio
                INNER JOIN usuarios u ON u.id_usuario = @id_proveedor
                WHERE c.id_usuario = @id_cliente
            ", conn))
            {
                dataCmd.Parameters.AddWithValue("@id_cliente", dto.id_cliente);
                dataCmd.Parameters.AddWithValue("@id_proveedor", dto.id_proveedor);
                dataCmd.Parameters.AddWithValue("@id_servicio", dto.id_servicio);
                using var dataReader = await dataCmd.ExecuteReaderAsync();
                if (await dataReader.ReadAsync())
                {
                    nombreCliente = dataReader["nombre_cliente"]?.ToString();
                    tituloServicio = dataReader["titulo_servicio"]?.ToString();
                    emailProveedor = dataReader["email_proveedor"]?.ToString();
                    nombreProveedor = dataReader["nombre_proveedor"]?.ToString();
                }
                dataReader.Close();
            }

            // Crear chat automático entre cliente y proveedor si no existe
            int u1 = Math.Min(dto.id_cliente, dto.id_proveedor);
            int u2 = Math.Max(dto.id_cliente, dto.id_proveedor);
            int idChat = 0;

            using var chatCheckCmd = new NpgsqlCommand("SELECT id_chat FROM chats WHERE id_usuario1 = @u1 AND id_usuario2 = @u2", conn);
            chatCheckCmd.Parameters.AddWithValue("@u1", u1);
            chatCheckCmd.Parameters.AddWithValue("@u2", u2);
            var chatResult = await chatCheckCmd.ExecuteScalarAsync();

            if (chatResult != null)
            {
                idChat = Convert.ToInt32(chatResult);
            }
            else
            {
                using var chatInsertCmd = new NpgsqlCommand("INSERT INTO chats (id_usuario1, id_usuario2) VALUES (@u1, @u2) RETURNING id_chat", conn);
                chatInsertCmd.Parameters.AddWithValue("@u1", u1);
                chatInsertCmd.Parameters.AddWithValue("@u2", u2);
                idChat = Convert.ToInt32(await chatInsertCmd.ExecuteScalarAsync());
            }

            // Enviar mensaje automático al chat con detalles de la solicitud
            string mensajeSolicitud = $@"<b>📨 Nueva solicitud de servicio</b><br>
<b>Cliente:</b> {nombreCliente ?? "Un estudiante"}<br>
<b>Servicio:</b> {tituloServicio ?? "Servicio"}<br>
<b>Tipo:</b> {dto.tipo_servicio ?? "No especificado"}<br>
<b>Descripción:</b> {dto.descripcion ?? "Sin descripción"}<br>
<b>Presupuesto:</b> ${dto.presupuesto:N0}<br>
{(dto.fecha_deseada.HasValue ? $"<b>Fecha deseada:</b> {dto.fecha_deseada.Value:dd/MM/yyyy}<br>" : "")}
{(dto.urgencia != null ? $"<b>Urgencia:</b> {dto.urgencia}<br>" : "")}
<i>Revisa la solicitud para aceptar o responder.</i>";

            using var msgCmd = new NpgsqlCommand(@"
                INSERT INTO mensajes (id_chat, id_remitente, id_destinatario, mensaje, tipo)
                VALUES (@chat, @rem, @dest, @msg, 'sistema')
                RETURNING id_mensaje", conn);
            msgCmd.Parameters.AddWithValue("@chat", idChat);
            msgCmd.Parameters.AddWithValue("@rem", dto.id_cliente);
            msgCmd.Parameters.AddWithValue("@dest", dto.id_proveedor);
            msgCmd.Parameters.AddWithValue("@msg", mensajeSolicitud);
            await msgCmd.ExecuteScalarAsync();

            using var updateChatCmd = new NpgsqlCommand("UPDATE chats SET ultimo_mensaje = NOW() WHERE id_chat = @chat", conn);
            updateChatCmd.Parameters.AddWithValue("@chat", idChat);
            await updateChatCmd.ExecuteNonQueryAsync();

            // Notificar via SignalR
            await _chatHub.Clients.Group($"chat_{idChat}").SendAsync("RecibirMensaje", new
            {
                id_chat = idChat,
                id_remitente = dto.id_cliente,
                id_destinatario = dto.id_proveedor,
                mensaje = mensajeSolicitud,
                tipo = "sistema",
                fecha_envio = DateTime.UtcNow.ToString("o")
            });

            // Email notification
            try
            {
                if (!string.IsNullOrEmpty(emailProveedor))
                {
                    _ = Task.Run(async () =>
                    {
                        try
                        {
                            Console.WriteLine($"📧 Intentando enviar correo a: {emailProveedor}");
                            await _emailService.EnviarNotificacionSolicitud(
                                emailProveedor,
                                nombreProveedor ?? "Proveedor",
                                nombreCliente ?? "Un estudiante",
                                tituloServicio ?? "Tu servicio",
                                dto.tipo_servicio ?? "No especificado",
                                dto.descripcion ?? "",
                                dto.presupuesto.ToString(),
                                dto.urgencia ?? ""
                            );
                        }
                        catch (Exception emailEx)
                        {
                            Console.WriteLine($"❌ Error enviando correo: {emailEx.Message}");
                        }
                    });
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"ERROR CORREO: {ex.Message}");
            }

            return Ok(new
            {
                message = "Solicitud enviada correctamente",
                id = idSolicitud?.ToString()
            });
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { error = ex.Message });
        }
    }

    private List<string> GetCamposRequeridosPorCategoria(string categoria)
    {
        return categoria switch
        {
            "tutorías" or "tutorias" => new List<string> { "descripcion", "presupuesto" },
            "ensayos y redacción" or "ensayos" => new List<string> { "descripcion", "presupuesto" },
            "proyectos" => new List<string> { "descripcion", "presupuesto" },
            "programación" or "programacion" => new List<string> { "descripcion", "presupuesto" },
            "diseño" or "diseno" => new List<string> { "descripcion", "presupuesto" },
            "arriendo de habitaciones" or "arriendo" => new List<string> { "descripcion", "presupuesto" },
            _ => new List<string> { "descripcion", "presupuesto" }
        };
    }

    // 🔹 SOLICITUDES ENVIADAS
    [HttpGet("enviadas/{id}")]
    public async Task<IActionResult> GetEnviadas(int id)
    {
        var lista = new List<object>();

        using var conn = new NpgsqlConnection(_config.GetConnectionString("DefaultConnection"));
        await conn.OpenAsync();

        var cmd = new NpgsqlCommand(@"
            SELECT s.id_solicitud, s.id_servicio, s.estado, s.descripcion,
                   u.nombre AS nombre_proveedor,
                   se.titulo AS titulo_servicio, se.icono,
                   s.campos_personalizados
            FROM solicitudes s
            INNER JOIN usuarios u ON s.id_proveedor = u.id_usuario
            INNER JOIN servicios se ON s.id_servicio = se.id_servicio
            WHERE s.id_cliente = @id
            ORDER BY s.id_solicitud DESC
        ", conn);

        cmd.Parameters.AddWithValue("@id", id);

        using var reader = await cmd.ExecuteReaderAsync();

        while (await reader.ReadAsync())
        {
            lista.Add(new
            {
                id_solicitud = reader["id_solicitud"],
                id_servicio = reader["id_servicio"],
                estado = reader["estado"],
                descripcion = reader["descripcion"] == DBNull.Value ? "" : reader["descripcion"].ToString(),
                nombre_proveedor = reader["nombre_proveedor"],
                titulo_servicio = reader["titulo_servicio"],
                icono = reader["icono"],
                campos_personalizados = reader["campos_personalizados"] != DBNull.Value 
                    ? reader["campos_personalizados"].ToString() : "{}"
            });
        }

        return Ok(lista);
    }

    // 🔹 SOLICITUDES RECIBIDAS
    [HttpGet("recibidas/{id}")]
    public async Task<IActionResult> GetRecibidas(int id)
    {
        var lista = new List<object>();

        using var conn = new NpgsqlConnection(_config.GetConnectionString("DefaultConnection"));
        await conn.OpenAsync();

        var cmd = new NpgsqlCommand(@"
            SELECT s.id_solicitud, s.estado, s.descripcion,
                   u.nombre AS nombre_cliente,
                   se.titulo AS titulo_servicio, se.icono,
                   s.motivo_rechazo, s.contraoferta,
                   s.campos_personalizados
            FROM solicitudes s
            INNER JOIN usuarios u ON s.id_cliente = u.id_usuario
            INNER JOIN servicios se ON s.id_servicio = se.id_servicio
            WHERE s.id_proveedor = @id
            ORDER BY s.id_solicitud DESC
        ", conn);

        cmd.Parameters.AddWithValue("@id", id);

        using var reader = await cmd.ExecuteReaderAsync();

        while (await reader.ReadAsync())
        {
            lista.Add(new
            {
                id_solicitud = reader["id_solicitud"],
                estado = reader["estado"],
                descripcion = reader["descripcion"] == DBNull.Value ? "" : reader["descripcion"].ToString(),
                nombre_cliente = reader["nombre_cliente"],
                titulo_servicio = reader["titulo_servicio"],
                icono = reader["icono"],
                motivo_rechazo = reader["motivo_rechazo"] == DBNull.Value ? "" : reader["motivo_rechazo"].ToString(),
                contraoferta = reader["contraoferta"] == DBNull.Value ? "" : reader["contraoferta"].ToString(),
                campos_personalizados = reader["campos_personalizados"] != DBNull.Value 
                    ? reader["campos_personalizados"].ToString() : "{}"
            });
        }

        return Ok(lista);
    }

    // 🔹 RESPONDER SOLICITUD (ACEPTAR / RECHAZAR)
    [HttpPost("responder")]
    public async Task<IActionResult> Responder([FromBody] ResponderSolicitudDTO dto)
    {
        using var conn = new NpgsqlConnection(_config.GetConnectionString("DefaultConnection"));
        await conn.OpenAsync();

        string estado = dto.accion == "aceptar" ? "Aceptada" : "Rechazada";
        bool fueAceptada = dto.accion == "aceptar";

        var cmd = new NpgsqlCommand(@"
            UPDATE solicitudes
            SET estado = @estado,
                motivo_rechazo = @motivo,
                contraoferta = @contraoferta,
                fue_aceptada = @fue_aceptada
            WHERE id_solicitud = @id
        ", conn);

        cmd.Parameters.AddWithValue("@estado", estado);
        cmd.Parameters.AddWithValue("@motivo", (object)dto.motivo_rechazo ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@contraoferta", dto.contraoferta.HasValue ? (object)dto.contraoferta.Value : DBNull.Value);
        cmd.Parameters.AddWithValue("@fue_aceptada", fueAceptada);
        cmd.Parameters.AddWithValue("@id", dto.id_solicitud);

        await cmd.ExecuteNonQueryAsync();

        return Ok(new { message = "Solicitud actualizada" });
    }

    // 🔹 MARCAR SERVICIO COMO COMPLETADO (Proveedor)
    [HttpPost("completar")]
    public async Task<IActionResult> Completar([FromBody] CompletarSolicitudDTO dto)
    {
        using var conn = new NpgsqlConnection(_config.GetConnectionString("DefaultConnection"));
        await conn.OpenAsync();

        var checkCmd = new NpgsqlCommand("SELECT estado FROM solicitudes WHERE id_solicitud = @id", conn);
        checkCmd.Parameters.AddWithValue("@id", dto.id_solicitud);
        var estadoActual = await checkCmd.ExecuteScalarAsync();

        if (estadoActual?.ToString() != "Aceptada")
            return BadRequest(new { error = "Solo se pueden completar solicitudes aceptadas." });

        var cmd = new NpgsqlCommand(@"
            UPDATE solicitudes
            SET estado = 'Completada'
            WHERE id_solicitud = @id
        ", conn);
        cmd.Parameters.AddWithValue("@id", dto.id_solicitud);

        await cmd.ExecuteNonQueryAsync();

        return Ok(new { message = "Servicio marcado como completado. El cliente ya puede calificar." });
    }

    // 🔹 VERIFICAR SI YA EXISTE SOLICITUD
    [HttpGet("verificar")]
    public async Task<IActionResult> Verificar([FromQuery] int id_cliente, [FromQuery] int id_servicio)
    {
        using var conn = new NpgsqlConnection(_config.GetConnectionString("DefaultConnection"));
        await conn.OpenAsync();

        var cmd = new NpgsqlCommand(@"
            SELECT COUNT(*) FROM solicitudes
            WHERE id_cliente = @id_cliente AND id_servicio = @id_servicio
            AND estado NOT IN ('Rechazada', 'Cancelada', 'Completada')
        ", conn);

        cmd.Parameters.AddWithValue("@id_cliente", id_cliente);
        cmd.Parameters.AddWithValue("@id_servicio", id_servicio);

        var count = Convert.ToInt32(await cmd.ExecuteScalarAsync());
        return Ok(new { existe = count > 0 });
    }

    // 🔹 ELIMINAR SOLICITUD
    [HttpDelete("eliminar")]
    public async Task<IActionResult> Eliminar([FromQuery] int id_cliente, [FromQuery] int id_servicio)
    {
        using var conn = new NpgsqlConnection(_config.GetConnectionString("DefaultConnection"));
        await conn.OpenAsync();

        var cmd = new NpgsqlCommand(@"
            DELETE FROM solicitudes
            WHERE id_cliente = @id_cliente AND id_servicio = @id_servicio
            AND estado IN ('Pendiente', 'Rechazada')
        ", conn);

        cmd.Parameters.AddWithValue("@id_cliente", id_cliente);
        cmd.Parameters.AddWithValue("@id_servicio", id_servicio);

        int filas = await cmd.ExecuteNonQueryAsync();
        if (filas == 0)
            return BadRequest(new { message = "No se puede eliminar esta solicitud" });

        return Ok(new { message = "Solicitud eliminada" });
    }
}
