import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'platform_http_client.dart';

class ApiClient {
  ApiClient({String? baseUrl, http.Client? client})
    : baseUrl = (baseUrl ?? _defaultApiBase).replaceAll(RegExp(r'/$'), ''),
      _client = client ?? createPlatformHttpClient();

  final String baseUrl;
  final http.Client _client;
  String? token;
  Future<void> Function()? onSessionExpired;

  Map<String, String> get _headers => {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
    if (kIsWeb) 'X-CLAC-Client': 'web',
    if (token != null) 'Authorization': 'Bearer $token',
  };

  Future<dynamic> _send(String method, String path, {Object? body}) async {
    final request = http.Request(method, Uri.parse('$baseUrl$path'))
      ..headers.addAll(_headers);
    if (body != null) request.body = jsonEncode(body);
    final streamed = await _client
        .send(request)
        .timeout(const Duration(seconds: 15));
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      dynamic decoded;
      try {
        decoded = response.body.isEmpty
            ? <String, dynamic>{}
            : jsonDecode(response.body);
      } on FormatException {
        decoded = null;
      }
      final serverMessage = decoded is Map<String, dynamic>
          ? decoded['error']?.toString() ??
                'Request failed (${response.statusCode})'
          : 'Request failed (${response.statusCode})';
      if (path != '/api/auth/login' &&
          (serverMessage == 'Invalid or expired token' ||
              serverMessage == 'Access token required')) {
        token = null;
        await onSessionExpired?.call();
      }
      throw Exception(
        '$method $path failed (${response.statusCode}): $serverMessage',
      );
    }
    // Non-JSON response (e.g. 204 No Content, plain text)
    if (response.body.isEmpty) return <String, dynamic>{};
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic> && decoded is! List<dynamic>) {
      throw ApiMethodError(
        'Unexpected response format: ${decoded.runtimeType}',
      );
    }
    return decoded;
  }

  Future<Map<String, dynamic>> login(String email, String password) async =>
      Map<String, dynamic>.from(
        await _send(
              'POST',
              '/api/auth/login',
              body: {'email': email, 'password': password},
            )
            as Map,
      );

  Future<Map<String, dynamic>> currentUser() async =>
      Map<String, dynamic>.from(await _send('GET', '/api/auth/me') as Map);

  Future<Map<String, dynamic>> profileSummary() async =>
      Map<String, dynamic>.from(
        await _send('GET', '/api/auth/me/summary') as Map,
      );

  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> data) async =>
      Map<String, dynamic>.from(
        await _send('PUT', '/api/auth/profile', body: data) as Map,
      );

  Future<void> logout() async => await _send('POST', '/api/auth/logout');

  Future<List<dynamic>> collectionPoints() async =>
      List<dynamic>.from(await _send('GET', '/api/collection-points') as List);

  Future<List<dynamic>> networkDirectory({
    String kind = 'all',
    String material = '',
    String query = '',
    String bounds = '7,30,12.5,38.5',
    int limit = 300,
  }) async {
    final params = <String, String>{
      'kind': kind,
      'bounds': bounds,
      'limit': '$limit',
      if (material.isNotEmpty && material != 'All materials')
        'material': material,
      if (query.trim().isNotEmpty) 'q': query.trim(),
    };
    final uri = Uri(path: '/api/network', queryParameters: params);
    return List<dynamic>.from(await _send('GET', uri.toString()) as List);
  }

  Future<List<dynamic>> myCollectionPoints() async => List<dynamic>.from(
    await _send('GET', '/api/collection-points/mine') as List,
  );

  Future<Map<String, dynamic>> createCollectionPoint(
    Map<String, dynamic> data,
  ) async => Map<String, dynamic>.from(
    await _send('POST', '/api/collection-points', body: data) as Map,
  );

  Future<Map<String, dynamic>> updateCollectionPoint(
    String id,
    Map<String, dynamic> data,
  ) async => Map<String, dynamic>.from(
    await _send(
          'PUT',
          '/api/collection-points/${Uri.encodeComponent(id)}',
          body: data,
        )
        as Map,
  );

  Future<void> deleteCollectionPoint(String id) async => await _send(
    'DELETE',
    '/api/collection-points/${Uri.encodeComponent(id)}',
  );

  Future<List<dynamic>> adminCollectionPoints() async => List<dynamic>.from(
    await _send('GET', '/api/admin/collection-points') as List,
  );

  Future<List<dynamic>> adminOrganizations() async => List<dynamic>.from(
    await _send('GET', '/api/admin/organizations') as List,
  );

  Future<Map<String, dynamic>> verifyOrganization(String id) async =>
      Map<String, dynamic>.from(
        await _send(
              'POST',
              '/api/admin/organizations/${Uri.encodeComponent(id)}/verify',
              body: const {},
            )
            as Map,
      );

  Future<Map<String, dynamic>> rejectOrganization(String id) async =>
      Map<String, dynamic>.from(
        await _send(
              'POST',
              '/api/admin/organizations/${Uri.encodeComponent(id)}/reject',
              body: const {},
            )
            as Map,
      );

  Future<Map<String, dynamic>> verifyCollectionPoint(String id) async =>
      Map<String, dynamic>.from(
        await _send(
              'POST',
              '/api/admin/collection-points/${Uri.encodeComponent(id)}/verify',
              body: const {},
            )
            as Map,
      );

  Future<Map<String, dynamic>> rejectCollectionPoint(
    String id, {
    String reason = '',
  }) async => Map<String, dynamic>.from(
    await _send(
          'POST',
          '/api/admin/collection-points/${Uri.encodeComponent(id)}/reject',
          body: {'reason': reason},
        )
        as Map,
  );

  Future<Map<String, dynamic>> register(Map<String, dynamic> data) async =>
      Map<String, dynamic>.from(
        await _send('POST', '/api/auth/register', body: data) as Map,
      );

  Future<Map<String, dynamic>> dashboard() async =>
      Map<String, dynamic>.from(await _send('GET', '/api/dashboard') as Map);

  Future<Map<String, dynamic>> personalImpact() async =>
      Map<String, dynamic>.from(
        await _send('GET', '/api/analytics/me/impact') as Map,
      );

  Future<Map<String, dynamic>> leaderboard() async => Map<String, dynamic>.from(
    await _send('GET', '/api/analytics/ranking') as Map,
  );

  Future<Map<String, dynamic>> adminStats() async =>
      Map<String, dynamic>.from(await _send('GET', '/api/admin/stats') as Map);

  Future<List<dynamic>> adminUsers() async =>
      List<dynamic>.from(await _send('GET', '/api/admin/users') as List);

  Future<Map<String, dynamic>> toggleUserActive(String id) async =>
      Map<String, dynamic>.from(
        await _send(
              'POST',
              '/api/admin/users/${Uri.encodeComponent(id)}/toggle-active',
              body: const {},
            )
            as Map,
      );

  Future<List<dynamic>> generators() async =>
      List<dynamic>.from(await _send('GET', '/api/generators') as List);

  Future<List<dynamic>> myGenerators() async =>
      List<dynamic>.from(await _send('GET', '/api/generators/mine') as List);

  Future<Map<String, dynamic>> matchGenerator(
    String id, {
    num? amountKg,
  }) async {
    final amount = amountKg == null ? '' : '?amount=$amountKg';
    return Map<String, dynamic>.from(
      await _send(
            'GET',
            '/api/generators/${Uri.encodeComponent(id)}/match$amount',
          )
          as Map,
    );
  }

  Future<Map<String, dynamic>> createListing(Map<String, dynamic> data) async =>
      Map<String, dynamic>.from(
        await _send('POST', '/api/generators', body: data) as Map,
      );

  Future<List<dynamic>> transactions() async => List<dynamic>.from(
    await _send('GET', '/api/transactions?limit=100') as List,
  );

  Future<Map<String, dynamic>> createPurchase(
    Map<String, dynamic> data,
  ) async => Map<String, dynamic>.from(
    await _send('POST', '/api/transactions', body: data) as Map,
  );

  Future<Map<String, dynamic>> updateStatus(String id, String status) async =>
      Map<String, dynamic>.from(
        await _send(
              'PATCH',
              '/api/transactions/$id/status',
              body: {'status': status},
            )
            as Map,
      );

  Future<List<dynamic>> notifications() async =>
      List<dynamic>.from(await _send('GET', '/api/notifications') as List);

  Future<void> markNotificationRead(String id) async =>
      await _send('PATCH', '/api/notifications/$id/read');

  Future<List<dynamic>> processors(String? wasteType, String? region) async {
    final query = <String>[];
    if (wasteType != null && wasteType.isNotEmpty) {
      query.add('wasteType=${Uri.encodeQueryComponent(wasteType)}');
    }
    if (region != null && region.isNotEmpty) {
      query.add('gouvernorat=${Uri.encodeQueryComponent(region)}');
    }
    final path = query.isEmpty
        ? '/api/processors'
        : '/api/processors?${query.join('&')}';
    return List<dynamic>.from(await _send('GET', path) as List);
  }

  Future<Map<String, dynamic>> getTransaction(String id) async =>
      Map<String, dynamic>.from(
        await _send('GET', '/api/transactions/$id') as Map,
      );

  Future<List<dynamic>> transactionMessages(String id) async =>
      List<dynamic>.from(
        await _send('GET', '/api/transactions/$id/messages') as List,
      );

  Future<Map<String, dynamic>> sendTransactionMessage(
    String id,
    String body,
  ) async => Map<String, dynamic>.from(
    await _send('POST', '/api/transactions/$id/messages', body: {'body': body})
        as Map,
  );

  Future<Map<String, dynamic>> schedulePickup(
    String id,
    DateTime pickupAt,
  ) async => Map<String, dynamic>.from(
    await _send(
          'PATCH',
          '/api/transactions/$id/schedule',
          body: {'scheduled_pickup_at': pickupAt.toUtc().toIso8601String()},
        )
        as Map,
  );

  Map<String, dynamic> decodeObject(String value) =>
      Map<String, dynamic>.from(jsonDecode(value) as Map);
  String encodeObject(Map<String, dynamic> value) => jsonEncode(value);
}

class ApiMethodError implements Exception {
  final String message;
  ApiMethodError(this.message);
  @override
  String toString() => message;
}

const _configuredApiBase = String.fromEnvironment('API_BASE_URL');
String get _defaultApiBase => _configuredApiBase.isNotEmpty
    ? _configuredApiBase
    : kIsWeb
    ? ''
    : defaultTargetPlatform == TargetPlatform.android
    ? 'http://10.0.2.2:5001'
    : 'http://localhost:5001';
