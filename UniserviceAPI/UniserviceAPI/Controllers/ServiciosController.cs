using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http.Features;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Configuration;
using Npgsql;
using UniserviceAPI.DTOs;
using UniserviceAPI.Services;

[ApiController]
[Route("api/[controller]")]
public class ServicesController : ControllerBase
{
    private readonly IConfiguration _config;
    private readonly SupabaseStorageService _storageService;
    private readonly UniserviceAPI.Services.EmailService _emailService;

    public ServicesController(IConfiguration config, SupabaseStorageService storageService, UniserviceAPI.Services.EmailService emailService)
    {
        _config = config;
        _storageService = storageService;
        _emailService = emailService;
    }

    // =========================
    // GET TODOS LOS SERVICIOS (ADMIN - INCLUYE PENDIENTES)
    // =========================
    [HttpGet("admin/all")]
    public async Task<IActionResult> GetAllAdmin()
    {
        try
        {
            using var conn = new NpgsqlConnection(_config.GetConnectionString("DefaultConnection"));
            await conn.OpenAsync();

            var servicios = new List<object>();

            using var cmd = new NpgsqlCommand(@"
                SELECT 
                    s.id_servicio, s.id_proveedor, s.titulo, s.descripcion,
                    s.precio_hora, s.icono, s.fecha_publicacion, s.modalidad,
                    s.disponibilidad, c.nombre_categoria, u.nombre AS proveedor, u.universidad
                FROM servicios s
                LEFT JOIN usuarios u ON s.id_proveedor = u.id_usuario
                LEFT JOIN categorias c ON s.id_categoria = c.id_categoria
                ORDER BY s.fecha_publicacion DESC
            ", conn);

            using var reader = await cmd.ExecuteReaderAsync();
            while (await reader.ReadAsync())
            {
                servicios.Add(new
                {
                    id_servicio = Convert.ToInt32(reader["id_servicio"]),
                    id_proveedor = reader["id_proveedor"] != DBNull.Value ? Convert.ToInt32(reader["id_proveedor"]) : 0,
                    titulo = reader["titulo"]?.ToString(),
                    descripcion = reader["descripcion"]?.ToString(),
                    precio_hora = reader["precio_hora"],
                    icono = reader["icono"]?.ToString() ?? "bi-pin",
                    fecha_publicacion = reader["fecha_publicacion"] != DBNull.Value ? Convert.ToDateTime(reader["fecha_publicacion"]).ToString("yyyy-MM-dd") : "",
                    modalidad = MapModalidad(reader["modalidad"]),
                    disponibilidad = MapDisponibilidad(reader["disponibilidad"]),
                    nombre_categoria = reader["nombre_categoria"]?.ToString(),
                    proveedor = reader["proveedor"]?.ToString(),
                    universidad = reader["universidad"]?.ToString()
                });
            }
            reader.Close();

            return Ok(servicios);
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { error = ex.Message });
        }
    }

