import 'dart:convert';

import 'package:clac_mobile/core/api_client.dart';
import 'package:clac_mobile/features/notifications/notifications_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets('tapping an unread notification marks it read', (tester) async {
    var markedRead = false;
    final api = ApiClient(
      baseUrl: 'https://clac.test',
      client: MockClient((request) async {
        if (request.method == 'GET') {
          return http.Response(
            jsonEncode([
              {
                'id': 'notice-1',
                'title': 'New exchange request',
                'message': 'A buyer requested material.',
                'read': false,
              },
            ]),
            200,
          );
        }
        if (request.method == 'PATCH') {
          markedRead = true;
          return http.Response('{}', 200);
        }
        return http.Response('{}', 404);
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: NotificationsScreen(user: const {'id': 'member-1'}, api: api),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('New exchange request'));
    await tester.pumpAndSettle();

    expect(markedRead, isTrue);
  });
}
