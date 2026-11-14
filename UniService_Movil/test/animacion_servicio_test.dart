import 'package:app_uniservice/core/app_theme.dart';
import 'package:app_uniservice/models/servicio.dart';
import 'package:app_uniservice/widgets/tarjeta_servicio.dart';
import 'package:app_uniservice/widgets/tarjeta_interactiva.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await GoogleFonts.pendingFonts([
      for (final peso in [
        FontWeight.w400,
        FontWeight.w500,
        FontWeight.w600,
        FontWeight.w700,
      ])
        GoogleFonts.poppins(fontWeight: peso),
    ]);
  });

  Future<void> mostrar(
    WidgetTester tester,
    VoidCallback abrir, {
    bool reducir = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.claro,
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reducir),
          child: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  SizedBox(
                    width: 320,
                    child: TarjetaServicio(
                      servicio: Servicio(
                        id: 1,
                        titulo: 'Tutoría de cálculo',
                        descripcion: 'Aprende a resolver derivadas.',
                        categoria: 'Tutorías',
                        proveedor: 'Laura',
                        precio: 20000,
                        estrellas: 0,
                        numResenas: 0,
                        fechaPublicacion: DateTime(2026),
                      ),
                      onTap: abrir,
                    ),
                  ),
                  const SizedBox(height: 1200),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Finder getTransform() => find
      .descendant(
        of: find.byType(TarjetaInteractiva),
        matching: find.byType(Transform),
      )
      .first;

  testWidgets(
    'La pulsación se anima antes de abrir y evita aperturas duplicadas',
    (tester) async {
      var aperturas = 0;
      await mostrar(tester, () => aperturas++);
      await tester.tap(find.byType(TarjetaServicio));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      expect(aperturas, 0);
      expect(
        tester.widget<Transform>(getTransform()).transform.storage[13],
        lessThan(0),
      );
      await tester.tap(find.byType(TarjetaServicio));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 150));
      expect(aperturas, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Deslizar la lista cancela el toque y no abre el servicio', (
    tester,
  ) async {
    var aperturas = 0;
    await mostrar(tester, () => aperturas++);
    await tester.drag(find.byType(TarjetaServicio), const Offset(0, -180));
    await tester.pumpAndSettle();
    expect(aperturas, 0);
  });

  testWidgets('El cursor eleva la tarjeta y al salir vuelve a su posición', (
    tester,
  ) async {
    var aperturas = 0;
    await mostrar(tester, () => aperturas++);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(700, 500));
    await mouse.moveTo(tester.getCenter(find.byType(TarjetaServicio)));
    await tester.pumpAndSettle();
    expect(
      tester.widget<Transform>(getTransform()).transform.storage[13],
      lessThan(0),
    );
    await mouse.moveTo(const Offset(700, 500));
    await tester.pumpAndSettle();
    expect(tester.widget<Transform>(getTransform()).transform.storage[13], 0);
    expect(aperturas, 0);
    await mouse.removePointer();
  });

  testWidgets('Reducir movimiento permite abrir inmediatamente', (
    tester,
  ) async {
    var aperturas = 0;
    await mostrar(tester, () => aperturas++, reducir: true);
    await tester.tap(find.byType(TarjetaServicio));
    expect(aperturas, 1);
    expect(tester.widget<Transform>(getTransform()).transform.storage[13], 0);
  });

  testWidgets(
    'Desmontar la tarjeta durante la animación cancela la navegación',
    (tester) async {
      var aperturas = 0;
      await mostrar(tester, () => aperturas++);
      await tester.tap(find.byType(TarjetaServicio));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 300));
      expect(aperturas, 0);
      expect(tester.takeException(), isNull);
    },
  );
}
