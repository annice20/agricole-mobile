import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

/// Exception levée quand l'API renvoie une erreur (4xx/5xx).
class ApiException implements Exception {
  final int statusCode;
  final String message;

  ApiException(this.statusCode, this.message);

  @override
  String toString() => message;
}

class Session {
  final String token;
  final String role;
  final int id;
  final String? nom;
  final String? prenom;
  final String? email;
  final int? agriculteurId;
  final int? regionId;
  final String? regionNom;

  Session({
    required this.token,
    required this.role,
    required this.id,
    this.nom,
    this.prenom,
    this.email,
    this.agriculteurId,
    this.regionId,
    this.regionNom,
  });

  Map<String, dynamic> toJson() => {
    "token": token,
    "role": role,
    "id": id,
    "nom": nom,
    "prenom": prenom,
    "email": email,
    "agriculteurId": agriculteurId,
    "regionId": regionId,
    "regionNom": regionNom,
  };

  factory Session.fromJson(Map<String, dynamic> json) => Session(
    token: json["token"],
    role: json["role"],
    id: json["id"],
    nom: json["nom"],
    prenom: json["prenom"],
    email: json["email"],
    agriculteurId: json["agriculteurId"],
    regionId: json["regionId"],
    regionNom: json["regionNom"],
  );
}

/// Client API centralisé — équivalent Flutter de axiosConfig.js +
/// services/authService.js (saveSession / getSession / clearSession).
///
/// Équivalence avec le web :
///   - rememberMe = true  -> persisté dans flutter_secure_storage
///                           (≈ localStorage : survit au redémarrage de
///                           l'app)
///   - rememberMe = false -> gardé UNIQUEMENT en mémoire (_memorySession)
///                           (≈ sessionStorage : perdu quand l'app est
///                           tuée/redémarrée, jamais écrit sur le disque)
class ApiClient {
  ApiClient._internal();
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;

  static const String baseUrl = "http://localhost:8081/api";

  static const _storage = FlutterSecureStorage();
  static const _sessionKey = "session";

  // Cache mémoire : sert de "sessionStorage" ET de cache rapide pour le
  // token pendant toute la durée de vie de l'app.
  Session? _memorySession;

  // Token posé immédiatement après login/OTP, AVANT la sauvegarde
  // complète de la session — corrige le même bug 403 documenté côté
  // React ("il faut poser le token avant tout appel API protégé").
  String? _pendingToken;

  // -----------------------------------------------------------------
  // GESTION DE SESSION
  // -----------------------------------------------------------------

  /// Pose le token tout de suite pour les appels authentifiés suivants,
  /// sans encore persister la session complète (utilisé le temps de
  /// récupérer l'agriculteurId par exemple).
  void setPendingToken(String token) {
    _pendingToken = token;
  }

  Future<void> saveSession(Session session, {bool rememberMe = false}) async {
    _pendingToken = null; // la session complète prend le relais
    _memorySession = session;

    if (rememberMe) {
      await _storage.write(
        key: _sessionKey,
        value: jsonEncode(session.toJson()),
      );
    } else {
      // On s'assure qu'aucune ancienne session "remember me" ne traîne
      await _storage.delete(key: _sessionKey);
    }
  }

  Future<Session?> getSession() async {
    if (_memorySession != null) return _memorySession;

    final raw = await _storage.read(key: _sessionKey);
    if (raw == null) return null;
    try {
      final session = Session.fromJson(jsonDecode(raw));
      _memorySession = session;
      return session;
    } catch (_) {
      return null;
    }
  }

  Future<void> clearSession() async {
    _memorySession = null;
    _pendingToken = null;
    await _storage.delete(key: _sessionKey);
  }

  Future<String?> _getToken() async {
    if (_pendingToken != null) return _pendingToken;
    if (_memorySession != null) return _memorySession!.token;
    final session = await getSession();
    return session?.token;
  }

  // -----------------------------------------------------------------
  // EN-TETES COMMUNS
  // -----------------------------------------------------------------

  Future<Map<String, String>> _buildHeaders({bool withAuth = true}) async {
    final headers = {"Content-Type": "application/json"};
    if (withAuth) {
      final token = await _getToken();
      if (token != null) {
        headers["Authorization"] = "Bearer $token";
      }
    }
    return headers;
  }

  // -----------------------------------------------------------------
  // TRAITEMENT COMMUN DES REPONSES
  // -----------------------------------------------------------------

  dynamic _processResponse(http.Response response) {
    final hasBody = response.body.isNotEmpty;
    final dynamic decoded = hasBody ? jsonDecode(response.body) : null;

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = (decoded is Map && decoded["message"] != null)
          ? decoded["message"].toString()
          : "Erreur ${response.statusCode}";
      throw ApiException(response.statusCode, message);
    }

    return decoded;
  }

  // -----------------------------------------------------------------
  // METHODES HTTP
  // -----------------------------------------------------------------

  Future<dynamic> get(String path, {bool withAuth = true}) async {
    final headers = await _buildHeaders(withAuth: withAuth);
    final response = await http
        .get(Uri.parse("$baseUrl$path"), headers: headers)
        .timeout(const Duration(seconds: 15));
    return _processResponse(response);
  }

  Future<dynamic> post(
    String path,
    Map<String, dynamic> body, {
    bool withAuth = true,
  }) async {
    final headers = await _buildHeaders(withAuth: withAuth);
    final response = await http
        .post(
          Uri.parse("$baseUrl$path"),
          headers: headers,
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 15));
    return _processResponse(response);
  }

  Future<dynamic> put(
    String path,
    Map<String, dynamic> body, {
    bool withAuth = true,
  }) async {
    final headers = await _buildHeaders(withAuth: withAuth);
    final response = await http
        .put(
          Uri.parse("$baseUrl$path"),
          headers: headers,
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 15));
    return _processResponse(response);
  }

  Future<dynamic> patch(
    String path,
    Map<String, dynamic> body, {
    bool withAuth = true,
  }) async {
    final headers = await _buildHeaders(withAuth: withAuth);
    final response = await http
        .patch(
          Uri.parse("$baseUrl$path"),
          headers: headers,
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 15));
    return _processResponse(response);
  }

  Future<void> delete(String path, {bool withAuth = true}) async {
    final headers = await _buildHeaders(withAuth: withAuth);
    final response = await http
        .delete(Uri.parse("$baseUrl$path"), headers: headers)
        .timeout(const Duration(seconds: 15));
    _processResponse(response);
  }

  /// Pour les endpoints qui retournent des bytes bruts (ex: PDF)
  Future<List<int>> getBytes(String path, {bool withAuth = true}) async {
    final headers = await _buildHeaders(withAuth: withAuth);
    final response = await http
        .get(Uri.parse("$baseUrl$path"), headers: headers)
        .timeout(const Duration(seconds: 30));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(response.statusCode, "Erreur ${response.statusCode}");
    }
    return response.bodyBytes;
  }
}
