using System.Data;
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using Google.Apis.Auth;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.IdentityModel.Tokens;
using Npgsql;
using UniserviceAPI.DTOs;
using UniserviceAPI.Services;
using UniServiceAPI.Models;

[ApiController]
[Route("api/auth")]
public class AuthController : ControllerBase
{
    private static Dictionary<string, string> codigos = new();
    private static HashSet<string> correosVerificados = new();

    private readonly EmailService _emailService;
    private readonly IConfiguration _config;

    public AuthController(EmailService emailService, IConfiguration config)
    {
        _emailService = emailService;
        _config = config;
    }

    // =========================
    // ENVIAR CÓDIGO
    // =========================
    [AllowAnonymous]
    [HttpPost("send-code")]
    public Task<IActionResult> EnviarCodigo([FromBody] EmailDTO data) => Task.FromResult<IActionResult>(StatusCode(403, new { error = "Usa /api/auth/institutional-email/send-code y verify-code" }));

    // =========================
    // VERIFICAR CÓDIGO
    // =========================
    [AllowAnonymous]
    [HttpPost("verify-code")]
    public IActionResult VerificarCodigo([FromBody] VerificarCodigoDTO data) => StatusCode(403, new { error = "Usa /api/auth/institutional-email/send-code y verify-code" });

    // =========================
    // REGISTER: crea la cuenta a partir del JWT efímero
    // emitido por /api/auth/institutional-email/verify-code.
    // =========================
    [AllowAnonymous]
    [HttpPost("register")]
    public async Task<IActionResult> Register([FromBody] RegisterDTO dto)
    {
        var email = InstitutionalAccess.NormalizeEmail(dto.correo);
        if (email == null)
            return BadRequest(new { error = "Usa tu correo @unicesar.edu.co" });

        var codeKey = _config["InstitutionalEmail:CodeKey"];
        var jwtKey = _config["Jwt:Key"];
        if (string.IsNullOrWhiteSpace(codeKey) || Encoding.UTF8.GetByteCount(codeKey) < 32 ||
            string.IsNullOrWhiteSpace(jwtKey) || Encoding.UTF8.GetByteCount(jwtKey) < 32)
            return StatusCode(503, new { error = "El registro aún no está configurado" });

        ClaimsPrincipal principal;
        try
        {
            // MapInboundClaims = false: si no, el claim "email" se renombra a
            // ClaimTypes.Email y FindFirst("email") devuelve null.
            principal = new JwtSecurityTokenHandler { MapInboundClaims = false }.ValidateToken(dto.verificacion_token, new TokenValidationParameters
            {
                ValidateIssuerSigningKey = true,
                IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(codeKey)),
                ValidateIssuer = false,
                ValidateAudience = false,
                ValidateLifetime = true,
                ClockSkew = TimeSpan.Zero
            }, out _);
        }
        catch
        {
            return BadRequest(new { error = "Verificación de correo inválida o vencida. Solicita un código nuevo" });
        }

        if (principal.FindFirst("purpose")?.Value != "institutional_email_verify" ||
            !string.Equals(principal.FindFirst("email")?.Value, email, StringComparison.Ordinal))
            return BadRequest(new { error = "Verificación de correo inválida" });

        var nombre = dto.nombre.Trim();
        var apellido = dto.apellido.Trim();
        var nombreCompleto = $"{nombre} {apellido}";
        if (nombreCompleto.Length > 100) nombreCompleto = nombreCompleto[..100];
        var telefono = dto.telefono.Trim();

        await using var conn = new NpgsqlConnection(_config.GetConnectionString("DefaultConnection"));
        await conn.OpenAsync();
        await using var tx = await conn.BeginTransactionAsync();

        await using (var exists = new NpgsqlCommand(
            "SELECT COUNT(*) FROM usuarios WHERE lower(trim(correo)) = @email", conn, tx))
        {
            exists.Parameters.AddWithValue("@email", email);
            if (Convert.ToInt32(await exists.ExecuteScalarAsync()) > 0)
                return Conflict(new { error = "Ya existe una cuenta con ese correo. Inicia sesión en su lugar" });
        }

        var hash = BCrypt.Net.BCrypt.HashPassword(dto.password);

