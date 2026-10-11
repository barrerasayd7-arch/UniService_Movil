using Microsoft.AspNetCore.Mvc;
using Npgsql;
using UniserviceAPI.DTOs;

[ApiController]
[Route("api/calificaciones")]
public class CalificacionesController : ControllerBase
{
    private readonly IConfiguration _config;

    public CalificacionesController(IConfiguration config)
    {
        _config = config;
    }

    // GET /api/calificaciones/{id_servicio}
    // Devuelve todas las reseñas de un servicio
    [HttpGet("{id_servicio}")]
    public async Task<IActionResult> GetByServicio(int id_servicio)
    {
        try
        {
            using var conn = new NpgsqlConnection(_config.GetConnectionString("DefaultConnection"));
            await conn.OpenAsync();

            using var cmd = new NpgsqlCommand(@"
                SELECT 
                    c.id_calificacion,
                    c.puntuacion,
                    c.comentario,
                    c.fecha_calificacion,
                    c.fecha_modificacion,
                    u.nombre AS autor
                FROM calificaciones c
                INNER JOIN usuarios u ON c.id_cliente = u.id_usuario
                WHERE c.id_servicio = @id_servicio
                ORDER BY c.fecha_calificacion DESC
            ", conn);

            cmd.Parameters.AddWithValue("@id_servicio", id_servicio);

            var resenas = new List<object>();
            using var reader = await cmd.ExecuteReaderAsync();

            while (await reader.ReadAsync())
            {
                resenas.Add(new
                {
                    id_calificacion = (int)reader["id_calificacion"],
                    estrellas = (byte)reader["puntuacion"],
                    comentario = reader["comentario"]?.ToString(),
                    fecha = ((DateTime)reader["fecha_calificacion"]).ToString("dd MMM yyyy"),
                    autor = reader["autor"]?.ToString(),
                    fecha_modificacion = reader["fecha_modificacion"] != DBNull.Value
                        ? ((DateTime)reader["fecha_modificacion"]).ToString("dd MMM yyyy")
                        : null
                });
            }

            return Ok(resenas);
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { error = ex.Message });
        }
    }

