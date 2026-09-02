import '../core/api_client.dart';

class EquipementService {
  final ApiClient _api = ApiClient();

  Future<List<dynamic>> getEquipements() async {
    final data = await _api.get('/equipements');
    return data is List ? data : [];
  }

  Future<dynamic> ajouterEquipement(Map<String, dynamic> data) async {
    return await _api.post('/equipements', data);
  }

  Future<dynamic> modifierEquipement(int id, Map<String, dynamic> data) async {
    return await _api.put('/equipements/$id', data);
  }

  Future<void> deleteEquipement(int id) async {
    await _api.delete('/equipements/$id');
  }
}
