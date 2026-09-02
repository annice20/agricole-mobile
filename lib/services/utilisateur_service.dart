import '../core/api_client.dart';

class UtilisateurService {
  final ApiClient _api = ApiClient();

  Future<List<dynamic>> getUtilisateurs() async {
    final data = await _api.get('/utilisateurs');
    return data as List<dynamic>;
  }

  Future<Map<String, dynamic>> creerUtilisateur(
    Map<String, dynamic> data,
  ) async {
    final result = await _api.post('/utilisateurs', data);
    return result as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> changerRoleUtilisateur(
    int id,
    String roleName, {
    int? regionId,
  }) async {
    final result = await _api.patch('/utilisateurs/$id', {
      'roleName': roleName,
      'regionId': regionId,
    });
    return result as Map<String, dynamic>;
  }

  Future<void> supprimerUtilisateur(int id) async {
    await _api.delete('/utilisateurs/$id');
  }
}
