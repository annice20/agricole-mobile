import '../core/api_client.dart';
import '../models/utilisateur.dart';

class ProfilService {
  static final ApiClient _api = ApiClient();

  static Future<Utilisateur> getProfil(int id) async {
    final data = await _api.get('/profil/$id');
    return Utilisateur.fromJson(data as Map<String, dynamic>);
  }

  static Future<Utilisateur> modifierProfil(
    int id,
    Map<String, dynamic> data,
  ) async {
    final result = await _api.put('/profil/$id', data);
    return Utilisateur.fromJson(result as Map<String, dynamic>);
  }

  static Future<void> changerMotDePasse(
    int id,
    Map<String, dynamic> data,
  ) async {
    await _api.put('/profil/$id/mot-de-passe', data);
  }
}
