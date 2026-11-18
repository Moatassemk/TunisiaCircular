import 'package:clac_mobile/core/api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('ApiClient', () {
    test('loads the public collection point directory', () async {
      final api = ApiClient(
        baseUrl: 'https://clac.test',
        client: MockClient((request) async {
          expect(request.method, 'GET');
          expect(request.url.path, '/api/collection-points');
          return http.Response('[]', 200);
        }),
      );

      expect(await api.collectionPoints(), isEmpty);
    });

    test('submits an authenticated collection point', () async {
      final api = ApiClient(
        baseUrl: 'https://clac.test',
        client: MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.path, '/api/collection-points');
          expect(request.headers['authorization'], 'Bearer test-token');
          expect(request.body, contains('Tunis'));
          return http.Response('{"id":"point-1"}', 201);
        }),
      )..token = 'test-token';

      expect(
        (await api.createCollectionPoint({'gouvernorat': 'Tunis'}))['id'],
        'point-1',
      );
    });

    test('updates an owned collection point for re-review', () async {
      final api = ApiClient(
        baseUrl: 'https://clac.test',
        client: MockClient((request) async {
          expect(request.method, 'PUT');
          expect(request.url.path, '/api/collection-points/point-1');
          expect(request.headers['authorization'], 'Bearer test-token');
          expect(request.body, contains('Bizerte'));
          return http.Response('{"id":"point-1","is_verified":false}', 200);
        }),
      )..token = 'test-token';

      final updated = await api.updateCollectionPoint('point-1', {
        'gouvernorat': 'Bizerte',
      });
      expect(updated['is_verified'], isFalse);
    });

    test('deletes an owned collection point', () async {
      final api = ApiClient(
        baseUrl: 'https://clac.test',
        client: MockClient((request) async {
          expect(request.method, 'DELETE');
          expect(request.url.path, '/api/collection-points/point-1');
          expect(request.headers['authorization'], 'Bearer test-token');
          return http.Response('', 204);
        }),
      )..token = 'test-token';

      await api.deleteCollectionPoint('point-1');
    });

    test(
      'queries the network by map bounds, material, and search text',
      () async {
        final api = ApiClient(
          baseUrl: 'https://clac.test',
          client: MockClient((request) async {
            expect(request.url.path, '/api/network');
            expect(request.url.queryParameters['kind'], 'Seller');
            expect(request.url.queryParameters['material'], 'pomace');
            expect(request.url.queryParameters['q'], 'Sfax');
            expect(request.url.queryParameters['bounds'], '9,33,11,36');
            return http.Response('[]', 200);
          }),
        );

        expect(
          await api.networkDirectory(
            kind: 'Seller',
            material: 'pomace',
            query: 'Sfax',
            bounds: '9,33,11,36',
          ),
          isEmpty,
        );
      },
    );

    test('posts a message to an authenticated exchange thread', () async {
      final api = ApiClient(
        baseUrl: 'https://clac.test',
        client: MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.path, '/api/transactions/tx-1/messages');
          expect(request.headers['authorization'], 'Bearer test-token');
          expect(request.body, contains('Collection tomorrow'));
          return http.Response('{"id":"message-1"}', 201);
        }),
      )..token = 'test-token';

      expect(
        (await api.sendTransactionMessage('tx-1', 'Collection tomorrow'))['id'],
        'message-1',
      );
    });

    test('schedules a pickup using an ISO timestamp', () async {
      final pickup = DateTime.utc(2027, 1, 4, 10);
      final api = ApiClient(
        baseUrl: 'https://clac.test',
        client: MockClient((request) async {
          expect(request.method, 'PATCH');
          expect(request.url.path, '/api/transactions/tx-1/schedule');
          expect(request.body, contains(pickup.toIso8601String()));
          return http.Response('{"id":"tx-1"}', 200);
        }),
      );

      expect((await api.schedulePickup('tx-1', pickup))['id'], 'tx-1');
    });

    test('keeps useful status details when a proxy returns HTML', () async {
      final api = ApiClient(
        baseUrl: 'https://clac.test',
        client: MockClient(
          (_) async => http.Response('<html>proxy failure</html>', 502),
        ),
      );

      await expectLater(
        api.notifications(),
        throwsA(
          predicate(
            (error) => error.toString().contains('Request failed (502)'),
          ),
        ),
      );
    });

    test('clears an expired mobile session and notifies the app', () async {
      var sessionExpired = false;
      final api = ApiClient(
        baseUrl: 'https://clac.test',
        client: MockClient(
          (_) async =>
              http.Response('{"error":"Invalid or expired token"}', 403),
        ),
      )..token = 'stale-token';
      api.onSessionExpired = () async {
        sessionExpired = true;
      };

      await expectLater(api.currentUser(), throwsA(isA<Exception>()));
      expect(api.token, isNull);
      expect(sessionExpired, isTrue);
    });
  });
}
