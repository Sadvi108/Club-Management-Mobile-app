// Invoice dates are rendered to members, so they must not be raw API timestamps.
//
// Caught from a screenshot: an invoice card read "2026-09-01T00:00:00". The Pay Your Dues
// card (Expo v2.11.1) shows Type / Period / Due / Status, so the timestamp has no slot to
// leak through — this pins that, and that the row still renders its member.
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

import 'package:dclix_app/screens/outstanding_invoices_screen.dart';
import 'package:dclix_app/services/api_service.dart';
import 'package:dclix_app/services/user_session.dart';

void main() {
  testWidgets('an ISO timestamp is never shown raw on an invoice', (tester) async {
    final original = ApiService.client;
    addTearDown(() => ApiService.client = original);
    ApiService.client = MockClient((request) async => http.Response(
        jsonEncode({
          'status': 200,
          'data': request.url.path == '/Outstanding/Fetch'
              ? [
                  {
                    'invoiceId': 5001,
                    'invoiceNo': 'INV-2026-0091',
                    'invoiceDescription': 'Monthly fee',
                    'invoiceDate': '2026-09-01T00:00:00',
                    'period': 'September-2026',
                    'dueAmount': 85.00,
                    'paymentStatus': 'Pending',
                    'studentName': 'Alex Tan',
                  }
                ]
              : []
        }),
        200));
    await tester.pumpWidget(ChangeNotifierProvider<UserSession>.value(
      value: UserSession.instance,
      child: const MaterialApp(home: OutstandingInvoicesScreen()),
    ));
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }

    expect(find.textContaining('T00:00:00'), findsNothing,
        reason: 'a raw ISO timestamp reached the invoice card');
    expect(find.text('Alex Tan'), findsOneWidget);
    expect(find.text('September-2026'), findsOneWidget);
  });
}