        int id;
        await using (var insert = new NpgsqlCommand("""
            INSERT INTO usuarios(nombre, correo, password_hash, telefono, universidad, id_rol, estado, ultima_actividad)
            VALUES (@nombre, @correo, @hash, @telefono, @universidad, 2, true, clock_timestamp())
            RETURNING id_usuario
            """, conn, tx))
        {
            insert.Parameters.AddWithValue("@nombre", nombreCompleto);
            insert.Parameters.AddWithValue("@correo", email);
            insert.Parameters.AddWithValue("@hash", hash);
            insert.Parameters.AddWithValue("@telefono", telefono);
            insert.Parameters.AddWithValue("@universidad", "Universidad Popular del Cesar");
            id = Convert.ToInt32(await insert.ExecuteScalarAsync());
        }

        var verifExpires = DateTime.UtcNow.Add(InstitutionalAccess.VerificationValidity);
        await using (var verif = new NpgsqlCommand("""
            INSERT INTO verificaciones_correo_institucional(id_usuario, correo, verificado_hasta)
            VALUES (@id, @correo, @expires)
            ON CONFLICT(id_usuario) DO UPDATE SET correo = EXCLUDED.correo,
              verificado_en = clock_timestamp(), verificado_hasta = EXCLUDED.verificado_hasta
            """, conn, tx))
        {
            verif.Parameters.AddWithValue("@id", id);
            verif.Parameters.AddWithValue("@correo", email);
            verif.Parameters.AddWithValue("@expires", verifExpires);
            await verif.ExecuteNonQueryAsync();
        }

        await tx.CommitAsync();

