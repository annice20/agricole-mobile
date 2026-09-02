import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../services/auth_service.dart';
import '../../services/location_service.dart';

class InscriptionPage extends StatefulWidget {
  const InscriptionPage({super.key});

  @override
  State<InscriptionPage> createState() => _InscriptionPageState();
}

class _InscriptionPageState extends State<InscriptionPage> {
  final _formKey = GlobalKey<FormState>();

  bool _loading = false;
  bool _geoLoading = false;

  // Listes et sélections
  List<dynamic> _regions = [];
  List<dynamic> _districts = [];
  int? _selectedRegionId;
  String _selectedRegionNom = "";
  int? _selectedDistrictId;
  String _selectedDistrictNom = "";

  // Coordonnées GPS
  Map<String, double>? _coordonnees;

  // Contrôleurs de formulaire
  final _nomController = TextEditingController();
  final _prenomController = TextEditingController();
  final _dateNaissanceController = TextEditingController();
  final _cinController = TextEditingController();
  final _telephoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _adresseController = TextEditingController();
  final _superficieController = TextEditingController();
  final _motDePasseController = TextEditingController();
  final _confirmationMotDePasseController = TextEditingController();

  String _genre = "Masculin";
  String _culturePrincipale = "Maïs";

  @override
  void initState() {
    super.initState();
    _chargerRegions();
  }

  @override
  void dispose() {
    _nomController.dispose();
    _prenomController.dispose();
    _dateNaissanceController.dispose();
    _cinController.dispose();
    _telephoneController.dispose();
    _emailController.dispose();
    _adresseController.dispose();
    _superficieController.dispose();
    _motDePasseController.dispose();
    _confirmationMotDePasseController.dispose();
    super.dispose();
  }

  // API - Charger les régions
  Future<void> _chargerRegions() async {
    try {
      final list = await LocationService().getRegions();
      if (mounted) {
        setState(() => _regions = list);
      }
    } catch (_) {
      _showSnackBar("Impossible de charger les régions", isError: true);
    }
  }

  // API - Charger les districts selon la région
  Future<void> _chargerDistricts(int regionId) async {
    try {
      final list = await LocationService().getDistrictsByRegion(regionId);
      if (mounted) {
        setState(() => _districts = list);
      }
    } catch (_) {
      _showSnackBar("Impossible de charger les districts", isError: true);
    }
  }

