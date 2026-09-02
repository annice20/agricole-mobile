import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../widgets/app_layout.dart';
import '../../services/agriculteur_service.dart';

class ListeAgriculteursPage extends StatefulWidget {
  const ListeAgriculteursPage({super.key});

  @override
  State<ListeAgriculteursPage> createState() => _ListeAgriculteursPageState();
}

class _ListeAgriculteursPageState extends State<ListeAgriculteursPage> {
  final _agriculteurService = AgriculteurService();

  bool _loading = true;
  List<dynamic> _agriculteurs = [];
  String _search = '';
  String _filterCulture = '';
  String? _filterActif; // null = tous, "true"/"false"
  int? _confirmDeleteId;

  String _role = '';
  int? _regionId;
  String? _regionNom;

  bool get _isAdmin => _role == 'ADMIN_NATIONAL';
  bool get _isResponsable => _role == 'RESPONSABLE_REGIONAL';
  bool get _isAgent => _role == 'AGENT_TERRAIN';

  bool get _canModify => _isAgent || _isAdmin;
  bool get _canActivate => _isAgent || _isAdmin || _isResponsable;
  bool get _canDelete => _isAdmin;

  @override
  void initState() {
    super.initState();
    _initialiser();
  }

  Future<void> _initialiser() async {
    final session = await ApiClient().getSession();
    setState(() {
      _role = session?.role ?? '';
      _regionId = session?.regionId;
      _regionNom = session?.regionNom;
    });
    await _chargerAgriculteurs();
  }

