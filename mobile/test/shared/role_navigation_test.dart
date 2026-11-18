import 'package:clac_mobile/shared/navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('rolePrimaryDestinations', () {
    test('collectors get points and the map', () {
      final items = rolePrimaryDestinations('collector');
      expect(items.map((item) => item.label), [
        'Home',
        'Points',
        'Requests',
        'Map',
        'More',
      ]);
      expect(items[1].pageIndex, 1);
      expect(items[3].pageIndex, 4);
      expect(items.last.isMore, isTrue);
    });

    test('sellers and buyers get different material destinations', () {
      expect(rolePrimaryDestinations('generator').map((item) => item.label), [
        'Home',
        'Materials',
        'Requests',
        'Impact',
        'More',
      ]);
      expect(rolePrimaryDestinations('processor').map((item) => item.label), [
        'Home',
        'Marketplace',
        'Requests',
        'Network',
        'More',
      ]);
    });

    test('admins get review as a primary destination', () {
      final items = rolePrimaryDestinations('admin');
      expect(items.map((item) => item.label), [
        'Home',
        'Review',
        'Requests',
        'Impact',
        'More',
      ]);
      expect(items[1].pageIndex, 11);
    });
  });

  testWidgets('dark bottom navigation uses readable label colours', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: Brightness.dark),
        home: Scaffold(
          bottomNavigationBar: ClacBottomNavigation(
            selectedIndex: 0,
            items: rolePrimaryDestinations('collector'),
            onSelected: (_) {},
          ),
        ),
      ),
    );

    final selected = tester.widget<Text>(find.text('Home'));
    final unselected = tester.widget<Text>(find.text('Requests'));
    expect(selected.style?.color, const Color(0xFF9BDCB4));
    expect(unselected.style?.color, const Color(0xFFAFC2B5));
  });

  testWidgets('renders role items and routes More without selecting a page', (
    tester,
  ) async {
    int? selected;
    var moreOpened = false;
    final items = rolePrimaryDestinations('collector');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: ClacBottomNavigation(
            selectedIndex: 1,
            items: items,
            onSelected: (value) {
              if (value == -1) {
                moreOpened = true;
              } else {
                selected = value;
              }
            },
          ),
        ),
      ),
    );

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Points'), findsOneWidget);
    expect(find.text('Requests'), findsOneWidget);
    expect(find.text('Map'), findsOneWidget);
    expect(find.text('More'), findsOneWidget);
    expect(find.text('Materials'), findsNothing);

    await tester.tap(find.text('Requests'));
    expect(selected, 2);

    await tester.tap(find.text('More'));
    expect(moreOpened, isTrue);
    expect(selected, 2);
  });
}
