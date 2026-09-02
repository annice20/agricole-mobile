import '../core/api_client.dart';
import '../models/aide_model.dart';

class DistributionService {
  final ApiClient _api = ApiClient();

  Future<List<dynamic>> getDistributions() async {
    final data = await _api.get('/distributions');
    return data as List<dynamic>;
  }

  Future<List<dynamic>> getDistributionsParRegion(int regionId) async {
    final data = await _api.get('/distributions/region/$regionId');
    return data as List<dynamic>;
  }

  Future<List<Aide>> getMesAides(String agriculteurId) async {
    final data = await _api.get('/distributions/agriculteur/$agriculteurId');

    if (data is List) {
      return data
          .map((jsonItem) => Aide.fromJson(jsonItem as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  Future<dynamic> createDistribution(Map<String, dynamic> data) async {
    return await _api.post('/distributions', data);
  }

  Future<dynamic> updateDistribution(int id, Map<String, dynamic> data) async {
    return await _api.put('/distributions/$id', data);
  }

  Future<void> deleteDistribution(int id) async {
    await _api.delete('/distributions/$id');
  }
}
