import '../core/api_client.dart';

/// Équivalent Flutter des appels /api/geo/* utilisés dans CarteAgricole.jsx
class GeoService {
  final ApiClient _api = ApiClient();

  Future<List<dynamic>> getExploitations() async {
    final data = await _api.get('/geo/exploitations');
    return data as List<dynamic>;
  }

  Future<List<dynamic>> getStatistiquesRegion() async {
    final data = await _api.get('/geo/statistiques-region');
    return data as List<dynamic>;
  }

  /// Enregistre les coordonnées GPS trouvées automatiquement pour un
  /// agriculteur. Le backend attend latitude/longitude en paramètres de
  /// requête (comme côté React), pas dans le corps JSON.
  Future<void> localiser(
    int agriculteurId,
    double latitude,
    double longitude,
  ) async {
    await _api.put(
      '/geo/localiser/$agriculteurId?latitude=$latitude&longitude=$longitude',
      const {},
    );
  }
}
