import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:consware_reimbursements/main.dart';
import 'package:consware_reimbursements/services/reimbursement_api_service.dart';

void main() {
  setUpAll(() async {
    // El listado formatea fechas con el locale es_CO.
    await initializeDateFormatting('es_CO');
  });

  /// Bomba la app completa con una API falsa (sin red) y pantalla alta
  /// para que todo el formulario quepa sin desplazar.
  Future<void> pumpApp(WidgetTester tester, ReimbursementApiService service) async {
    tester.view.physicalSize = const Size(900, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ConswareReimbursementsApp(apiService: service));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'POST exitoso: vuelve al listado, repite el GET y muestra la solicitud (lista inicialmente vacía)',
      (WidgetTester tester) async {
    final items = <Map<String, dynamic>>[];
    final apiService = ReimbursementApiService(
      client: MockClient((request) async {
        if (request.method == 'POST') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          items.add({
            'id': items.length + 1,
            'employeeName': body['employeeName'],
            'amount': body['amount'],
            'category': body['category'],
            'description': body['description'],
            'status': 'Pending',
            'rejectionReason': null,
            'createdAtUtc': '2026-11-06T10:00:00Z',
            'decidedAtUtc': null,
          });
          // El backend real responde con charset utf-8.
          return http.Response(
            jsonEncode(items.last),
            201,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return http.Response(
          jsonEncode(items),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    await pumpApp(tester, apiService);

    // El listado inicial está vacío y sigue permitiendo "tirar para refrescar".
    await tester.tap(find.text('Mis solicitudes'));
    await tester.pumpAndSettle();
    expect(find.text('Aún no tienes solicitudes'), findsOneWidget);

    // Crear una solicitud desde la pestaña Crear.
    await tester.tap(find.text('Crear'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, '650000');
    await tester.enterText(find.byType(TextFormField).last, 'Taxi aeropuerto');
    await tester.tap(find.text('Enviar solicitud'));
    await tester.pump(); // POST en curso.
    await tester.pumpAndSettle(); // Éxito, cambio de pestaña y GET automático.

    // El GET se repitió y la lista (antes vacía) muestra la solicitud.
    expect(find.text('Taxi aeropuerto'), findsOneWidget);
    expect(find.text('Alimentación'), findsOneWidget);
    expect(find.text(r'$650.000 COP'), findsOneWidget);
    expect(find.text('Aún no tienes solicitudes'), findsNothing);

    // El formulario conserva su estado al volver (IndexedStack lo mantiene vivo).
    await tester.tap(find.text('Crear'));
    await tester.pumpAndSettle();
    expect(find.text('Nueva solicitud de reembolso'), findsOneWidget);

    // Cierra el SnackBar para no dejar temporizadores pendientes.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  testWidgets(
      'entrar a Mis solicitudes repite el GET y refresca la decisión del gestor',
      (WidgetTester tester) async {
    var approved = false;
    final apiService = ReimbursementApiService(
      client: MockClient((request) async => http.Response(
            jsonEncode([
              {
                'id': 1,
                'employeeName': 'Empleado Demo',
                'amount': 650000,
                'category': 'Transporte',
                'description': 'Taxi aeropuerto',
                'status': approved ? 'Approved' : 'Pending',
                'rejectionReason': null,
                'createdAtUtc': '2026-11-01T10:00:00Z',
                'decidedAtUtc': approved ? '2026-11-01T11:00:00Z' : null,
              }
            ]),
            200,
          )),
    );

    await pumpApp(tester, apiService);

    // Primera visita: la solicitud sigue Pendiente.
    await tester.tap(find.text('Mis solicitudes'));
    await tester.pumpAndSettle();
    expect(find.text('Pendiente'), findsOneWidget);

    // El gestor aprueba la solicitud desde otro dispositivo.
    approved = true;

    // Salir y volver a entrar a "Mis solicitudes": el GET se repite.
    await tester.tap(find.text('Crear'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mis solicitudes'));
    await tester.pumpAndSettle();

    expect(find.text('Pendiente'), findsNothing);
    expect(find.text('Aprobada'), findsOneWidget);
  });
}
