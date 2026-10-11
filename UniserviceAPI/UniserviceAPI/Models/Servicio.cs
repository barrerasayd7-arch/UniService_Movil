namespace UniServiceAPI.Models
{
    public class Servicio
    {
        public int id_servicio { get; set; }
        public int id_proveedor { get; set; }
        public string titulo { get; set; }
        public string descripcion { get; set; }
        public decimal precio_hora { get; set; }
        public string contacto { get; set; }
        public int modalidad { get; set; }
        public int disponibilidad { get; set; }
        
        // Google Maps
        public decimal? ubicacion_lat { get; set; }
        public decimal? ubicacion_lng { get; set; }
        public string? direccion { get; set; }
    }
}
