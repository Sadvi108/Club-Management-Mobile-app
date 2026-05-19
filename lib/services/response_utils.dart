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
