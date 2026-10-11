using System.Net.Mail;
using System.Security.Claims;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Filters;
using Npgsql;

namespace UniserviceAPI.Services;

public static class InstitutionalAccess
{
    public static string? NormalizeEmail(string? value)
    {
        var normalized = value?.Trim().ToLowerInvariant();
        if (normalized == null || normalized.Length > 100 ||
            !MailAddress.TryCreate(normalized, out var address) ||
            address.Address != normalized || address.Host != "unicesar.edu.co" ||
            !System.Text.RegularExpressions.Regex.IsMatch(normalized, "^[a-z0-9][a-z0-9._+-]*@unicesar[.]edu[.]co$")) return null;
        return normalized;
    }

    public static int? UserId(ClaimsPrincipal user) =>
        int.TryParse(user.FindFirst("id")?.Value, out var id) && id > 0 ? id : null;
}

// Nombre conservado por compatibilidad: verifica acceso institucional, no matrícula.
public sealed class ActiveStudentFilter(IConfiguration config) : IAsyncActionFilter
{
    public async Task OnActionExecutionAsync(ActionExecutingContext context, ActionExecutionDelegate next)
    {
        var id = InstitutionalAccess.UserId(context.HttpContext.User);
        if (id == null)
        {
            context.Result = new UnauthorizedObjectResult(new { error = "Sesión inválida" });
            return;
        }
        await using var conn = new NpgsqlConnection(config.GetConnectionString("DefaultConnection"));
        await conn.OpenAsync(context.HttpContext.RequestAborted);
        await using var cmd = new NpgsqlCommand("""
            SELECT EXISTS (SELECT 1 FROM usuarios u WHERE u.id_usuario = @id AND u.estado = true AND (
              EXISTS (SELECT 1 FROM verificaciones_correo_institucional v WHERE v.id_usuario = u.id_usuario
                AND v.correo = lower(trim(u.correo)) AND v.verificado_hasta > now())
              OR EXISTS (SELECT 1 FROM identidades_institucionales i WHERE i.id_usuario = u.id_usuario AND i.verificado_hasta > now())
            ))
            """, conn);
        cmd.Parameters.AddWithValue("id", id.Value);
        if (await cmd.ExecuteScalarAsync(context.HttpContext.RequestAborted) is not true)
        {
            context.Result = new ObjectResult(new { error = "Verifica tu correo institucional para continuar" }) { StatusCode = 403 };
            return;
        }
        await next();
    }
}
