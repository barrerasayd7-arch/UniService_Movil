-- =====================================================
-- SUPABASE: Datos de prueba (PostgreSQL)
-- Copiar y pegar TODO en el SQL Editor de Supabase
-- =====================================================

-- Limpiar datos existentes (en orden inverso a las FK)
DELETE FROM aspectos_destacados;
DELETE FROM calificaciones;
DELETE FROM solicitudes;
DELETE FROM servicios_imagenes;
DELETE FROM servicios;
DELETE FROM seguidores;
DELETE FROM usuarios;
DELETE FROM categorias;
DELETE FROM rol_usuarios;

-- Resetear secuencias
ALTER SEQUENCE rol_usuarios_id_rol_seq RESTART WITH 1;
ALTER SEQUENCE usuarios_id_usuario_seq RESTART WITH 1;
ALTER SEQUENCE categorias_id_categoria_seq RESTART WITH 1;
ALTER SEQUENCE servicios_id_servicio_seq RESTART WITH 1;
ALTER SEQUENCE solicitudes_id_solicitud_seq RESTART WITH 1;
ALTER SEQUENCE calificaciones_id_calificacion_seq RESTART WITH 1;

-- 1. ROLES
INSERT INTO rol_usuarios (nombre_rol) VALUES
    ('Administrador'),
    ('Usuario comun');

-- 2. USUARIOS (contraseña: 123456789 para todos)
INSERT INTO usuarios (telefono, password_hash, nombre, descripcion, correo, id_rol, universidad) VALUES
    ('3117906271', '$2y$10$n.QB9K1ni2zC/zjJGKcfaufpqQjeAE8Nx.gbW/U36aRyjFqecG7RO', 'UniService', 'Administrador del sistema', 'uniservice.soporte@gmail.com', 1, 'Sin universidad'),
    ('3043307911', '$2y$10$n.QB9K1ni2zC/zjJGKcfaufpqQjeAE8Nx.gbW/U36aRyjFqecG7RO', 'Sayd', 'Estudiante de Ingenieria de Sistemas UPC', 'barrerasayd7@gmail.com', 2, 'Universidad Popular del Cesar'),
    ('3001234567', '$2y$10$n.QB9K1ni2zC/zjJGKcfaufpqQjeAE8Nx.gbW/U36aRyjFqecG7RO', 'Camilo', 'Estudiante de Ingenieria de Sistemas', 'camilo.sist@gmail.com', 2, 'Universidad Pontificia Comillas'),
    ('3012345678', '$2y$10$n.QB9K1ni2zC/zjJGKcfaufpqQjeAE8Nx.gbW/U36aRyjFqecG7RO', 'Valentina', 'Estudiante de Derecho Septimo Semestre', 'valen_upc@gmail.com', 2, 'Universidad Pontificia Comillas'),
    ('3109876543', '$2y$10$n.QB9K1ni2zC/zjJGKcfaufpqQjeAE8Nx.gbW/U36aRyjFqecG7RO', 'Andres', 'Monitor de Matematicas y Fisica', 'andres_monitor@gmail.com', 2, 'Universidad Pontificia Comillas'),
    ('3156789012', '$2y$10$n.QB9K1ni2zC/zjJGKcfaufpqQjeAE8Nx.gbW/U36aRyjFqecG7RO', 'Mariana', 'Apasionada por programacion en Python y React', 'mariana_dev@gmail.com', 2, 'Universidad Pontificia Comillas'),
    ('3204567890', '$2y$10$n.QB9K1ni2zC/zjJGKcfaufpqQjeAE8Nx.gbW/U36aRyjFqecG7RO', 'Mateo', 'Estudiante de Contaduria Publica', 'mateo.contable@gmail.com', 2, 'Universidad Pontificia Comillas'),
    ('3009998877', '$2y$10$n.QB9K1ni2zC/zjJGKcfaufpqQjeAE8Nx.gbW/U36aRyjFqecG7RO', 'Daniela', 'Lider del grupo de investigacion de software', 'daniela_inv@gmail.com', 2, 'Sin universidad'),
    ('3112223344', '$2y$10$n.QB9K1ni2zC/zjJGKcfaufpqQjeAE8Nx.gbW/U36aRyjFqecG7RO', 'Sebastian', 'Estudiante de Ing. Electronica', 'sebas_elec@gmail.com', 2, 'Sin universidad'),
    ('3183334455', '$2y$10$n.QB9K1ni2zC/zjJGKcfaufpqQjeAE8Nx.gbW/U36aRyjFqecG7RO', 'Paula', 'Estudiante de Psicologia UPC', 'paula.psi@gmail.com', 2, 'Sin universidad'),
    ('3045556677', '$2y$10$n.QB9K1ni2zC/zjJGKcfaufpqQjeAE8Nx.gbW/U36aRyjFqecG7RO', 'Santiago', 'Interesado en redes y ciberseguridad', 'santiago_net@gmail.com', 2, 'Sin universidad'),
    ('3127778899', '$2y$10$n.QB9K1ni2zC/zjJGKcfaufpqQjeAE8Nx.gbW/U36aRyjFqecG7RO', 'Gabriela', 'Estudiante de Licenciatura en Idiomas', 'gabi.languages@gmail.com', 2, 'Sin universidad'),
    ('3162223344', '$2y$10$n.QB9K1ni2zC/zjJGKcfaufpqQjeAE8Nx.gbW/U36aRyjFqecG7RO', 'Julian', 'Especialista en bases de datos SQL', 'julian.sql@gmail.com', 2, 'Sin universidad'),
    ('3174445566', '$2y$10$n.QB9K1ni2zC/zjJGKcfaufpqQjeAE8Nx.gbW/U36aRyjFqecG7RO', 'Elena', 'Estudiante de Ingenieria Ambiental', 'elena_ambiental@gmail.com', 2, 'Sin universidad'),
    ('3028889900', '$2y$10$n.QB9K1ni2zC/zjJGKcfaufpqQjeAE8Nx.gbW/U36aRyjFqecG7RO', 'Diego', 'Entusiasta de la IA y el Machine Learning', 'diego_ia@gmail.com', 2, 'Sin universidad'),
    ('3136667788', '$2y$10$n.QB9K1ni2zC/zjJGKcfaufpqQjeAE8Nx.gbW/U36aRyjFqecG7RO', 'Sara', 'Estudiante de Economia', 'sara_econ@gmail.com', 2, 'Sin universidad'),
    ('3005554433', '$2y$10$n.QB9K1ni2zC/zjJGKcfaufpqQjeAE8Nx.gbW/U36aRyjFqecG7RO', 'Felipe', 'Desarrollador backend junior', 'felipe_back@gmail.com', 2, 'Universidad Pontificia Comillas'),
    ('3141110099', '$2y$10$n.QB9K1ni2zC/zjJGKcfaufpqQjeAE8Nx.gbW/U36aRyjFqecG7RO', 'Lucia', 'Estudiante de Sociologia', 'lucia_soc@gmail.com', 2, 'Sin universidad');

