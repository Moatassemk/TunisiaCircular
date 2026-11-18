import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:clac_mobile/main.dart' as app;

const _email = String.fromEnvironment('CLAC_TEST_EMAIL');
const _password = String.fromEnvironment('CLAC_TEST_PASSWORD');

Future<void> _settle(WidgetTester tester) =>
    tester.pumpAndSettle(const Duration(milliseconds: 250));

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'member can sign in, open the Tunisia network, and start an exact map pin',
    (tester) async {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString('locale', 'en');
      await preferences.remove('token');
      await preferences.remove('user');
      app.main();
      await _settle(tester);

      await tester.tap(find.text('Already a member? Sign in'));
      await _settle(tester);
      final fields = find.byType(TextFormField);
      expect(fields, findsNWidgets(2));
      await tester.enterText(fields.at(0), _email);
      await tester.enterText(fields.at(1), _password);
      await tester.tap(find.text('Sign in').last);
      await _settle(tester);

      expect(find.byType(Scaffold), findsWidgets);
      await tester.tap(find.byTooltip('Open navigation menu'));
      await _settle(tester);
      await tester.tap(find.text('Tunisia map'));
      await _settle(tester);
      await tester.tap(find.text('My points'));
      await _settle(tester);
      await tester.tap(find.text('Add point').first);
      await _settle(tester);
      await tester.ensureVisible(find.text('Select on map'));
      await tester.tap(find.text('Select on map'));
      await _settle(tester);

      expect(find.text('Tap the exact site location'), findsOneWidget);
      final titleRect = tester.getRect(
        find.text('Tap the exact site location'),
      );
      await tester.tapAt(Offset(titleRect.center.dx, titleRect.bottom + 150));
      await tester.pumpAndSettle();
      expect(find.text('Tap the exact site location'), findsNothing);
    },
    skip: _email.isEmpty || _password.isEmpty,
  );
}
