import '../core/api_client.dart';

class DemandeAideService {
  final ApiClient _api = ApiClient();

  Future<List<dynamic>> getDemandes() async {
    final data = await _api.get('/demandes');
    return data as List<dynamic>;
  }

  Future<List<dynamic>> getDemandesParRegion(int regionId) async {
    final data = await _api.get('/demandes/region/$regionId');
    return data as List<dynamic>;
  }

  Future<dynamic> createDemande(Map<String, dynamic> data) async {
    return await _api.post('/demandes', data);
  }

  Future<dynamic> updateDemande(int id, Map<String, dynamic> data) async {
    return await _api.put('/demandes/$id', data);
  }

  Future<void> deleteDemande(int id) async {
    await _api.delete('/demandes/$id');
  }

  Future<dynamic> changerStatut(int id, String statut) async {
    return await _api.patch('/demandes/$id/statut', {'statut': statut});
  }
}
