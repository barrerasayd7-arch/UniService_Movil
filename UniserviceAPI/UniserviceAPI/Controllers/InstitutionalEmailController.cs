using System.ComponentModel.DataAnnotations;
using System.Globalization;
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.IdentityModel.Tokens;
using Npgsql;
using UniserviceAPI.Services;

namespace UniserviceAPI.Controllers;

public sealed record InstitutionalEmailRequest([Required, StringLength(100)] string correo);
public sealed record InstitutionalCodeRequest(
    [Required, StringLength(100)] string correo,
    [Required, RegularExpression("^[0-9]{6}$")] string codigo,
    [StringLength(50, MinimumLength = 2)] string? nombre);

[ApiController, Route("api/auth/institutional-email"), AllowAnonymous]
[EnableRateLimiting("InstitutionalEmail")]
public sealed class InstitutionalEmailController(IConfiguration config, IHttpClientFactory clients) : ControllerBase
{
    private bool Configured => Encoding.UTF8.GetByteCount(config["InstitutionalEmail:CodeKey"] ?? "") >= 32
        && Encoding.UTF8.GetByteCount(config["Jwt:Key"] ?? "") >= 32
        && config["Jwt:Key"] != "uniservice_super_secret_key_2026_segura_12345"
        && !string.IsNullOrWhiteSpace(config["Brevo:ApiKey"])
        && !string.IsNullOrWhiteSpace(config["Brevo:FromEmail"]);

    private byte[] Hash(string email, Guid challenge, string code) =>
        HMACSHA256.HashData(Encoding.UTF8.GetBytes(config["InstitutionalEmail:CodeKey"]!),
            Encoding.UTF8.GetBytes($"{email}:{challenge:D}:{code}"));

    private static async Task Lock(NpgsqlConnection conn, NpgsqlTransaction tx, string email, CancellationToken ct)
    {
        await using var cmd = new NpgsqlCommand("SELECT pg_advisory_xact_lock(hashtextextended(@email, 0))", conn, tx);
        cmd.Parameters.AddWithValue("email", email);
        await cmd.ExecuteNonQueryAsync(ct);
    }

