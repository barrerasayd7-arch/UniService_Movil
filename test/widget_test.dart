import 'package:flutter_test/flutter_test.dart';

import 'package:app_uniservice/main.dart';

void main() {
  testWidgets('La app arranca en el login', (WidgetTester tester) async {
    await tester.pumpWidget(const UniServiceApp());
    await tester.pump();

    // El login muestra el título del formulario
    expect(find.textContaining('Accede a la'), findsOneWidget);
  });
}