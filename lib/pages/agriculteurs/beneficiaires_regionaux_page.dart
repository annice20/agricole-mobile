import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../widgets/app_layout.dart';
import '../../services/agriculteur_service.dart';
import '../../services/location_service.dart';

class BeneficiairesRegionauxPage extends StatefulWidget {
  const BeneficiairesRegionauxPage({super.key});

  @override
  State<BeneficiairesRegionauxPage> createState() =>
      _BeneficiairesRegionauxPageState();
}

class _BeneficiairesRegionauxPageState
    extends State<BeneficiairesRegionauxPage> {
  final _agriculteurService = AgriculteurService();
  final _locationService = LocationService();

  List<dynamic> _regions = [];
  Map<String, dynamic>? _selectedRegion;
  List<dynamic> _beneficiaires = [];
  String _search = '';
  bool _loading = false;

  Session? _session;
  bool get _isResponsable => _session?.role == 'RESPONSABLE_REGIONAL';

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final session = await ApiClient().getSession();
    setState(() => _session = session);
    await _chargerRegions();

    // Pour un responsable régional : verrouille automatiquement sur sa
    // propre région dès le chargement, sans passer par le sélecteur.
    if (_isResponsable && session?.regionId != null) {
      final regionUtilisateur = _regions.firstWhere(
        (r) => r['id'] == session!.regionId,
        orElse: () => null,
      );
      if (regionUtilisateur != null) {
        await _chargerBeneficiaires(regionUtilisateur as Map<String, dynamic>);
      }
    }
  }

  Future<void> _chargerRegions() async {
    try {
      final regions = await _locationService.getRegions();
      setState(() => _regions = regions);
    } on ApiException catch (e) {
      _showSnack(
        'Erreur lors du chargement des régions : ${e.message}',
        erreur: true,
      );
    } catch (_) {
      _showSnack('Erreur lors du chargement des régions', erreur: true);
    }
  }

  Future<void> _chargerBeneficiaires(Map<String, dynamic>? region) async {
    setState(() => _selectedRegion = region);
    if (region == null) {
      setState(() => _beneficiaires = []);
      return;
    }
    setState(() => _loading = true);
    try {
      final data = await _agriculteurService.getBeneficiairesParRegion(
        region['id'] as int,
      );
      setState(() => _beneficiaires = data);
    } on ApiException catch (e) {
      _showSnack(
        'Erreur lors du chargement des bénéficiaires : ${e.message}',
        erreur: true,
      );
    } catch (_) {
      _showSnack('Erreur lors du chargement des bénéficiaires', erreur: true);
    } finally {
      setState(() => _loading = false);
    }
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

  List<dynamic> get _beneficiairesFiltres {
    final q = _search.toLowerCase();
    if (q.isEmpty) return _beneficiaires;
    return _beneficiaires.where((b) {
      final m = b as Map;
      final nom = (m['nom'] ?? '').toString().toLowerCase();
      final prenom = (m['prenom'] ?? '').toString().toLowerCase();
      final telephone = (m['telephone'] ?? '').toString().toLowerCase();
      return nom.contains(q) || prenom.contains(q) || telephone.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return AppLayout(
      currentRoute: '/beneficiaires-regionaux',
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(),
            const SizedBox(height: 16),
            _buildKpis(),
            const SizedBox(height: 16),
            _buildFiltres(),
            const SizedBox(height: 16),
            _buildListe(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Bénéficiaires Régionaux',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: Colors.green.shade900,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          _isResponsable
              ? 'Consultation des agriculteurs de votre région ayant reçu une aide.'
              : 'Consultation des agriculteurs ayant reçu une aide par région.',
          style: TextStyle(fontSize: 12, color: Colors.green.shade700),
        ),
      ],
    );
  }

  Widget _buildKpis() {
    final kpis = [
      (Icons.people, 'Bénéficiaires', '${_beneficiaires.length}'),
      (
        Icons.location_on,
        _isResponsable ? 'Région' : 'Région sélectionnée',
        _selectedRegion?['nom']?.toString() ?? '-',
      ),
      (Icons.search, 'Résultats filtrés', '${_beneficiairesFiltres.length}'),
    ];

    return Column(
      children: kpis
          .map(
            (kpi) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.6),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.4)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          kpi.$2.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                            color: Colors.green.shade700.withOpacity(0.8),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          kpi.$3,
                          style: TextStyle(
                            fontSize: kpi.$1 == Icons.location_on ? 18 : 26,
                            fontWeight: FontWeight.w900,
                            color: Colors.green.shade900,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(kpi.$1, color: Colors.green.shade700),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildFiltres() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.4)),
      ),
      child: Column(
        children: [
          // Le sélecteur de région n'est visible que pour l'admin national.
          // Un responsable régional est verrouillé sur sa propre région.
          if (_isResponsable)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.location_on,
                    size: 16,
                    color: Colors.green.shade700,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _selectedRegion?['nom']?.toString() ??
                        _session?.regionNom ??
                        'Votre région',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade900,
                    ),
                  ),
                ],
              ),
            )
          else
            DropdownButtonFormField<Map<String, dynamic>>(
              initialValue: _selectedRegion,
              decoration: _inputDecoration(),
              hint: const Text(
                'Sélectionner une région',
                style: TextStyle(fontSize: 13),
              ),
              items: _regions
                  .map(
                    (r) => DropdownMenuItem(
                      value: r as Map<String, dynamic>,
                      child: Text(r['nom'].toString()),
                    ),
                  )
                  .toList(),
              onChanged: _chargerBeneficiaires,
            ),
          const SizedBox(height: 10),
          TextField(
            onChanged: (v) => setState(() => _search = v),
            decoration: _inputDecoration().copyWith(
              prefixIcon: const Icon(Icons.search, size: 20),
              hintText: 'Rechercher un agriculteur...',
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration() => InputDecoration(
    filled: true,
    fillColor: Colors.white,
    hintStyle: const TextStyle(fontSize: 13),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.green.shade200),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.green.shade200),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.green.shade500, width: 2),
    ),
  );

  Widget _buildListe() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_selectedRegion == null) {
      return _emptyState(
        'Sélectionnez une région pour afficher les bénéficiaires.',
      );
    }

    if (_beneficiairesFiltres.isEmpty) {
      return _emptyState('Aucun bénéficiaire trouvé.');
    }

    return Column(
      children: _beneficiairesFiltres.map((b) => _buildCard(b as Map)).toList(),
    );
  }

  Widget _emptyState(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.4)),
      ),
      child: Center(
        child: Text(
          message,
          style: TextStyle(
            color: Colors.green.shade700,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildCard(Map b) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.person, size: 16, color: Colors.green.shade700),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${b['nom'] ?? ''} ${b['prenom'] ?? ''}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade900,
                    fontSize: 15,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.green.shade200.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.green.shade300.withOpacity(0.3),
                  ),
                ),
                child: Text(
                  b['typeCulture']?.toString() ?? 'Non spécifiée',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (b['telephone'] != null)
            Row(
              children: [
                Icon(Icons.phone, size: 14, color: Colors.green.shade600),
                const SizedBox(width: 6),
                Text(
                  b['telephone'].toString(),
                  style: TextStyle(fontSize: 12, color: Colors.green.shade900),
                ),
              ],
            ),
          if (b['adresse'] != null) ...[
            const SizedBox(height: 4),
            Text(
              b['adresse'].toString(),
              style: TextStyle(
                fontSize: 12,
                color: Colors.green.shade800.withOpacity(0.9),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
