using Microsoft.AspNetCore.SignalR;

namespace UniserviceAPI.Hubs;

public class ChatHub : Hub
{
    private static readonly Dictionary<string, int> _userConnections = new();
    private static readonly Dictionary<int, HashSet<string>> _userGroups = new();

    public async Task ConectarUsuario(int usuarioId)
    {
        _userConnections[Context.ConnectionId] = usuarioId;

        if (!_userGroups.ContainsKey(usuarioId))
            _userGroups[usuarioId] = new HashSet<string>();

        _userGroups[usuarioId].Add(Context.ConnectionId);

        await Clients.All.SendAsync("UsuarioConectado", usuarioId);
    }

    public async Task EnviarMensajeDirecto(int idChat, int remitenteId, int destinatarioId, string mensaje, string tipo = "texto")
    {
        var mensajeData = new
        {
            id_chat = idChat,
            id_remitente = remitenteId,
            id_destinatario = destinatarioId,
            mensaje = mensaje,
            tipo = tipo,
            fecha_envio = DateTime.UtcNow.ToString("o")
        };

        if (_userGroups.ContainsKey(destinatarioId))
        {
            foreach (var connId in _userGroups[destinatarioId])
            {
                await Clients.Client(connId).SendAsync("RecibirMensaje", mensajeData);
            }
        }

        await Clients.Caller.SendAsync("MensajeEnviado", mensajeData);
    }

    public async Task NotificarNuevoChat(int idChat, int remitenteId, int destinatarioId, string nombreRemitente, string previewMensaje)
    {
        var notificacion = new
        {
            id_chat = idChat,
            id_remitente = remitenteId,
            nombre_remitente = nombreRemitente,
            preview_mensaje = previewMensaje
        };

        if (_userGroups.ContainsKey(destinatarioId))
        {
            foreach (var connId in _userGroups[destinatarioId])
            {
                await Clients.Client(connId).SendAsync("NuevoChatNotification", notificacion);
            }
        }
    }

    public async Task MarcarLeidoNotificacion(int chatId, int usuarioId)
    {
        await Clients.OthersInGroup($"chat_{chatId}").SendAsync("MensajesLeidos", new { id_chat = chatId });
    }

    public async Task UnirseChat(int chatId)
    {
        await Groups.AddToGroupAsync(Context.ConnectionId, $"chat_{chatId}");
    }

    public async Task SalirChat(int chatId)
    {
        await Groups.RemoveFromGroupAsync(Context.ConnectionId, $"chat_{chatId}");
    }

    public async Task EnviarEscribiendo(int chatId, int usuarioId, bool escribiendo)
    {
        await Clients.OthersInGroup($"chat_{chatId}").SendAsync("UsuarioEscribiendo", new
        {
            id_chat = chatId,
            id_usuario = usuarioId,
            escribiendo = escribiendo
        });
    }

    public override async Task OnDisconnectedAsync(Exception? exception)
    {
        if (_userConnections.TryGetValue(Context.ConnectionId, out var usuarioId))
        {
            _userConnections.Remove(Context.ConnectionId);

            if (_userGroups.ContainsKey(usuarioId))
            {
                _userGroups[usuarioId].Remove(Context.ConnectionId);

                if (_userGroups[usuarioId].Count == 0)
                {
                    _userGroups.Remove(usuarioId);
                    await Clients.All.SendAsync("UsuarioDesconectado", usuarioId);
                }
            }
        }

        await base.OnDisconnectedAsync(exception);
    }
}
