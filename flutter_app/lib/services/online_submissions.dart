import 'api_service.dart';
import 'response_utils.dart';

/// Proposed contracts preserved from Expo v2.11.1. These are not in Club.Api's
/// deployed route table; a 404 must render Awaiting backend, not an empty report.
class OnlineSubmissions {
  static Future<List<Map<String, dynamic>>> fetch() async =>
      findRecordList(await ApiService.get('/Reports/OnlineSubmissions'))
          .whereType<Map>()
          .map((r) => Map<String, dynamic>.from(r))
          .toList();
  static Future<Map<String, dynamic>?> detail(int id) async {
    final data = unwrapData(
        await ApiService.get('/Reports/OnlineSubmissionDetails/$id'));
    return data is Map ? Map<String, dynamic>.from(data) : null;
  }

  static Future<void> approve(Map<String, dynamic> data) async {
    final response = await ApiService.post('/Account/ApproveStudent', {
      'id': data['id'],
      for (final key in [
        'trainingCentreId',
        'studentCentreId',
        'examCentreId',
        'presentGradeId',
        'feeTypeId'
      ])
        key: data[key],
    });
    final error = apiEnvelopeError(response);
    if (error != null) throw Exception(error);
  }

  static Future<void> reject(int id) async {
    final response = await ApiService.post(
        '/Account/RejectStudent', {'id': id, 'remarks': ''});
    final error = apiEnvelopeError(response);
    if (error != null) throw Exception(error);
  }
}
