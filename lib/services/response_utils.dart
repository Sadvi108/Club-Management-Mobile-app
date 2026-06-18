/// Shared helpers for turning varied API JSON responses into a clean
/// list of record maps and reading fields out of them.

/// Recursively locate the first List of records in an API response.
/// Handles `{data: [...]}`, `{data: {rows: [...]}}`, bare lists, etc.
List<dynamic> findRecordList(dynamic resp) {
  if (resp is List) return resp;
  if (resp is Map) {
    const keys = [
      'data', 'items', 'rows', 'results', 'value', 'records',
      'collections', 'slips', 'list', 'payments',
    ];
    for (final k in keys) {
      final v = resp[k];
      if (v is List) return v;
    }
    for (final v in resp.values) {
      if (v is List) return v;
      if (v is Map) {
        final nested = findRecordList(v);
        if (nested.isNotEmpty) return nested;
      }
    }
  }
  return const [];
}

/// Inspect an API response envelope and return a human-readable error
/// message when it signals failure, or null when it looks successful.
///
/// The backend wraps some failures in an HTTP-200 body, e.g. a wrong login
/// returns `{status: 404, meta: {code: 404, error: "Account not found..."}}`.
/// Callers that only check the HTTP status miss these, so this reads the
/// envelope's own `status` / `meta.code` and surfaces `meta.error`
/// (or a top-level `error`/`message`) instead of a generic failure.
String? apiEnvelopeError(dynamic resp) {
  if (resp is! Map) return null;
  final meta = resp['meta'];
  int? code;
  final s = resp['status'];
  if (s is num) code = s.toInt();
  if (code == null && meta is Map && meta['code'] is num) {
    code = (meta['code'] as num).toInt();
  }
  // No status info → assume success (let the caller validate `data`).
  if (code == null) return null;
  if (code >= 200 && code < 300) return null;
  final metaError =
      (meta is Map) ? (meta['error']?.toString().trim() ?? '') : '';
  if (metaError.isNotEmpty) return metaError;
  final topError = (resp['error'] ?? resp['message'] ?? '').toString().trim();
  if (topError.isNotEmpty && topError != 'null') return topError;
  return 'Request failed (status $code).';
}

/// First non-empty string value across a set of candidate keys.
String pickField(Map row, List<String> keys) {
  for (final k in keys) {
    final v = row[k];
    if (v == null) continue;
    final s = v.toString().trim();
    if (s.isNotEmpty && s != 'null') return s;
  }
  return '';
}

/// First numeric value across a set of candidate keys.
num pickAmount(Map row, List<String> keys) {
  for (final k in keys) {
    final v = row[k];
    if (v is num) return v;
    if (v is String) {
      final n = num.tryParse(v.replaceAll(RegExp(r'[^\d.\-]'), ''));
      if (n != null) return n;
    }
  }
  return 0;
}
