using System.Collections.Concurrent;
using Microsoft.AspNetCore.SignalR;

namespace UniserviceAPI.Services;

// Un único registro por proceso; no conserva instancias de Hub (son transitorias).
// Además de filtrar invocaciones, vigila conexiones ociosas que sólo reciben eventos.
public sealed class ChatSessionGuard : BackgroundService, IHubFilter
{
    private static readonly TimeSpan Intervalo = TimeSpan.FromSeconds(5);
    private static readonly TimeSpan TimeoutConsulta = TimeSpan.FromSeconds(5);
    private readonly AccountStatus _cuentas;
    private readonly ILogger<ChatSessionGuard> _logger;
    private readonly ConcurrentDictionary<string, Conexion> _conexiones = new();
    private sealed record Conexion(int Usuario, HubCallerContext Contexto);

    public ChatSessionGuard(AccountStatus cuentas, ILogger<ChatSessionGuard> logger)
    {
        _cuentas = cuentas;
        _logger = logger;
        _cuentas.Invalidated += CerrarUsuario;
    }

    public async Task OnConnectedAsync(HubLifetimeContext context, Func<HubLifetimeContext, Task> next)
    {
        var caller = context.Context;
        var id = InstitutionalAccess.UserId(caller.User!);
        if (id == null) { caller.Abort(); return; }

        // Registrar ANTES de consultar evita perder una revocación durante la conexión.
        _conexiones[caller.ConnectionId] = new(id.Value, caller);
        try
        {
            await Validar(caller);
            await next(context);
        }
        catch
        {
            Cerrar(caller);
            throw;
        }
    }

    public async ValueTask<object?> InvokeMethodAsync(HubInvocationContext context,
        Func<HubInvocationContext, ValueTask<object?>> next)
    {
        // Cubre todos los métodos actuales y futuros, incluido "escribiendo".
        await Validar(context.Context);
        return await next(context);
    }

    public async Task OnDisconnectedAsync(HubLifetimeContext context, Exception? exception,
        Func<HubLifetimeContext, Exception?, Task> next)
    {
        _conexiones.TryRemove(context.Context.ConnectionId, out _);
        await next(context, exception);
    }

    private static bool Vigente(HubCallerContext context, AccountState? cuenta)
    {
        var user = context.User!;
        return !context.ConnectionAborted.IsCancellationRequested
            && cuenta is { Activa: true }
            && Sesiones.EmitidoEn(user) > 0
            && Sesiones.EmitidoEn(user) >= cuenta.SesionesDesde
            && long.TryParse(user.FindFirst("exp")?.Value, out var exp)
            && exp > DateTimeOffset.UtcNow.ToUnixTimeSeconds();
    }

    private async Task Validar(HubCallerContext context)
    {
        try
        {
            using var timeout = CancellationTokenSource.CreateLinkedTokenSource(context.ConnectionAborted);
            timeout.CancelAfter(TimeoutConsulta);
            var id = InstitutionalAccess.UserId(context.User!);
            if (id != null && Vigente(context, await _cuentas.GetFresh(id.Value, timeout.Token))) return;
        }
        catch (Exception ex)
        {
            if (!context.ConnectionAborted.IsCancellationRequested)
                _logger.LogWarning("No se pudo validar la sesión de chat: {Tipo}", ex.GetType().Name);
        }
        // Ante un fallo de BD no se deja una conexión sin autorización comprobable.
        Cerrar(context);
        throw new HubException("Tu sesión de chat terminó. Conecta de nuevo.");
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        using var timer = new PeriodicTimer(Intervalo);
        try
        {
            while (await timer.WaitForNextTickAsync(stoppingToken))
            {
                // Una consulta por usuario y revisión, aunque tenga varios dispositivos.
                var usuarios = _conexiones.Values.ToArray().GroupBy(c => c.Usuario);
                await Parallel.ForEachAsync(usuarios,
                    new ParallelOptions { CancellationToken = stoppingToken, MaxDegreeOfParallelism = 8 },
                    async (conexiones, ct) =>
                    {
                        AccountState? cuenta = null;
                        try
                        {
                            using var timeout = CancellationTokenSource.CreateLinkedTokenSource(ct);
                            timeout.CancelAfter(TimeoutConsulta);
                            cuenta = await _cuentas.GetFresh(conexiones.Key, timeout.Token);
                        }
                        catch (Exception ex)
                        {
                            if (!ct.IsCancellationRequested)
                                _logger.LogWarning("No se pudo revisar la sesión de chat: {Tipo}", ex.GetType().Name);
                        }
                        foreach (var conexion in conexiones)
                            if (!Vigente(conexion.Contexto, cuenta)) Cerrar(conexion.Contexto);
                    });
            }
        }
        catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested) { }
    }

    private void CerrarUsuario(int id)
    {
        foreach (var conexion in _conexiones.Values)
            if (conexion.Usuario == id) Cerrar(conexion.Contexto);
    }

    private void Cerrar(HubCallerContext context)
    {
        _conexiones.TryRemove(context.ConnectionId, out _);
        context.Abort();
    }

    public override void Dispose()
    {
        _cuentas.Invalidated -= CerrarUsuario;
        foreach (var conexion in _conexiones.Values) Cerrar(conexion.Contexto);
        base.Dispose();
    }
}
