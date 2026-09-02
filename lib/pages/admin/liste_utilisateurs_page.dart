import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../widgets/app_layout.dart';
import '../../services/utilisateur_service.dart';
import '../../services/location_service.dart';

class ListeUtilisateursPage extends StatefulWidget {
  const ListeUtilisateursPage({super.key});

  @override
  State<ListeUtilisateursPage> createState() => _ListeUtilisateursPageState();
}

class _ListeUtilisateursPageState extends State<ListeUtilisateursPage> {
  final _utilisateurService = UtilisateurService();
  final _locationService = LocationService();

  bool _verificationSession = true;
  bool _loading = true;
  List<dynamic> _utilisateurs = [];
  List<dynamic> _regions = [];
  String _search = '';
  String? _filterRole;

  Session? _session;

  static const _rolesDisponibles = [
    {'value': 'ADMIN_NATIONAL', 'label': 'Administrateur National'},
    {'value': 'RESPONSABLE_REGIONAL', 'label': 'Responsable Régional'},
    {'value': 'AGENT_TERRAIN', 'label': 'Agent de Terrain'},
  ];

  // Sélection de rôle en attente d'une région avant confirmation
  final Map<int, Map<String, dynamic>> _roleEnAttente = {};

  @override
  void initState() {
    super.initState();
    _init();
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
    setState(() {
      _session = session;
      _verificationSession = false;
    });
    await Future.wait([_fetchUtilisateurs(), _chargerRegions()]);
  }