    [HttpPost("send-code")]
    public async Task<IActionResult> Send(InstitutionalEmailRequest request, CancellationToken ct)
    {
        var email = InstitutionalAccess.NormalizeEmail(request.correo);
        if (email == null) return BadRequest(new { error = "Usa tu correo @unicesar.edu.co" });
        if (!Configured) return StatusCode(503, new { error = "El acceso por correo aún no está configurado" });
        await using var conn = new NpgsqlConnection(config.GetConnectionString("DefaultConnection"));
        await conn.OpenAsync(ct);
        await using var tx = await conn.BeginTransactionAsync(ct);
        await Lock(conn, tx, email, ct);
        var code = RandomNumberGenerator.GetInt32(0, 1000000).ToString("D6", CultureInfo.InvariantCulture);
        var challenge = Guid.NewGuid();
        await using (var save = new NpgsqlCommand("""
            INSERT INTO uniservice_mobile.codigos_correo(correo, desafio, hash, expira_en)
            VALUES (@email, @challenge, @hash, clock_timestamp() + interval '10 minutes')
            ON CONFLICT (correo) DO UPDATE SET desafio = EXCLUDED.desafio, hash = EXCLUDED.hash,
              expira_en = EXCLUDED.expira_en, ultimo_envio = clock_timestamp(), consumido = false,
              ventana = CASE WHEN codigos_correo.ventana <= clock_timestamp() - interval '1 hour' THEN clock_timestamp() ELSE codigos_correo.ventana END,
              envios = CASE WHEN codigos_correo.ventana <= clock_timestamp() - interval '1 hour' THEN 1 ELSE codigos_correo.envios + 1 END,
              fallos = CASE WHEN codigos_correo.ventana <= clock_timestamp() - interval '1 hour' THEN 0 ELSE codigos_correo.fallos END
            WHERE codigos_correo.ultimo_envio <= clock_timestamp() - interval '60 seconds'
              AND (codigos_correo.ventana <= clock_timestamp() - interval '1 hour' OR (codigos_correo.envios < 5 AND codigos_correo.fallos < 5))
            RETURNING correo
            """, conn, tx))
        {
            save.Parameters.AddWithValue("email", email);
            save.Parameters.AddWithValue("challenge", challenge);
            save.Parameters.AddWithValue("hash", Hash(email, challenge, code));
            if (await save.ExecuteScalarAsync(ct) == null)
                return StatusCode(429, new { error = "Espera antes de solicitar otro código. Máximo 5 envíos o intentos fallidos por hora" });
        }
        // La transacción mantiene el código inaccesible hasta que el proveedor acepta el envío.
        using var message = new HttpRequestMessage(HttpMethod.Post, "https://api.brevo.com/v3/smtp/email");
        message.Headers.Add("api-key", config["Brevo:ApiKey"]);
        message.Content = JsonContent.Create(new
        {
            sender = new { email = config["Brevo:FromEmail"], name = config["Brevo:FromName"] ?? "UniService" },
            to = new[] { new { email } },
            subject = "Tu código de acceso a UniService",
            htmlContent = $"<p>Tu código de acceso es <strong>{code}</strong>.</p><p>Caduca en 10 minutos y solo puedes usarlo una vez. No lo compartas.</p><p>Si no lo solicitaste, ignora este correo.</p>"
        });
        try
        {
            using var response = await clients.CreateClient("InstitutionalEmail").SendAsync(message, ct);
            if (!response.IsSuccessStatusCode)
                return StatusCode(503, new { error = "No pudimos enviar el código. Inténtalo más tarde" });
        }
        catch (HttpRequestException) { return StatusCode(503, new { error = "Servicio de correo no disponible" }); }
        catch (OperationCanceledException) when (!ct.IsCancellationRequested)
        { return StatusCode(503, new { error = "Servicio de correo no disponible" }); }
        await tx.CommitAsync(ct);
        return Ok(new { mensaje = "Código enviado. Revisa tu bandeja y correo no deseado", expires_in = 600, resend_after = 60 });
    }

