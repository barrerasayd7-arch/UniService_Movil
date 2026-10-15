import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app_uniservice/widgets/explorador_servicios.dart';
import 'package:app_uniservice/widgets/tarjeta_servicio.dart';

import 'fakes/api_falsa.dart';

Widget _app(ApiFalsa api) => MaterialApp(
  home: Scaffold(
    body: SingleChildScrollView(
      child: ExploradorServicios(
        repositorio: api.repositorio(),
        onTapServicio: (_) {},
        encabezado: const Text('Hola'),
      ),
    ),
  ),
);

/// Monta el explorador y espera la primera respuesta de la API.
Future<ApiFalsa> _montar(WidgetTester tester, [ApiFalsa? api]) async {
  api ??= ApiFalsa();
  await tester.pumpWidget(_app(api));
  await tester.pumpAndSettle();
  return api;
}

/// Escribe en el buscador y deja pasar la espera antes de consultar la API.
Future<void> _buscar(WidgetTester tester, String texto) async {
  await tester.enterText(find.byType(TextField), texto);
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    // Celular típico: 390 x 844.
    final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = const Size(390, 844);
    view.devicePixelRatio = 1;
  });
  tearDown(() => TestWidgetsFlutterBinding.instance.platformDispatcher.views.first.reset());

  testWidgets('Sin filtros muestra destacados y la primera página', (tester) async {
    final api = await _montar(tester);
    expect(find.text('Mejor calificados'), findsOneWidget);
    expect(find.text('Todos los servicios'), findsOneWidget);
    expect(find.byType(TarjetaServicio), findsWidgets);
    expect(api.peticiones.first.queryParameters['pagina'], '1');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Buscar consulta la API al dejar de escribir y oculta destacados', (tester) async {
    final api = await _montar(tester);
    final antes = api.peticiones.length;
    await tester.enterText(find.byType(TextField), 'flu');
    await tester.pump(const Duration(milliseconds: 100));
    await _buscar(tester, 'flutter');
    // Una sola consulta por la búsqueda, no una por letra.
    final busquedas = api.peticiones.skip(antes).toList();
    expect(busquedas.map((u) => u.queryParameters['busqueda']), ['flutter']);
    expect(find.text('1 resultado'), findsOneWidget);
    expect(find.text('Mejor calificados'), findsNothing);
  });

  testWidgets('Una categoría filtra en el servidor', (tester) async {
    tester.view.physicalSize = const Size(1280, 900); // todos los chips a la vista
    final api = await _montar(tester);
    await tester.tap(find.byKey(const ValueKey('chip-arriendo')));
    await tester.pumpAndSettle();
    expect(api.peticiones.last.queryParameters['categoria'], '6');
    expect(find.text('1 resultado'), findsOneWidget);
  });

  testWidgets('Sin resultados ofrece volver a ver todos', (tester) async {
    await _montar(tester);
    await _buscar(tester, 'zzzz');
    expect(find.text('Sin resultados para "zzzz"'), findsOneWidget);
    await tester.tap(find.text('Ver todos'));
    await tester.pumpAndSettle();
    expect(find.text('Todos los servicios'), findsOneWidget);
    expect(find.byType(TarjetaServicio), findsWidgets);
  });

  testWidgets('"Ver más" pide la página siguiente', (tester) async {
    final api = await _montar(tester);
    final boton = find.text('Ver más servicios (3)');
    await tester.scrollUntilVisible(
      boton,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(boton);
    await tester.pumpAndSettle();
    expect(api.peticiones.last.queryParameters['pagina'], '2');
    expect(find.textContaining('Ver más servicios'), findsNothing);
  });

  testWidgets('Si la API falla muestra el error y permite reintentar', (tester) async {
    final api = ApiFalsa()..fallar = true;
    await _montar(tester, api);
    expect(find.text('No pudimos cargar los servicios'), findsOneWidget);
    expect(find.text('Error interno del servidor'), findsOneWidget);

    api.fallar = false;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(find.byType(TarjetaServicio), findsWidgets);
  });

  testWidgets('Sin servicios publicados invita a publicar', (tester) async {
    await _montar(tester, ApiFalsa([]));
    expect(find.text('Todavía no hay servicios publicados'), findsOneWidget);
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
    await _montar(tester);
    expect(altosUniformes(tester), everyElement(1));
  });

  testWidgets('En pantalla ancha la rejilla usa columnas de igual altura', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    await _montar(tester);
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