  // Géocodage Nominatim (OpenStreetMap)
  Future<Map<String, double>?> _geocoderAdresse(
    String adresse,
    String districtNom,
    String regionNom,
  ) async {
    final query = "$adresse, $districtNom, $regionNom, Madagascar";

    setState(() => _geoLoading = true);

    try {
      final uri = Uri.parse(
        "https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&limit=1&countrycodes=mg",
      );
      final response = await http.get(uri, headers: {"Accept-Language": "fr"});

      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        if (data.isNotEmpty) {
          final coords = {
            "latitude": double.parse(data[0]["lat"]),
            "longitude": double.parse(data[0]["lon"]),
          };
          setState(() => _coordonnees = coords);
          return coords;
        }
      }

      // Fallback si l'adresse exacte échoue
      final fallbackUri = Uri.parse(
        "https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent('$districtNom, $regionNom, Madagascar')}&format=json&limit=1&countrycodes=mg",
      );
      final fallbackResponse = await http.get(fallbackUri);

      if (fallbackResponse.statusCode == 200) {
        final List fallbackData = json.decode(fallbackResponse.body);
        if (fallbackData.isNotEmpty) {
          final coords = {
            "latitude": double.parse(fallbackData[0]["lat"]),
            "longitude": double.parse(fallbackData[0]["lon"]),
          };
          setState(() => _coordonnees = coords);
          return coords;
        }
      }

      _showSnackBar(
        "Localisation introuvable : enregistrement sans GPS.",
        isWarning: true,
      );
      return null;
    } catch (e) {
      _showSnackBar(
        "Service GPS indisponible : enregistrement sans GPS.",
        isWarning: true,
      );
      return null;
    } finally {
      if (mounted) setState(() => _geoLoading = false);
    }
  }

  // Soumission du formulaire
  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedDistrictId == null) {
      _showSnackBar("Veuillez sélectionner un district.", isWarning: true);
      return;
    }

    if (_motDePasseController.text != _confirmationMotDePasseController.text) {
      _showSnackBar("Les mots de passe ne correspondent pas.", isError: true);
      return;
    }

    setState(() => _loading = true);

    Map<String, double>? coords = _coordonnees;
    coords ??= await _geocoderAdresse(
      _adresseController.text,
      _selectedDistrictNom,
      _selectedRegionNom,
    );

    final payload = {
      "nom": _nomController.text,
      "prenom": _prenomController.text,
      "genre": _genre,
      "sexe": _genre,
      "dateNaissance": _dateNaissanceController.text,
      "cin": _cinController.text,
      "telephone": _telephoneController.text,
      "email": _emailController.text,
      "adresse": _adresseController.text,
      "culturePrincipale": _culturePrincipale,
      "typeCulture": _culturePrincipale,
      "superficie": _superficieController.text.isNotEmpty
          ? double.tryParse(_superficieController.text)
          : null,
      "districtId": _selectedDistrictId,
      "motDePasse": _motDePasseController.text,
      "latitude": coords?["latitude"],
      "longitude": coords?["longitude"],
    };

    try {
      await AuthService().inscrireAgriculteur(payload);
      _showSnackBar(
        "Inscription réussie ! Votre compte sera activé après validation.",
      );
      if (mounted) {
        Navigator.pushReplacementNamed(context, "/");
      }
    } catch (e) {
      _showSnackBar("Échec de l'inscription.", isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showSnackBar(
    String text, {
    bool isError = false,
    bool isWarning = false,
  }) {
    Color bg = Colors.green.shade800;
    if (isError) bg = Colors.red.shade700;
    if (isWarning) bg = Colors.orange.shade800;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: bg,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // Sélection de la date
  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(1990),
      firstDate: DateTime(1940),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _dateNaissanceController.text =
            "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFD1FAE5), Color(0xFFA7F3D0), Color(0xFF6EE7B7)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 650),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.65),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withOpacity(0.5)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header
                      Center(
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF15803D),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(
                                Icons.eco,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              "Inscription Producteur",
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF14532D),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Créez votre compte pour accéder aux programmes d'aide agricole.",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.green.shade900.withOpacity(0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Identité
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _nomController,
                              label: "Nom",
                              validator: (v) =>
                                  v!.isEmpty ? "Champ requis" : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTextField(
                              controller: _prenomController,
                              label: "Prénom",
                              validator: (v) =>
                                  v!.isEmpty ? "Champ requis" : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Genre & Date Naissance
                      Row(
                        children: [
                          Expanded(
                            child: _buildDropdown(
                              label: "Genre",
                              value: _genre,
                              items: const ["Masculin", "Féminin"],
                              onChanged: (val) => setState(() => _genre = val!),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: InkWell(
                              onTap: _selectDate,
                              child: IgnorePointer(
                                child: _buildTextField(
                                  controller: _dateNaissanceController,
                                  label: "Date de Naissance",
                                  icon: Icons.calendar_today,
                                  validator: (v) =>
                                      v!.isEmpty ? "Champ requis" : null,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // CIN & Téléphone
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _cinController,
                              label: "Numéro CIN",
                              maxLength: 12,
                              keyboardType: TextInputType.number,
                              validator: (v) =>
                                  v!.isEmpty ? "Champ requis" : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTextField(
                              controller: _telephoneController,
                              label: "Téléphone",
                              keyboardType: TextInputType.phone,
                              validator: (v) =>
                                  v!.isEmpty ? "Champ requis" : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Email & Adresse
                      _buildTextField(
                        controller: _emailController,
                        label: "Email",
                        icon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) => v!.isEmpty ? "Champ requis" : null,
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: _adresseController,
                        label: "Adresse (Ville/Commune)",
                        placeholder: "Ex: Ambohimanarina",
                        onChanged: (_) => setState(() => _coordonnees = null),
                        validator: (v) => v!.isEmpty ? "Champ requis" : null,
                      ),
                      const SizedBox(height: 12),

                      // Mots de passe
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _motDePasseController,
                              label: "Mot de passe",
                              obscureText: true,
                              icon: Icons.lock_outline,
                              validator: (v) =>
                                  v!.length < 6 ? "Min. 6 caractères" : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTextField(
                              controller: _confirmationMotDePasseController,
                              label: "Confirmer",
                              obscureText: true,
                              icon: Icons.lock_outline,
                              validator: (v) =>
                                  v!.length < 6 ? "Min. 6 caractères" : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Section Données Agricoles
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF14532D).withOpacity(0.06),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFF14532D).withOpacity(0.12),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildDropdown(
                                label: "Culture Principale",
                                value: _culturePrincipale,
                                items: const [
                                  "Maïs",
                                  "Vanille",
                                  "Riz",
                                  "Girofle",
                                ],
                                onChanged: (val) =>
                                    setState(() => _culturePrincipale = val!),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildTextField(
                                controller: _superficieController,
                                label: "Superficie (Ha)",
                                placeholder: "Ex: 0.05",
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Region / District
                      Row(
                        children: [
                          Expanded(
                            child: _buildDropdownDynamic(
                              label: "Région",
                              icon: Icons.public,
                              value: _selectedRegionId,
                              items: _regions,
                              onChanged: (val) {
                                final sel = _regions.firstWhere(
                                  (r) => r["id"] == val,
                                  orElse: () => null,
                                );
                                setState(() {
                                  _selectedRegionId = val;
                                  _selectedRegionNom = sel?["nom"] ?? "";
                                  _selectedDistrictId = null;
                                  _selectedDistrictNom = "";
                                  _districts = [];
                                  _coordonnees = null;
                                });
                                if (val != null) _chargerDistricts(val);
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildDropdownDynamic(
                              label: "District",
                              icon: Icons.location_on_outlined,
                              value: _selectedDistrictId,
                              items: _districts,
                              disabled: _selectedRegionId == null,
                              onChanged: (val) {
                                final sel = _districts.firstWhere(
                                  (d) => d["id"] == val,
                                  orElse: () => null,
                                );
                                setState(() {
                                  _selectedDistrictId = val;
                                  _selectedDistrictNom = sel?["nom"] ?? "";
                                  _coordonnees = null;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Information GPS Status
                      if (_selectedDistrictId != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _coordonnees != null
                                ? Colors.green.shade100
                                : Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _coordonnees != null
                                  ? Colors.green.shade400
                                  : Colors.orange.shade400,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _coordonnees != null
                                    ? Icons.check_circle_outline
                                    : Icons.location_on_outlined,
                                color: _coordonnees != null
                                    ? Colors.green.shade800
                                    : Colors.orange.shade800,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _coordonnees != null
                                      ? "GPS : ${_coordonnees!['latitude']!.toStringAsFixed(4)}, ${_coordonnees!['longitude']!.toStringAsFixed(4)}"
                                      : "La géolocalisation GPS sera détectée à la validation.",
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: _coordonnees != null
                                        ? Colors.green.shade900
                                        : Colors.orange.shade900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 20),

                      // Bouton Valider
                      SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          onPressed: (_loading || _geoLoading)
                              ? null
                              : _handleSubmit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF15803D),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 2,
                          ),
                          child: (_loading || _geoLoading)
                              ? Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      _geoLoading
                                          ? "Localisation GPS..."
                                          : "Inscription en cours...",
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                )
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.person_add_alt_1,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      "S'inscrire",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Lien Connexion
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Déjà inscrit ? ",
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.green.shade900.withOpacity(0.8),
                            ),
                          ),
                          GestureDetector(
                            onTap: () =>
                                Navigator.pushReplacementNamed(context, "/"),
                            child: const Text(
                              "Se connecter",
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF14532D),
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- Composants réutilisables ---

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? placeholder,
    IconData? icon,
    bool obscureText = false,
    int? maxLength,
    TextInputType keyboardType = TextInputType.text,
    Function(String)? onChanged,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: Color(0xFF14532D),
          ),
        ),
        const SizedBox(height: 4),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          maxLength: maxLength,
          keyboardType: keyboardType,
          onChanged: onChanged,
          validator: validator,
          style: const TextStyle(fontSize: 13, color: Color(0xFF14532D)),
          decoration: InputDecoration(
            hintText: placeholder,
            counterText: "",
            prefixIcon: icon != null
                ? Icon(icon, size: 16, color: const Color(0xFF15803D))
                : null,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            filled: true,
            fillColor: Colors.white.withOpacity(0.6),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.8)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.8)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFF15803D),
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> items,
    required void Function(String?) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: Color(0xFF14532D),
          ),
        ),
        const SizedBox(height: 4),
        DropdownButtonFormField<String>(
          value: value,
          onChanged: onChanged,
          items: items
              .map(
                (item) => DropdownMenuItem(
                  value: item,
                  child: Text(item, style: const TextStyle(fontSize: 13)),
                ),
              )
              .toList(),
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            filled: true,
            fillColor: Colors.white.withOpacity(0.6),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.8)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownDynamic({
    required String label,
    required IconData icon,
    required int? value,
    required List<dynamic> items,
    required void Function(int?) onChanged,
    bool disabled = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 12, color: const Color(0xFF14532D)),
            const SizedBox(width: 4),
            Text(
              label.toUpperCase(),
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: Color(0xFF14532D),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        DropdownButtonFormField<int>(
          value: value,
          onChanged: disabled ? null : onChanged,
          items: items
              .map(
                (item) => DropdownMenuItem<int>(
                  value: item["id"],
                  child: Text(
                    item["nom"] ?? "",
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              )
              .toList(),
          decoration: InputDecoration(
            hintText: disabled
                ? "Sélectionner d'abord la région"
                : "-- Choisir --",
            hintStyle: const TextStyle(fontSize: 11),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            filled: true,
            fillColor: disabled
                ? Colors.grey.shade200.withOpacity(0.5)
                : Colors.white.withOpacity(0.6),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.8)),
            ),
          ),
        ),
      ],
    );
  }
}
