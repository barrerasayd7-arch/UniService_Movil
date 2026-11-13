using Microsoft.AspNetCore.Mvc;
using Npgsql;
using UniserviceAPI.Services;
using static UniserviceAPI.Services.ServiciosComun;

namespace UniserviceAPI.Controllers;

// Resumen de actividad real, protegido por el filtro global de sesión.
// No inventa eventos históricos: usa el último estado guardado de cada entidad.
[ApiController, Route("api/notificaciones")]
public sealed class NotificacionesController(IConfiguration config) : ControllerBase
{
    [HttpGet]
    public async Task<IActionResult> Listar(CancellationToken ct)
    {
        await using var conn = await Open(config, ct);
        await using var cmd = new NpgsqlCommand(Consulta, conn);
        cmd.Parameters.AddWithValue("user", InstitutionalAccess.UserId(User)!.Value);
        var avisos = new List<object>();
        await using var r = await cmd.ExecuteReaderAsync(ct);
        while (await r.ReadAsync(ct)) avisos.Add(new
        {
            id = r.Get<string>("id"), texto = r.Get<string>("texto"),
            fecha = r.Utc("fecha"), destino = r.Get<string>("destino"),
            argumento = r.Get<int>("argumento")
        });
        return Ok(avisos);
    }

    // Todas las ramas filtran por el destinatario obtenido del JWT.
    internal const string Consulta = """
        SELECT * FROM (
          SELECT concat('solicitud:', so.id_solicitud, ':', so.estado, ':',
                        coalesce(so.fecha_actualizacion, so.fecha_creacion)::text) AS id,
            CASE WHEN so.estado = 'Pendiente'
              THEN cl.nombre || ' solicitó tu servicio "' || s.titulo || '".'
              WHEN so.estado = 'Cancelada'
              THEN cl.nombre || ' canceló la solicitud de "' || s.titulo || '".'
              ELSE 'Tu solicitud de "' || s.titulo || '" fue ' || lower(so.estado) || '.'
                || CASE WHEN so.estado = 'Rechazada' AND so.motivo_rechazo IS NOT NULL
                     THEN ' Motivo: ' || so.motivo_rechazo ELSE '' END
            END AS texto,
            coalesce(so.fecha_actualizacion, so.fecha_creacion) AS fecha,
            'solicitudes'::text AS destino,
            CASE WHEN so.id_cliente = @user THEN 1 ELSE 0 END AS argumento
          FROM solicitudes so
          JOIN servicios s ON s.id_servicio = so.id_servicio
          JOIN usuarios cl ON cl.id_usuario = so.id_cliente
          WHERE (so.id_proveedor = @user AND so.estado IN ('Pendiente', 'Cancelada'))
             OR (so.id_cliente = @user AND so.estado IN ('Aceptada', 'Rechazada', 'Completada'))

          UNION ALL
          SELECT concat('servicio:', s.id_servicio, ':', s.estado, ':', s.revisado_en::text),
            'Tu servicio "' || s.titulo || '" fue ' || s.estado || '.'
              || CASE WHEN s.estado = 'rechazado' AND s.motivo_rechazo IS NOT NULL
                   THEN ' Motivo: ' || s.motivo_rechazo ELSE '' END,
            s.revisado_en, 'mis-servicios', s.id_servicio
          FROM servicios s
          WHERE s.id_proveedor = @user AND s.estado IN ('aprobado', 'rechazado')
            AND s.revisado_en IS NOT NULL

          UNION ALL
          SELECT concat('resena:', c.id_calificacion, ':', coalesce(c.fecha_modificacion, c.fecha_calificacion)::text),
            u.nombre || CASE WHEN c.fecha_modificacion IS NULL THEN ' dejó' ELSE ' actualizó' END
              || ' una reseña de ' || c.puntuacion || ' estrellas en "' || s.titulo || '".',
            coalesce(c.fecha_modificacion, c.fecha_calificacion) AT TIME ZONE 'UTC',
            'servicio', s.id_servicio
          FROM calificaciones c
          JOIN servicios s ON s.id_servicio = c.id_servicio
          JOIN usuarios u ON u.id_usuario = c.id_cliente
          WHERE s.id_proveedor = @user AND c.id_cliente <> @user
        ) avisos
        ORDER BY fecha DESC NULLS LAST, id DESC
        LIMIT 100
        """;
}
