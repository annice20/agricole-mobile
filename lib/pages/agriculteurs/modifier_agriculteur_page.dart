import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../core/api_client.dart';
import '../../widgets/app_layout.dart';
import '../../services/agriculteur_service.dart';
import '../../services/location_service.dart';

class ModifierAgriculteurPage extends StatefulWidget {
  const ModifierAgriculteurPage({super.key});

  @override
  State<ModifierAgriculteurPage> createState() =>
      _ModifierAgriculteurPageState();
}

class _ModifierAgriculteurPageState extends State<ModifierAgriculteurPage> {
  final _formKey = GlobalKey<FormState>();
  final _agriculteurService = AgriculteurService();
  final _locationService = LocationService();

  bool _chargementInitial = true;
  bool _loading = false;
  bool _geoLoading = false;
  bool _argsLoaded = false;

  late int _agriculteurId;
  double? _latitude;
  double? _longitude;
  String? _adresseOriginale;
  bool _actifExistant = false;

  List<dynamic> _regions = [];
  List<dynamic> _districts = [];
  Map<String, dynamic>? _selectedRegion;
  Map<String, dynamic>? _selectedDistrict;

  final _nomCtrl = TextEditingController();
  final _prenomCtrl = TextEditingController();
  final _dateNaissanceCtrl = TextEditingController();
  final _cinCtrl = TextEditingController();
  final _telephoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _adresseCtrl = TextEditingController();
  final _superficieCtrl = TextEditingController();

  String _genre = 'Masculin';
  String _culturePrincipale = 'Maïs';

