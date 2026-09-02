import '../core/api_client.dart';
import 'agriculteur_service.dart';

class LoginResult {
  final String? statusCompte;
  final String? message;
  final bool otpRequis;
  final String? token;
  final String? role;
  final int? id;
  final String? nom;
  final String? prenom;
  final int? regionId;
  final String? regionNom;

  LoginResult({
    this.statusCompte,
    this.message,
    this.otpRequis = false,
    this.token,
    this.role,
    this.id,
    this.nom,
    this.prenom,
    this.regionId,
    this.regionNom,
  });

  factory LoginResult.fromJson(Map<String, dynamic> json) => LoginResult(
    statusCompte: json["statusCompte"],
    message: json["message"],
    otpRequis: (json["otpRequis"] ?? json["isOtpRequired"] ?? false) == true,
    token: json["token"],
    role: json["role"],
    id: json["id"],
    nom: json["nom"],
    prenom: json["prenom"],
    regionId: json["regionId"],
    regionNom: json["regionNom"],
  );
}

/// Équivalent Flutter de services/authService.js.
class AuthService {
  final ApiClient _api = ApiClient();
  final AgriculteurService _agriculteurService = AgriculteurService();

  Future<LoginResult> login(String email, String motDePasse) async {
    final data = await _api.post("/auth/login", {
      "email": email,
      "motDePasse": motDePasse,
    }, withAuth: false);
    return LoginResult.fromJson(data as Map<String, dynamic>);
  }

  Future<LoginResult> verifierOtp(String email, String codeOtp) async {
    final data = await _api.post("/auth/verifier-otp", {
      "email": email,
      "codeOtp": codeOtp,
    }, withAuth: false);
    return LoginResult.fromJson(data as Map<String, dynamic>);
  }

  Future<void> renvoyerOtp(String email) async {
    await _api.post("/auth/renvoyer-otp", {"email": email}, withAuth: false);
  }

  Future<Map<String, dynamic>> inscrireAgriculteur(
    Map<String, dynamic> data,
  ) async {
    return await _api.post("/auth/inscription", data, withAuth: false)
        as Map<String, dynamic>;
  }

  Future<void> demanderReinitialisation(String email) async {
    await _api.post("/auth/forgot-password", {"email": email}, withAuth: false);
  }

  Future<void> reinitialiserMotDePasse(
    String token,
    String nouveauMotDePasse,
  ) async {
    await _api.post("/auth/reset-password", {
      "token": token,
      "nouveauMotDePasse": nouveauMotDePasse,
    }, withAuth: false);
  }

  Future<void> sauvegarderSession(
    LoginResult data, {
    bool rememberMe = false,
    String? email,
  }) async {
    if (data.token == null || data.role == null || data.id == null) {
      throw ApiException(500, "Réponse de connexion incomplète");
    }

    _api.setPendingToken(data.token!);

    int? agriculteurId;
    if (data.role == "AGRICULTEUR") {
      final agriculteur = await _agriculteurService.getByUtilisateurId(
        data.id!,
      );
      agriculteurId = agriculteur["id"] as int?;
    }

    final session = Session(
      token: data.token!,
      role: data.role!,
      id: data.id!,
      nom: data.nom,
      prenom: data.prenom,
      email: email,
      agriculteurId: agriculteurId,
      regionId: data.regionId,
      regionNom: data.regionNom,
    );

    await _api.saveSession(session, rememberMe: rememberMe);
  }

  Future<Session?> getSession() => _api.getSession();

  Future<void> logout() => _api.clearSession();
}