        var sessionToken = new JwtSecurityToken(
            claims: new[] { new Claim("id", id.ToString()), new Claim("id_rol", "2") },
            expires: DateTime.UtcNow.AddDays(1),
            signingCredentials: new SigningCredentials(
                new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwtKey)),
                SecurityAlgorithms.HmacSha256));

        return Ok(new
        {
            token = new JwtSecurityTokenHandler().WriteToken(sessionToken),
            user = new
            {
                id,
                nombre = nombreCompleto,
                correo = email,
                id_rol = 2,
                telefono,
                universidad = "Universidad Popular del Cesar"
            }
        });
    }

    // =========================
    // LOGIN
    // =========================
    [AllowAnonymous]
    [HttpPost("login")]
    public async Task<IActionResult> Login([FromBody] LoginDTO dto)
    {
        using (NpgsqlConnection conn = new NpgsqlConnection(_config.GetConnectionString("DefaultConnection")))
        {
            await conn.OpenAsync();

            int id, idRol;
            string? nombreUser, correoUser;
            bool estado = true;

            var cmd = new NpgsqlCommand("SELECT id_usuario, id_rol, nombre, correo, password_hash, estado FROM usuarios WHERE correo = @correo", conn);
            cmd.Parameters.AddWithValue("@correo", dto.correo);

            using (var reader = await cmd.ExecuteReaderAsync())
            {
                if (!await reader.ReadAsync())
                    return NotFound(new { error = "Usuario no existe o contraseña incorrecta" });

                string hash = reader["password_hash"]?.ToString() ?? "";

                if (string.IsNullOrEmpty(hash) || !BCrypt.Net.BCrypt.Verify(dto.password, hash))
                    return Unauthorized(new { error = "Usuario no existe o contraseña incorrecta" });

                id = (int)reader["id_usuario"];
                idRol = reader["id_rol"] != DBNull.Value ? Convert.ToInt32(reader["id_rol"]) : 2;
                nombreUser = reader["nombre"]?.ToString();
                correoUser = reader["correo"]?.ToString();
                estado = reader["estado"] != DBNull.Value && (bool)reader["estado"];
            }

            if (!estado)
                return Unauthorized(new { error = "Tu cuenta ha sido suspendida. Contacta al administrador." });

            var updateAct = new NpgsqlCommand("UPDATE usuarios SET ultima_actividad = NOW() WHERE id_usuario = @id", conn);
            updateAct.Parameters.AddWithValue("@id", id);
            await updateAct.ExecuteNonQueryAsync();

            // JWT
            var jwtKey = _config["Jwt:Key"]!;
            var key = Encoding.UTF8.GetBytes(jwtKey);

            var token = new JwtSecurityToken(
                claims: new[] { new Claim("id", id.ToString()), new Claim("id_rol", idRol.ToString()) },
                expires: DateTime.UtcNow.AddDays(1),
                signingCredentials: new SigningCredentials(
                    new SymmetricSecurityKey(key),
                    SecurityAlgorithms.HmacSha256
                )
            );

            return Ok(new
            {
                token = new JwtSecurityTokenHandler().WriteToken(token),
                user = new
                {
                    id = id,
                    nombre = nombreUser,
                    correo = correoUser,
                    id_rol = idRol
                }
            });
        }
    }

    // =========================
    // LOGOUT (actualizar ultima_actividad)
    // =========================
    [AllowAnonymous]
    [HttpPost("logout")]
    public async Task<IActionResult> Logout([FromBody] LogoutDTO dto)
    {
        using var conn = new NpgsqlConnection(_config.GetConnectionString("DefaultConnection"));
        await conn.OpenAsync();

        var cmd = new NpgsqlCommand(
            "UPDATE usuarios SET ultima_actividad = NOW() WHERE id_usuario = @id", conn);
        cmd.Parameters.AddWithValue("@id", dto.id_usuario);
        await cmd.ExecuteNonQueryAsync();

        return Ok(new { ok = true });
    }

    // =========================
    // GOOGLE LOGIN
    // =========================
    [AllowAnonymous]
    [HttpPost("google-login")]
    public Task<IActionResult> GoogleLogin([FromBody] GoogleLoginDTO dto) => Task.FromResult<IActionResult>(StatusCode(403, new { error = "Verifica tu correo @unicesar.edu.co con un código" }));

    // =========================
    // FORGOT PASSWORD (ENVÍA CÓDIGO DE RECUPERACIÓN)
    // =========================
    [AllowAnonymous]
    [HttpPost("forgot-password")]
    public async Task<IActionResult> ForgotPassword([FromBody] EmailDTO data)
    {
        try
        {
            using var conn = new NpgsqlConnection(_config.GetConnectionString("DefaultConnection"));
            await conn.OpenAsync();

            var cmd = new NpgsqlCommand("SELECT COUNT(*) FROM usuarios WHERE correo = @correo", conn);
            cmd.Parameters.AddWithValue("@correo", data.correo);
            int existe = Convert.ToInt32(await cmd.ExecuteScalarAsync());

            if (existe == 0)
                return NotFound(new { error = "Correo no registrado" });

            var codigo = new Random().Next(100000, 999999).ToString();
            codigos[data.correo] = codigo;

            _ = Task.Delay(300000).ContinueWith(_ =>
            {
                if (codigos.ContainsKey(data.correo) && codigos[data.correo] == codigo)
                    codigos.Remove(data.correo);
            });

            _ = Task.Run(async () =>
            {
                try
                {
                    await _emailService.EnviarCodigoVerificacion(data.correo, codigo);
                }
                catch (Exception ex)
                {
                    Console.WriteLine($"[EMAIL] Error enviando código recuperación: {ex.Message}");
                }
            });

            return Ok(new { ok = true });
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { error = ex.Message });
        }
    }

    // =========================
    // RESET PASSWORD (GUARDA NUEVA CONTRASEÑA)
    // =========================
    [AllowAnonymous]
    [HttpPost("reset-password")]
    public async Task<IActionResult> ResetPassword([FromBody] ResetPasswordDTO dto)
    {
        if (string.IsNullOrEmpty(dto.codigo) ||
            !codigos.ContainsKey(dto.correo) ||
            codigos[dto.correo] != dto.codigo)
            return BadRequest(new { error = "Código de verificación inválido o expirado" });

        try
        {
            using var conn = new NpgsqlConnection(_config.GetConnectionString("DefaultConnection"));
            await conn.OpenAsync();

            string hash = BCrypt.Net.BCrypt.HashPassword(dto.nuevaPassword);

            var cmd = new NpgsqlCommand(
                "UPDATE usuarios SET password_hash = @hash WHERE correo = @correo", conn);
            cmd.Parameters.AddWithValue("@hash", hash);
            cmd.Parameters.AddWithValue("@correo", dto.correo);

            int filas = await cmd.ExecuteNonQueryAsync();
            if (filas == 0)
                return NotFound(new { error = "Usuario no encontrado" });

            codigos.Remove(dto.correo);

            return Ok(new { ok = true });
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { error = ex.Message });
        }
    }

    // =========================
    // CAMBIAR CONTRASEÑA (usuario autenticado)
    // =========================
    [HttpPost("change-password")]
    public async Task<IActionResult> ChangePassword([FromBody] ChangePasswordDTO dto)
    {
        try
        {
            var userIdClaim = User.FindFirst("id")?.Value;
            if (string.IsNullOrEmpty(userIdClaim))
                return Unauthorized(new { error = "Token inválido o expirado" });

            int userId = int.Parse(userIdClaim);

            if (string.IsNullOrEmpty(dto.ContrasenaActual) || string.IsNullOrEmpty(dto.ContrasenaNueva))
                return BadRequest(new { error = "Todos los campos son requeridos" });

            if (dto.ContrasenaNueva.Length < 8)
                return BadRequest(new { error = "La nueva contraseña debe tener al menos 8 caracteres" });

            using var conn = new NpgsqlConnection(_config.GetConnectionString("DefaultConnection"));
            await conn.OpenAsync();

            var cmd = new NpgsqlCommand("SELECT password_hash FROM usuarios WHERE id_usuario = @id", conn);
            cmd.Parameters.AddWithValue("@id", userId);

            var hash = (string?)await cmd.ExecuteScalarAsync();
            if (string.IsNullOrEmpty(hash))
                return NotFound(new { error = "Usuario no encontrado" });

            if (!BCrypt.Net.BCrypt.Verify(dto.ContrasenaActual, hash))
                return BadRequest(new { error = "La contraseña actual es incorrecta" });

            string nuevoHash = BCrypt.Net.BCrypt.HashPassword(dto.ContrasenaNueva);
            var updateCmd = new NpgsqlCommand(
                "UPDATE usuarios SET password_hash = @hash WHERE id_usuario = @id", conn);
            updateCmd.Parameters.AddWithValue("@hash", nuevoHash);
            updateCmd.Parameters.AddWithValue("@id", userId);

            await updateCmd.ExecuteNonQueryAsync();
            return Ok(new { ok = true });
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { error = ex.Message });
        }
    }

    // =========================
    // CAMBIAR CORREO (usuario autenticado)
    // =========================
    [HttpPost("change-email")]
    public Task<IActionResult> ChangeEmail([FromBody] ChangeEmailDTO dto) => Task.FromResult<IActionResult>(StatusCode(403, new { error = "El cambio de correo verificado requiere un proceso supervisado" }));

    // =========================
    // VERIFICAR CONTRASEÑA MAESTRA DE ADMIN
    // =========================
    private static readonly Dictionary<int, (int intentos, DateTime bloqueadoHasta)> _adminAttempts = new();

    [HttpPost("verify-admin-master")]
    public IActionResult VerifyAdminMaster([FromBody] VerifyAdminMasterDTO dto)
    {
        try
        {
            var userIdClaim = User.FindFirst("id")?.Value;
            var rolClaim = User.FindFirst("id_rol")?.Value;

            if (string.IsNullOrEmpty(userIdClaim))
                return Unauthorized(new { error = "Token inválido o expirado" });

            if (rolClaim != "1")
                return StatusCode(403, new { error = "No tienes permisos de administrador" });

            int userId = int.Parse(userIdClaim);

            var entry = (intentos: 0, bloqueadoHasta: default(DateTime));

            if (_adminAttempts.TryGetValue(userId, out var storedEntry))
            {
                if (storedEntry.bloqueadoHasta > DateTime.UtcNow)
                {
                    var minutosRestantes = (int)Math.Ceiling((storedEntry.bloqueadoHasta - DateTime.UtcNow).TotalMinutes);
                    return StatusCode(429, new { error = $"Demasiados intentos. Intenta de nuevo en {minutosRestantes} minuto(s).", bloqueado = true });
                }

                if (storedEntry.bloqueadoHasta != default)
                    _adminAttempts.Remove(userId);
            }

            // Sin hash configurado no hay contraseña maestra válida (antes había una por defecto en el código).
            var storedHash = _config["Admin:MasterPasswordHash"];
            if (string.IsNullOrWhiteSpace(storedHash))
                return StatusCode(503, new { error = "La contraseña maestra de administrador no está configurada" });

            if (!BCrypt.Net.BCrypt.Verify(dto.MasterPassword, storedHash))
            {
                var nuevosIntentos = entry.intentos + 1;
                if (nuevosIntentos >= 3)
                {
                    var bloqueoHasta = DateTime.UtcNow.AddMinutes(10);
                    _adminAttempts[userId] = (nuevosIntentos, bloqueoHasta);
                    return BadRequest(new { error = "Demasiados intentos fallidos. Cuenta bloqueada por 10 minutos.", bloqueado = true });
                }

                _adminAttempts[userId] = (nuevosIntentos, default);
                return BadRequest(new { error = $"Contraseña maestra incorrecta. Intento {nuevosIntentos} de 3.", intentos = nuevosIntentos });
            }

            _adminAttempts.Remove(userId);
            return Ok(new { ok = true });
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { error = ex.Message });
        }
    }
}