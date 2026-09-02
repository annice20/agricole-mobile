import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;

import '../../core/api_client.dart';
import '../../widgets/app_layout.dart';
import '../../services/geo_service.dart';
import '../../services/agriculteur_service.dart';

class CarteAgricolePage extends StatefulWidget {
  const CarteAgricolePage({super.key});

  @override
  State<CarteAgricolePage> createState() => _CarteAgricolePageState();
}

class _CarteAgricolePageState extends State<CarteAgricolePage> {
  final _geoService = GeoService();
  final _agriculteurService = AgriculteurService();
  final _mapController = MapController();

  bool _loading = true;
  List<dynamic> _exploitations = [];
  List<dynamic> _statsRegions = [];
  List<dynamic> _sansGeo = [];
  int? _geocodageEnCoursId;

  String _filtre = 'tous'; // 'tous' | 'beneficiaires'
  String _recherche = '';
  List<dynamic> _suggestions = [];

  String _role = '';
  bool get _isAdmin => _role == 'ADMIN_NATIONAL';
  bool get _isAgent => _role == 'AGENT_TERRAIN';
  bool get _canGeolocaliser => _isAgent || _isAdmin;

  static const LatLng _centreMadagascar = LatLng(-18.9249, 47.5185);

  @override
  void initState() {
    super.initState();
    _initialiser();
  }

  Future<void> _initialiser() async {
    final session = await ApiClient().getSession();
    setState(() => _role = session?.role ?? '');
    await _chargerDonnees();
  }