    [HttpPost("verify-code")]
    public async Task<IActionResult> Verify(InstitutionalCodeRequest request, CancellationToken ct)
    {
        var email = InstitutionalAccess.NormalizeEmail(request.correo);
        if (email == null) return BadRequest(new { error = "Usa tu correo @unicesar.edu.co" });
        if (!Configured) return StatusCode(503, new { error = "El acceso por correo aún no está configurado" });
        await using var conn = new NpgsqlConnection(config.GetConnectionString("DefaultConnection"));
        await conn.OpenAsync(ct);
        await using var tx = await conn.BeginTransactionAsync(ct);
        await Lock(conn, tx, email, ct);
        byte[] stored; Guid challenge;
        await using (var find = new NpgsqlCommand("""
            SELECT desafio, hash FROM uniservice_mobile.codigos_correo
            WHERE correo = @email AND expira_en > clock_timestamp() AND fallos < 5 AND NOT consumido FOR UPDATE
            """, conn, tx))
        {
            find.Parameters.AddWithValue("email", email);
            await using var reader = await find.ExecuteReaderAsync(ct);
            if (!await reader.ReadAsync(ct)) return BadRequest(new { error = "Código inválido, vencido o agotado" });
            challenge = reader.GetGuid(0); stored = reader.GetFieldValue<byte[]>(1);
        }
        if (!CryptographicOperations.FixedTimeEquals(stored, Hash(email, challenge, request.codigo)))
        {
            await using var failed = new NpgsqlCommand("UPDATE uniservice_mobile.codigos_correo SET fallos = fallos + 1 WHERE correo = @email", conn, tx);
            failed.Parameters.AddWithValue("email", email);
            await failed.ExecuteNonQueryAsync(ct);
            await tx.CommitAsync(ct);
            return BadRequest(new { error = "Código inválido, vencido o agotado" });
        }
        // Consumir incluso si la cuenta necesita vinculación supervisada o está suspendida.
        await using (var consume = new NpgsqlCommand("UPDATE uniservice_mobile.codigos_correo SET consumido = true WHERE correo = @email", conn, tx))
        {
            consume.Parameters.AddWithValue("email", email); await consume.ExecuteNonQueryAsync(ct);
        }
        var id = 0; var role = 2; var name = request.nombre?.Trim() ?? email.Split('@')[0];
        if (name.Length < 2) name = "Usuario";
        if (name.Length > 50) name = name[..50];
        var active = true; var linked = false;
        await using (var user = new NpgsqlCommand("""
            SELECT u.id_usuario, u.id_rol, u.nombre, u.estado,
              EXISTS (SELECT 1 FROM verificaciones_correo_institucional v WHERE v.id_usuario = u.id_usuario AND v.correo = @email)
            FROM usuarios u WHERE lower(trim(u.correo)) = @email FOR UPDATE OF u
            """, conn, tx))
        {
            user.Parameters.AddWithValue("email", email);
            await using var reader = await user.ExecuteReaderAsync(ct);
            if (await reader.ReadAsync(ct))
            {
                id = reader.GetInt32(0); role = reader.IsDBNull(1) ? 2 : reader.GetInt32(1);
                name = reader.GetString(2); active = !reader.IsDBNull(3) && reader.GetBoolean(3); linked = reader.GetBoolean(4);
            }
        }
        if (!active || (id != 0 && !linked))
        {
            await tx.CommitAsync(ct);
            return !active ? StatusCode(403, new { error = "Cuenta suspendida" })
                : Conflict(new { error = "Cuenta existente: solicita al administrador vincular el acceso por correo" });
        }
        if (id == 0)
        {
            await using var create = new NpgsqlCommand("""
                INSERT INTO usuarios(correo, nombre, id_rol, estado) VALUES (@email, @name, 2, true)
                ON CONFLICT DO NOTHING RETURNING id_usuario
                """, conn, tx);
            create.Parameters.AddWithValue("email", email); create.Parameters.AddWithValue("name", name);
            var created = await create.ExecuteScalarAsync(ct);
            if (created == null)
            {
                await tx.CommitAsync(ct);
                return Conflict(new { error = "Cuenta existente: solicita al administrador vincular el acceso por correo" });
            }
            id = Convert.ToInt32(created);
        }
        var expires = DateTime.UtcNow.AddHours(1);
        await using (var verify = new NpgsqlCommand("""
            INSERT INTO verificaciones_correo_institucional(id_usuario, correo, verificado_hasta)
            VALUES (@id, @email, @expires)
            ON CONFLICT(id_usuario) DO UPDATE SET correo = EXCLUDED.correo, verificado_en = clock_timestamp(), verificado_hasta = EXCLUDED.verificado_hasta;
            UPDATE usuarios SET ultima_actividad = clock_timestamp() WHERE id_usuario = @id
            """, conn, tx))
        {
            verify.Parameters.AddWithValue("id", id); verify.Parameters.AddWithValue("email", email);
            verify.Parameters.AddWithValue("expires", expires); await verify.ExecuteNonQueryAsync(ct);
        }
        await tx.CommitAsync(ct);
        var token = new JwtSecurityToken(claims: [new Claim("id", id.ToString()), new Claim("id_rol", role.ToString()),
            new Claim("auth_method", "institutional_email")], expires: expires,
            signingCredentials: new SigningCredentials(new SymmetricSecurityKey(Encoding.UTF8.GetBytes(config["Jwt:Key"]!)), SecurityAlgorithms.HmacSha256));
        return Ok(new { token = new JwtSecurityTokenHandler().WriteToken(token), expires_at = expires,
            user = new { id, nombre = name, correo = email, id_rol = role, correo_institucional_verificado = true } });
    }
}