-- 3. CATEGORÍAS
INSERT INTO categorias (nombre_categoria) VALUES
    ('Tutorías'),
    ('Ensayos y redacción'),
    ('Proyectos'),
    ('Programación'),
    ('Diseño'),
    ('Arriendo de habitaciones'),
    ('Otros servicios');

-- 4. SEGUIDORES
INSERT INTO seguidores (id_seguidor, id_seguido) VALUES
    (1, 3), (3, 1),
    (2, 4), (4, 2),
    (3, 5), (5, 3),
    (4, 6), (6, 4),
    (1, 13), (13, 1),
    (13, 11), (11, 13),
    (15, 1), (1, 15),
    (17, 3), (3, 17),
    (8, 10), (10, 8),
    (10, 12), (12, 10),
    (18, 8), (8, 18),
    (14, 17), (17, 14),
    (5, 1), (7, 2),
    (9, 4), (12, 17),
    (16, 3), (6, 11),
    (2, 15), (4, 9);

-- 5. SERVICIOS
INSERT INTO servicios (id_proveedor, titulo, descripcion, id_categoria, precio_hora, contacto, modalidad, icono, disponibilidad) VALUES
    (3, 'Bases de Datos SQL', 'Diseño de diagramas ER y consultas complejas', 4, 40000.00, '3001234567', 1, '🗄️', 1),
    (4, 'Scripts en Python', 'Automatización de tareas y análisis de datos', 4, 30000.00, '3012345678', 1, '🐍', 1),
    (11, 'App Móvil con Flutter', 'Desarrollo de prototipos para Android/iOS', 4, 120000.00, '3210001122', 1, '📱', 1),
    (13, 'Corrección de Bugs Java', 'Debug de proyectos universitarios en Java', 4, 20000.00, '3162223344', 1, '👾', 1),
    (5, 'Clases de Álgebra Lineal', 'Vectores, matrices y espacios vectoriales', 1, 15000.00, '3109876543', 0, '📐', 1),
    (8, 'Tutoría de Psicología', 'Apoyo en teorías del aprendizaje', 1, 18000.00, '3183334455', 0, '🧠', 1),
    (10, 'Clases de Inglés B1', 'Práctica de conversación y gramática', 1, 25000.00, '3127778899', 0, '🇺🇸', 1),
    (16, 'Tutoría de Microeconomía', 'Curvas de oferta, demanda y equilibrio', 1, 22000.00, '3136667788', 0, '📈', 1),
    (15, 'Tutoría de Física II', 'Termodinámica y electromagnetismo', 1, 30000.00, '3028889900', 0, '⚡', 1),
    (2, 'Corrección de Estilo APA', 'Ajuste de normas APA 7ma edición para tesis', 2, 10000.00, '3117906271', 1, '✍️', 1),
    (18, 'Redacción de Ensayos', 'Textos argumentativos sobre sociología', 2, 25000.00, '3141110099', 1, '📝', 1),
    (12, 'Traducción de Resúmenes', 'Traducción técnico-académica (Inglés/Español)', 2, 12000.00, '3051112233', 1, '🌐', 1),
    (6, 'Plan de Negocios', 'Estructuración de proyectos de emprendimiento', 3, 50000.00, '3156789012', 1, '💼', 1),
    (14, 'Asesoría Ambiental', 'Informes de impacto y gestión de residuos', 3, 45000.00, '3174445566', 1, '🌱', 1),
    (7, 'Análisis Estadístico', 'Procesamiento de datos en Excel o SPSS', 3, 35000.00, '3204567890', 1, '📊', 1),
    (9, 'Logotipos para Proyectos', 'Diseño de identidad visual para startups', 5, 60000.00, '3045556677', 1, '🎨', 1),
    (1, 'Edición de Video', 'Montaje para redes sociales y presentaciones', 5, 40000.00, '3043307911', 1, '🎬', 1),
    (4, 'Diseño de Diapositivas', 'Presentaciones interactivas en Canva', 5, 15000.00, '3012345678', 1, '✨', 1),
    (17, 'Habitación Central', 'Cerca a la UPC, incluye servicios y WiFi', 6, 450000.00, '3005554433', 0, '🏠', 1),
    (12, 'Aparto-estudio Estudiantes', 'Entrada independiente y baño privado', 6, 600000.00, '3051112233', 0, '🔑', 1),
    (5, 'Cupo Universitario', 'Habitación compartida, ambiente tranquilo', 6, 300000.00, '3109876543', 0, '🛌', 1),
    (3, 'Mantenimiento de PC', 'Limpieza física y cambio de pasta térmica', 7, 50000.00, '3001234567', 1, '🔧', 1),
    (10, 'Venta de Almuerzos', 'Comida casera con domicilio en el campus', 7, 12000.00, '3127778899', 0, '🍱', 1),
    (8, 'Asesoría Nutricional', 'Planes de alimentación para estudiantes', 7, 30000.00, '3183334455', 0, '🍎', 1),
    (15, 'Reparación de Celulares', 'Cambio de pantallas y baterías', 7, 80000.00, '3028889900', 1, '🛠️', 1),
    (6, 'Venta de Accesorios', 'Cables USB, audífonos y protectores', 7, 15000.00, '3156789012', 1, '🎧', 1),
    (13, 'Formateo de Laptops', 'Instalación de Windows y Office', 7, 45000.00, '3162223344', 1, '💿', 1),
    (11, 'Fotografía para Eventos', 'Sesiones fotográficas académicas', 7, 100000.00, '3210001122', 1, '📸', 1);

