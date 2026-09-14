// Render smoke tests for the screens that need no network.
//
// A Dart analyzer error is not the failure mode that reaches members — an unbounded-height
// Column, a null-deref in a builder or an overflow is, and none of those show up until the
// widget is actually laid out.
import 'package:flutter/material.dart';
import 'package:dclix_app/data/guide_content.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:dclix_app/screens/offer_detail_screen.dart';
import 'package:dclix_app/screens/offers_screen.dart';
import 'package:dclix_app/screens/student_details_screen.dart';
import 'package:dclix_app/screens/user_guide_screen.dart';
import 'package:dclix_app/services/user_session.dart';

Widget _wrap(Widget child) => ChangeNotifierProvider<UserSession>.value(
      value: UserSession.instance,
      child: MaterialApp(home: child),
    );

void main() {
  setUp(() {
    UserSession.instance.myInfo = null;
    UserSession.instance.homeStats = null;
    UserSession.instance.studentAddtnlInfo = null;
  });

  group('UserGuideScreen', () {
    testWidgets('opens on the sign-in page and pages forward to the end',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_wrap(const UserGuideScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Signing in'), findsOneWidget);
      expect(find.text('Feature 1 of ${kGuideSteps.length}'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Walk every page: each one lays out its own steps, tips and callout.
      for (var i = 2; i <= kGuideSteps.length; i++) {
        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();
        expect(find.text('Feature $i of ${kGuideSteps.length}'), findsOneWidget,
            reason: 'stuck before page $i');
        expect(tester.takeException(), isNull, reason: 'page $i threw');
      }
      // The last page offers Done, not Next.
      expect(find.text('Done'), findsOneWidget);
    });
  });

  group('OffersScreen', () {
    testWidgets('with no offers it says so rather than rendering blank',
        (tester) async {
      await tester.pumpWidget(_wrap(const OffersScreen()));
      await tester.pump();
      expect(find.text('No offers right now.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders an offer and flags an expired one', (tester) async {
      UserSession.instance.homeStats = {
        'myoffers': [
          {'code': 'A1', 'title': 'Raya Special', 'description': '20% off'},
          {
            'code': 'B2',
            'title': 'Old Deal',
            'expiryDate': '2020-01-01T00:00:00'
          },
        ]
      };
      await tester.pumpWidget(_wrap(const OffersScreen()));
      await tester.pump();
      expect(find.text('Raya Special'), findsOneWidget);
      expect(find.text('Expired'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('OfferDetailScreen', () {
    testWidgets('an unknown code shows not-found, never another offer',
        (tester) async {
      // The regression that matters: this screen is the voucher shown at the counter,
      // so falling back to "the first offer" would present someone else's terms.
      UserSession.instance.homeStats = {
        'myoffers': [
          {'code': 'REAL', 'title': 'Members Only 30%'},
        ]
      };
      await tester.pumpWidget(_wrap(const OfferDetailScreen(code: 'GONE')));
      await tester.pump();
      expect(find.text('Offer not found'), findsOneWidget);
      expect(find.text('Members Only 30%'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the matching offer renders with its voucher strip',
        (tester) async {
      UserSession.instance.homeStats = {
        'myoffers': [
          {
            'code': 'REAL',
            'title': 'Members Only 30%',
            'expiryDate': '2099-06-01T00:00:00'
          },
        ]
      };
      UserSession.instance.myInfo = {
        'name': 'Test Member',
        'registrationNo': 'D-123'
      };
      await tester.pumpWidget(_wrap(const OfferDetailScreen(code: 'REAL')));
      await tester.pump();
      expect(find.text('Members Only 30%'), findsOneWidget);
      expect(find.text('REAL'), findsOneWidget);
      expect(find.text('Show this screen to redeem'), findsOneWidget);
      expect(find.text('01 Jun 2099'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('StudentDetailsScreen', () {
    // Both API calls fail in a test (no network), which is exactly the flaky-connection
    // case this guards.
    testWidgets(
        'a failed refresh does not put a red error over good cached data',
        (tester) async {
      UserSession.instance.myInfo = {
        'name': 'Alex Tan',
        'registrationNo': 'DCX-0001',
        'currentGrade': 'Green Belt',
      };
      await tester.pumpWidget(_wrap(const StudentDetailsScreen()));
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 300));
      }

      expect(find.text('Alex Tan'), findsOneWidget);
      expect(find.textContaining('Could not load'), findsNothing,
          reason:
              'the details rendered fine; an error banner reads as "my record is broken"');
      expect(tester.takeException(), isNull);
    });

    testWidgets('with nothing cached it DOES report the failure',
        (tester) async {
      // The opposite case still has to work — silence here would be a blank screen with
      // no explanation.
      UserSession.instance.myInfo = null;
      UserSession.instance.studentAddtnlInfo = null;
      UserSession.instance.authData = null;
      await tester.pumpWidget(_wrap(const StudentDetailsScreen()));
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 300));
      }
      expect(find.textContaining('Could not load'), findsOneWidget);
    });
  });
}
