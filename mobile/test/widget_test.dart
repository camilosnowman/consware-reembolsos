import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:consware_reimbursements/main.dart';
import 'package:consware_reimbursements/services/reimbursement_api_service.dart';

void main() {
  testWidgets('la app arranca y muestra la pestaña Crear',
      (WidgetTester tester) async {
    // API falsa (sin red): el listado inicial está vacío.
    final apiService = ReimbursementApiService(
      client: MockClient(
        (request) async => http.Response(
          '[]',
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      ),
    );
    await tester.pumpWidget(
      ConswareReimbursementsApp(apiService: apiService),
    );
    await tester.pumpAndSettle();

    expect(find.text('Crear'), findsOneWidget);
    expect(find.text('Nueva solicitud de reembolso'), findsOneWidget);
  });
}