-- 6. SOLICITUDES
INSERT INTO solicitudes (id_cliente, id_proveedor, id_servicio, fue_aceptada, estado) VALUES
    (3, 11, 3, true, 'Aceptada'),
    (11, 1, 1, true, 'Aceptada'),
    (15, 13, 4, true, 'Aceptada'),
    (1, 3, 1, true, 'Aceptada'),
    (17, 4, 2, false, 'Pendiente'),
    (5, 2, 2, true, 'Aceptada'),
    (8, 10, 7, true, 'Aceptada'),
    (16, 5, 5, false, 'Pendiente'),
    (10, 16, 8, true, 'Aceptada'),
    (2, 15, 9, false, 'Pendiente'),
    (18, 2, 10, true, 'Aceptada'),
    (12, 18, 11, true, 'Aceptada'),
    (9, 4, 18, true, 'Aceptada'),
    (4, 9, 16, false, 'Pendiente'),
    (7, 1, 17, true, 'Aceptada'),
    (5, 17, 19, true, 'Aceptada'),
    (10, 12, 20, false, 'Pendiente'),
    (14, 5, 21, true, 'Aceptada'),
    (1, 10, 23, true, 'Aceptada'),
    (3, 8, 24, false, 'Pendiente'),
    (6, 15, 25, true, 'Aceptada'),
    (13, 6, 26, true, 'Aceptada'),
    (11, 13, 27, false, 'Pendiente'),
    (8, 11, 28, true, 'Aceptada'),
    (12, 3, 22, true, 'Aceptada'),
    (7, 10, 23, true, 'Aceptada'),
    (18, 12, 12, true, 'Aceptada'),
    (4, 1, 1, true, 'Aceptada');