  static const List<String> _genres = ['Masculin', 'Féminin'];
  static const List<String> _cultures = ['Maïs', 'Vanille', 'Riz', 'Girofle'];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_argsLoaded) {
      final args = ModalRoute.of(context)!.settings.arguments as Map;
      _agriculteurId = args['id'] as int;
      _argsLoaded = true;
      _initialiser();
    }
  }

  @override
  void dispose() {
    _nomCtrl.dispose();
    _prenomCtrl.dispose();
    _dateNaissanceCtrl.dispose();
    _cinCtrl.dispose();
    _telephoneCtrl.dispose();
    _emailCtrl.dispose();
    _adresseCtrl.dispose();
    _superficieCtrl.dispose();
    super.dispose();
  }

  void _showSnack(
    String message, {
    bool erreur = false,
    bool avertissement = false,
  }) {
    if (!mounted) return;
    final color = erreur
        ? Colors.red.shade600
        : avertissement
        ? Colors.orange.shade600
        : Colors.green.shade700;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  }

  Future<void> _initialiser() async {
    try {
      final regions = await _locationService.getRegions();
      setState(() => _regions = regions);

      final a = await _agriculteurService.getById(_agriculteurId);

      _nomCtrl.text = a['nom'] ?? '';
      _prenomCtrl.text = a['prenom'] ?? '';
      _genre = a['genre'] ?? a['sexe'] ?? 'Masculin';
      _dateNaissanceCtrl.text = (a['dateNaissance'] ?? '')
          .toString()
          .split('T')
          .first;
      _cinCtrl.text = a['cin'] ?? '';
      _telephoneCtrl.text = a['telephone'] ?? '';
      _emailCtrl.text = a['email'] ?? '';
      _adresseCtrl.text = a['adresse'] ?? '';
      _adresseOriginale = a['adresse'] ?? '';
      _culturePrincipale = a['culturePrincipale'] ?? a['typeCulture'] ?? 'Maïs';
      _superficieCtrl.text = a['superficie'] != null
          ? '${a['superficie']}'
          : '';
      _actifExistant = a['actif'] == true;

      if (a['latitude'] != null && a['longitude'] != null) {
        _latitude = (a['latitude'] as num).toDouble();
        _longitude = (a['longitude'] as num).toDouble();
      }

      final district = a['district'];
      final region = district?['region'];
      if (region != null) {
        final regionMatch = _regions.firstWhere(
          (r) => r['id'] == region['id'],
          orElse: () => null,
        );
        if (regionMatch != null) {
          _selectedRegion = regionMatch as Map<String, dynamic>;
          final districts = await _locationService.getDistrictsByRegion(
            _selectedRegion!['id'] as int,
          );
          _districts = districts;
          if (district != null) {
            final districtMatch = _districts.firstWhere(
              (d) => d['id'] == district['id'],
              orElse: () => null,
            );
            if (districtMatch != null) {
              _selectedDistrict = districtMatch as Map<String, dynamic>;
            }
          }
        }
      }

      setState(() {});
    } on ApiException catch (e) {
      _showSnack('Impossible de charger la fiche : ${e.message}', erreur: true);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      _showSnack(
        "Impossible de charger la fiche de l'agriculteur",
        erreur: true,
      );
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _chargementInitial = false);
    }
  }

  Future<void> _chargerDistricts(int regionId) async {
    try {
      final districts = await _locationService.getDistrictsByRegion(regionId);
      setState(() => _districts = districts);
    } catch (_) {
      _showSnack('Impossible de charger les districts', erreur: true);
    }
  }

  void _onRegionChanged(Map<String, dynamic>? region) {
    setState(() {
      _selectedRegion = region;
      _selectedDistrict = null;
      _districts = [];
      _latitude = null;
      _longitude = null;
    });
    if (region != null) _chargerDistricts(region['id'] as int);
  }

  void _onDistrictChanged(Map<String, dynamic>? district) {
    setState(() {
      _selectedDistrict = district;
      _latitude = null;
      _longitude = null;
    });
  }

  Future<Map<String, double>?> _tenterGeocodage(String query) async {
    final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
      'q': query,
      'format': 'json',
      'limit': '1',
      'countrycodes': 'mg',
    });
    final response = await http.get(uri, headers: {'Accept-Language': 'fr'});
    if (response.statusCode != 200) return null;
    final List results = jsonDecode(response.body);
    if (results.isEmpty) return null;
    final result = results.first;
    return {
      'latitude': double.parse(result['lat']),
      'longitude': double.parse(result['lon']),
    };
  }

  Future<Map<String, double>?> _geocoderAdresse() async {
    setState(() => _geoLoading = true);
    final districtNom = _selectedDistrict?['nom'] ?? '';
    final regionNom = _selectedRegion?['nom'] ?? '';

    try {
      final precis = await _tenterGeocodage(
        '${_adresseCtrl.text}, $districtNom, $regionNom, Madagascar',
      );
      if (precis != null) {
        setState(() {
          _latitude = precis['latitude'];
          _longitude = precis['longitude'];
        });
        _showSnack(
          'Localisation mise à jour : ${precis['latitude']!.toStringAsFixed(4)}, '
          '${precis['longitude']!.toStringAsFixed(4)}',
        );
        return precis;
      }
      _showSnack(
        'Localisation introuvable — les coordonnées existantes seront conservées.',
        avertissement: true,
      );
      return null;
    } catch (_) {
      _showSnack(
        'Service de géolocalisation indisponible.',
        avertissement: true,
      );
      return null;
    } finally {
      setState(() => _geoLoading = false);
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDistrict == null) {
      _showSnack(
        'Veuillez sélectionner un district pour la localisation.',
        avertissement: true,
      );
      return;
    }

    setState(() => _loading = true);

    // Ne re-géolocalise que si l'adresse a changé (sinon on garde le GPS existant)
    if (_latitude == null || _longitude == null) {
      if (_adresseCtrl.text != _adresseOriginale) {
        await _geocoderAdresse();
      }
    }

    final donneesAEnvoyer = <String, dynamic>{
      'nom': _nomCtrl.text,
      'prenom': _prenomCtrl.text,
      'genre': _genre,
      'sexe': _genre,
      'dateNaissance': _dateNaissanceCtrl.text,
      'cin': _cinCtrl.text,
      'telephone': _telephoneCtrl.text,
      'email': _emailCtrl.text,
      'adresse': _adresseCtrl.text,
      'culturePrincipale': _culturePrincipale,
      'typeCulture': _culturePrincipale,
      'superficie': _superficieCtrl.text.isNotEmpty
          ? double.tryParse(_superficieCtrl.text)
          : null,
      'actif': _actifExistant,
      'districtId': _selectedDistrict!['id'],
      'latitude': _latitude,
      'longitude': _longitude,
    };

    try {
      await _agriculteurService.update(_agriculteurId, donneesAEnvoyer);
      _showSnack('Fiche agriculteur mise à jour avec succès !');
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      _showSnack('Échec de la mise à jour : ${e.message}', erreur: true);
    } catch (_) {
      _showSnack('Échec de la mise à jour', erreur: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _selectionnerDate() async {
    final now = DateTime.now();
    DateTime initial;
    try {
      initial = _dateNaissanceCtrl.text.isNotEmpty
          ? DateTime.parse(_dateNaissanceCtrl.text)
          : DateTime(now.year - 30);
    } catch (_) {
      initial = DateTime(now.year - 30);
    }
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (date != null) {
      _dateNaissanceCtrl.text =
          '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_argsLoaded || _chargementInitial) {
      return AppLayout(
        currentRoute: '/agriculteurs/modifier',
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Colors.green.shade700),
              const SizedBox(height: 16),
              Text(
                'Chargement de la fiche...',
                style: TextStyle(
                  color: Colors.green.shade900,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return AppLayout(
      currentRoute: '/agriculteurs/modifier',
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.5),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.4)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 24),
                    _buildRow([
                      _champTexte('Nom', _nomCtrl, required: true),
                      _champTexte('Prénom', _prenomCtrl, required: true),
                      _dropdownTexte(
                        'Genre',
                        _genre,
                        _genres,
                        (v) => setState(() => _genre = v!),
                      ),
                    ]),
                    const SizedBox(height: 12),
                    _buildRow([
                      _champDate(
                        'Date de naissance',
                        _dateNaissanceCtrl,
                        _selectionnerDate,
                      ),
                      _champTexte(
                        'Numéro CIN',
                        _cinCtrl,
                        required: true,
                        maxLength: 12,
                      ),
                      _champTexte(
                        'Téléphone',
                        _telephoneCtrl,
                        required: true,
                        keyboardType: TextInputType.phone,
                      ),
                    ]),
                    const SizedBox(height: 12),
                    _buildRow([
                      _champTexte(
                        'Email',
                        _emailCtrl,
                        required: true,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      _champTexte(
                        'Adresse (Ville/Commune)',
                        _adresseCtrl,
                        required: true,
                        onChanged: (_) {
                          setState(() {
                            _latitude = null;
                            _longitude = null;
                          });
                        },
                      ),
                    ]),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.green.withOpacity(0.1),
                        ),
                      ),
                      child: _buildRow([
                        _dropdownTexte(
                          'Culture principale',
                          _culturePrincipale,
                          _cultures,
                          (v) => setState(() => _culturePrincipale = v!),
                        ),
                        _champTexte(
                          'Superficie exploitation (Ha)',
                          _superficieCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 16),
                    _buildRow([_dropdownRegion(), _dropdownDistrict()]),
                    const SizedBox(height: 16),
                    if (_selectedDistrict != null) _buildStatutGps(),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: (_loading || _geoLoading)
                          ? null
                          : _handleSubmit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: (_loading || _geoLoading)
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const SizedBox(
                                  height: 16,
                                  width: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation(
                                      Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  _geoLoading
                                      ? 'Détection GPS en cours...'
                                      : 'Enregistrement...',
                                ),
                              ],
                            )
                          : const Text(
                              'Enregistrer les modifications',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.green.shade700,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.edit, color: Colors.white, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          'Modifier le Producteur',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: Colors.green.shade900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          "Mettez à jour les informations de l'agriculteur et de son exploitation.",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            color: Colors.green.shade700.withOpacity(0.8),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildRow(List<Widget> children) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 560;
        if (!isWide) {
          return Column(
            children: children
                .map(
                  (c) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: c,
                  ),
                )
                .toList(),
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children
              .map(
                (c) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: c,
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        color: Colors.green.shade900,
      ),
    ),
  );

  InputDecoration get _inputDecoration => InputDecoration(
    filled: true,
    fillColor: Colors.white.withOpacity(0.5),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.white.withOpacity(0.6)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.white.withOpacity(0.6)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.green.shade700, width: 2),
    ),
  );

  Widget _champTexte(
    String label,
    TextEditingController controller, {
    bool required = false,
    int? maxLength,
    TextInputType? keyboardType,
    void Function(String)? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(label),
        TextFormField(
          controller: controller,
          maxLength: maxLength,
          keyboardType: keyboardType,
          onChanged: onChanged,
          decoration: _inputDecoration.copyWith(counterText: ''),
          style: const TextStyle(fontSize: 14),
          validator: required
              ? (v) => (v == null || v.isEmpty) ? 'Champ requis' : null
              : null,
        ),
      ],
    );
  }

  Widget _champDate(
    String label,
    TextEditingController controller,
    VoidCallback onTap,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(label),
        TextFormField(
          controller: controller,
          readOnly: true,
          onTap: onTap,
          decoration: _inputDecoration.copyWith(
            hintText: 'AAAA-MM-JJ',
            suffixIcon: const Icon(Icons.calendar_today, size: 16),
          ),
          style: const TextStyle(fontSize: 14),
          validator: (v) => (v == null || v.isEmpty) ? 'Champ requis' : null,
        ),
      ],
    );
  }

  Widget _dropdownTexte(
    String label,
    String value,
    List<String> options,
    void Function(String?) onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(label),
        DropdownButtonFormField<String>(
          initialValue: value,
          decoration: _inputDecoration,
          items: options
              .map((o) => DropdownMenuItem(value: o, child: Text(o)))
              .toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _dropdownRegion() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Région'),
        DropdownButtonFormField<Map<String, dynamic>>(
          initialValue: _selectedRegion,
          decoration: _inputDecoration,
          hint: const Text(
            '-- Choisir la région --',
            style: TextStyle(fontSize: 13),
          ),
          items: _regions
              .map(
                (r) => DropdownMenuItem(
                  value: r as Map<String, dynamic>,
                  child: Text(r['nom']),
                ),
              )
              .toList(),
          onChanged: _onRegionChanged,
          validator: (v) => v == null ? 'Champ requis' : null,
        ),
      ],
    );
  }

  Widget _dropdownDistrict() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('District de liaison'),
        DropdownButtonFormField<Map<String, dynamic>>(
          initialValue: _selectedDistrict,
          decoration: _inputDecoration,
          hint: const Text(
            '-- Sélectionner le district --',
            style: TextStyle(fontSize: 13),
          ),
          items: _districts
              .map(
                (d) => DropdownMenuItem(
                  value: d as Map<String, dynamic>,
                  child: Text(d['nom']),
                ),
              )
              .toList(),
          onChanged: _selectedRegion == null ? null : _onDistrictChanged,
          validator: (v) => v == null ? 'Champ requis' : null,
        ),
      ],
    );
  }

  Widget _buildStatutGps() {
    final trouve = _latitude != null && _longitude != null;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: trouve
            ? Colors.green.shade50.withOpacity(0.8)
            : Colors.orange.shade50.withOpacity(0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: trouve ? Colors.green.shade300 : Colors.orange.shade300,
        ),
      ),
      child: Row(
        children: [
          Icon(
            trouve ? Icons.check_circle : Icons.location_on,
            size: 18,
            color: trouve ? Colors.green.shade600 : Colors.orange.shade500,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              trouve
                  ? 'GPS actuel : ${_latitude!.toStringAsFixed(5)}, ${_longitude!.toStringAsFixed(5)}'
                  : 'La localisation GPS sera redétectée automatiquement si vous modifiez l\'adresse.',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: trouve ? Colors.green.shade800 : Colors.orange.shade800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
