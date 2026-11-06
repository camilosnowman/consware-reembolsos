import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:consware_reimbursements/widgets/status_badge.dart';

Widget _wrap(StatusBadge badge) => MaterialApp(
      home: Scaffold(body: Center(child: badge)),
    );

void main() {
  group('StatusBadge con los estados de la API (inglés)', () {
    testWidgets('Approved se muestra como Aprobada en verde',
        (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(const StatusBadge(status: 'Approved')));

      final text = tester.widget<Text>(find.text('Aprobada'));
      expect(text.style?.color, Colors.green.shade700);
    });

    testWidgets('Rejected se muestra como Rechazada en rojo',
        (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(const StatusBadge(status: 'Rejected')));

      final text = tester.widget<Text>(find.text('Rechazada'));
      expect(text.style?.color, Colors.red.shade700);
    });

    testWidgets('Pending se muestra como Pendiente en naranja',
        (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(const StatusBadge(status: 'Pending')));

      final text = tester.widget<Text>(find.text('Pendiente'));
      expect(text.style?.color, Colors.orange.shade800);
    });

    testWidgets('tolera mayúsculas/minúsculas del backend',
        (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(const StatusBadge(status: 'rejected')));
      expect(find.text('Rechazada'), findsOneWidget);

      await tester.pumpWidget(_wrap(const StatusBadge(status: 'APPROVED')));
      expect(find.text('Aprobada'), findsOneWidget);
    });
  });

  group('isRejectedStatus (condición para mostrar el motivo)', () {
    test('reconoce los valores de la API y el español', () {
      expect(isRejectedStatus('Rejected'), isTrue);
      expect(isRejectedStatus('rejected'), isTrue);
      expect(isRejectedStatus(' RECHAZADA '), isTrue);
      expect(isRejectedStatus('Approved'), isFalse);
      expect(isRejectedStatus('Pending'), isFalse);
      expect(isRejectedStatus('pendiente'), isFalse);
      expect(isRejectedStatus(''), isFalse);
    });
  });
}