-- 7. CALIFICACIONES
INSERT INTO calificaciones (id_solicitud, id_cliente, id_servicio, puntuacion, comentario) VALUES
    (1, 3, 3, 5, 'Excelente manejo de SQL, me salvó el proyecto de bases de datos.'),
    (2, 4, 4, 5, 'El script de Python funcionó perfecto, muy rápido.'),
    (3, 11, 3, 4, 'Muy buen diseño de interfaces, aunque demoró un poquito en la entrega.'),
    (4, 15, 4, 5, 'Encontró el error en mi código Java en 10 minutos. Recomendado.'),
    (28, 4, 1, 5, 'La interfaz en React quedó súper moderna, justo lo que buscaba.'),
    (6, 5, 2, 5, 'Explica el Cálculo Integral mucho mejor que el profesor, 10/10.'),
    (7, 8, 7, 4, 'Muy buena la clase de inglés, me ayudó mucho con la pronunciación.'),
    (9, 10, 8, 5, 'Domina totalmente el tema de microeconomía. Muy paciente.'),
    (19, 1, 23, 5, 'El almuerzo estaba delicioso y calientico, gran servicio en la U.'),
    (27, 18, 12, 4, 'La traducción técnica fue muy precisa, me sirvió para el abstract.'),
    (16, 5, 19, 5, 'La habitación es tal cual las fotos, muy cerca de la sede Sabanas.'),
    (18, 14, 21, 4, 'Ambiente muy tranquilo para estudiar, el WiFi vuela.'),
    (21, 6, 25, 3, 'Arregló el celular, pero la pantalla no quedó del todo centrada.'),
    (22, 13, 26, 5, 'Los audífonos son originales y a buen precio.'),
    (24, 8, 28, 5, 'Las fotos para mi grado quedaron increíbles, muy profesional.'),
    (11, 18, 10, 5, 'Me dejó el ensayo con normas APA perfecto, sin errores.'),
    (15, 7, 17, 4, 'Buen editor de video, entendió rápido la idea.'),
    (25, 12, 22, 5, 'Mi laptop quedó como nueva después del mantenimiento.'),
    (26, 7, 23, 5, 'Puntual con la entrega del almuerzo en la biblioteca.'),
    (5, 2, 1, 2, 'No pudimos concretar la hora, pero fue amable.'),
    (8, 16, 5, 4, 'Las clases de álgebra me ayudaron a pasar el parcial.'),
    (14, 9, 18, 4, 'Las diapositivas en Canva quedaron muy estéticas.'),
    (20, 3, 24, 3, 'La asesoría fue buena, pero un poco costosa para ser estudiante.'),
    (10, 2, 15, 5, 'Física II es difícil, pero con esta tutoría se entiende todo.'),
    (17, 10, 20, 5, 'El aparto-estudio es muy seguro y el sector es bueno.'),
    (23, 11, 27, 4, 'Formateo rápido y dejó todos los drivers instalados.'),
    (12, 1, 2, 5, 'El mejor tutor de la UPC, sin duda alguna.');

-- 8. ASPECTOS DESTACADOS
INSERT INTO aspectos_destacados (id_calificacion, tipo_aspecto) VALUES
    (1, 'Puntualidad'),
    (1, 'Calidad'),
    (1, 'Comunicación'),
    (1, 'Precio justo');
