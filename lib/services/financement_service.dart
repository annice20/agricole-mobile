import '../core/api_client.dart';

class FinancementService {
  final ApiClient _api = ApiClient();

  Future<List<dynamic>> getAllFinancements() async {
    final data = await _api.get('/financements');
    return data as List<dynamic>;
  }

  Future<dynamic> createFinancement(Map<String, dynamic> data) async {
    return await _api.post('/financements', data);
  }

  Future<dynamic> updateFinancement(int id, Map<String, dynamic> data) async {
    return await _api.put('/financements/$id', data);
  }

  Future<void> deleteFinancement(int id) async {
    await _api.delete('/financements/$id');
  }
}
