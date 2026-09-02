import '../core/api_client.dart';

class AgriculteurService {
  final ApiClient _api = ApiClient();

  Future<List<dynamic>> getAll() async {
    final data = await _api.get("/agriculteurs");
    return data as List<dynamic>;
  }

  Future<Map<String, dynamic>> getById(int id) async {
    final data = await _api.get("/agriculteurs/$id");
    return data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getByUtilisateurId(int utilisateurId) async {
    final data = await _api.get("/agriculteurs/utilisateur/$utilisateurId");
    return data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> create(Map<String, dynamic> data) async {
    final result = await _api.post("/agriculteurs", data);
    return result as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> update(int id, Map<String, dynamic> data) async {
    final result = await _api.put("/agriculteurs/$id", data);
    return result as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> changerActivation(
    int id,
    String statusCompte,
  ) async {
    final data = await _api.patch("/agriculteurs/$id/activation", {
      "statusCompte": statusCompte,
    });
    return data as Map<String, dynamic>;
  }

  Future<List<dynamic>> getBeneficiairesParRegion(int regionId) async {
    final data = await _api.get("/agriculteurs/beneficiaires/region/$regionId");
    return data as List<dynamic>;
  }

  // tous les agriculteurs d'une région (vue responsable régional)
  Future<List<dynamic>> getByRegion(int regionId) async {
    final data = await _api.get("/agriculteurs/region/$regionId");
    return data as List<dynamic>;
  }

  Future<void> delete(int id) async {
    await _api.delete("/agriculteurs/$id");
  }
}
