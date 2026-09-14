import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'response_utils.dart';
import 'api_changes.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;
  const ApiException(this.statusCode, this.message);
  @override
  String toString() => '$message (HTTP $statusCode)';
}

class ApiService {
  static const String baseUrl = 'http://apimac.zyncbook.com';

  /// Host that serves the `/Bcpg` Boost routes on production's behalf.
  ///
  /// Probed on prod: `POST /Bcpg/PayInvoices` answers 404 there — the four Boost routes are
  /// not deployed to production yet — while the UAT deployment serves them against the SAME
  /// database, so a token issued by prod authenticates and the same invoice ids come back.
  /// ONLY `/Bcpg/*` is sent here; auth, invoices and everything else stay on [baseUrl].
  ///
  /// Delete this the moment `/Bcpg` ships to production. A cross-host payment path is a
  /// stopgap, not the destination.
  static const String boostBaseUrl = 'https://apimacuat.zyncbook.com';

  /// The Boost host currently serves a self-signed Plesk certificate, which phones reject.
  /// Surfaced in the error message so a failure reads as a server problem, not a user one.
  static const bool boostHostSelfSigned = true;

  static bool isBoostPath(String endpoint) => endpoint.startsWith('/Bcpg');

  /// Web preview only: the local CORS proxy (port 8082). Browsers cannot call Club.Api
  /// directly — it 401s CORS preflight on authenticated routes. Native builds ignore this.
  /// Set with `--dart-define=WEB_API_PROXY=http://localhost:8082`.
  static const String webApiProxy = String.fromEnvironment('WEB_API_PROXY');

  /// Base URL for a given endpoint — Boost routes may live on a different host.
  static String baseUrlFor(String endpoint) {
    final boost = isBoostPath(endpoint);
    if (kIsWeb && webApiProxy.isNotEmpty) {
      return '$webApiProxy/@${boost ? 'uat' : 'prod'}';
    }
    return boost ? boostBaseUrl : baseUrl;
  }

  /// The HTTP client every request goes through.
  ///
  /// Overridable so tests and the screenshot tool can serve canned responses. The only
  /// alternative was intercepting dart:io with HttpOverrides, which means reimplementing
  /// HttpClient, HttpClientRequest and HttpClientResponse by hand — easy to get subtly
  /// wrong, and it was: requests arrived and responses silently never came back.
  ///
  /// Defaults to a real client, so production behaviour is unchanged.
  static http.Client client = http.Client();

  static String? _token;
  static int sessionEpoch = 0;
  static const requestTimeout = Duration(seconds: 25);

  static Future<http.Response> _request(Future<http.Response> response) async {
    final epoch = sessionEpoch;
    final result = await response.timeout(requestTimeout);
    if (epoch != sessionEpoch)
      throw const ApiException(
          409, 'The account changed while loading. Please retry.');
    return result;
  }

  static dynamic _complete(String endpoint, http.Response response) {
    final data = _handle(response);
    ApiChanges.accepted(endpoint, data);
    return data;
  }

  /// Network logging — only in debug builds. Release builds must not dump
  /// request/response bodies (PII: IC numbers, payments) to logcat.
  static void _log(String msg) {
    if (kDebugMode) print(msg);
  }

  static void setToken(String token) {
    final next = token.isEmpty ? null : token;
    if (_token != next) sessionEpoch++;
    _token = next;
  }

  static void clearToken() {
    sessionEpoch++;
    _token = null;
  }

  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  static Future<dynamic> get(String endpoint) async {
    final url = Uri.parse('${baseUrlFor(endpoint)}$endpoint');
    _log('📤 GET: $url');
    final response = await _request(client.get(url, headers: _headers));
    _log('📥 Status: ${response.statusCode}');
    return _complete(endpoint, response);
  }

  static Future<dynamic> post(
      String endpoint, Map<String, dynamic> body) async {
    final url = Uri.parse('${baseUrlFor(endpoint)}$endpoint');
    _log('📤 POST: $url');
    final response = await _request(
        client.post(url, headers: _headers, body: jsonEncode(body)));
    _log('📥 Status: ${response.statusCode}');
    return _complete(endpoint, response);
  }

