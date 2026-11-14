# Tema claro y oscuro

El botón de sol/luna se encuentra en las barras del inicio (invitado y usuario)
y en la pantalla de acceso. El cambio se aplica también a las rutas abiertas,
formularios, diálogos, chat y panel administrativo, conservando su estado.

Se inicia en oscuro si no existe una preferencia. La elección se guarda en el
dispositivo mediante `FlutterSecureStorage`, bajo `uniservice_tema`, y se restaura
antes de mostrar la app. No depende de la cuenta ni cambia al cerrar sesión.
Si no se puede guardar, el botón informa el fallo; el cambio visual sigue funcionando.

La paleta clara toma como referencia `frontend/src/styles/light_theme/B_styleHome.css`
del proyecto web: fondos `#f8f9fc`, `#f0f4f9`, tarjetas blancas y texto `#0d1b2a`.
Algunos acentos se oscurecen en Flutter para que sus textos tengan contraste.
Se conserva Poppins / DM Serif Display. Al pulsar sol/luna, una pantalla con
el mensaje "Cambiando tema", un icono y un aro animado cubre el contenido.
El tema se aplica cuando la cobertura está completa; después se revela la misma
pantalla, conservando sus datos. Dura aproximadamente 1,4 segundos y se inspira
en `B_StyleHome.jsx` de la web. Impide cambios simultáneos y volver atrás a mitad
del efecto. Con "reducir movimiento" del sistema, el cambio es directo.

- `core/app_colors.dart`: `AppColors.of(context)` devuelve la paleta y registra
  la dependencia de `Theme`; evita colores globales mutables.
- `core/app_theme.dart`: temas Material para controles, superficies y textos.
- `data/tema_controller.dart`: preferencia y escrituras ordenadas.
- `widgets/boton_tema.dart`: control accesible con icono y descripción de la acción.
- `widgets/transicion_tema.dart`: cobertura animada del cambio de tema.

Las tarjetas del catálogo y destacados usan `widgets/tarjeta_interactiva.dart`:
relieve, inclinación leve y borde resaltado al pasar el cursor o tocar. Al tocar,
se completa una pulsación de hasta 220 ms antes de abrir el detalle. Arrastrar
la lista cancela el toque; pulsar repetidamente no duplica la navegación.
También respeta "reducir movimiento".

Los pintores reciben la paleta desde el widget y se repintan al cambiarla.
Los colores propios de logos, imágenes y avatares decorativos se conservan.
Para nuevas pantallas, usar la paleta contextual o `Theme.of(context)`; evitar
fondos o textos fijos del tema oscuro. `AppColors` mantiene constantes de marca
para usos que no dependen del tema.

Verificación: `flutter test --no-pub test/tema_test.dart test/animacion_servicio_test.dart`
y la suite completa.
Prueba manual: alternar desde el login y ambos inicios, navegar por formularios,
abrir un chat y la campana, revisar el panel, cerrar y volver a abrir la app.
No requiere SQL ni cambios en el proyecto web o el backend.
