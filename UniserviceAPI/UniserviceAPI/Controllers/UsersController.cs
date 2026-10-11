using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.IdentityModel.Tokens;
using Npgsql;

[ApiController]
[Route("api/[controller]")]
public class UsersController : ControllerBase
{
    private readonly IConfiguration _config;

    public UsersController(IConfiguration config)
    {
        _config = config;
    }

    // 🔹 LOGIN ACTUALIZADO PARA ID_ROL (1=Admin, 2=User)
    [AllowAnonymous]
    [HttpPost("login")]
    public async Task<IActionResult> Login([FromBody] LoginDTO dto)
    {
        try
        {
            using var conn = new NpgsqlConnection(_config.GetConnectionString("DefaultConnection"));
            await conn.OpenAsync();

            // Buscamos al usuario incluyendo la columna id_rol que vimos en tu DB
            using var cmd = new NpgsqlCommand("SELECT * FROM usuarios WHERE correo = @correo", conn);
            cmd.Parameters.AddWithValue("@correo", dto.correo);

            using var reader = await cmd.ExecuteReaderAsync();

            if (!await reader.ReadAsync())
                return NotFound(new { message = "Usuario no existe" });

            string hash = reader["password_hash"]?.ToString()?.Trim() ?? "";
            bool valid = BCrypt.Net.BCrypt.Verify(dto.password, hash);

            if (!valid)
                return Unauthorized(new { message = "Contraseña incorrecta" });

            int id = (int)reader["id_usuario"];
            int idRol = reader["id_rol"] != DBNull.Value ? Convert.ToInt32(reader["id_rol"]) : 2;

            bool estado = reader["estado"] != DBNull.Value && (bool)reader["estado"];
            if (!estado)
                return Unauthorized(new { message = "Tu cuenta ha sido suspendida. Contacta al administrador." });

            // Actualizar ultima_actividad al hacer login
            var updateAct = new NpgsqlCommand("UPDATE usuarios SET ultima_actividad = NOW() WHERE id_usuario = @id", conn);
            updateAct.Parameters.AddWithValue("@id", id);
            await updateAct.ExecuteNonQueryAsync();

            // 🔐 GENERAR TOKEN
            var jwtKey = _config["Jwt:Key"] ?? "ClaveSuperSecretaDeRespaldo_UniServices_2026";
            var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwtKey));
            var creds = new SigningCredentials(key, SecurityAlgorithms.HmacSha256);

            var claims = new[]
            {
                new Claim("id", id.ToString()),
                new Claim("id_rol", idRol.ToString()) // Guardamos el rol en el token
            };

            var token = new JwtSecurityToken(
                claims: claims,
                expires: DateTime.Now.AddDays(1),
                signingCredentials: creds
            );

            var tokenString = new JwtSecurityTokenHandler().WriteToken(token);

