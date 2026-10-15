import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app_uniservice/data/servicios_mock.dart';
import 'package:app_uniservice/widgets/explorador_servicios.dart';
import 'package:app_uniservice/widgets/tarjeta_servicio.dart';

Widget _app() => MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: ExploradorServicios(
            servicios: serviciosMock,
            onTapServicio: (_) {},
            encabezado: const Text('Hola'),
          ),
        ),
      ),
    );

void main() {
  setUp(() {
    // Celular típico: 390 x 844.
    final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = const Size(390, 844);
    view.devicePixelRatio = 1;
  });
  tearDown(() => TestWidgetsFlutterBinding.instance.platformDispatcher.views.first.reset());

  testWidgets('Sin filtros muestra destacados y todos los servicios', (tester) async {
    await tester.pumpWidget(_app());
    expect(find.text('Mejor calificados'), findsOneWidget);
    expect(find.text('Todos los servicios'), findsOneWidget);
    expect(find.byType(TarjetaServicio), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Buscar filtra mientras se escribe y oculta destacados', (tester) async {
    await tester.pumpWidget(_app());
    await tester.enterText(find.byType(TextField), 'flutter');
    await tester.pump();
    expect(find.text('1 resultado'), findsOneWidget);
    expect(find.text('Mejor calificados'), findsNothing);
  });

  testWidgets('Sin resultados ofrece volver a ver todos', (tester) async {
    await tester.pumpWidget(_app());
    await tester.enterText(find.byType(TextField), 'zzzz');
    await tester.pump();
    expect(find.text('Sin resultados para "zzzz"'), findsOneWidget);
    await tester.tap(find.text('Ver todos'));
    await tester.pump();
    expect(find.text('Todos los servicios'), findsOneWidget);
  });

  // Tarjetas lado a lado (carrusel y rejilla de varias columnas) deben medir lo mismo
  // entre las de igual ancho. Devuelve cuántas alturas distintas hay por cada ancho.
  Iterable<int> altosUniformes(WidgetTester tester) {
    final porAncho = <double, Set<double>>{};
    for (final w in tester.widgetList<TarjetaServicio>(find.byType(TarjetaServicio))) {
      if (!w.alturaUniforme) continue;
      final s = tester.getSize(find.byWidget(w));
      porAncho.putIfAbsent(s.width, () => {}).add(s.height);
    }
    return porAncho.values.map((a) => a.length);
  }

  testWidgets('El carrusel tiene tarjetas de igual altura', (tester) async {
    await tester.pumpWidget(_app());
    expect(altosUniformes(tester), everyElement(1));
  });

  testWidgets('En pantalla ancha la rejilla usa columnas de igual altura', (tester) async {
    final view = tester.view;
    view.physicalSize = const Size(1280, 900);
    await tester.pumpWidget(_app());
    final grid = tester
        .widgetList<TarjetaServicio>(find.byType(TarjetaServicio))
        .map((w) => tester.getSize(find.byWidget(w)))
        .where((s) => s.width < 400)
        .toList();
    expect(grid, isNotEmpty);
    expect(altosUniformes(tester), everyElement(1));
    expect(tester.takeException(), isNull);
  });
}
