using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Filters;
using Microsoft.Extensions.Caching.Memory;
using Npgsql;

namespace UniserviceAPI.Services;

public sealed record AccountState(bool Activa, int Rol);

// Estado de cuenta leído de la BD (no del JWT): una suspensión o un cambio de rol
// aplica en segundos aunque el token del usuario siga vigente.
public sealed class AccountStatus(IConfiguration config, IMemoryCache cache)
{
    private static readonly TimeSpan Ttl = TimeSpan.FromSeconds(30);
    private static string Key(int id) => $"cuenta:{id}";

    public async Task<AccountState?> Get(int id, CancellationToken ct)
    {
        if (cache.TryGetValue(Key(id), out AccountState? cached)) return cached;
        await using var conn = new NpgsqlConnection(config.GetConnectionString("DefaultConnection"));
        await conn.OpenAsync(ct);
        await using var cmd = new NpgsqlCommand(
            "SELECT estado IS TRUE, COALESCE(id_rol, 2) FROM usuarios WHERE id_usuario = @id", conn);
        cmd.Parameters.AddWithValue("id", id);
        await using var reader = await cmd.ExecuteReaderAsync(ct);
        AccountState? state = await reader.ReadAsync(ct) ? new(reader.GetBoolean(0), reader.GetInt32(1)) : null;
        cache.Set(Key(id), state, Ttl);
        return state;
    }

    public void Invalidate(int id) => cache.Remove(Key(id));
}

// Filtro global: rechaza peticiones autenticadas de cuentas suspendidas o eliminadas.
public sealed class ActiveAccountFilter(AccountStatus status) : IAsyncActionFilter
{
    public async Task OnActionExecutionAsync(ActionExecutingContext context, ActionExecutionDelegate next)
    {
        var anonymous = context.ActionDescriptor.EndpointMetadata.Any(m => m is IAllowAnonymous);
        var id = InstitutionalAccess.UserId(context.HttpContext.User);
        if (!anonymous && id != null)
        {
            var state = await status.Get(id.Value, context.HttpContext.RequestAborted);
            if (state is not { Activa: true })
            {
                context.Result = new ObjectResult(new { error = "Tu cuenta ha sido suspendida. Contacta al administrador.", suspendida = true }) { StatusCode = 403 };
                return;
            }
        }
        await next();
    }
}

public sealed class AdminFilter(AccountStatus status) : IAsyncActionFilter
{
    public async Task OnActionExecutionAsync(ActionExecutingContext context, ActionExecutionDelegate next)
    {
        var id = InstitutionalAccess.UserId(context.HttpContext.User);
        var state = id == null ? null : await status.Get(id.Value, context.HttpContext.RequestAborted);
        if (state is not { Activa: true, Rol: 1 })
        {
            context.Result = new ObjectResult(new { error = "No tienes permisos de administrador" }) { StatusCode = 403 };
            return;
        }
        await next();
    }
}

// Exige rol administrador (id_rol = 1) y cuenta activa, comprobados contra la BD.
public sealed class AdminOnlyAttribute() : TypeFilterAttribute(typeof(AdminFilter));