            // 3. Respuesta para React con id_rol
            return Ok(new
            {
                token = tokenString,
                user = new
                {
                    id = id,
                    nombre = reader["nombre"]?.ToString(),
                    correo = reader["correo"]?.ToString(),
                    id_rol = idRol // 👈 React usará esto para redirigir al admin
                }
            });
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { error = ex.Message });
        }
    }

    // 🔹 GET USER BY ID (Para el Perfil)
    [HttpGet("{id}")]
    public async Task<IActionResult> GetUserById(int id)
    {
        try
        {
            using var conn = new NpgsqlConnection(_config.GetConnectionString("DefaultConnection"));
            await conn.OpenAsync();

            string sql = @"
            SELECT 
                u.id_usuario, u.nombre, u.correo, u.estado, u.id_rol, u.ultima_actividad,
                COALESCE(u.avatar, '../src/img/default-avatar.png') as avatar, 
                COALESCE(u.descripcion, 'Sin descripción') as descripcion, 
                COALESCE(u.telefono, 'No disponible') as telefono, 
                COALESCE(u.fecha_registro, NOW()) as fecha_registro, 
                COALESCE(u.universidad, 'Sin universidad') as universidad,
                (SELECT COUNT(*) FROM seguidores WHERE id_seguido  = u.id_usuario) as total_seguidores,
                (SELECT COUNT(*) FROM seguidores WHERE id_seguidor = u.id_usuario) as total_siguiendo,
                (SELECT COUNT(*) FROM servicios  WHERE id_proveedor = u.id_usuario) as total_publicaciones,
                (SELECT AVG(CAST(puntuacion AS FLOAT)) FROM calificaciones WHERE id_servicio IN (SELECT id_servicio FROM servicios WHERE id_proveedor = u.id_usuario)) as reputacion
            FROM usuarios u
            WHERE u.id_usuario = @id";

            using var cmd = new NpgsqlCommand(sql, conn);
            cmd.Parameters.AddWithValue("@id", id);

            using var reader = await cmd.ExecuteReaderAsync();

            if (await reader.ReadAsync())
            {
                return Ok(new
                {
                    id = (int)reader["id_usuario"],
                    nombre = reader["nombre"]?.ToString(),
                    correo = reader["correo"]?.ToString(),
                    estado = reader["estado"],
                    id_rol = Convert.ToInt32(reader["id_rol"]),
                    avatar = reader["avatar"]?.ToString(),
                    descripcion = reader["descripcion"]?.ToString(),
                    telefono = reader["telefono"]?.ToString(),
                    fecha_registro = (DateTime)reader["fecha_registro"],
                    universidad = reader["universidad"]?.ToString(),
                    ultima_actividad = reader["ultima_actividad"] != DBNull.Value ? (DateTime?)reader["ultima_actividad"] : null,
                    total_seguidores = reader["total_seguidores"] == DBNull.Value ? 0 : Convert.ToInt32(reader["total_seguidores"]),
                    total_siguiendo = reader["total_siguiendo"] == DBNull.Value ? 0 : Convert.ToInt32(reader["total_siguiendo"]),
                    total_publicaciones = reader["total_publicaciones"] == DBNull.Value ? 0 : Convert.ToInt32(reader["total_publicaciones"]),
                    reputacion = reader["reputacion"] == DBNull.Value ? (double?)null : (double)reader["reputacion"],
                });
            }
            return NotFound(new { message = "Usuario no encontrado" });
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { error = "Error en SQL: " + ex.Message });
        }
    }

    // 🔹 UPDATE USER (PUT /api/users/{id})
    [HttpPut("{id}")]
    public async Task<IActionResult> UpdateUser(int id, [FromBody] UpdateUserDTO dto)
    {
        if (UniserviceAPI.Services.InstitutionalAccess.UserId(User) != id && User.FindFirst("id_rol")?.Value != "1")
            return StatusCode(403);
        if (dto.estado != null && User.FindFirst("id_rol")?.Value != "1")
            return StatusCode(403);
        try
        {
            using var conn = new NpgsqlConnection(_config.GetConnectionString("DefaultConnection"));
            await conn.OpenAsync();

            var fields = new List<string>();
            var cmd = new NpgsqlCommand("", conn);

            if (dto.nombre != null)
            {
                fields.Add("nombre = @nombre");
                cmd.Parameters.AddWithValue("@nombre", dto.nombre);
            }
            if (dto.descripcion != null)
            {
                fields.Add("descripcion = @descripcion");
                cmd.Parameters.AddWithValue("@descripcion", dto.descripcion);
            }
            if (dto.telefono != null)
            {
                fields.Add("telefono = @telefono");
                cmd.Parameters.AddWithValue("@telefono", dto.telefono);
            }
            if (dto.universidad != null)
            {
                fields.Add("universidad = @universidad");
                cmd.Parameters.AddWithValue("@universidad", dto.universidad);
            }
            if (dto.avatar != null)
            {
                fields.Add("avatar = @avatar");
                cmd.Parameters.AddWithValue("@avatar", dto.avatar);
            }
            if (dto.estado != null)
            {
                fields.Add("estado = @estado");
                bool estadoBool = dto.estado switch
                {
                    bool b => b,
                    int i => i != 0,
                    long l => l != 0,
                    string s => s == "1" || s.ToLower() == "true" || s.ToLower() == "activo",
                    _ => true
                };
                cmd.Parameters.AddWithValue("@estado", NpgsqlTypes.NpgsqlDbType.Boolean, estadoBool);
            }

            if (fields.Count == 0)
                return BadRequest(new { error = "No hay campos para actualizar" });

            cmd.CommandText = $"UPDATE usuarios SET {string.Join(", ", fields)} WHERE id_usuario = @id";
            cmd.Parameters.AddWithValue("@id", id);

            int filas = await cmd.ExecuteNonQueryAsync();
            if (filas == 0)
                return NotFound(new { error = "Usuario no encontrado" });

            return Ok(new { ok = true });
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { error = ex.Message });
        }
    }

    // 🔹 DELETE USER (DELETE /api/users/{id})
    [HttpDelete("{id}")]
    public async Task<IActionResult> DeleteUser(int id)
    {
        if (User.FindFirst("id_rol")?.Value != "1") return StatusCode(403);
        try
        {
            using var conn = new NpgsqlConnection(_config.GetConnectionString("DefaultConnection"));
            await conn.OpenAsync();

            using var cmd = new NpgsqlCommand("DELETE FROM usuarios WHERE id_usuario = @id", conn);
            cmd.Parameters.AddWithValue("@id", id);

            int filas = await cmd.ExecuteNonQueryAsync();
            if (filas == 0)
                return NotFound(new { error = "Usuario no encontrado" });

            return Ok(new { ok = true });
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { error = ex.Message });
        }
    }

    //METODO PARA OBTENER TODOS LOS USUARIOS (PARA ADMIN)
    [HttpGet]
    public async Task<IActionResult> GetAllUsers()
    {
        if (User.FindFirst("id_rol")?.Value != "1") return StatusCode(403);
        try
        {
            using var conn = new NpgsqlConnection(_config.GetConnectionString("DefaultConnection"));
            await conn.OpenAsync();
            string sql = "SELECT id_usuario, nombre, correo, estado, id_rol FROM usuarios";
            using var cmd = new NpgsqlCommand(sql, conn);
            using var reader = await cmd.ExecuteReaderAsync();
            var users = new List<object>();
            while (await reader.ReadAsync())
            {
                users.Add(new
                {
                    id = (int)reader["id_usuario"],
                    nombre = reader["nombre"]?.ToString(),
                    correo = reader["correo"]?.ToString(),
                    estado = reader["estado"],
                    id_rol = Convert.ToInt32(reader["id_rol"])
                });
            }
            return Ok(users);
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { error = "Error en SQL: " + ex.Message });
        }
    }
}