  /// Raw-bytes GET — for binary endpoints (e.g. ReceiptAsPDF returns a
  /// PDF, not JSON). Never json-decodes.
  static Future<Uint8List> getBytes(String endpoint) async {
    final url = Uri.parse('${baseUrlFor(endpoint)}$endpoint');
    _log('📤 GET(bytes): $url');
    final response = await _request(client.get(url, headers: {
      if (_token != null) 'Authorization': 'Bearer $_token',
    }));
    _log('📥 Status: ${response.statusCode} (${response.bodyBytes.length}B)');
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response.bodyBytes;
    }
    throw Exception('❌ Error ${response.statusCode}');
  }

  /// Fetch a PDF tolerant of how the server actually returns it:
  ///   1. raw PDF bytes (starts with `%PDF`)
  ///   2. a base64 string (optionally `data:application/pdf;base64,...`)
  ///   3. a JSON wrapper carrying a `url`/`downloadUrl` or a `base64`/`data`
  ///      field (fetched / decoded recursively)
  ///
  /// Returns the decoded PDF bytes when found, otherwise the raw body bytes
  /// (the caller still validates with a `%PDF` magic check). Different
  /// backends/accounts return different shapes — this normalises all of
  /// them so the receipt opens for every student/instructor, not just the
  /// ones whose gateway happens to stream raw bytes.
  static Future<Uint8List> getPdfSmart(String endpoint) async {
    final url = Uri.parse('${baseUrlFor(endpoint)}$endpoint');
    _log('📤 GET(pdf): $url');
    final response = await _request(client.get(url, headers: {
      'Accept': 'application/pdf, application/json, */*',
      if (_token != null) 'Authorization': 'Bearer $_token',
    }));
    _log('📥 Status: ${response.statusCode} (${response.bodyBytes.length}B)');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('❌ Error ${response.statusCode}');
    }
    final bytes = response.bodyBytes;
    if (_isPdf(bytes)) return bytes;

    // Interpret the body as text to detect base64 / JSON wrappers.
    String text;
    try {
      text = utf8.decode(bytes, allowMalformed: true);
    } catch (_) {
      return bytes;
    }
    final trimmed = text.trim();

    // JSON wrapper { url | downloadUrl | base64 | data | pdf | file ... }.
    if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
      try {
        final cand = _digPdfString(jsonDecode(trimmed));
        if (cand != null) {
          if (cand.startsWith('http')) {
            final target = Uri.parse(cand);
            final r2 = await _request(client.get(target, headers: {
              if (_token != null && target.origin == url.origin)
                'Authorization': 'Bearer $_token',
            }));
            if (_isPdf(r2.bodyBytes)) return r2.bodyBytes;
            final b2 =
                _tryBase64(utf8.decode(r2.bodyBytes, allowMalformed: true));
            if (b2 != null) return b2;
          } else {
            final b = _tryBase64(cand);
            if (b != null) return b;
          }
        }
      } catch (_) {/* fall through */}
    }

    // Plain base64 body.
    final b = _tryBase64(trimmed);
    if (b != null) return b;

    return bytes; // caller validates / shows "unavailable"
  }

  static bool _isPdf(List<int> b) =>
      b.length > 4 &&
      b[0] == 0x25 &&
      b[1] == 0x50 &&
      b[2] == 0x44 &&
      b[3] == 0x46; // %PDF

  /// Decode [s] as base64 and return the bytes only if they're a real PDF.
  static Uint8List? _tryBase64(String s) {
    var t = s.trim();
    if (t.startsWith('data:') && t.contains(',')) t = t.split(',').last;
    t = t.replaceAll(RegExp(r'\s'), '');
    if (t.length < 100 || !RegExp(r'^[A-Za-z0-9+/=]+$').hasMatch(t)) {
      return null;
    }
    try {
      final d = base64Decode(t);
      if (_isPdf(d)) return d;
    } catch (_) {}
    return null;
  }

  /// Recursively dig a JSON value for the first string that could be a PDF
  /// URL or base64 payload.
  static String? _digPdfString(dynamic j) {
    if (j is String) return j.isEmpty ? null : j;
    if (j is Map) {
      for (final k in const [
        'url',
        'fileUrl',
        'link',
        'downloadUrl',
        'pdfUrl',
        'receiptUrl',
        'base64',
        'data',
        'pdf',
        'file',
        'content',
        'document',
      ]) {
        final v = j[k];
        if (v is String && v.isNotEmpty) return v;
      }
      for (final v in j.values) {
        final r = _digPdfString(v);
        if (r != null) return r;
      }
    }
    if (j is List) {
      for (final v in j) {
        final r = _digPdfString(v);
        if (r != null) return r;
      }
    }
    return null;
  }

  /// multipart/form-data POST — for endpoints that reject JSON
  /// (e.g. /Profile/UpdateProfile).
  ///
  /// By default empty fields are omitted, which is what the prepay call wants. An EDIT
  /// FORM must pass [sendEmptyFields]: dropping an empty value there makes clearing a
  /// field impossible — the member deletes their email, nothing is sent for it, and the
  /// server keeps the old address while the app reports "Saved".
  ///
  /// [files] attaches uploads under [fileField]; the server names it `files` for
  /// /Profile/UpdateProfile.
  static Future<dynamic> postMultipart(
    String endpoint,
    Map<String, String> fields, {
    bool sendEmptyFields = false,
    List<String> files = const [],
    String fileField = 'files',
    Map<String, List<String>> repeatedFields = const {},
    List<({String name, Uint8List bytes})> uploads = const [],
  }) async {
    final url = Uri.parse('${baseUrlFor(endpoint)}$endpoint');
    _log('📤 POST(multipart): $url');
    final req = http.MultipartRequest('POST', url);
    if (_token != null) req.headers['Authorization'] = 'Bearer $_token';
    fields.forEach((k, v) {
      if (sendEmptyFields || v.isNotEmpty) req.fields[k] = v;
    });
    for (final path in files) {
      req.files.add(await http.MultipartFile.fromPath(fileField, path));
    }
    // MultipartRequest.fields is a Map, so use form-data parts to preserve repeated
    // InvoiceIds exactly as the React Native FormData contract sends them.
    repeatedFields.forEach((name, values) {
      for (final value in values) {
        req.files.add(http.MultipartFile.fromString(name, value));
      }
    });
    for (final upload in uploads) {
      req.files.add(http.MultipartFile.fromBytes(fileField, upload.bytes,
          filename: upload.name));
    }
    final response =
        await _request(client.send(req).then(http.Response.fromStream));
    _log('📥 Status: ${response.statusCode}');
    return _complete(endpoint, response);
  }

  static Future<dynamic> put(String endpoint, Map<String, dynamic> body) async {
    final url = Uri.parse('${baseUrlFor(endpoint)}$endpoint');
    _log('📤 PUT: $url');
    final response = await _request(
        client.put(url, headers: _headers, body: jsonEncode(body)));
    _log('📥 Status: ${response.statusCode}');
    return _complete(endpoint, response);
  }

  static Future<dynamic> delete(String endpoint) async {
    final url = Uri.parse('${baseUrlFor(endpoint)}$endpoint');
    _log('📤 DELETE: $url');
    final response = await _request(client.delete(url, headers: _headers));
    _log('📥 Status: ${response.statusCode}');
    return _complete(endpoint, response);
  }

  static dynamic _handle(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return null;
      final body = jsonDecode(response.body);
      final error = apiEnvelopeError(body);
      if (error != null) {
        throw ApiException(apiEnvelopeErrorCode(body) ?? 400, error);
      }
      return body;
    } else if (response.statusCode == 401) {
      throw const ApiException(
          401, 'Your session has expired. Please log in again.');
    } else if (response.statusCode == 404) {
      throw const ApiException(
          404, 'This feature is not available on the server yet.');
    } else {
      throw ApiException(
          response.statusCode,
          response.statusCode >= 500
              ? 'Server error — please try again in a moment.'
              : 'The request could not be completed. Please check the details and try again.');
    }
  }
}
