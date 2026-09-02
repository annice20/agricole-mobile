import '../core/api_client.dart';

/// Équivalent Flutter de locationService.js
class LocationService {
  final ApiClient _api = ApiClient();

  Future<List<dynamic>> getRegions() async {
    final data = await _api.get("/regions");
    return data as List<dynamic>;
  }

  Future<List<dynamic>> getDistrictsByRegion(int regionId) async {
    final data = await _api.get("/districts/region/$regionId");
    return data as List<dynamic>;
  }
}