    // =========================
    // GET TODOS LOS SERVICIOS (CON PAGINACIÓN Y FILTROS)
    // =========================
    // Soporta: ?page=1&pageSize=8&categoria=1&busqueda=texto&orden=recientes
    // También mantiene compatibilidad: sin parámetros = devuelve todos (legacy)
    // =========================
    [AllowAnonymous]
    [HttpGet]
    public async Task<IActionResult> GetAll(
        [FromQuery] int page = 0,
        [FromQuery] int pageSize = 0,
        [FromQuery] string? categoria = null,
        [FromQuery] string? busqueda = null,
        [FromQuery] string? orden = null)
    {
        try
        {
            using var conn = new NpgsqlConnection(_config.GetConnectionString("DefaultConnection"));
            await conn.OpenAsync();

            // Convertir categoría: acepta ID numérico o nombre (tutorias, arriendo, etc.)
            int? catId = null;
            if (!string.IsNullOrEmpty(categoria))
            {
                if (int.TryParse(categoria, out int parsedId))
                {
                    catId = parsedId;
                }
                else
                {
                    // Mapeo de nombre a ID
                    catId = categoria.ToLower() switch
                    {
                        "tutorias" or "tutorías" => 1,
                        "ensayos" or "ensayos y redacción" => 2,
                        "proyectos" => 3,
                        "programacion" or "programación" => 4,
                        "diseno" or "diseño" => 5,
                        "arriendo" or "arriendo de habitaciones" => 6,
                        "otros" or "otros servicios" => 7,
                        _ => null
                    };
                }
            }

            // Si no se envían parámetros de paginación, usar comportamiento legacy (todos los datos)
            bool usarPaginacion = page > 0 && pageSize > 0;

            if (usarPaginacion)
            {
                // NUEVO: Usar función optimizada con paginación en BD
                using var cmd = new NpgsqlCommand(@"
                    SELECT * FROM sp_ObtenerServiciosPaginados(
                        @page, @pageSize, @categoria, @busqueda, @orden
                    )
                ", conn);

                cmd.Parameters.AddWithValue("@page", page);
                cmd.Parameters.AddWithValue("@pageSize", pageSize);
                cmd.Parameters.AddWithValue("@categoria", catId.HasValue ? (object)catId.Value : DBNull.Value);
                cmd.Parameters.AddWithValue("@busqueda", string.IsNullOrEmpty(busqueda) ? DBNull.Value : busqueda.ToLower());
                cmd.Parameters.AddWithValue("@orden", string.IsNullOrEmpty(orden) ? "recientes" : orden);

                var servicios = new List<object>();
                long totalResults = 0;

                using var reader = await cmd.ExecuteReaderAsync();
                while (await reader.ReadAsync())
                {
                    double prom = reader["promedio_estrellas"] != DBNull.Value 
                        ? Convert.ToDouble(reader["promedio_estrellas"]) : 0;
                    long numResenasLong = Convert.ToInt64(reader["num_resenas"]);
                    int numResenas = (int)numResenasLong;
                    totalResults = Convert.ToInt64(reader["total_results"]);

                    var estrellasArr = numResenas > 0 
                        ? Enumerable.Repeat(prom, numResenas).ToArray() 
                        : Array.Empty<double>();

                    servicios.Add(new
                    {
                        id_servicio = Convert.ToInt32(reader["id_servicio"]),
                        id_proveedor = Convert.ToInt32(reader["id_proveedor"]),
                        titulo = reader["titulo"]?.ToString(),
                        descripcion = reader["descripcion"]?.ToString(),
                        precio_hora = reader["precio_hora"],
                        icono = reader["icono"]?.ToString() ?? "bi-pin",
                        fecha_publicacion = Convert.ToDateTime(reader["fecha_publicacion"]).ToString("yyyy-MM-dd"),
                        modalidad = MapModalidad(reader["modalidad"]),
                        disponibilidad = MapDisponibilidad(reader["disponibilidad"]),
                        nombre_categoria = reader["nombre_categoria"]?.ToString(),
                        proveedor = reader["proveedor"]?.ToString(),
                        universidad = reader["universidad"]?.ToString(),
                        estrellas = estrellasArr
                    });
                }
                reader.Close();

                // Obtener imágenes solo para los servicios de esta página
                var idsEnPagina = servicios.Select(s => (int)((dynamic)s).id_servicio).ToArray();
                if (idsEnPagina.Length > 0)
                {
                    using var cmdImg = new NpgsqlCommand(@"
                        SELECT id_servicio, id_imagen, url_imagen, es_principal, fecha_subida
                        FROM servicios_imagenes
                        WHERE id_servicio = ANY(@ids)
                        ORDER BY id_servicio, fecha_subida ASC
                    ", conn);
                    cmdImg.Parameters.AddWithValue("@ids", idsEnPagina);
                    
                    using var rImg = await cmdImg.ExecuteReaderAsync();
                    var imagenesPorServicio = new Dictionary<int, List<object>>();
                    while (await rImg.ReadAsync())
                    {
                        int idServ = Convert.ToInt32(rImg["id_servicio"]);
                        if (!imagenesPorServicio.ContainsKey(idServ))
                            imagenesPorServicio[idServ] = new List<object>();
                        
                        imagenesPorServicio[idServ].Add(new
                        {
                            id_imagen = rImg["id_imagen"],
                            url_imagen = rImg["url_imagen"],
                            es_principal = Convert.ToBoolean(rImg["es_principal"]),
                            fecha_subida = rImg["fecha_subida"]
                        });
                    }
                    rImg.Close();

                    // Combinar
                    for (int i = 0; i < servicios.Count; i++)
                    {
                        dynamic s = servicios[i];
                        int id = s.id_servicio;
                        imagenesPorServicio.TryGetValue(id, out var imgs);
                        
                        servicios[i] = new
                        {
                            s.id_servicio,
                            s.id_proveedor,
                            s.titulo,
                            s.descripcion,
                            s.precio_hora,
                            s.icono,
                            s.fecha_publicacion,
                            s.modalidad,
                            s.disponibilidad,
                            s.nombre_categoria,
                            s.proveedor,
                            s.universidad,
                            s.estrellas,
                            imagenes = imgs ?? new List<object>()
                        };
                    }
                }

                return Ok(new
                {
                    servicios,
                    paginacion = new
                    {
                        pagina = page,
                        porPagina = pageSize,
                        total = totalResults,
                        totalPaginas = (int)Math.Ceiling((double)totalResults / pageSize)
                    }
                });
            }
            else
            {
                // LEGACY: Sin paginación (comportamiento original para no romper frontend actual)
                var servicios = new List<object>();

                using var cmd = new NpgsqlCommand(@"
                SELECT 
                    s.id_servicio,
                    s.id_proveedor, 
                    s.titulo,
                    s.descripcion,
                    s.precio_hora,
                    s.icono,
                    s.fecha_publicacion,
                    s.modalidad,
                    s.disponibilidad,
                    c.nombre_categoria,
                    u.nombre AS proveedor,
                    u.universidad,
                    COUNT(cal.id_calificacion)      AS num_resenas,
                    COALESCE(AVG(CAST(cal.puntuacion AS FLOAT)), 0) AS promedio_estrellas
                FROM servicios s
                LEFT JOIN usuarios u ON s.id_proveedor = u.id_usuario
                LEFT JOIN categorias c ON s.id_categoria = c.id_categoria
                LEFT JOIN calificaciones cal ON cal.id_servicio = s.id_servicio
                WHERE s.disponibilidad >= 0
                GROUP BY
                    s.id_servicio, s.id_proveedor, s.titulo, s.descripcion,
                    s.precio_hora, s.icono, s.fecha_publicacion, s.modalidad,
                    s.disponibilidad, c.nombre_categoria, u.nombre, u.universidad
                ORDER BY s.fecha_publicacion DESC
            ", conn);

                using var reader = await cmd.ExecuteReaderAsync();

                var serviciosTemp = new List<dynamic>();
                while (await reader.ReadAsync())
                {
                    double prom = (double)reader["promedio_estrellas"];
                    int numResenas = Convert.ToInt32(reader["num_resenas"]);
                    int idServicio = Convert.ToInt32(reader["id_servicio"]);

                    var estrellasArr = Enumerable.Repeat(prom, numResenas).ToArray();

                    serviciosTemp.Add(new
                    {
                        id_servicio = idServicio,
                        id_proveedor = (int)reader["id_proveedor"],
                        titulo = reader["titulo"]?.ToString(),
                        descripcion = reader["descripcion"]?.ToString(),
                        precio_hora = reader["precio_hora"],
                        icono = reader["icono"]?.ToString() ?? "bi-pin",
                        fecha_publicacion = Convert.ToDateTime(reader["fecha_publicacion"]).ToString("yyyy-MM-dd"),
                        modalidad = MapModalidad(reader["modalidad"]),
                        disponibilidad = MapDisponibilidad(reader["disponibilidad"]),
                        nombre_categoria = reader["nombre_categoria"]?.ToString(),
                        proveedor = reader["proveedor"]?.ToString(),
                        universidad = reader["universidad"]?.ToString(),
                        estrellas = estrellasArr
                    });
                }
                reader.Close();

                // Obtener imágenes para todos los servicios en una sola consulta
                using var cmdImg = new NpgsqlCommand(@"
                    SELECT id_servicio, id_imagen, url_imagen, es_principal, fecha_subida
                    FROM servicios_imagenes
                    ORDER BY id_servicio, fecha_subida ASC
                ", conn);
                using var rImg = await cmdImg.ExecuteReaderAsync();
                
                var imagenesPorServicio = new Dictionary<int, List<object>>();
                while (await rImg.ReadAsync())
                {
                    int idServ = Convert.ToInt32(rImg["id_servicio"]);
                    if (!imagenesPorServicio.ContainsKey(idServ))
                        imagenesPorServicio[idServ] = new List<object>();
                    
                    imagenesPorServicio[idServ].Add(new
                    {
                        id_imagen = rImg["id_imagen"],
                        url_imagen = rImg["url_imagen"],
                        es_principal = Convert.ToBoolean(rImg["es_principal"]),
                        fecha_subida = rImg["fecha_subida"]
                    });
                }
                rImg.Close();

                // Combinar servicios con sus imágenes
                foreach (var s in serviciosTemp)
                {
                    int id = s.id_servicio;
                    imagenesPorServicio.TryGetValue(id, out var imgs);
                    
                    servicios.Add(new
                    {
                        s.id_servicio,
                        s.id_proveedor,
                        s.titulo,
                        s.descripcion,
                        s.precio_hora,
                        s.icono,
                        s.fecha_publicacion,
                        s.modalidad,
                        s.disponibilidad,
                        s.nombre_categoria,
                        s.proveedor,
                        s.universidad,
                        s.estrellas,
                        imagenes = imgs ?? new List<object>()
                    });
                }

                Console.WriteLine($"[DEBUG] GetAll: {servicios.Count} servicios, {imagenesPorServicio.Count} con imágenes");

                return Ok(servicios);
            }
        }
        catch (Exception ex)
        {
            Console.WriteLine($"[ERROR] GetAll: {ex.Message}");
            return StatusCode(500, new { error = ex.Message });
        }
    }

    // =========================
    // GET POR ID
    // =========================
    [HttpGet("{id}")]
    public async Task<IActionResult> GetById(int id)
    {
        try
        {
            using var conn = new NpgsqlConnection(_config.GetConnectionString("DefaultConnection"));
            await conn.OpenAsync();

            // 1. Datos del servicio (incluyendo ubicación)
            using var cmd = new NpgsqlCommand(@"
            SELECT 
                s.id_servicio,
                s.id_proveedor,
                s.titulo,
                s.descripcion,
                s.precio_hora,
                s.icono,
                s.contacto,
                s.fecha_publicacion,
                s.modalidad,
                s.disponibilidad,
                c.nombre_categoria,
                u.nombre AS proveedor,
                u.universidad,
                u.avatar,
                s.ubicacion_lat,
                s.ubicacion_lng,
                s.direccion
            FROM servicios s
            LEFT JOIN usuarios u ON s.id_proveedor = u.id_usuario
            LEFT JOIN categorias c ON s.id_categoria = c.id_categoria
            WHERE s.id_servicio = @id
        ", conn);
            cmd.Parameters.AddWithValue("@id", id);

            using var reader = await cmd.ExecuteReaderAsync();
            if (!await reader.ReadAsync())
            {
                reader.Close();
                return NotFound(new { error = "Servicio no encontrado" });
            }

            int idServicio = reader["id_servicio"] != DBNull.Value ? Convert.ToInt32(reader["id_servicio"]) : 0;
            int idProveedor = reader["id_proveedor"] != DBNull.Value ? Convert.ToInt32(reader["id_proveedor"]) : 0;
            DateTime fechaPub = reader["fecha_publicacion"] != DBNull.Value ? Convert.ToDateTime(reader["fecha_publicacion"]) : DateTime.Now;

            var servicio = new
            {
                id_servicio = idServicio,
                id_proveedor = idProveedor,
                titulo = reader["titulo"]?.ToString() ?? "Sin título",
                descripcion = reader["descripcion"]?.ToString() ?? "Sin descripción",
                precio_hora = reader["precio_hora"] != DBNull.Value ? reader["precio_hora"] : 0,
                icono = reader["icono"]?.ToString() ?? "bi-pin",
                contacto = reader["contacto"]?.ToString() ?? "",
                fecha_publicacion = fechaPub.ToString("yyyy-MM-dd"),
                modalidad = MapModalidad(reader["modalidad"]),
                disponibilidad = MapDisponibilidad(reader["disponibilidad"]),
                nombre_categoria = reader["nombre_categoria"]?.ToString() ?? "",
                proveedor = reader["proveedor"]?.ToString() ?? "Proveedor anónimo",
                avatar = reader["avatar"]?.ToString() ?? "",
                universidad = reader["universidad"]?.ToString() ?? "",
                ubicacion_lat = reader["ubicacion_lat"] != DBNull.Value ? Convert.ToDecimal(reader["ubicacion_lat"]) : (decimal?)null,
                ubicacion_lng = reader["ubicacion_lng"] != DBNull.Value ? Convert.ToDecimal(reader["ubicacion_lng"]) : (decimal?)null,
                direccion = reader["direccion"]?.ToString() ?? ""
            };
            reader.Close();

            // 2. Imágenes del servicio (galería real)
            var imagenes = new List<object>();
            using var cmdImagenes = new NpgsqlCommand(@"
                SELECT id_imagen, url_imagen, es_principal, fecha_subida
                FROM servicios_imagenes
                WHERE id_servicio = @id
                ORDER BY fecha_subida ASC
            ", conn);
            cmdImagenes.Parameters.AddWithValue("@id", id);
            using var rImagenes = await cmdImagenes.ExecuteReaderAsync();
            while (await rImagenes.ReadAsync())
            {
                var esPrincipalVal = rImagenes["es_principal"];
                bool esPrincipal = esPrincipalVal switch
                {
                    bool b => b,
                    int i => i != 0,
                    long l => l != 0,
                    byte b => b != 0,
                    short s => s != 0,
                    _ => false
                };

                imagenes.Add(new
                {
                    id_imagen = rImagenes["id_imagen"] != DBNull.Value ? Convert.ToInt32(rImagenes["id_imagen"]) : 0,
                    url_imagen = rImagenes["url_imagen"]?.ToString() ?? "",
                    es_principal = esPrincipal,
                    fecha_subida = rImagenes["fecha_subida"]?.ToString() ?? ""
                });
            }
            rImagenes.Close();

            // 3. Reseñas
            using var cmdResenas = new NpgsqlCommand(@"
            SELECT 
                c.puntuacion,
                c.comentario,
                c.fecha_calificacion,
                u.nombre AS autor
            FROM calificaciones c
            INNER JOIN usuarios u ON c.id_cliente = u.id_usuario
            WHERE c.id_servicio = @id
            ORDER BY c.fecha_calificacion DESC
        ", conn);
            cmdResenas.Parameters.AddWithValue("@id", id);

            var resenas = new List<object>();
            using var rReader = await cmdResenas.ExecuteReaderAsync();
            while (await rReader.ReadAsync())
            {
                byte puntuacion = rReader["puntuacion"] != DBNull.Value ? Convert.ToByte(rReader["puntuacion"]) : (byte)5;
                DateTime fechaCal = rReader["fecha_calificacion"] != DBNull.Value ? Convert.ToDateTime(rReader["fecha_calificacion"]) : DateTime.Now;

                resenas.Add(new
                {
                    estrellas = puntuacion,
                    comentario = rReader["comentario"]?.ToString() ?? "",
                    fecha = fechaCal.ToString("dd MMM yyyy"),
                    autor = rReader["autor"]?.ToString() ?? "Anónimo"
                });
            }
            rReader.Close();

            double prom = resenas.Count > 0
                ? resenas.Average(r => (double)((dynamic)r).estrellas)
                : 0;

            return Ok(new
            {
                servicio.id_servicio,
                servicio.id_proveedor,
                servicio.titulo,
                servicio.descripcion,
                servicio.precio_hora,
                servicio.icono,
                servicio.contacto,
                servicio.fecha_publicacion,
                servicio.modalidad,
                servicio.disponibilidad,
                servicio.nombre_categoria,
                servicio.proveedor,
                servicio.universidad,
                servicio.ubicacion_lat,
                servicio.ubicacion_lng,
                servicio.direccion,
                imagenes,
                resenas,
                estrellas = prom.ToString("0.0")
            });
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { error = ex.Message, detalle = ex.StackTrace });
        }
    }

    // =========================
    // CREATE SERVICIO
    // =========================
    [HttpPost]
    public async Task<IActionResult> Create([FromBody] ServicioDTO dto)
    {
        try
        {
            using var conn = new NpgsqlConnection(_config.GetConnectionString("DefaultConnection"));
            await conn.OpenAsync();

            using var cmd = new NpgsqlCommand(@"
                INSERT INTO servicios
                (id_proveedor, titulo, descripcion, id_categoria, precio_hora, contacto, modalidad, icono, disponibilidad, fecha_publicacion, ubicacion_lat, ubicacion_lng, direccion)
                VALUES
                (@id_proveedor, @titulo, @descripcion, @id_categoria, @precio_hora, @contacto, @modalidad, @icono, -1, NOW(), @ubicacion_lat, @ubicacion_lng, @direccion)
                RETURNING id_servicio
            ", conn);

            cmd.Parameters.AddWithValue("@id_proveedor", dto.id_proveedor);
            cmd.Parameters.AddWithValue("@titulo", dto.titulo);
            cmd.Parameters.AddWithValue("@descripcion", dto.descripcion);
            cmd.Parameters.AddWithValue("@id_categoria", dto.id_categoria);
            cmd.Parameters.AddWithValue("@precio_hora", dto.precio_hora);
            cmd.Parameters.AddWithValue("@contacto", dto.contacto ?? "");
            cmd.Parameters.AddWithValue("@modalidad", dto.modalidad);
            cmd.Parameters.AddWithValue("@icono", dto.icono ?? "📌");
            cmd.Parameters.AddWithValue("@ubicacion_lat", dto.ubicacion_lat.HasValue ? (object)dto.ubicacion_lat.Value : DBNull.Value);
            cmd.Parameters.AddWithValue("@ubicacion_lng", dto.ubicacion_lng.HasValue ? (object)dto.ubicacion_lng.Value : DBNull.Value);
            cmd.Parameters.AddWithValue("@direccion", (object)dto.direccion ?? DBNull.Value);

            var idServicio = await cmd.ExecuteScalarAsync();
            // Notificar a todos los admins del nuevo servicio pendiente
            try
            {
                using var cmdAdmins = new NpgsqlCommand(
                    "SELECT email, nombre FROM usuarios WHERE rol = 1", conn);
                using var rAdmins = await cmdAdmins.ExecuteReaderAsync();
                var admins = new List<(string email, string nombre)>();
                while (await rAdmins.ReadAsync())
                    admins.Add((rAdmins["email"].ToString()!, rAdmins["nombre"].ToString()!));
                rAdmins.Close();

                // Obtener nombre del proveedor
                using var cmdProv = new NpgsqlCommand(
                    "SELECT nombre FROM usuarios WHERE id_usuario = @id", conn);
                cmdProv.Parameters.AddWithValue("@id", dto.id_proveedor);
                var nombreProv = (await cmdProv.ExecuteScalarAsync())?.ToString() ?? "Usuario";

                foreach (var (email, nombre) in admins)
                {
                    _ = Task.Run(async () =>
                    {
                        try
                        {
                            await _emailService.EnviarNotificacionNuevoServicio(
                                email, nombre, nombreProv, dto.titulo, Convert.ToInt32(idServicio));
                        }
                        catch (Exception ex)
                        {
                            Console.WriteLine($"[EMAIL] Error notificando admin: {ex.Message}");
                        }
                    });
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[EMAIL] No se pudo notificar a admins: {ex.Message}");
            }

            return Ok(new { ok = true, message = "Servicio creado correctamente", id_servicio = idServicio });
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { error = ex.Message });
        }
    }

    // =========================
    // SUBIR IMÁGENES DE SERVICIO (máx 5)
    // =========================
    [HttpPost("{id}/imagenes")]
    [RequestSizeLimit(52428800)]
    [DisableRequestSizeLimit]
    public async Task<IActionResult> SubirImagenes(int id)
    {
        try
        {
            var imagenes = Request.Form.Files.ToList();
            
            Console.WriteLine($"[DEBUG] Recibiendo imágenes para servicio {id}. Cantidad recibida: {imagenes?.Count ?? 0}");
            
            if (imagenes == null || imagenes.Count == 0)
                return BadRequest(new { error = "No se recibieron imágenes" });

            Console.WriteLine($"[DEBUG] Archivos recibidos:");
            foreach (var img in imagenes)
            {
                Console.WriteLine($"  - {img.FileName} ({img.Length} bytes, {img.ContentType})");
            }

            if (imagenes.Count > 5)
                return BadRequest(new { error = "Máximo 5 imágenes por servicio" });

            // Validar tipo y tamaño
            var tiposPermitidos = new[] { "image/jpeg", "image/png", "image/webp" };
            long tamanoMaximo = 5 * 1024 * 1024; // 5MB

            foreach (var imagen in imagenes)
            {
                if (!tiposPermitidos.Contains(imagen.ContentType))
                    return BadRequest(new { error = "Solo se permiten imágenes JPG, PNG o WebP" });
                
                if (imagen.Length > tamanoMaximo)
                    return BadRequest(new { error = "Cada imagen debe ser menor a 5MB" });
            }

            Console.WriteLine($"[DEBUG] Validación OK. Subiendo a Supabase...");

            // Eliminar imagen por defecto ANTES de subir las nuevas
            using var connPre = new NpgsqlConnection(_config.GetConnectionString("DefaultConnection"));
            await connPre.OpenAsync();
            using var cmdDeleteDefault = new NpgsqlCommand(@"
                DELETE FROM servicios_imagenes 
                WHERE id_servicio = @id 
                AND (url_imagen LIKE '%default%' OR url_imagen LIKE 'img/%')
            ", connPre);
            cmdDeleteDefault.Parameters.AddWithValue("@id", id);
            int eliminadas = await cmdDeleteDefault.ExecuteNonQueryAsync();
            Console.WriteLine($"[DEBUG] Imágenes default eliminadas: {eliminadas}");
            connPre.Close();

            // Subir a Supabase Storage
            var urls = await _storageService.SubirMultiplesImagenesAsync(id, imagenes);

            Console.WriteLine($"[DEBUG] URLs generadas: {urls.Count}");

            // Guardar URLs en la base de datos
            using var conn = new NpgsqlConnection(_config.GetConnectionString("DefaultConnection"));
            await conn.OpenAsync();

            foreach (var url in urls)
            {
                using var cmd = new NpgsqlCommand(@"
                    INSERT INTO servicios_imagenes (id_servicio, url_imagen, es_principal)
                    VALUES (@id_servicio, @url, @es_principal)
                ", conn);
                cmd.Parameters.AddWithValue("@id_servicio", id);
                cmd.Parameters.AddWithValue("@url", url);
                // La primera imagen es principal, las demás no
                cmd.Parameters.AddWithValue("@es_principal", urls.IndexOf(url) == 0);
                await cmd.ExecuteNonQueryAsync();
            }

            Console.WriteLine($"[DEBUG] {urls.Count} imágenes guardadas en BD para servicio {id}");

            return Ok(new { ok = true, message = "Imágenes subidas correctamente", urls });
        }
        catch (NpgsqlException ex) when (ex.Message.Contains("más de 5 imágenes"))
        {
            return BadRequest(new { error = ex.Message });
        }
        catch (Exception ex)
        {
            Console.WriteLine($"[ERROR] Subiendo imágenes: {ex.Message}");
            Console.WriteLine($"[ERROR] Stack: {ex.StackTrace}");
            return StatusCode(500, new { error = ex.Message });
        }
    }

    // =========================
    // ACTUALIZAR ORDEN DE IMAGEN
    // =========================
    [HttpPut("{idServicio}/imagenes/{idImagen}/orden")]
    public async Task<IActionResult> ActualizarOrdenImagen(int idServicio, int idImagen, [FromBody] dynamic data)
    {
        try
        {
            int orden = data.orden;
            bool esPrincipal = data.es_principal;

            Console.WriteLine($"[DEBUG] Actualizando orden: idImagen={idImagen}, orden={orden}, esPrincipal={esPrincipal}");

            using var conn = new NpgsqlConnection(_config.GetConnectionString("DefaultConnection"));
            await conn.OpenAsync();

            // Desmarcar todas como principal primero
            using var cmdReset = new NpgsqlCommand(
                "UPDATE servicios_imagenes SET es_principal = FALSE WHERE id_servicio = @id", conn);
            cmdReset.Parameters.AddWithValue("@id", idServicio);
            await cmdReset.ExecuteNonQueryAsync();

            // Marcar la imagen seleccionada como principal si corresponde
            // y actualizar fecha_subida para reflejar el orden
            using var cmd = new NpgsqlCommand(@"
                UPDATE servicios_imagenes 
                SET es_principal = @es_principal,
                    fecha_subida = NOW() + INTERVAL '1 second' * @orden
                WHERE id_imagen = @id AND id_servicio = @id_servicio
            ", conn);
            cmd.Parameters.AddWithValue("@id", idImagen);
            cmd.Parameters.AddWithValue("@id_servicio", idServicio);
            cmd.Parameters.AddWithValue("@es_principal", esPrincipal);
            cmd.Parameters.AddWithValue("@orden", orden);
            await cmd.ExecuteNonQueryAsync();

            Console.WriteLine($"[DEBUG] Orden actualizado exitosamente");

            return Ok(new { ok = true });
        }
        catch (Exception ex)
        {
            Console.WriteLine($"[ERROR] Actualizando orden: {ex.Message}");
            return StatusCode(500, new { error = ex.Message });
        }
    }

    // =========================
    // ELIMINAR IMAGEN DE SERVICIO
    // =========================
    [HttpDelete("{idServicio}/imagenes/{idImagen}")]
    public async Task<IActionResult> EliminarImagen(int idServicio, int idImagen)
    {
        try
        {
            using var conn = new NpgsqlConnection(_config.GetConnectionString("DefaultConnection"));
            await conn.OpenAsync();

            // Obtener URL de la imagen
            using var cmdGet = new NpgsqlCommand("SELECT url_imagen FROM servicios_imagenes WHERE id_imagen = @id AND id_servicio = @id_servicio", conn);
            cmdGet.Parameters.AddWithValue("@id", idImagen);
            cmdGet.Parameters.AddWithValue("@id_servicio", idServicio);
            var urlImagen = await cmdGet.ExecuteScalarAsync() as string;

            if (string.IsNullOrEmpty(urlImagen))
                return NotFound(new { error = "Imagen no encontrada" });

            // Solo eliminar de Supabase si es una imagen real (no default)
            if (!urlImagen.Contains("default") && !urlImagen.StartsWith("img/"))
            {
                await _storageService.EliminarImagenAsync(urlImagen);
            }

            // Eliminar de la base de datos
            using var cmdDelete = new NpgsqlCommand("DELETE FROM servicios_imagenes WHERE id_imagen = @id AND id_servicio = @id_servicio", conn);
            cmdDelete.Parameters.AddWithValue("@id", idImagen);
            cmdDelete.Parameters.AddWithValue("@id_servicio", idServicio);
            await cmdDelete.ExecuteNonQueryAsync();

            return Ok(new { ok = true, message = "Imagen eliminada" });
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { error = ex.Message });
        }
    }

    private string MapModalidad(object value)
    {
        if (value == null || value == DBNull.Value) return "🏫 Presencial";

        string str = value.ToString();
        return str switch
        {
            "0" => "🏫 Presencial",
            "1" => "💻 Virtual",
            "2" => "🔄 Mixta",
            "Presencial" => "🏫 Presencial",
            "Virtual" => "💻 Virtual",
            "Mixta" => "🔄 Mixta",
            _ => "🏫 Presencial"
        };
    }

    private string MapDisponibilidad(object value)
    {
        if (value == null || value == DBNull.Value) return "📆 Entre semana";

        string str = value.ToString();
        return str switch
        {
            "-1" => "Pausado",
            "0" => "📆 Entre semana",
            "1" => "🎉 Fines de semana",
            "2" => "⏰ Siempre disponible",
            "Pausado" => "Pausado",
            "Entre semana" => "📆 Entre semana",
            "Fines de semana" => "🎉 Fines de semana",
            "Siempre disponible" => "⏰ Siempre disponible",
            _ => "📆 Entre semana"
        };
    }

    // ── PUT /api/services/{id}/pausar (Admin) - Toggle disponibilidad
    [HttpPut("{id}/pausar")]
    public async Task<IActionResult> Pausar(int id)
    {
        try
        {
            using var conn = new NpgsqlConnection(_config.GetConnectionString("DefaultConnection"));
            await conn.OpenAsync();

            using var cmd = new NpgsqlCommand(
                "UPDATE servicios SET disponibilidad = CASE WHEN disponibilidad = -1 THEN 2 ELSE -1 END WHERE id_servicio = @id", conn);
            cmd.Parameters.AddWithValue("@id", id);

            int filas = await cmd.ExecuteNonQueryAsync();
            if (filas == 0)
                return NotFound(new { error = "Servicio no encontrado" });

            return Ok(new { ok = true });
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { error = ex.Message });
        }
    }

    // ── PUT /api/services/{id} (Update by owner)
    [HttpPut("{id}")]
    public async Task<IActionResult> Update(int id, [FromBody] EditarServicioDTO dto)
    {
        try
        {
            using var conn = new NpgsqlConnection(_config.GetConnectionString("DefaultConnection"));
            await conn.OpenAsync();

            using var cmd = new NpgsqlCommand(@"
                UPDATE servicios
                SET titulo = @titulo,
                    descripcion = @descripcion,
                    precio_hora = @precio_hora,
                    contacto = @contacto,
                    icono = @icono,
                    ubicacion_lat = @ubicacion_lat,
                    ubicacion_lng = @ubicacion_lng,
                    direccion = @direccion
                WHERE id_servicio = @id AND id_proveedor = @id_proveedor
            ", conn);

            cmd.Parameters.AddWithValue("@id", id);
            cmd.Parameters.AddWithValue("@id_proveedor", dto.id_proveedor);
            cmd.Parameters.AddWithValue("@titulo", dto.titulo ?? "");
            cmd.Parameters.AddWithValue("@descripcion", dto.descripcion ?? "");
            cmd.Parameters.AddWithValue("@precio_hora", dto.precio_hora);
            cmd.Parameters.AddWithValue("@contacto", dto.contacto ?? "");
            cmd.Parameters.AddWithValue("@icono", dto.icono ?? "");
            cmd.Parameters.AddWithValue("@ubicacion_lat", dto.ubicacion_lat.HasValue ? (object)dto.ubicacion_lat.Value : DBNull.Value);
            cmd.Parameters.AddWithValue("@ubicacion_lng", dto.ubicacion_lng.HasValue ? (object)dto.ubicacion_lng.Value : DBNull.Value);
            cmd.Parameters.AddWithValue("@direccion", (object)dto.direccion ?? DBNull.Value);

            int filas = await cmd.ExecuteNonQueryAsync();
            if (filas == 0)
                return NotFound(new { error = "Servicio no encontrado o no tienes permiso" });

            return Ok(new { ok = true });
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { error = ex.Message });
        }
    }

    // ── DELETE /api/services/{id}
    [HttpDelete("{id}")]
    public async Task<IActionResult> Delete(int id, [FromQuery] int id_proveedor)
    {
        try
        {
            using var conn = new NpgsqlConnection(_config.GetConnectionString("DefaultConnection"));
            await conn.OpenAsync();

            // 1. Verificar que el servicio pertenece al proveedor
            using var cmdCheck = new NpgsqlCommand(
                "SELECT COUNT(1) FROM servicios WHERE id_servicio = @id AND id_proveedor = @id_proveedor",
                conn);
            cmdCheck.Parameters.AddWithValue("@id", id);
            cmdCheck.Parameters.AddWithValue("@id_proveedor", id_proveedor);
            int existe = Convert.ToInt32(await cmdCheck.ExecuteScalarAsync());
            if (existe == 0)
                return NotFound(new { error = "Servicio no encontrado o no tienes permiso" });

            // 2. Eliminar calificaciones del servicio
            using var cmdCalif = new NpgsqlCommand(
                "DELETE FROM calificaciones WHERE id_servicio = @id", conn);
            cmdCalif.Parameters.AddWithValue("@id", id);
            await cmdCalif.ExecuteNonQueryAsync();

            // 3. Eliminar solicitudes del servicio
            using var cmdSol = new NpgsqlCommand(
                "DELETE FROM solicitudes WHERE id_servicio = @id", conn);
            cmdSol.Parameters.AddWithValue("@id", id);
            await cmdSol.ExecuteNonQueryAsync();

            // 4. Ahora sí eliminar el servicio
            using var cmd = new NpgsqlCommand(
                "DELETE FROM servicios WHERE id_servicio = @id AND id_proveedor = @id_proveedor",
                conn);
            cmd.Parameters.AddWithValue("@id", id);
            cmd.Parameters.AddWithValue("@id_proveedor", id_proveedor);
            await cmd.ExecuteNonQueryAsync();

            return Ok(new { ok = true });
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { error = ex.Message });
        }
    }

    [HttpPut("{id}/aprobar")]
    public async Task<IActionResult> Aprobar(int id)
    {
        try
        {
            using var conn = new NpgsqlConnection(_config.GetConnectionString("DefaultConnection"));
            await conn.OpenAsync();

            // 1. Obtener info del proveedor PRIMERO (antes del UPDATE)
            string emailProv = "", nombreProv = "", tituloServ = "";
            using (var cmdInfo = new NpgsqlCommand(@"
            SELECT u.correo, u.nombre, s.titulo
            FROM servicios s
            INNER JOIN usuarios u ON s.id_proveedor = u.id_usuario
            WHERE s.id_servicio = @id", conn))
            {
                cmdInfo.Parameters.AddWithValue("@id", id);
                using var r = await cmdInfo.ExecuteReaderAsync();
                if (await r.ReadAsync())
                {
                    emailProv = r["correo"].ToString()!;
                    nombreProv = r["nombre"].ToString()!;
                    tituloServ = r["titulo"].ToString()!;
                }
            }

            // 2. Aprobar el servicio
            using (var cmd = new NpgsqlCommand(
                "UPDATE servicios SET disponibilidad = 2 WHERE id_servicio = @id", conn))
            {
                cmd.Parameters.AddWithValue("@id", id);
                int filas = await cmd.ExecuteNonQueryAsync();
                if (filas == 0)
                    return NotFound(new { error = "Servicio no encontrado" });
            }

            // 3. Enviar correo en segundo plano
            if (!string.IsNullOrEmpty(emailProv))
            {
                Console.WriteLine($"[EMAIL] Enviando aprobación a {emailProv}...");
                _ = Task.Run(async () =>
                {
                    try
                    {
                        await _emailService.EnviarResultadoRevision(emailProv, nombreProv, tituloServ, aprobado: true);
                    }
                    catch (Exception ex)
                    {
                        Console.WriteLine($"[EMAIL] Error enviando aprobación: {ex.Message}");
                    }
                });
            }
            else
            {
                Console.WriteLine($"[EMAIL] No se encontró correo del proveedor para servicio {id}");
            }

            return Ok(new { ok = true });
        }
        catch (Exception ex)
        {
            Console.WriteLine($"[ERROR] Aprobar: {ex.Message}");
            return StatusCode(500, new { error = ex.Message });
        }
    }
    // ── PUT /api/services/{id}/rechazar (Admin)
    [HttpPut("{id}/rechazar")]
    public async Task<IActionResult> Rechazar(int id, [FromBody] RechazarServicioDTO dto)
    {
        try
        {
            using var conn = new NpgsqlConnection(_config.GetConnectionString("DefaultConnection"));
            await conn.OpenAsync();

            // 1. Obtener info del proveedor ANTES de borrar
            string emailProv = "", nombreProv = "", tituloServ = "";
            using (var cmdInfo = new NpgsqlCommand(@"
            SELECT u.correo, u.nombre, s.titulo
            FROM servicios s
            INNER JOIN usuarios u ON s.id_proveedor = u.id_usuario
            WHERE s.id_servicio = @id", conn))
            {
                cmdInfo.Parameters.AddWithValue("@id", id);
                using var r = await cmdInfo.ExecuteReaderAsync();
                if (await r.ReadAsync())
                {
                    emailProv = r["correo"].ToString()!;
                    nombreProv = r["nombre"].ToString()!;
                    tituloServ = r["titulo"].ToString()!;
                }
            }

            // 2. Eliminar el servicio
            using (var cmd = new NpgsqlCommand(
                "DELETE FROM servicios WHERE id_servicio = @id", conn))
            {
                cmd.Parameters.AddWithValue("@id", id);
                int filas = await cmd.ExecuteNonQueryAsync();
                if (filas == 0)
                    return NotFound(new { error = "Servicio no encontrado" });
            }

            // 3. Enviar correo en segundo plano
            if (!string.IsNullOrEmpty(emailProv))
            {
                Console.WriteLine($"[EMAIL] Enviando rechazo a {emailProv}...");
                _ = Task.Run(async () =>
                {
                    try
                    {
                        await _emailService.EnviarResultadoRevision(
                            emailProv, nombreProv, tituloServ,
                            aprobado: false,
                            razonRechazo: dto?.razon);
                    }
                    catch (Exception ex)
                    {
                        Console.WriteLine($"[EMAIL] Error enviando rechazo: {ex.Message}");
                    }
                });
            }
            else
            {
                Console.WriteLine($"[EMAIL] No se encontró correo del proveedor para servicio {id}");
            }

            return Ok(new { ok = true });
        }
        catch (Exception ex)
        {
            Console.WriteLine($"[ERROR] Rechazar: {ex.Message}");
            return StatusCode(500, new { error = ex.Message });
        }
    }
}
