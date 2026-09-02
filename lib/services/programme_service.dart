import '../core/api_client.dart';

class ProgrammeService {
  final ApiClient _api = ApiClient();

  Future<List<dynamic>> getAll() async {
    final data = await _api.get('/programmes');
    return data as List<dynamic>;
  }

  Future<Map<String, dynamic>> getById(int id) async {
    final data = await _api.get('/programmes/$id');
    return data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> create(Map<String, dynamic> data) async {
    final result = await _api.post('/programmes', data);
    return result as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> update(int id, Map<String, dynamic> data) async {
    final result = await _api.put('/programmes/$id', data);
    return result as Map<String, dynamic>;
  }

  /// Bascule le statut actif/inactif (équivalent handleToggleActif du web).
  Future<Map<String, dynamic>> toggleActif(int id, bool actif) async {
    final result = await _api.patch('/programmes/$id', {'actif': actif});
    return result as Map<String, dynamic>;
  }

  Future<void> delete(int id) async {
    await _api.delete('/programmes/$id');
  }
}
