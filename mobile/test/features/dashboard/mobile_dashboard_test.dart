import 'dart:async';
import 'dart:convert';

import 'package:clac_mobile/core/api_client.dart';
import 'package:clac_mobile/core/app_theme.dart';
import 'package:clac_mobile/features/dashboard/workspace_screens.dart';
import 'package:clac_mobile/shared/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _collector = <String, dynamic>{
  'id': 'collector-1',
  'role': 'collector',
  'name': 'GreenMinds Collect',
  'company_name': 'GreenMinds',
  'gouvernorat': 'Sousse',
  'is_verified': true,
};

Map<String, dynamic> get _summary => {
  'transaction_count': 0,
  'transaction_kg': 0,
  'carbon_saved_kg': 0,
  'listing_count': 0,
  'monthly_listing_kg': 0,
  'collection_point_count': 2,
  'verified_collection_point_count': 1,
  'recent_activity': <dynamic>[],
};

Map<String, dynamic> get _dashboard => {
  'stats': {
    'generators': 5,
    'processors': 4,
    'transactions': 2,
    'monthlyPotentialKg': 1800,
    'totalWasteDivertedKg': 300,
    'totalCarbonSavedKgCO2e': 246.61,
  },
};

ApiClient _api(Future<http.Response> Function(http.Request) handler) =>
    ApiClient(baseUrl: 'https://clac.test', client: MockClient(handler));

void _setPhoneSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _app(ApiClient api, {Map<String, dynamic> user = _collector}) =>
    MaterialApp(
      theme: buildAppTheme(),
      home: Scaffold(
        body: MobileDashboard(
          user: user,
          api: api,
          onOpenMarketplace: () {},
          onOpenNotifications: () {},
          onOpenNetwork: () {},
          onOpenImpact: () {},
          onOpenProfile: () {},
          onOpenRequests: () {},
          onOpenAdmin: () {},
        ),
      ),
    );

void main() {
  testWidgets('shows skeletons while dashboard data is loading', (
    tester,
  ) async {
    _setPhoneSize(tester);
    final gate = Completer<void>();
    final api = _api((request) async {
      await gate.future;
      final body = request.url.path == '/api/dashboard' ? _dashboard : _summary;
      return http.Response(jsonEncode(body), 200);
    });

    await tester.pumpWidget(_app(api));
    await tester.pump();

    expect(find.byType(SkeletonBox), findsWidgets);
    expect(find.text('Quick actions'), findsNothing);

    gate.complete();
    await tester.pumpAndSettle();

    expect(find.byType(SkeletonBox), findsNothing);
    await tester.scrollUntilVisible(
      find.text('Quick actions'),
      220,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Quick actions'), findsOneWidget);
  });

  testWidgets('renders collector metrics, actions and empty activity', (
    tester,
  ) async {
    _setPhoneSize(tester);
    final api = _api((request) async {
      final body = request.url.path == '/api/dashboard' ? _dashboard : _summary;
      return http.Response(
        jsonEncode(body),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    await tester.pumpWidget(_app(api));
    await tester.pumpAndSettle();

    expect(find.text('Grow your collection network.'), findsOneWidget);
    expect(find.text('Collection specialist'), findsOneWidget);
    expect(find.text('AT A GLANCE'), findsOneWidget);
    expect(find.text('Verified points'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Quick actions'),
      220,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Quick actions'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Your collection exchanges will appear here.'),
      220,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.text('Your collection exchanges will appear here.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('surfaces pending verification and points in review', (
    tester,
  ) async {
    _setPhoneSize(tester);
    final api = _api((request) async {
      final body = request.url.path == '/api/dashboard' ? _dashboard : _summary;
      return http.Response(jsonEncode(body), 200);
    });

    await tester.pumpWidget(
      _app(api, user: {..._collector, 'is_verified': false}),
    );
    await tester.pumpAndSettle();

    expect(find.text('MEMBER WORKSPACE'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Your organization is awaiting verification'),
      160,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.text('Your organization is awaiting verification'),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.text('1 collection point in review'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('1 collection point in review'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows a retryable error state when the dashboard fails', (
    tester,
  ) async {
    _setPhoneSize(tester);
    final api = _api(
      (_) async => http.Response('{"error":"Dashboard unavailable"}', 503),
    );

    await tester.pumpWidget(_app(api));
    await tester.pumpAndSettle();

    expect(find.text('Connection interrupted'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(find.text('Quick actions'), findsNothing);
  });
}
