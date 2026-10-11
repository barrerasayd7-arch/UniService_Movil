using Microsoft.AspNetCore.Mvc;
using Npgsql;
using Microsoft.Extensions.Configuration;
using System;
using System.Data;
using System.Threading.Tasks;

[ApiController]
[Route("api/[controller]")]
public class SeguidoresController : ControllerBase
{
    private readonly IConfiguration _config;

    public SeguidoresController(IConfiguration config)
    {
        _config = config;
    }

    // ?? TOGGLE (seguir / dejar de seguir)
    [HttpPost("toggle")]
    public async Task<IActionResult> ToggleSeguimiento([FromBody] SeguimientoDTO dto)
    {
        try
        {
            using var conn = new NpgsqlConnection(_config.GetConnectionString("DefaultConnection"));
            await conn.OpenAsync();

            if (dto.id_seguidor == dto.id_seguido)
                return BadRequest(new { error = "Un usuario no puede seguirse a sí mismo." });

            using var checkCmd = new NpgsqlCommand(
                "SELECT COUNT(*) FROM seguidores WHERE id_seguidor = @seguidor AND id_seguido = @seguido", conn);
            checkCmd.Parameters.AddWithValue("@seguidor", dto.id_seguidor);
            checkCmd.Parameters.AddWithValue("@seguido", dto.id_seguido);
            int existe = Convert.ToInt32(await checkCmd.ExecuteScalarAsync());

            if (existe > 0)
            {
                using var delCmd = new NpgsqlCommand(
                    "DELETE FROM seguidores WHERE id_seguidor = @seguidor AND id_seguido = @seguido", conn);
                delCmd.Parameters.AddWithValue("@seguidor", dto.id_seguidor);
                delCmd.Parameters.AddWithValue("@seguido", dto.id_seguido);
                await delCmd.ExecuteNonQueryAsync();
                return Ok(new { resultado = "Dejado de seguir" });
            }
            else
            {
                using var insCmd = new NpgsqlCommand(
                    "INSERT INTO seguidores (id_seguidor, id_seguido) VALUES (@seguidor, @seguido)", conn);
                insCmd.Parameters.AddWithValue("@seguidor", dto.id_seguidor);
                insCmd.Parameters.AddWithValue("@seguido", dto.id_seguido);
                await insCmd.ExecuteNonQueryAsync();
                return Ok(new { resultado = "Siguiendo" });
            }
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { error = ex.Message });
        }
    }

    // ?? ESTADO (si sigue o no)
    [HttpGet("estado")]
    public async Task<IActionResult> EstadoSeguimiento(int seguidor, int seguido)
    {
        try
        {
            using var conn = new NpgsqlConnection(_config.GetConnectionString("DefaultConnection"));
            await conn.OpenAsync();

            using var cmd = new NpgsqlCommand(@"
                SELECT COUNT(*) 
                FROM seguidores 
                WHERE id_seguidor = @seguidor AND id_seguido = @seguido
            ", conn);

            cmd.Parameters.AddWithValue("@seguidor", seguidor);
            cmd.Parameters.AddWithValue("@seguido", seguido);

            int total = Convert.ToInt32(await cmd.ExecuteScalarAsync());

            return Ok(new { sigues = total > 0 });
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { error = ex.Message });
        }
    }
    // GET /api/seguidores/lista?id_usuario=X
    [HttpGet("lista")]
    public async Task<IActionResult> ListaSeguidores(int id_usuario)
    {
        try
        {
            using var conn = new NpgsqlConnection(_config.GetConnectionString("DefaultConnection"));
            await conn.OpenAsync();

            using var cmd = new NpgsqlCommand(@"
            SELECT u.id_usuario, u.nombre, u.universidad, u.avatar
            FROM seguidores s
            INNER JOIN usuarios u ON s.id_seguidor = u.id_usuario
            WHERE s.id_seguido = @id_usuario
        ", conn);

            cmd.Parameters.AddWithValue("@id_usuario", id_usuario);

            var lista = new List<object>();
            using var reader = await cmd.ExecuteReaderAsync();
            while (await reader.ReadAsync())
            {
                lista.Add(new
                {
                    id_usuario = (int)reader["id_usuario"],
                    nombre = reader["nombre"]?.ToString(),
                    universidad = reader["universidad"]?.ToString(),
                    avatar = reader["avatar"]?.ToString()
                });
            }

            return Ok(lista);
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { error = ex.Message });
        }
    }
    // GET /api/seguidores/siguiendo?id_usuario=X
    [HttpGet("siguiendo")]
    public async Task<IActionResult> ListaSiguiendo(int id_usuario)
    {
        try
        {
            using var conn = new NpgsqlConnection(_config.GetConnectionString("DefaultConnection"));
            await conn.OpenAsync();

            using var cmd = new NpgsqlCommand(@"
            SELECT u.id_usuario, u.nombre, u.universidad, u.avatar
            FROM seguidores s
            INNER JOIN usuarios u ON s.id_seguido = u.id_usuario
            WHERE s.id_seguidor = @id_usuario
        ", conn);

            cmd.Parameters.AddWithValue("@id_usuario", id_usuario);

            var lista = new List<object>();
            using var reader = await cmd.ExecuteReaderAsync();
            while (await reader.ReadAsync())
            {
                lista.Add(new
                {
                    id_usuario = (int)reader["id_usuario"],
                    nombre = reader["nombre"]?.ToString(),
                    universidad = reader["universidad"]?.ToString(),
                    avatar = reader["avatar"]?.ToString()
                });
            }

            return Ok(lista);
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { error = ex.Message });
        }
    }
}