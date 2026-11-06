import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:consware_reimbursements/screens/my_reimbursements_screen.dart';
import 'package:consware_reimbursements/services/reimbursement_api_service.dart';

/// Item típico de /api/reimbursements (JSON camelCase de la API).
Map<String, dynamic> _item({
  int id = 1,
  String status = 'Pending',
  String? rejectionReason,
}) =>
    {
      'id': id,
      'employeeName': 'Empleado Demo',
      'amount': 650000,
      'category': 'Transporte',
      'description': 'Taxi aeropuerto',
      'status': status,
      'rejectionReason': rejectionReason,
      'createdAtUtc': '2026-11-01T10:00:00Z',
      'decidedAtUtc': status == 'Pending' ? null : '2026-11-01T11:00:00Z',
    };

http.Response _ok(List<Map<String, dynamic>> items) => http.Response(
      jsonEncode(items),
      200,
      // El backend real responde con charset utf-8; sin este header,
      // http.Response codificaría el body como latin1.
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

Widget _wrap(Widget child) => MaterialApp(home: child);

void main() {
  setUpAll(() async {
    // El listado formatea fechas con el locale es_CO.
    await initializeDateFormatting('es_CO');
  });

  testWidgets('solicitud rechazada muestra badge Rechazada y el motivo',
      (WidgetTester tester) async {
    final apiService = ReimbursementApiService(
      client: MockClient(
        (request) async => _ok([
          _item(status: 'Rejected', rejectionReason: 'Fuera de política'),
        ]),
      ),
    );

    await tester.pumpWidget(_wrap(MyReimbursementsScreen(
      apiService: apiService,
      employeeName: 'Empleado Demo',
    )));
    await tester.pumpAndSettle();

    expect(find.text('Rechazada'), findsOneWidget);
    expect(find.text('Motivo del rechazo: Fuera de política'), findsOneWidget);
  });

  testWidgets('solicitud aprobada muestra badge Aprobada y sin motivo',
      (WidgetTester tester) async {
    final apiService = ReimbursementApiService(
      client: MockClient(
        (request) async => _ok([_item(status: 'Approved')]),
      ),
    );

    await tester.pumpWidget(_wrap(MyReimbursementsScreen(
      apiService: apiService,
      employeeName: 'Empleado Demo',
    )));
    await tester.pumpAndSettle();

    expect(find.text('Aprobada'), findsOneWidget);
    expect(find.textContaining('Motivo del rechazo'), findsNothing);
  });

  testWidgets('rechazada sin motivo no muestra la caja de motivo',
      (WidgetTester tester) async {
    final apiService = ReimbursementApiService(
      client: MockClient(
        (request) async => _ok([_item(status: 'Rejected')]),
      ),
    );

    await tester.pumpWidget(_wrap(MyReimbursementsScreen(
      apiService: apiService,
      employeeName: 'Empleado Demo',
    )));
    await tester.pumpAndSettle();

    expect(find.text('Rechazada'), findsOneWidget);
    expect(find.textContaining('Motivo del rechazo'), findsNothing);
  });

  testWidgets('error de red muestra mensaje y botón REINTENTAR; al reintentar recupera',
      (WidgetTester tester) async {
    var offline = true;
    final apiService = ReimbursementApiService(
      client: MockClient((request) async {
        if (offline) {
          throw const SocketException('sin conexión');
        }
        return _ok([_item(status: 'Approved')]);
      }),
    );

    await tester.pumpWidget(_wrap(MyReimbursementsScreen(
      apiService: apiService,
      employeeName: 'Empleado Demo',
    )));
    await tester.pumpAndSettle();

    expect(find.text('No se pudo conectar con el servidor'), findsOneWidget);
    expect(find.text('REINTENTAR'), findsOneWidget);

    // La red se recupera y el usuario reintenta.
    offline = false;
    await tester.tap(find.text('REINTENTAR'));
    await tester.pumpAndSettle();

    expect(find.text('No se pudo conectar con el servidor'), findsNothing);
    expect(find.text('Aprobada'), findsOneWidget);
  });
}
