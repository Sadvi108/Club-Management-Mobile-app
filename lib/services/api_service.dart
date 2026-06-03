import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = 'http://apimac.zyncbook.com';
  static String? _token;

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
    print('📤 GET: $url');
    final response = await http.get(url, headers: _headers);
    print('📥 Status: ${response.statusCode}');
    print('📥 Body: ${response.body}');
    return _handle(response);
  }

  static Future<dynamic> post(String endpoint, Map<String, dynamic> body) async {
    final url = Uri.parse('$baseUrl$endpoint');
    print('📤 POST: $url');
    print('📤 Body: ${jsonEncode(_redactForLog(body))}');
    final response =
        await http.post(url, headers: _headers, body: jsonEncode(body));
    print('📥 Status: ${response.statusCode}');
    print('📥 Body: ${response.body}');
    return _handle(response);
  }

  /// Raw-bytes GET — for binary endpoints (e.g. ReceiptAsPDF returns a
  /// PDF, not JSON). Never json-decodes.
  static Future<Uint8List> getBytes(String endpoint) async {
    final url = Uri.parse('$baseUrl$endpoint');
    print('📤 GET(bytes): $url');
    final response = await http.get(url, headers: {
      if (_token != null) 'Authorization': 'Bearer $_token',
    });
    print('📥 Status: ${response.statusCode} (${response.bodyBytes.length}B)');
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response.bodyBytes;
    }
    throw Exception('❌ Error ${response.statusCode}');
  }

  /// multipart/form-data POST — for endpoints that reject JSON
  /// (e.g. /Profile/UpdateProfile). Only non-empty string fields are sent.
  static Future<dynamic> postMultipart(
      String endpoint, Map<String, String> fields) async {
    final url = Uri.parse('$baseUrl$endpoint');
    print('📤 POST(multipart): $url');
    final req = http.MultipartRequest('POST', url);
    if (_token != null) req.headers['Authorization'] = 'Bearer $_token';
    fields.forEach((k, v) {
      if (v.isNotEmpty) req.fields[k] = v;
    });
    final streamed = await req.send();
    final response = await http.Response.fromStream(streamed);
    print('📥 Status: ${response.statusCode}');
    return _handle(response);
  }

  static Future<dynamic> put(String endpoint, Map<String, dynamic> body) async {
    final url = Uri.parse('$baseUrl$endpoint');
    print('📤 PUT: $url');
    final response =
        await http.put(url, headers: _headers, body: jsonEncode(body));
    print('📥 Status: ${response.statusCode}');
    print('📥 Body: ${response.body}');
    return _handle(response);
  }

  static Future<dynamic> delete(String endpoint) async {
    final url = Uri.parse('$baseUrl$endpoint');
    print('📤 DELETE: $url');
    final response = await http.delete(url, headers: _headers);
    print('📥 Status: ${response.statusCode}');
    print('📥 Body: ${response.body}');
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
