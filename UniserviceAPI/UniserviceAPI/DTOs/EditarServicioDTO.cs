namespace UniserviceAPI.DTOs
{
    public class EditarServicioDTO
    {
        public int id_proveedor { get; set; }
        public string titulo { get; set; } = null!;
        public string descripcion { get; set; } = null!;
        public decimal precio_hora { get; set; }
        public string contacto { get; set; } = null!;
        public string icono { get; set; } = null!;
    }
}
