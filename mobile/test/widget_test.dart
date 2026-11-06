import 'package:flutter_test/flutter_test.dart';
import 'package:consware_reimbursements/main.dart';

void main() {
  testWidgets('la app arranca y muestra el titulo Crear', (WidgetTester tester) async {
    await tester.pumpWidget(const ConswareReimbursementsApp());
    expect(find.text('Crear').first, findsOneWidget);
  });
}
