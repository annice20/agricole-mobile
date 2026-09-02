import '../core/api_client.dart';

class ReclamationService {
  final ApiClient _api = ApiClient();

  Future<List<dynamic>> getReclamationsByAgriculteur(int agriculteurId) async {
    final data = await _api.get('/reclamations/agriculteur/$agriculteurId');
    return data as List<dynamic>;
  }

  Future<List<dynamic>> getAllReclamations() async {
    final data = await _api.get('/reclamations');
    return data as List<dynamic>;
  }

  Future<List<dynamic>> getReclamationsParRegion(int regionId) async {
    final data = await _api.get('/reclamations/region/$regionId');
    return data as List<dynamic>;
  }

  Future<dynamic> changerStatut(int id, String statut) async {
    return await _api.put('/reclamations/$id/statut', {'statut': statut});
  }

  Future<dynamic> createReclamation(Map<String, dynamic> data) async {
    return await _api.post('/reclamations', data);
  }

  Future<dynamic> getReclamationById(int id) async {
    return await _api.get('/reclamations/$id');
  }

  Future<dynamic> updateReclamation(int id, Map<String, dynamic> data) async {
    return await _api.put('/reclamations/$id', data);
  }

  Future<void> deleteReclamation(int id) async {
    await _api.delete('/reclamations/$id');
  }
}
