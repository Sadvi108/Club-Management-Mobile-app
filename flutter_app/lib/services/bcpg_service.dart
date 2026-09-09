import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// BoostConnect Payment Gateway (BCPG) — direct mobile→BCPG client.
///
/// PORT of `application/libraries/Bcpg.php` from the PHP webapp. Per-request
/// HMAC-SHA256 Basic auth (NOT a long-lived bearer token):
///
///   raw      = METHOD + PATH + JSON_BODY            (payload "" for GET)
///   hash     = HMAC-SHA256(raw, merchantSecret)      // RAW BYTES
///   password = base64(hash)
///   token    = base64("$clientId:$password")
///   Authorization: Basic <token>
///
/// ⚠️ SECURITY NOTE
/// The merchant secret SHIPS INSIDE THE APP. Anyone decompiling the APK
/// can extract it and forge requests against the BCPG sandbox/production
/// account. This is per explicit instruction ("no backend, everything in
/// app"). Mitigations to consider before production:
///   1. Store secret in flutter_secure_storage instead of compile-time const.
///   2. Fetch secret at login from existing webapp API (still extractable
///      from a logged-in session but at least not in the APK binary).
///   3. Implement BCPG-side IP allowlist / per-device throttle.
class BcpgService {
  /// Compile-time config. Override per build flavor with --dart-define:
  ///   flutter build apk --dart-define=BCPG_API_URL=https://api.boostconnect.biz/gateway \
  ///                     --dart-define=BCPG_CLIENT_ID=xxx \
  ///                     --dart-define=BCPG_SECRET=yyy
  static const String apiUrl = String.fromEnvironment(
    'BCPG_API_URL',
    defaultValue: 'https://stage-api.boostconnect.biz/gateway',
  );
  static const String _clientId =
      String.fromEnvironment('BCPG_CLIENT_ID', defaultValue: '');
  static const String _merchantSecret =
      String.fromEnvironment('BCPG_SECRET', defaultValue: '');

  /// Per-club credential overrides (if the app fetches them at login
  /// from an existing API instead of using the compile-time defaults).
  static String? _runtimeClientId;
  static String? _runtimeSecret;

  /// Inject runtime-loaded credentials (e.g. from /Account/Authenticate
  /// payload or a /Club/BcpgCreds endpoint). Empty strings = ignored.
  static void setCredentials({String? clientId, String? merchantSecret}) {
    if (clientId != null && clientId.trim().isNotEmpty) {
      _runtimeClientId = clientId.trim();
    }
    if (merchantSecret != null && merchantSecret.trim().isNotEmpty) {
      _runtimeSecret = merchantSecret.trim();
    }
  }

  static String get clientId =>
      (_runtimeClientId != null && _runtimeClientId!.isNotEmpty)
          ? _runtimeClientId!
          : _clientId;

  static String get merchantSecret =>
      (_runtimeSecret != null && _runtimeSecret!.isNotEmpty)
          ? _runtimeSecret!
          : _merchantSecret;

  static bool get isConfigured =>
      clientId.isNotEmpty && merchantSecret.isNotEmpty;

  static void _log(String msg) {
    if (kDebugMode) debugPrint('BCPG: $msg');
  }

  /// Build the `Authorization: Basic <...>` header per BCPG spec.
  /// Mirrors `Bcpg::getBasicAuthHeader` 1:1.
  static String _buildAuthHeader(String method, String path, String payload) {
    final raw = method + path + payload;
    final hmac = Hmac(sha256, utf8.encode(merchantSecret));
    final digest = hmac.convert(utf8.encode(raw));
    final password = base64.encode(digest.bytes); // raw bytes → base64
    final token = base64.encode(utf8.encode('$clientId:$password'));
    return 'Basic $token';
  }

  /// POST /v1/payments/init — kick off an FPX payment session.
  ///
  /// Required [data] keys (matches PHP `initiatePayment`):
  ///   referenceId, amount (num), currency ("MYR"), created (ISO-8601 UTC),
  ///   description, returnUrl, callbackUrl, customer{fullName,email,phone}.
  ///
  /// Returns the decoded JSON map. On success the map contains
  /// `uuid` + `paymentUrl`. On failure check `error` / `message` / `http_code`.
  static Future<Map<String, dynamic>> initiatePayment(
      Map<String, dynamic> data) async {
    if (!isConfigured) {
      return {
        'error': true,
        'message': 'BCPG credentials not configured.',
        'http_code': 0,
      };
    }
    const path = '/v1/payments/init';
    final url = Uri.parse('$apiUrl$path');

    final body = <String, dynamic>{
      'referenceId': data['referenceId'],
      'amount': (data['amount'] as num).toDouble(),
      'currency': data['currency'] ?? 'MYR',
      'created': data['created'],
      'description': data['description'],
      'returnUrl': data['returnUrl'],
      'callbackUrl': data['callbackUrl'],
      if (data['customer'] != null) 'customer': data['customer'],
    };

    final jsonBody = jsonEncode(body);
    final auth = _buildAuthHeader('POST', path, jsonBody);

    _log('POST $url');
    _log('body=$jsonBody');

    try {
      final resp = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': auth,
        },
        body: jsonBody,
      ).timeout(const Duration(seconds: 30));