    // POST /api/calificaciones
    // Crea una nueva reseña (solo si la solicitud fue completada)
    [HttpPost]
    public async Task<IActionResult> Crear([FromBody] CalificacionDTO dto)
    {
        try
        {
            using var conn = new NpgsqlConnection(_config.GetConnectionString("DefaultConnection"));
            await conn.OpenAsync();

            // Verificar que la solicitud existe y fue completada
            using var checkCmd = new NpgsqlCommand(@"
                SELECT COUNT(*) FROM solicitudes
                WHERE id_solicitud = @id_solicitud
                  AND id_cliente   = @id_cliente
                  AND id_servicio  = @id_servicio
                  AND estado       = 'Completada'
            ", conn);

            checkCmd.Parameters.AddWithValue("@id_solicitud", dto.id_solicitud);
            checkCmd.Parameters.AddWithValue("@id_cliente", dto.id_cliente);
            checkCmd.Parameters.AddWithValue("@id_servicio", dto.id_servicio);

            int valida = Convert.ToInt32(await checkCmd.ExecuteScalarAsync());
            if (valida == 0)
                return BadRequest(new { error = "Solo puedes calificar servicios que han sido completados por el proveedor" });

            // Insertar calificación
            using var cmd = new NpgsqlCommand(@"
                INSERT INTO calificaciones
                    (id_solicitud, id_cliente, id_servicio, puntuacion, comentario)
                VALUES
                    (@id_solicitud, @id_cliente, @id_servicio, @puntuacion, @comentario)
            ", conn);

            cmd.Parameters.AddWithValue("@id_solicitud", dto.id_solicitud);
            cmd.Parameters.AddWithValue("@id_cliente", dto.id_cliente);
            cmd.Parameters.AddWithValue("@id_servicio", dto.id_servicio);
            cmd.Parameters.AddWithValue("@puntuacion", dto.puntuacion);
            cmd.Parameters.AddWithValue("@comentario", dto.comentario ?? (object)DBNull.Value);

            await cmd.ExecuteNonQueryAsync();
            return Ok(new { ok = true });
        }
        catch (NpgsqlException ex) when (ex.SqlState == "23505") // violación UNIQUE
        {
            return BadRequest(new { error = "Ya calificaste este servicio" });
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { error = ex.Message });
        }
    }

    // GET /api/calificaciones/puede-calificar?id_cliente=X&id_servicio=Y
    // El frontend lo usa para saber si mostrar el formulario
    [HttpGet("puede-calificar")]
    public async Task<IActionResult> PuedeCalificar([FromQuery] int id_cliente, [FromQuery] int id_servicio)
    {
        try
        {
            using var conn = new NpgsqlConnection(_config.GetConnectionString("DefaultConnection"));
            await conn.OpenAsync();

            // ¿Tiene solicitud COMPLETADA? (Solo se puede calificar si el proveedor marcó como completada)
            using var cmdSol = new NpgsqlCommand(@"
                SELECT COUNT(*) FROM solicitudes
                WHERE id_cliente  = @id_cliente
                  AND id_servicio = @id_servicio
                  AND estado      = 'Completada'
            ", conn);
            cmdSol.Parameters.AddWithValue("@id_cliente", id_cliente);
            cmdSol.Parameters.AddWithValue("@id_servicio", id_servicio);
            int tieneSolicitud = Convert.ToInt32(await cmdSol.ExecuteScalarAsync());

            // ¿Ya calificó?
            using var cmdCalif = new NpgsqlCommand(@"
                SELECT COUNT(*) FROM calificaciones
                WHERE id_cliente  = @id_cliente
                  AND id_servicio = @id_servicio
            ", conn);
            cmdCalif.Parameters.AddWithValue("@id_cliente", id_cliente);
            cmdCalif.Parameters.AddWithValue("@id_servicio", id_servicio);
            int yaCalifico = Convert.ToInt32(await cmdCalif.ExecuteScalarAsync());

            // También devolvemos el id_solicitud para usarlo al crear la calificación
            int idSolicitud = 0;
            if (tieneSolicitud > 0)
            {
                using var cmdId = new NpgsqlCommand(@"
                    SELECT id_solicitud FROM solicitudes
                    WHERE id_cliente  = @id_cliente
                      AND id_servicio = @id_servicio
                      AND estado      = 'Completada'
                    LIMIT 1
                ", conn);
                cmdId.Parameters.AddWithValue("@id_cliente", id_cliente);
                cmdId.Parameters.AddWithValue("@id_servicio", id_servicio);
                var result = await cmdId.ExecuteScalarAsync();
                if (result != null) idSolicitud = (int)result;
            }

            // Si ya calificó, devolver su calificación actual
            object miCalificacion = null;
            if (yaCalifico > 0)
            {
                using var cmdMiCalif = new NpgsqlCommand(@"
                    SELECT id_calificacion, puntuacion, comentario, fecha_calificacion, fecha_modificacion
                    FROM calificaciones
                    WHERE id_cliente = @id_cliente AND id_servicio = @id_servicio
                    LIMIT 1
                ", conn);
                cmdMiCalif.Parameters.AddWithValue("@id_cliente", id_cliente);
                cmdMiCalif.Parameters.AddWithValue("@id_servicio", id_servicio);
                using var reader = await cmdMiCalif.ExecuteReaderAsync();
                if (await reader.ReadAsync())
                {
                    miCalificacion = new
                    {
                        id_calificacion = (int)reader["id_calificacion"],
                        puntuacion = (byte)reader["puntuacion"],
                        comentario = reader["comentario"]?.ToString(),
                        fecha = ((DateTime)reader["fecha_calificacion"]).ToString("dd MMM yyyy"),
                        fecha_modificacion = reader["fecha_modificacion"] != DBNull.Value
                            ? ((DateTime)reader["fecha_modificacion"]).ToString("dd MMM yyyy")
                            : null
                    };
                }
            }

            return Ok(new
            {
                puede = tieneSolicitud > 0 && yaCalifico == 0,
                yaCalifico = yaCalifico > 0,
                id_solicitud = idSolicitud,
                mi_calificacion = miCalificacion
            });
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { error = ex.Message });
        }
    }

    // PUT /api/calificaciones/{id}
    // Actualizar una calificación existente
    [HttpPut("{id}")]
    public async Task<IActionResult> Actualizar(int id, [FromBody] CalificacionDTO dto)
    {
        try
        {
            using var conn = new NpgsqlConnection(_config.GetConnectionString("DefaultConnection"));
            await conn.OpenAsync();

            // Verificar que la calificación pertenece al usuario
            using var checkCmd = new NpgsqlCommand(@"
                SELECT COUNT(*) FROM calificaciones
                WHERE id_calificacion = @id AND id_cliente = @id_cliente
            ", conn);
            checkCmd.Parameters.AddWithValue("@id", id);
            checkCmd.Parameters.AddWithValue("@id_cliente", dto.id_cliente);
            int existe = Convert.ToInt32(await checkCmd.ExecuteScalarAsync());
            if (existe == 0)
                return BadRequest(new { error = "No puedes editar esta calificación" });

            using var cmd = new NpgsqlCommand(@"
                UPDATE calificaciones
                SET puntuacion = @puntuacion,
                    comentario = @comentario,
                    fecha_modificacion = NOW()
                WHERE id_calificacion = @id
            ", conn);
            cmd.Parameters.AddWithValue("@id", id);
            cmd.Parameters.AddWithValue("@puntuacion", dto.puntuacion);
            cmd.Parameters.AddWithValue("@comentario", dto.comentario ?? (object)DBNull.Value);

            await cmd.ExecuteNonQueryAsync();
            return Ok(new { ok = true });
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { error = ex.Message });
        }
    }
}