import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:consware_reimbursements/main.dart';
import 'package:consware_reimbursements/services/reimbursement_api_service.dart';

/// Cliente falso que registra si alguien llamó a close().
class _TrackingMockClient extends MockClient {
  _TrackingMockClient(super.fn);

  bool closed = false;

  @override
  void close() {
    closed = true;
    super.close();
  }
}

/// Servicio que registra si HomeShell intentó disponerlo.
class _TrackingApiService extends ReimbursementApiService {
  _TrackingApiService({required super.client});

  bool disposed = false;

  @override
  void dispose() {
    disposed = true;
    super.dispose();
  }
}

void main() {
  test('el servicio no cierra el http.Client inyectado (no es su dueño)',
      () async {
    final client = _TrackingMockClient(
      (request) async => http.Response(
        '[]',
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      ),
    );
    final service = ReimbursementApiService(client: client);

    service.dispose();

    expect(client.closed, isFalse);
    // Sigue siendo usable: el ciclo de vida del cliente lo controla quien
    // lo inyectó.
    expect(await service.getMyReimbursements('Empleado Demo'), isEmpty);
  });

  testWidgets('HomeShell no dispone el apiService inyectado',
      (WidgetTester tester) async {
    final client = _TrackingMockClient(
      (request) async => http.Response(
        '[]',
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      ),
    );
    final service = _TrackingApiService(client: client);

    await tester.pumpWidget(ConswareReimbursementsApp(apiService: service));
    await tester.pumpAndSettle();

    // Al desmontar la app, el servicio inyectado sigue siendo propiedad
    // de las pruebas y no debe cerrarse.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();

    expect(service.disposed, isFalse);
    expect(client.closed, isFalse);
    service.dispose();
  });
}
