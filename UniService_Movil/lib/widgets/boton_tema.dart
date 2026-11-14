import 'package:flutter/material.dart';
import '../data/tema_controller.dart';
import 'transicion_tema.dart';

/// Sol/luna: cambia el tema de toda la app sin reemplazar la ruta actual.
class BotonTema extends StatelessWidget {
  const BotonTema({super.key});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: TemaController.instance,
    builder: (context, _) {
      final tema = TemaController.instance;
      return IconButton(
        tooltip: tema.oscuro ? 'Activar tema claro' : 'Activar tema oscuro',
        icon: Icon(
          tema.oscuro ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
        ),
        onPressed: () async {
          final guardado = await TransicionTema.cambiar(context);
          if (guardado == false && context.mounted) {
            ScaffoldMessenger.maybeOf(context)?.showSnackBar(
              const SnackBar(
                content: Text(
                  'El tema cambió, pero no pudimos guardar la preferencia en este dispositivo.',
                ),
              ),
            );
          }
        },
      );
    },
  );
}