  Future<void> _chargerDonnees() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _geoService.getExploitations(),
        _geoService.getStatistiquesRegion(),
        _agriculteurService.getAll(),
      ]);
      final exploitations = results[0];
      final stats = results[1];
      final tous = results[2];

      final localises = exploitations.map((e) => (e as Map)['id']).toSet();
      final sansGeo = tous
          .where((a) => !localises.contains((a as Map)['id']))
          .toList();

      setState(() {
        _exploitations = exploitations;
        _statsRegions = stats;
        _sansGeo = sansGeo;
      });
    } on ApiException catch (e) {
      _showSnack(
        'Impossible de charger les données cartographiques : ${e.message}',
        erreur: true,
      );
    } catch (_) {
      _showSnack(
        'Impossible de charger les données cartographiques',
        erreur: true,
      );
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

  Future<void> _localiserAutomatiquement(Map agriculteur) async {
    if (!_canGeolocaliser) {
      _showSnack(
        'Seuls les agents de terrain ou administrateurs peuvent géolocaliser un agriculteur.',
        erreur: true,
      );
      return;
    }

    setState(() => _geocodageEnCoursId = agriculteur['id'] as int);
    final adresse = agriculteur['adresse'] ?? '';
    final query = '$adresse, Madagascar';

    try {
      var coords = await _tenterGeocodage(query);

      if (coords == null) {
        _showSnack(
          'Adresse "$adresse" non trouvée, tentative avec Madagascar...',
        );
        coords = await _tenterGeocodage('Madagascar');
      }

      if (coords != null) {
        await _geoService.localiser(
          agriculteur['id'] as int,
          coords['latitude']!,
          coords['longitude']!,
        );
        _showSnack(
          '${agriculteur['nom']} ${agriculteur['prenom']} localisé automatiquement !',
        );
        await _chargerDonnees();
      } else {
        _showSnack(
          'Impossible de localiser ${agriculteur['nom']} — adresse introuvable sur OpenStreetMap.',
          erreur: true,
        );
      }
    } catch (_) {
      _showSnack(
        'Erreur lors de la géolocalisation automatique.',
        erreur: true,
      );
    } finally {
      setState(() => _geocodageEnCoursId = null);
    }
  }

  Future<Map<String, double>?> _tenterGeocodage(String query) async {
    final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
      'q': query,
      'format': 'json',
      'limit': '1',
      'countrycodes': 'mg',
    });
    final response = await http.get(uri);
    if (response.statusCode != 200) return null;
    final List results = jsonDecode(response.body);
    if (results.isEmpty) return null;
    final r = results.first;
    return {
      'latitude': double.parse(r['lat']),
      'longitude': double.parse(r['lon']),
    };
  }

  void _onRechercheChanged(String valeur) {
    setState(() => _recherche = valeur);
    if (valeur.trim().isEmpty) {
      setState(() => _suggestions = []);
      return;
    }
    final q = valeur.toLowerCase();
    final resultats = _exploitations.where((exp) {
      final m = exp as Map;
      return '${m['nom']} ${m['prenom']}'.toLowerCase().contains(q);
    }).toList();
    setState(() => _suggestions = resultats.take(6).toList());
  }

  void _allerVersAgriculteur(Map exp) {
    final lat = (exp['latitude'] as num).toDouble();
    final lng = (exp['longitude'] as num).toDouble();
    _mapController.move(LatLng(lat, lng), 14);
    setState(() {
      _recherche = '${exp['nom']} ${exp['prenom']}';
      _suggestions = [];
    });
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _afficherDetails(exp);
    });
  }

  List<dynamic> get _exploitationsFiltrees => _filtre == 'beneficiaires'
      ? _exploitations.where((e) => (e as Map)['actif'] == true).toList()
      : _exploitations;

  void _afficherDetails(Map exp) {
    final actif = exp['actif'] == true;
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${exp['nom']} ${exp['prenom']}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              if (exp['typeCulture'] != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    exp['typeCulture'].toString(),
                    style: TextStyle(
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              const SizedBox(height: 10),
              if (exp['adresse'] != null)
                Text(
                  exp['adresse'].toString(),
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              Text(
                '${exp['nomDistrict'] ?? '—'} — ${exp['nomRegion'] ?? '—'}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              if (exp['superficie'] != null)
                Text(
                  'Superficie : ${exp['superficie']} Ha',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              Text(
                'GPS : ${(exp['latitude'] as num).toStringAsFixed(4)}, '
                '${(exp['longitude'] as num).toStringAsFixed(4)}',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: actif ? Colors.green.shade100 : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  actif ? 'Bénéficiaire' : 'Non bénéficiaire',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: actif ? Colors.green.shade800 : Colors.grey.shade700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppLayout(
      currentRoute: '/carte',
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _chargerDonnees,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 16),
                    _buildKpis(),
                    const SizedBox(height: 16),
                    _buildCarteCard(),
                    const SizedBox(height: 16),
                    _buildALocaliser(),
                    const SizedBox(height: 16),
                    _buildStatsRegions(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Cartographie Agricole',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: Colors.green.shade900,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Localisation GPS automatique des exploitations via OpenStreetMap.',
          style: TextStyle(
            fontSize: 12,
            color: Colors.green.shade800.withOpacity(0.75),
          ),
        ),
      ],
    );
  }

  Widget _buildKpis() {
    final regionsCouvertes = _statsRegions
        .where((r) => (r as Map)['totalLocalises'] > 0)
        .length;

    final kpis = [
      ('Total localisés', '${_exploitations.length}'),
      (
        'Bénéficiaires',
        '${_exploitations.where((e) => (e as Map)['actif'] == true).length}',
      ),
      ('Non localisés', '${_sansGeo.length}'),
      ('Régions couvertes', '$regionsCouvertes / ${_statsRegions.length}'),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.7,
      children: kpis
          .map(
            (kpi) => Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    kpi.$1.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    kpi.$2,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Colors.green.shade900,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildCarteCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.4)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(Icons.map, size: 18, color: Colors.green.shade900),
                const SizedBox(width: 6),
                Text(
                  'Carte des exploitations',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Colors.green.shade900,
                  ),
                ),
                const Spacer(),
                _filtreChip('Tous', 'tous'),
                const SizedBox(width: 6),
                _filtreChip('Bénéficiaires', 'beneficiaires'),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: TextField(
              onChanged: _onRechercheChanged,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _recherche.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close, size: 16),
                        onPressed: () {
                          setState(() {
                            _recherche = '';
                            _suggestions = [];
                          });
                        },
                      )
                    : null,
                hintText: 'Rechercher un agriculteur par nom...',
                hintStyle: const TextStyle(fontSize: 13),
                filled: true,
                fillColor: Colors.white.withOpacity(0.7),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          if (_suggestions.isNotEmpty)
            Container(
              margin: const EdgeInsets.fromLTRB(12, 4, 12, 0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Column(
                children: _suggestions.map((exp) {
                  final m = exp as Map;
                  return ListTile(
                    dense: true,
                    leading: Icon(
                      Icons.my_location,
                      size: 16,
                      color: Colors.green.shade700,
                    ),
                    title: Text(
                      '${m['nom']} ${m['prenom']}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      '${m['nomDistrict'] ?? ''} — ${m['nomRegion'] ?? ''}',
                      style: const TextStyle(fontSize: 11),
                    ),
                    onTap: () => _allerVersAgriculteur(m),
                  );
                }).toList(),
              ),
            )
          else if (_recherche.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'Aucun agriculteur localisé trouvé pour "$_recherche"',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.green.shade700.withOpacity(0.6),
                ),
                textAlign: TextAlign.center,
              ),
            ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              height: 380,
              child: FlutterMap(
                mapController: _mapController,
                options: const MapOptions(
                  initialCenter: _centreMadagascar,
                  initialZoom: 6,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                    subdomains: const ['a', 'b', 'c'],
                    userAgentPackageName: 'com.agroplateforme.app',
                  ),
                  MarkerLayer(
                    markers: _exploitationsFiltrees.map((exp) {
                      final m = exp as Map;
                      final lat = (m['latitude'] as num).toDouble();
                      final lng = (m['longitude'] as num).toDouble();
                      final actif = m['actif'] == true;
                      return Marker(
                        point: LatLng(lat, lng),
                        width: 36,
                        height: 36,
                        child: GestureDetector(
                          onTap: () => _afficherDetails(m),
                          child: Icon(
                            Icons.location_on,
                            size: 34,
                            color: actif ? Colors.green.shade700 : Colors.grey,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                _legende(Colors.green.shade700, 'Bénéficiaire actif'),
                const SizedBox(width: 16),
                _legende(Colors.grey, 'Non bénéficiaire'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _filtreChip(String label, String value) {
    final selected = _filtre == value;
    return GestureDetector(
      onTap: () => setState(() => _filtre = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? Colors.green.shade700
              : Colors.white.withOpacity(0.6),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: selected ? Colors.white : Colors.green.shade800,
          ),
        ),
      ),
    );
  }

  Widget _legende(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.green.shade800,
          ),
        ),
      ],
    );
  }

  Widget _buildALocaliser() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.location_off, size: 16, color: Colors.orange),
              const SizedBox(width: 6),
              Text(
                'À localiser (${_sansGeo.length})',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Colors.green.shade900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_sansGeo.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  'Tous les agriculteurs sont localisés',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.green.shade700.withOpacity(0.6),
                  ),
                ),
              ),
            )
          else
            ..._sansGeo.map((ag) {
              final m = ag as Map;
              final enCours = _geocodageEnCoursId == m['id'];
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.4)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${m['nom']} ${m['prenom']}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            m['adresse'] ?? 'Adresse non renseignée',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.grey,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    if (_canGeolocaliser)
                      ElevatedButton.icon(
                        onPressed: enCours
                            ? null
                            : () => _localiserAutomatiquement(m),
                        icon: enCours
                            ? const SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.refresh, size: 14),
                        label: Text(
                          enCours ? '...' : 'GPS auto',
                          style: const TextStyle(fontSize: 11),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildStatsRegions() {
    final stats = _statsRegions.where((r) => (r as Map)['total'] > 0).toList();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.pie_chart, size: 16, color: Colors.green.shade900),
              const SizedBox(width: 6),
              Text(
                'Analyse par région',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Colors.green.shade900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...stats.map((region) {
            final m = region as Map;
            final total = (m['total'] as num).toDouble();
            final actifs = (m['totalActifs'] as num).toDouble();
            final ratio = total > 0 ? actifs / total : 0.0;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          m['nomRegion']?.toString() ?? '—',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '${m['totalActifs']} bénéf.',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: ratio,
                      minHeight: 5,
                      backgroundColor: Colors.green.shade900.withOpacity(0.08),
                      valueColor: AlwaysStoppedAnimation(Colors.green.shade700),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${m['total']} inscrits',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.grey,
                        ),
                      ),
                      Text(
                        '${m['totalLocalises']} localisés',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.grey,
                        ),
                      ),
                      Text(
                        '${(m['superficieTotale'] as num?)?.toStringAsFixed(1) ?? '0.0'} Ha',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
