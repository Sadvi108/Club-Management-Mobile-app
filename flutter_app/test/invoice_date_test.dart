// Invoice dates are rendered to members, so they must not be raw API timestamps.
//
// Caught from a screenshot: an invoice card read "2026-09-01T00:00:00".
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:dclix_app/screens/outstanding_invoices_screen.dart';
import 'package:dclix_app/services/user_session.dart';

void main() {
  testWidgets('an ISO timestamp is never shown raw on an invoice', (tester) async {
    UserSession.instance.outstandingList = [
      {
        'id': 5001,
        'invoiceNo': 'INV-2026-0091',
        'invoiceDescription': 'Monthly fee',
        'invoiceDate': '2026-09-01T00:00:00',
        'dueAmount': 85.00,
        'studentName': 'Alex Tan',
      }
    ];
    await tester.pumpWidget(ChangeNotifierProvider<UserSession>.value(
      value: UserSession.instance,
      child: const MaterialApp(home: OutstandingInvoicesScreen()),
    ));
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }

    expect(find.textContaining('T00:00:00'), findsNothing,
        reason: 'a raw ISO timestamp reached the invoice card');
    expect(find.textContaining('Sep 2026'), findsWidgets,
        reason: 'the date should read like a date');
  });
}
