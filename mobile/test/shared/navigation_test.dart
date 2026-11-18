import 'package:clac_mobile/shared/navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('drawer-only screens do not falsely highlight Overview', (
    tester,
  ) async {
    int? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: ClacBottomNavigation(
            selectedIndex: null,
            onSelected: (value) => selected = value,
          ),
        ),
      ),
    );

    final overview = tester.widget<Icon>(
      find.byIcon(Icons.space_dashboard_outlined),
    );
    final map = tester.widget<Icon>(find.byIcon(Icons.map_outlined));
    expect(overview.color, const Color(0xff718076));
    expect(map.color, const Color(0xff718076));
    await tester.tap(find.text('Map'));
    expect(selected, 4);
  });

  testWidgets('active bottom destination has a distinct state', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          bottomNavigationBar: ClacBottomNavigation(
            selectedIndex: 2,
            onSelected: _ignore,
          ),
        ),
      ),
    );

    expect(
      tester.widget<Icon>(find.byIcon(Icons.receipt_long_outlined)).color,
      const Color(0xff236749),
    );
    expect(
      tester.widget<Icon>(find.byIcon(Icons.space_dashboard_outlined)).color,
      const Color(0xff718076),
    );
  });
}

void _ignore(int _) {}
