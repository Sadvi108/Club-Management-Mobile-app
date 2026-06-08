import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = 'http://apimac.zyncbook.com';
  static String? _token;

  /// Network logging — only in debug builds. Release builds must not dump
  /// request/response bodies (PII: IC numbers, payments) to logcat.
  static void _log(String msg) {
    if (kDebugMode) print(msg);
  }

  static void setToken(String token) {
    _token = token.isEmpty ? null : token;
  }

  static void clearToken() {
    _token = null;
  }

  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  static Future<dynamic> get(String endpoint) async {
    final url = Uri.parse('$baseUrl$endpoint');
    _log('📤 GET: $url');
    final response = await http.get(url, headers: _headers);
    _log('📥 Status: ${response.statusCode}');
    _log('📥 Body: ${response.body}');
    return _handle(response);
  }

  static Future<dynamic> post(String endpoint, Map<String, dynamic> body) async {
    final url = Uri.parse('$baseUrl$endpoint');
    _log('📤 POST: $url');
    _log('📤 Body: ${jsonEncode(_redactForLog(body))}');
    final response =
        await http.post(url, headers: _headers, body: jsonEncode(body));
    _log('📥 Status: ${response.statusCode}');
    _log('📥 Body: ${response.body}');
    return _handle(response);
  }

  /// Raw-bytes GET — for binary endpoints (e.g. ReceiptAsPDF returns a
  /// PDF, not JSON). Never json-decodes.
  static Future<Uint8List> getBytes(String endpoint) async {
    final url = Uri.parse('$baseUrl$endpoint');
    _log('📤 GET(bytes): $url');
    final response = await http.get(url, headers: {
      if (_token != null) 'Authorization': 'Bearer $_token',
    });
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
    final url = Uri.parse('$baseUrl$endpoint');
    _log('📤 GET(pdf): $url');
    final response = await http.get(url, headers: {
      'Accept': 'application/pdf, application/json, */*',
      if (_token != null) 'Authorization': 'Bearer $_token',
    });
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
            final r2 = await http.get(Uri.parse(cand), headers: {
              if (_token != null) 'Authorization': 'Bearer $_token',
            });
            if (_isPdf(r2.bodyBytes)) return r2.bodyBytes;
            final b2 = _tryBase64(
                utf8.decode(r2.bodyBytes, allowMalformed: true));
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
      b[0] == 0x25 && b[1] == 0x50 && b[2] == 0x44 && b[3] == 0x46; // %PDF

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
        'url', 'fileUrl', 'link', 'downloadUrl', 'pdfUrl', 'receiptUrl',
        'base64', 'data', 'pdf', 'file', 'content', 'document',
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
  /// (e.g. /Profile/UpdateProfile). Only non-empty string fields are sent.
  static Future<dynamic> postMultipart(
      String endpoint, Map<String, String> fields) async {
    final url = Uri.parse('$baseUrl$endpoint');
    _log('📤 POST(multipart): $url');
    final req = http.MultipartRequest('POST', url);
    if (_token != null) req.headers['Authorization'] = 'Bearer $_token';
    fields.forEach((k, v) {
      if (v.isNotEmpty) req.fields[k] = v;
    });
    final streamed = await req.send();
    final response = await http.Response.fromStream(streamed);
    _log('📥 Status: ${response.statusCode}');
    return _handle(response);
  }

  static Future<dynamic> put(String endpoint, Map<String, dynamic> body) async {
    final url = Uri.parse('$baseUrl$endpoint');
    _log('📤 PUT: $url');
    final response =
        await http.put(url, headers: _headers, body: jsonEncode(body));
    _log('📥 Status: ${response.statusCode}');
    _log('📥 Body: ${response.body}');
    return _handle(response);
  }

  static Future<dynamic> delete(String endpoint) async {
    final url = Uri.parse('$baseUrl$endpoint');
    _log('📤 DELETE: $url');
    final response = await http.delete(url, headers: _headers);
    _log('📥 Status: ${response.statusCode}');
    _log('📥 Body: ${response.body}');
    return _handle(response);
  }

  static dynamic _handle(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return null;
      return jsonDecode(response.body);
    } else if (response.statusCode == 401) {
      throw Exception('❌ Unauthorized - Token missing or expired');
    } else if (response.statusCode == 404) {
      throw Exception('❌ Not Found - Wrong endpoint');
    } else {
      throw Exception('❌ Error ${response.statusCode}: ${response.body}');
    }
  }

  static Map<String, dynamic> _redactForLog(Map<String, dynamic> body) {
    final redacted = Map<String, dynamic>.from(body);
    if (redacted.containsKey('password')) redacted['password'] = '***';
    if (redacted.containsKey('accessToken')) redacted['accessToken'] = '***';
    return redacted;
  }
}