  Future<void> _chargerAgriculteurs() async {
    setState(() => _loading = true);
    try {
      // Vue régionale : le responsable régional ne voit que sa région
      final data = (_isResponsable && _regionId != null)
          ? await _agriculteurService.getByRegion(_regionId!)
          : await _agriculteurService.getAll();
      setState(() => _agriculteurs = data);
    } on ApiException catch (e) {
      _showSnack(
        'Impossible de charger les agriculteurs : ${e.message}',
        erreur: true,
      );
    } catch (_) {
      _showSnack('Impossible de charger les agriculteurs', erreur: true);
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

  String _str(dynamic val) {
    if (val == null) return '—';
    if (val is Map) {
      return (val['nom'] ?? val['libelle'] ?? val['name'] ?? '—').toString();
    }
    return val.toString();
  }

  String _nomComplet(Map a) => '${_str(a['prenom'])} ${_str(a['nom'])}'.trim();

  String _regionNomAgriculteur(Map a) {
    final district = a['district'];
    if (district is Map && district['region'] is Map) {
      return _str(district['region']);
    }
    return '—';
  }

  String _districtNom(Map a) {
    final district = a['district'];
    if (district is Map) return _str(district);
    return '—';
  }

  List<String> get _cultures {
    final set = <String>{};
    for (final a in _agriculteurs) {
      final c = (a as Map)['typeCulture'];
      if (c != null && c.toString().isNotEmpty) set.add(c.toString());
    }
    final list = set.toList()..sort();
    return list;
  }

  List<dynamic> get _filtered {
    final q = _search.toLowerCase();
    return _agriculteurs.where((a) {
      final map = a as Map;
      final matchTexte =
          q.isEmpty ||
          _nomComplet(map).toLowerCase().contains(q) ||
          _regionNomAgriculteur(map).toLowerCase().contains(q) ||
          _districtNom(map).toLowerCase().contains(q);
      final matchCulture =
          _filterCulture.isEmpty || map['typeCulture'] == _filterCulture;
      final matchActif =
          _filterActif == null ||
          (map['actif'] == true) == (_filterActif == 'true');
      return matchTexte && matchCulture && matchActif;
    }).toList();
  }

  double get _surfaceTotale {
    double total = 0;
    for (final a in _agriculteurs) {
      final s = (a as Map)['superficie'];
      if (s is num) total += s.toDouble();
    }
    return total;
  }

  int get _nbRegions {
    final set = <String>{};
    for (final a in _agriculteurs) {
      final r = _regionNomAgriculteur(a as Map);
      if (r != '—') set.add(r);
    }
    return set.length;
  }

  Future<void> _toggleActif(Map a) async {
    if (!_canActivate) {
      _showSnack(
        'Seuls les agents de terrain, les administrateurs ou responsables régionaux peuvent activer un compte',
        erreur: true,
      );
      return;
    }
    final actif = a['actif'] == true;
    try {
      await _agriculteurService.changerActivation(
        a['id'] as int,
        actif ? 'EN_ATTENTE' : 'ACTIF',
      );
      _showSnack(
        !actif
            ? "Compte activé ! Un e-mail de confirmation a été envoyé à l'agriculteur."
            : 'Compte désactivé avec succès.',
      );
      setState(() {
        final index = _agriculteurs.indexWhere((x) => x['id'] == a['id']);
        if (index != -1) {
          _agriculteurs[index] = {...a, 'actif': !actif};
        }
      });
    } on ApiException catch (e) {
      _showSnack(
        'Impossible de modifier le statut : ${e.message}',
        erreur: true,
      );
    } catch (_) {
      _showSnack('Impossible de modifier le statut', erreur: true);
    }
  }

  Future<void> _supprimer(int id) async {
    if (!_canDelete) {
      _showSnack('Action non autorisée pour votre rôle', erreur: true);
      return;
    }
    try {
      await _agriculteurService.delete(id);
      _showSnack('Agriculteur supprimé');
      setState(() {
        _agriculteurs.removeWhere((a) => a['id'] == id);
        _confirmDeleteId = null;
      });
    } on ApiException catch (e) {
      _showSnack(
        "Impossible de supprimer l'agriculteur : ${e.message}",
        erreur: true,
      );
    } catch (_) {
      _showSnack("Impossible de supprimer l'agriculteur", erreur: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppLayout(
      currentRoute: '/agriculteurs',
      child: RefreshIndicator(
        onRefresh: _chargerAgriculteurs,
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
              _buildFiltres(),
              const SizedBox(height: 16),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 60),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_filtered.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 48),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.4)),
                  ),
                  child: Center(
                    child: Text(
                      'Aucun agriculteur trouvé.',
                      style: TextStyle(
                        color: Colors.green.shade800.withOpacity(0.6),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                )
              else
                Column(
                  children: _filtered.map((a) => _buildCard(a as Map)).toList(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Agriculteurs',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: Colors.green.shade900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _isResponsable
                    ? 'Agriculteurs enregistrés dans votre région${_regionNom != null ? " ($_regionNom)" : ""}.'
                    : 'Gestion des agriculteurs enregistrés sur la plateforme.',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.green.shade800.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
        if (_canModify)
          ElevatedButton.icon(
            onPressed: () async {
              await Navigator.pushNamed(context, '/agriculteurs/ajouter');
              _chargerAgriculteurs();
            },
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Nouveau'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildKpis() {
    final kpis = [
      ('Total inscrits', '${_agriculteurs.length}'),
      (
        'Producteurs actifs',
        '${_agriculteurs.where((a) => (a as Map)['actif'] == true).length}',
      ),
      ('Surface totale', '${_surfaceTotale.toStringAsFixed(2)} ha'),
      ('Régions couvertes', '$_nbRegions'),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.6,
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
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    kpi.$2,
                    style: TextStyle(
                      fontSize: 22,
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

  Widget _buildFiltres() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.4)),
      ),
      child: Column(
        children: [
          TextField(
            onChanged: (v) => setState(() => _search = v),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search, size: 20),
              hintText: 'Rechercher par nom, région, district...',
              hintStyle: const TextStyle(fontSize: 13),
              filled: true,
              fillColor: Colors.white.withOpacity(0.6),
              contentPadding: const EdgeInsets.symmetric(
                vertical: 0,
                horizontal: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _filterCulture.isEmpty ? null : _filterCulture,
                  decoration: _dropdownDecoration(),
                  hint: const Text(
                    'Toutes les cultures',
                    style: TextStyle(fontSize: 12),
                  ),
                  items: _cultures
                      .map(
                        (c) => DropdownMenuItem(
                          value: c,
                          child: Text(c, style: const TextStyle(fontSize: 13)),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _filterCulture = v ?? ''),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _filterActif,
                  decoration: _dropdownDecoration(),
                  hint: const Text(
                    'Tous les statuts',
                    style: TextStyle(fontSize: 12),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'true',
                      child: Text('Actif', style: TextStyle(fontSize: 13)),
                    ),
                    DropdownMenuItem(
                      value: 'false',
                      child: Text('Inactif', style: TextStyle(fontSize: 13)),
                    ),
                  ],
                  onChanged: (v) => setState(() => _filterActif = v),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  InputDecoration _dropdownDecoration() => InputDecoration(
    filled: true,
    fillColor: Colors.white.withOpacity(0.6),
    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
  );

  Widget _buildCard(Map a) {
    final actif = a['actif'] == true;
    final isConfirmingDelete = _confirmDeleteId == a['id'];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _nomComplet(a),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade900,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _str(a['telephone']),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green.shade800.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: actif ? Colors.green.shade200 : Colors.red.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  actif ? 'Actif' : 'Inactif',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: actif ? Colors.green.shade900 : Colors.red.shade800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              if (a['typeCulture'] != null)
                _chip(a['typeCulture'].toString(), Colors.green),
              _chip(
                '${_regionNomAgriculteur(a)} / ${_districtNom(a)}',
                Colors.blueGrey,
              ),
              if (a['superficie'] != null)
                _chip('${a['superficie']} ha', Colors.brown),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 4,
            children: [
              IconButton(
                tooltip: 'Suivre les aides distribuées',
                onPressed: () => Navigator.pushNamed(
                  context,
                  Uri(
                    path: '/mes-aides',
                    queryParameters: {
                      'agriculteurId': a['id'].toString(),
                      'agriNom': _nomComplet(a),
                    },
                  ).toString(),
                ),
                icon: Icon(
                  Icons.card_giftcard,
                  size: 20,
                  color: Colors.green.shade700,
                ),
              ),
              if (_canActivate)
                IconButton(
                  tooltip: actif
                      ? 'Désactiver le compte'
                      : 'Activer et valider le compte',
                  onPressed: () => _toggleActif(a),
                  icon: Icon(
                    Icons.toggle_on,
                    size: 22,
                    color: actif ? Colors.green.shade700 : Colors.grey.shade400,
                  ),
                ),
              if (_canModify)
                IconButton(
                  tooltip: 'Modifier les informations',
                  onPressed: () async {
                    await Navigator.pushNamed(
                      context,
                      '/agriculteurs/modifier',
                      arguments: {"id": a['id']},
                    );
                    _chargerAgriculteurs();
                  },
                  icon: const Icon(Icons.edit),
                ),
              if (_canDelete)
                isConfirmingDelete
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextButton(
                            onPressed: () => _supprimer(a['id'] as int),
                            style: TextButton.styleFrom(
                              backgroundColor: Colors.red.shade600,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(0, 30),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                            ),
                            child: const Text(
                              'Oui',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                          const SizedBox(width: 4),
                          TextButton(
                            onPressed: () =>
                                setState(() => _confirmDeleteId = null),
                            style: TextButton.styleFrom(
                              backgroundColor: Colors.grey.shade300,
                              minimumSize: const Size(0, 30),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                            ),
                            child: const Text(
                              'Non',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      )
                    : IconButton(
                        tooltip: 'Supprimer définitivement',
                        onPressed: () =>
                            setState(() => _confirmDeleteId = a['id'] as int),
                        icon: const Icon(
                          Icons.delete,
                          size: 18,
                          color: Colors.red,
                        ),
                      ),
              IconButton(
                tooltip: "Demandes d'aide (Collecte)",
                onPressed: () => Navigator.pushNamed(
                  context,
                  Uri(
                    path: '/demandes',
                    queryParameters: {
                      'agriculteurId': a['id'].toString(),
                      'agriNom': _nomComplet(a),
                    },
                  ).toString(),
                ),
                icon: const Icon(
                  Icons.description,
                  size: 18,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.shade200),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color.shade800,
        ),
      ),
    );
  }
}
