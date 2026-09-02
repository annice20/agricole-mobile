import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../widgets/app_layout.dart';
import '../../services/utilisateur_service.dart';
import '../../services/location_service.dart';

class CreerUtilisateurPage extends StatefulWidget {
  const CreerUtilisateurPage({super.key});

  @override
  State<CreerUtilisateurPage> createState() => _CreerUtilisateurPageState();
}

class _CreerUtilisateurPageState extends State<CreerUtilisateurPage> {
  final _formKey = GlobalKey<FormState>();
  final _utilisateurService = UtilisateurService();
  final _locationService = LocationService();

  final _nomCtrl = TextEditingController();
  final _prenomCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _telephoneCtrl = TextEditingController();
  final _motDePasseCtrl = TextEditingController();

  static const _rolesDisponibles = [
    {'value': 'ADMIN_NATIONAL', 'label': 'Administrateur National'},
    {'value': 'RESPONSABLE_REGIONAL', 'label': 'Responsable Régional'},
    {'value': 'AGENT_TERRAIN', 'label': 'Agent de Terrain'},
  ];

  String? _roleSelectionne;
  int? _regionId;
  List<dynamic> _regions = [];

  bool _verificationSession = true;
  bool _enregistrement = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _nomCtrl.dispose();
    _prenomCtrl.dispose();
    _emailCtrl.dispose();
    _telephoneCtrl.dispose();
    _motDePasseCtrl.dispose();
    super.dispose();
  }

  void _showSnack(String message, {bool erreur = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: erreur ? Colors.red.shade600 : Colors.green.shade700,
      ),
    );
  }

  Future<void> _init() async {
    final session = await ApiClient().getSession();
    if (session == null || session.role != 'ADMIN_NATIONAL') {
      _showSnack('Accès réservé aux administrateurs nationaux.', erreur: true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pushReplacementNamed(context, '/');
      });
      return;
    }
    setState(() => _verificationSession = false);
    await _chargerRegions();
  }

  Future<void> _chargerRegions() async {
    try {
      final data = await _locationService.getRegions();
      setState(() => _regions = data);
    } catch (_) {
      _showSnack('Impossible de charger les régions', erreur: true);
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_roleSelectionne == null) {
      _showSnack('Veuillez sélectionner un rôle', erreur: true);
      return;
    }
    if (_roleSelectionne == 'RESPONSABLE_REGIONAL' && _regionId == null) {
      _showSnack('Veuillez sélectionner la région gérée', erreur: true);
      return;
    }

    setState(() => _enregistrement = true);
    try {
      final result = await _utilisateurService.creerUtilisateur({
        'nom': _nomCtrl.text,
        'prenom': _prenomCtrl.text,
        'email': _emailCtrl.text,
        'telephone': _telephoneCtrl.text,
        'motDePasse': _motDePasseCtrl.text,
        'roleName': _roleSelectionne,
        'regionId': _roleSelectionne == 'RESPONSABLE_REGIONAL'
            ? _regionId
            : null,
      });
      _showSnack('Compte créé pour ${result['prenom']} ${result['nom']}');
      _formKey.currentState!.reset();
      _nomCtrl.clear();
      _prenomCtrl.clear();
      _emailCtrl.clear();
      _telephoneCtrl.clear();
      _motDePasseCtrl.clear();
      setState(() {
        _roleSelectionne = null;
        _regionId = null;
      });
    } on ApiException catch (e) {
      _showSnack(e.message, erreur: true);
    } catch (_) {
      _showSnack('Impossible de créer le compte', erreur: true);
    } finally {
      if (mounted) setState(() => _enregistrement = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_verificationSession) {
      return AppLayout(
        currentRoute: '/creer-utilisateur',
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    return AppLayout(
      currentRoute: '/creer-utilisateur',
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Créer un Compte Utilisateur',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Colors.green.shade900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Réservé aux comptes internes : administrateurs, responsables régionaux et agents de terrain.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green.shade800.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.4)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _nomCtrl,
                                decoration: _decoration('Nom'),
                                validator: (v) =>
                                    (v == null || v.isEmpty) ? 'Requis' : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _prenomCtrl,
                                decoration: _decoration('Prénom'),
                                validator: (v) =>
                                    (v == null || v.isEmpty) ? 'Requis' : null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          decoration: _decoration('Email'),
                          validator: (v) => (v == null || !v.contains('@'))
                              ? 'Email invalide'
                              : null,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _telephoneCtrl,
                          keyboardType: TextInputType.phone,
                          decoration: _decoration('Téléphone'),
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _motDePasseCtrl,
                          obscureText: true,
                          decoration: _decoration('Mot de passe provisoire'),
                          validator: (v) => (v == null || v.length < 6)
                              ? 'Au moins 6 caractères'
                              : null,
                        ),
                        const SizedBox(height: 14),
                        DropdownButtonFormField<String>(
                          initialValue: _roleSelectionne,
                          decoration: _decoration('Rôle'),
                          items: _rolesDisponibles
                              .map(
                                (r) => DropdownMenuItem(
                                  value: r['value'],
                                  child: Text(r['label']!),
                                ),
                              )
                              .toList(),
                          onChanged: (v) {
                            setState(() {
                              _roleSelectionne = v;
                              if (v != 'RESPONSABLE_REGIONAL') {
                                _regionId = null;
                              }
                            });
                          },
                        ),
                        if (_roleSelectionne == 'RESPONSABLE_REGIONAL') ...[
                          const SizedBox(height: 14),
                          DropdownButtonFormField<int>(
                            initialValue: _regionId,
                            decoration: _decoration('Région gérée'),
                            items: _regions
                                .map(
                                  (r) => DropdownMenuItem<int>(
                                    value: r['id'] as int,
                                    child: Text(r['nom'].toString()),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) => setState(() => _regionId = v),
                          ),
                        ],
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: _enregistrement ? null : _handleSubmit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            _enregistrement
                                ? 'Création du compte...'
                                : 'Créer le compte',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _decoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.green.shade200),
      ),
    );
  }
}
