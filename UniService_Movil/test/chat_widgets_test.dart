import 'package:app_uniservice/models/chat.dart';
import 'package:app_uniservice/screens/chat/chat_screen.dart';
import 'package:app_uniservice/screens/chat/chat_session.dart';
import 'package:app_uniservice/screens/chat/chats_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'fakes/chat_api_falsa.dart';

void main() {
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<void> mostrar(
    WidgetTester tester,
    Widget pantalla, {
    Size size = const Size(360, 780),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        navigatorObservers: [chatRouteObserver],
        home: pantalla,
      ),
    );
    await tester.pumpAndSettle();
  }

  ChatScreen conversacion(ChatApiFalsa api, {bool disponible = true}) =>
      ChatScreen(
        repositorio: api.repo,
        miId: 1,
        destino: DestinoChat(
          idChat: 7,
          contacto: ContactoChat(
            id: 2,
            nombre: 'Laura Pérez',
            disponible: disponible,
          ),
        ),
      );

  testWidgets('La bandeja busca por nombre y filtra mensajes no leídos', (
    tester,
  ) async {
    final api = ChatApiFalsa()..datos.add(mensajeFalso(1));
    await mostrar(tester, ChatsScreen(repositorio: api.repo));
    expect(find.text('Laura Pérez'), findsOneWidget);
    expect(find.text('Carlos Gómez'), findsOneWidget);
    await tester.tap(find.text('No leídos'));
    await tester.pumpAndSettle();
    expect(find.text('Carlos Gómez'), findsNothing);
    await tester.tap(find.text('No leídos'));
    await tester.enterText(find.byType(TextField), 'carlos');
    await tester.pumpAndSettle();
    expect(find.text('Laura Pérez'), findsNothing);
    expect(find.text('Carlos Gómez'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Un error de bandeja se recupera con Actualizar', (tester) async {
    final api = ChatApiFalsa()..errorListado = 503;
    await mostrar(tester, ChatsScreen(repositorio: api.repo));
    expect(find.text('No pudimos cargar tus chats'), findsOneWidget);
    api.errorListado = null;
    await tester.tap(find.text('Actualizar'));
    await tester.pumpAndSettle();
    expect(find.text('Laura Pérez'), findsOneWidget);
  });

  testWidgets('Enviar limpia el borrador confirmado y no duplica el mensaje', (
    tester,
  ) async {
    final api = ChatApiFalsa();
    await mostrar(tester, conversacion(api));
    await tester.enterText(
      find.byKey(const ValueKey('borrador-chat')),
      'Hola Laura',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('enviar-chat')));
    await tester.pumpAndSettle();
    expect(find.text('Hola Laura'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('borrador-chat')))
          .controller!
          .text,
      isEmpty,
    );
    expect(api.datos.length, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Si falla el envío conserva el borrador y permite enviarlo después',
    (tester) async {
      final api = ChatApiFalsa()..errorEnvio = 429;
      await mostrar(tester, conversacion(api));
      await tester.enterText(
        find.byKey(const ValueKey('borrador-chat')),
        '¿A qué hora?',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('enviar-chat')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('borrador-chat')))
            .controller!
            .text,
        '¿A qué hora?',
      );
      expect(api.datos, isEmpty);
      api.errorEnvio = null;
      await tester.tap(find.byKey(const ValueKey('enviar-chat')));
      await tester.pumpAndSettle();
      expect(api.datos.single['mensaje'], '¿A qué hora?');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Al recibir un evento carga el mensaje y marca lectura', (
    tester,
  ) async {
    final api = ChatApiFalsa();
    await mostrar(tester, conversacion(api));
    api.lecturas = 0;
    api.datos.add(mensajeFalso(1, texto: 'Buenos días'));
    api.repo.avisarCambio(7);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pumpAndSettle();
    expect(find.text('Buenos días'), findsOneWidget);
    expect(api.lecturas, 1);
  });

  testWidgets('Una conversación oculta no marca mensajes como leídos', (
    tester,
  ) async {
    final api = ChatApiFalsa();
    await mostrar(tester, conversacion(api));
    api.lecturas = 0;
    final contexto = tester.element(find.byType(ChatScreen));
    Navigator.of(contexto).push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Otra pantalla')),
      ),
    );
    await tester.pumpAndSettle();
    api.datos.add(mensajeFalso(1));
    api.repo.avisarCambio(7);
    await tester.pump();
    await tester.pump(const Duration(seconds: 11));
    expect(api.lecturas, 0);
    Navigator.of(contexto).pop();
    await tester.pumpAndSettle();
    expect(api.lecturas, 1);
  });

  testWidgets('Cuenta suspendida permite consultar pero no escribir', (
    tester,
  ) async {
    final api = ChatApiFalsa()
      ..datos.add(mensajeFalso(1, texto: 'Mensaje anterior'));
    await mostrar(tester, conversacion(api, disponible: false));
    expect(find.text('Mensaje anterior'), findsOneWidget);
    expect(find.text('Conversación de solo lectura'), findsOneWidget);
    expect(find.byKey(const ValueKey('borrador-chat')), findsNothing);
  });

  testWidgets('El chat cabe con teclado y textos largos en móvil', (
    tester,
  ) async {
    final api = ChatApiFalsa()
      ..datos.addAll([
        mensajeFalso(
          1,
          texto: 'Nueva solicitud para tutoría.\nPresupuesto: 20000',
          tipo: 'sistema',
        ),
        mensajeFalso(
          2,
          remitente: 1,
          texto: 'Un mensaje largo con detalles del servicio. ' * 12,
        ),
      ]);
    await mostrar(tester, conversacion(api), size: const Size(360, 780));
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('enviar-chat')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('El chat también se muestra en escritorio sin desbordamientos', (
    tester,
  ) async {
    final api = ChatApiFalsa()..datos.add(mensajeFalso(1));
    await mostrar(tester, conversacion(api), size: const Size(1280, 800));
    expect(find.text('Mensaje 1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
