using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Filters;
using System.Security.Claims;

namespace UniserviceAPI.Filters
{
    /// <summary>
    /// Extrae el ID del usuario autenticado desde el JWT.
    /// Uso: var userId = AuthHelper.GetUserId(User); en cualquier controller.
    /// </summary>
    public static class AuthHelper
    {
        public static int? GetUserId(ClaimsPrincipal user)
        {
            var claim = user.FindFirst("id")?.Value;
            return string.IsNullOrEmpty(claim) ? null : int.Parse(claim);
        }

        public static int? GetUserRole(ClaimsPrincipal user)
        {
            var claim = user.FindFirst("id_rol")?.Value;
            return string.IsNullOrEmpty(claim) ? null : int.Parse(claim);
        }

        public static bool IsAdmin(ClaimsPrincipal user)
        {
            return GetUserRole(user) == 1;
        }
    }
}