      _log('HTTP ${resp.statusCode} ${resp.body}');

      Map<String, dynamic> parsed;
      try {
        final decoded = jsonDecode(resp.body);
        parsed = decoded is Map
            ? Map<String, dynamic>.from(decoded)
            : <String, dynamic>{'raw': resp.body};
      } catch (_) {
        parsed = <String, dynamic>{'raw': resp.body};
      }
      parsed['http_code'] = resp.statusCode;
      return parsed;
    } catch (e) {
      _log('initiatePayment failed: $e');
      return {
        'error': true,
        'message': 'Network error: $e',
        'http_code': 0,
      };
    }
  }

  /// GET /v1/payments/refs/{referenceId}/fpxDetails — verify payment status.
  ///
  /// Possible response `status` values: `succeeded`, `expired`, `failed`,
  /// `denied`, plus HTTP 404 = not found.
  static Future<Map<String, dynamic>> getFPXPaymentDetails(
      String referenceId) async {
    if (!isConfigured) {
      return {
        'error': true,
        'message': 'BCPG credentials not configured.',
        'http_code': 0,
      };
    }
    final path = '/v1/payments/refs/$referenceId/fpxDetails';
    final url = Uri.parse('$apiUrl$path');
    // GET → payload is empty string per BCPG spec.
    final auth = _buildAuthHeader('GET', path, '');

    _log('GET $url');

    try {
      final resp = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': auth,
        },
      ).timeout(const Duration(seconds: 30));

      _log('HTTP ${resp.statusCode} ${resp.body}');

      Map<String, dynamic> parsed;
      try {
        final decoded = jsonDecode(resp.body);
        parsed = decoded is Map
            ? Map<String, dynamic>.from(decoded)
            : <String, dynamic>{'raw': resp.body};
      } catch (_) {
        parsed = <String, dynamic>{'raw': resp.body};
      }
      parsed['http_code'] = resp.statusCode;
      return parsed;
    } catch (e) {
      _log('getFPXPaymentDetails failed: $e');
      return {
        'error': true,
        'message': 'Network error: $e',
        'http_code': 0,
      };
    }
  }

  /// Generate a referenceId in the same format as the webapp:
  /// `SUB{clubId}{YmdHis}` plus 4 random digits for extra collision-safety
  /// (no central uniqueness check on mobile-only flow).
  static String generateReferenceId(int clubId) {
    final now = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    final ts = '${now.year}${two(now.month)}${two(now.day)}'
        '${two(now.hour)}${two(now.minute)}${two(now.second)}';
    final rand = (now.microsecond % 10000).toString().padLeft(4, '0');
    return 'SUB$clubId$ts$rand';
  }

  /// UTC ISO-8601 with milliseconds + Z (matches PHP `gmdate('Y-m-d\TH:i:s.v\Z')`).
  static String utcIsoNow() {
    final now = DateTime.now().toUtc();
    String two(int v) => v.toString().padLeft(2, '0');
    final ms = now.millisecond.toString().padLeft(3, '0');
    return '${now.year}-${two(now.month)}-${two(now.day)}'
        'T${two(now.hour)}:${two(now.minute)}:${two(now.second)}.${ms}Z';
  }

  /// Poll [getFPXPaymentDetails] until the status is terminal or the
  /// timeout elapses. Returns the final response map.
  ///
  /// `interval` between polls; `timeout` is the total budget. Defaults
  /// (2s × 30s) give 15 attempts — long enough for FPX to settle after
  /// the user returns from the bank UI.
  static Future<Map<String, dynamic>> pollUntilTerminal(
    String referenceId, {
    Duration interval = const Duration(seconds: 2),
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final deadline = DateTime.now().add(timeout);
    Map<String, dynamic> last = const {};
    while (DateTime.now().isBefore(deadline)) {
      last = await getFPXPaymentDetails(referenceId);
      final status = (last['status'] ?? '').toString();
      const terminal = {'succeeded', 'expired', 'failed', 'denied'};
      if (terminal.contains(status)) return last;
      if (last['http_code'] == 404) return last;
      await Future.delayed(interval);
    }
    return last.isEmpty
        ? {'error': true, 'message': 'Poll timeout', 'http_code': 0}
        : last;
  }
}