  Future<void> _fetchUtilisateurs() async {
    setState(() => _loading = true);
    try {
      final data = await _utilisateurService.getUtilisateurs();
      setState(() => _utilisateurs = data);
    } catch (_) {
      _showSnack('Impossible de charger les utilisateurs', erreur: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _chargerRegions() async {
    try {
      final data = await _locationService.getRegions();
      setState(() => _regions = data);
    } catch (_) {
      _showSnack('Impossible de charger les régions', erreur: true);
    }
  }

  String _getRoleName(Map u) {
    final roles = u['roles'] as List<dynamic>?;
    if (roles != null && roles.isNotEmpty) {
      return roles[0]['nom']?.toString() ?? '';
    }
    return u['roleName']?.toString() ?? '';
  }

  void _handleSelectRole(Map u, String nouveauRole) {
    final id = u['id'] as int;
    if (nouveauRole == _getRoleName(u)) return;
    if (id == _session?.id) {
      _showSnack(
        'Vous ne pouvez pas modifier votre propre rôle.',
        erreur: true,
      );
      return;
    }

    if (nouveauRole == 'RESPONSABLE_REGIONAL') {
      final regionGeree = u['regionGeree'];
      setState(() {
        _roleEnAttente[id] = {
          'roleName': nouveauRole,
          'regionId': regionGeree != null ? regionGeree['id'] : null,
        };
      });
      return;
    }

    _appliquerChangementRole(u, nouveauRole, null);
  }

  Future<void> _appliquerChangementRole(
    Map u,
    String nouveauRole,
    int? regionId,
  ) async {
    final id = u['id'] as int;
    try {
      await _utilisateurService.changerRoleUtilisateur(
        id,
        nouveauRole,
        regionId: regionId,
      );
      _showSnack('Rôle mis à jour avec succès');
      await _fetchUtilisateurs();
      setState(() => _roleEnAttente.remove(id));
    } on ApiException catch (e) {
      _showSnack(e.message, erreur: true);
    } catch (_) {
      _showSnack('Impossible de modifier le rôle', erreur: true);
    }
  }

  void _confirmerRegion(Map u) {
    final id = u['id'] as int;
    final attente = _roleEnAttente[id];
    if (attente == null || attente['regionId'] == null) {
      _showSnack('Veuillez sélectionner une région', erreur: true);
      return;
    }
    _appliquerChangementRole(u, attente['roleName'], attente['regionId']);
  }

  Future<void> _supprimer(int id) async {
    if (id == _session?.id) {
      _showSnack(
        'Vous ne pouvez pas supprimer votre propre compte.',
        erreur: true,
      );
      return;
    }
    final confirme = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer cet utilisateur ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirme != true) return;

    try {
      await _utilisateurService.supprimerUtilisateur(id);
      _showSnack('Utilisateur supprimé');
      await _fetchUtilisateurs();
    } catch (_) {
      _showSnack('Impossible de supprimer cet utilisateur', erreur: true);
    }
  }

  String _nomComplet(Map u) => '${u['prenom'] ?? ''} ${u['nom'] ?? ''}'.trim();

  List<dynamic> get _filtered {
    final q = _search.toLowerCase();
    return _utilisateurs.where((u) {
      final map = u as Map;
      final matchSearch =
          q.isEmpty ||
          _nomComplet(map).toLowerCase().contains(q) ||
          (map['email']?.toString().toLowerCase() ?? '').contains(q);
      final matchRole = _filterRole == null || _getRoleName(map) == _filterRole;
      return matchSearch && matchRole;
    }).toList();
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
      child: RefreshIndicator(
        onRefresh: _fetchUtilisateurs,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Utilisateurs',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: Colors.green.shade900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Gestion des comptes internes.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.green.shade800.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () async {
                      await Navigator.pushNamed(
                        context,
                        '/creer-utilisateur/nouveau',
                      );
                      _fetchUtilisateurs();
                    },
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Nouveau'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                onChanged: (v) => setState(() => _search = v),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search, size: 20),
                  hintText: 'Rechercher par nom ou email...',
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.6),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
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
                  ),
                  child: Center(
                    child: Text(
                      'Aucun utilisateur trouvé.',
                      style: TextStyle(
                        color: Colors.green.shade800.withOpacity(0.6),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                )
              else
                Column(
                  children: _filtered.map((u) => _buildCard(u as Map)).toList(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCard(Map u) {
    final id = u['id'] as int;
    final roleActuel = _getRoleName(u);
    final attente = _roleEnAttente[id];
    final isSelf = id == _session?.id;
    final regionGeree = u['regionGeree'];

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
                      _nomComplet(u),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade900,
                        fontSize: 15,
                      ),
                    ),
                    if (isSelf)
                      Text(
                        '(Vous)',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700,
                        ),
                      ),
                    const SizedBox(height: 2),
                    Text(
                      u['email']?.toString() ?? '—',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green.shade800,
                      ),
                    ),
                  ],
                ),
              ),
              if (!isSelf)
                IconButton(
                  onPressed: () => _supprimer(id),
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Colors.red,
                    size: 20,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  roleActuel.replaceAll('_', ' '),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.green.shade800,
                  ),
                ),
              ),
              if (roleActuel == 'RESPONSABLE_REGIONAL')
                Text(
                  regionGeree != null
                      ? regionGeree['nom'].toString()
                      : 'Aucune région assignée',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.green.shade700.withOpacity(0.8),
                  ),
                ),
            ],
          ),
          if (!isSelf) ...[
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: attente != null ? attente['roleName'] : roleActuel,
              decoration: InputDecoration(
                isDense: true,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              items: _rolesDisponibles
                  .map(
                    (r) => DropdownMenuItem(
                      value: r['value'],
                      child: Text(
                        r['label']!,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) => _handleSelectRole(u, v!),
            ),
            if (attente != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: attente['regionId'],
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: '-- Région --',
                        filled: true,
                        fillColor: Colors.blue.shade50,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      items: _regions
                          .map(
                            (r) => DropdownMenuItem<int>(
                              value: r['id'] as int,
                              child: Text(
                                r['nom'].toString(),
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => attente['regionId'] = v),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => _confirmerRegion(u),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      minimumSize: const Size(0, 40),
                    ),
                    child: const Text('OK', style: TextStyle(fontSize: 12)),
                  ),
                  const SizedBox(width: 4),
                  TextButton(
                    onPressed: () => setState(() => _roleEnAttente.remove(id)),
                    child: const Text('✕'),
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }
}
