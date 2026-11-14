import 'package:app_uniservice/core/app_colors.dart';
import 'package:app_uniservice/core/app_theme.dart';
import 'package:app_uniservice/core/categorias.dart';
import 'package:app_uniservice/data/tema_controller.dart';
import 'package:app_uniservice/main.dart';
import 'package:app_uniservice/screens/home/navbar_home.dart';
import 'package:app_uniservice/screens/home_guest/navbar_invitado.dart';
import 'package:app_uniservice/screens/publicar/publicar_screen.dart';
import 'package:app_uniservice/widgets/boton_tema.dart';
import 'package:app_uniservice/widgets/transicion_tema.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

class _StorageFallido extends Fake implements FlutterSecureStorage {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #read) {
      return Future<String?>.error(Exception('No disponible'));
    }
    if (invocation.memberName == #write) {
      return Future<void>.error(Exception('No disponible'));
    }
    return super.noSuchMethod(invocation);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    // Cargar las fuentes locales antes de medir o animar texto.
    await GoogleFonts.pendingFonts([
      for (final peso in [
        FontWeight.w400,
        FontWeight.w500,
        FontWeight.w600,
        FontWeight.w700,
        FontWeight.w800,
      ])
        GoogleFonts.poppins(fontWeight: peso),
      GoogleFonts.dmSerifDisplay(),
    ]);
  });
  setUp(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    FlutterSecureStorage.setMockInitialValues({});
    await TemaController.instance.restaurar();
  });

  test(
    'Conserva la preferencia al reiniciar y ordena cambios rápidos',
    () async {
      final c = TemaController();
      addTearDown(c.dispose);
      expect(c.modo, ThemeMode.dark);
      expect(await c.alternar(), isTrue);
      final reiniciado = TemaController();
      addTearDown(reiniciado.dispose);
      await reiniciado.restaurar();
      expect(reiniciado.modo, ThemeMode.light);
      await Future.wait([c.alternar(), c.alternar(), c.alternar()]);
      await reiniciado.restaurar();
      expect(reiniciado.modo, ThemeMode.dark);
    },
  );

  test(
    'Un fallo al guardar permite cambiar el tema e informa el fallo',
    () async {
      final c = TemaController(storage: _StorageFallido());
      addTearDown(c.dispose);
      await c.restaurar();
      expect(c.modo, ThemeMode.dark);
      expect(await c.alternar(), isFalse);
      expect(c.modo, ThemeMode.light);
    },
  );

  test('Paleta clara: texto, acciones y categorías tienen contraste', () {
    const p = AppPalette(oscuro: false);
    double contraste(Color texto, Color fondo) =>
        (fondo.computeLuminance() + .05) / (texto.computeLuminance() + .05);
    for (final color in [
      p.texto,
      p.texto2,
      p.texto3,
      p.placeholder,
      p.teal,
      p.teal2,
      p.amarillo,
      p.errorTexto,
      p.admin,
      p.verificado,
    ]) {
      expect(contraste(color, p.bg), greaterThanOrEqualTo(4.5));
    }
    for (final categoria in coloresCategoria.values) {
      expect(
        contraste(p.legible(categoria.color), p.card),
        greaterThanOrEqualTo(5),
      );
    }
  });

  void celular(WidgetTester tester, [double ancho = 360]) {
    tester.view.physicalSize = Size(ancho, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      tester.view.reset();
    });
  }

  Widget conTema(Widget child) => ListenableBuilder(
    listenable: TemaController.instance,
    builder: (context, _) => MaterialApp(
      theme: AppTheme.claro,
      darkTheme: AppTheme.oscuro,
      themeMode: TemaController.instance.modo,
      home: child,
    ),
  );

  testWidgets('El botón conserva el correo y la ruta al cambiar de tema', (
    tester,
  ) async {
    celular(tester);
    await tester.pumpWidget(const UniServiceApp(rutaInicial: '/login'));
    await tester.pump();
    await tester.enterText(find.byType(TextField).first, 'ana@unicesar.edu.co');
    await tester.tap(find.byTooltip('Activar tema claro'));
    await tester.pump();
    expect(find.text('Cambiando tema'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 350));
    expect(TemaController.instance.modo, ThemeMode.dark);
    // Atrás no debe retirar la cobertura a mitad del cambio.
    await navigatorKey.currentState!.maybePop();
    await tester.pump(const Duration(milliseconds: 150));
    expect(TemaController.instance.modo, ThemeMode.light);
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Cambiando tema'), findsNothing);
    expect(find.text('ana@unicesar.edu.co'), findsOneWidget);
    expect(find.byTooltip('Activar tema oscuro'), findsOneWidget);
    expect(
      Theme.of(tester.element(find.byType(TextField).first)).brightness,
      Brightness.light,
    );
    final barras = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
      find.byType(AnnotatedRegion<SystemUiOverlayStyle>).first,
    );
    expect(barras.value.statusBarIconBrightness, Brightness.dark);
    navigatorKey.currentState!.pushNamed('/privacidad');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Política de Privacidad'), findsOneWidget);
    final cambio = TemaController.instance.alternar();
    await tester.pump();
    await cambio;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Política de Privacidad'), findsOneWidget);
    navigatorKey.currentState!.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('ana@unicesar.edu.co'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Un formulario const abierto actualiza colores sin perder el borrador',
    (tester) async {
      celular(tester);
      await tester.pumpWidget(conTema(const PublicarScreen()));
      await tester.pump();
      await tester.enterText(
        find.byType(TextFormField).first,
        'Tutoría de cálculo',
      );
      final estado = tester.state(find.byType(PublicarScreen));
      final cambio = TemaController.instance.alternar();
      await tester.pump();
      await cambio;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.state(find.byType(PublicarScreen)), same(estado));
      expect(find.text('Tutoría de cálculo'), findsOneWidget);
      final campo = tester.widget<TextFormField>(
        find.byType(TextFormField).first,
      );
      expect(campo.controller!.text, 'Tutoría de cálculo');
      expect(
        Theme.of(tester.element(find.byType(PublicarScreen))).brightness,
        Brightness.light,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'La transición funciona en ambos sentidos y bloquea cambios simultáneos',
    (tester) async {
      celular(tester);
      await tester.pumpWidget(
        conTema(const Scaffold(body: Center(child: BotonTema()))),
      );
      for (final destino in [ThemeMode.light, ThemeMode.dark]) {
        await tester.tap(find.byType(IconButton));
        await tester.pump();
        expect(find.text('Cambiando tema'), findsOneWidget);
        final duplicado = await TransicionTema.cambiar(
          tester.element(find.byType(BotonTema).first),
        );
        expect(duplicado, isNull);
        await tester.pumpAndSettle();
        expect(find.text('Cambiando tema'), findsNothing);
        expect(TemaController.instance.modo, destino);
        expect(
          await const FlutterSecureStorage().read(key: TemaController.clave),
          destino == ThemeMode.light ? 'claro' : 'oscuro',
        );
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Reducir movimiento omite la pantalla animada de tema', (
    tester,
  ) async {
    celular(tester);
    await tester.pumpWidget(
      conTema(
        const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: Scaffold(body: Center(child: BotonTema())),
        ),
      ),
    );
    await tester.tap(find.byType(IconButton));
    await tester.pumpAndSettle();
    expect(find.text('Cambiando tema'), findsNothing);
    expect(TemaController.instance.modo, ThemeMode.light);
  });

  for (final ancho in [320.0, 800.0, 1025.0, 1280.0, 1401.0]) {
    testWidgets(
      'Los botones de tema caben en las barras a ${ancho.toInt()} px',
      (tester) async {
        celular(tester, ancho);
        final cambio = TemaController.instance.alternar();
        await tester.pump();
        await cambio;
        await tester.pumpWidget(
          conTema(
            Scaffold(
              body: Column(
                children: [
                  NavbarInvitado(
                    movil: ancho <= Breakpoints.navbarInvitado,
                    menuAbierto: false,
                    onToggleMenu: () {},
                    onAncla: (_) {},
                    onLogin: () {},
                  ),
                  NavbarHome(
                    movil: ancho <= Breakpoints.navbarUsuario,
                    menuAbierto: false,
                    scrolled: false,
                    nombreUsuario: 'María Fernanda Hernández Martínez',
                    onToggleMenu: () {},
                    onAncla: (_) {},
                    onSolicitudes: () {},
                    onPerfil: () {},
                    onCerrarSesion: () {},
                    onPanelAdmin: () {},
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pump();
        expect(find.byTooltip('Activar tema oscuro'), findsNWidgets(2));
        expect(tester.takeException(), isNull);
      },
    );
  }
}
