import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../widgets/app_layout.dart';
import '../../services/reclamation_service.dart';

class GestionReclamationsPage extends StatefulWidget {
  const GestionReclamationsPage({super.key});

  @override
  State<GestionReclamationsPage> createState() =>
      _GestionReclamationsPageState();
}

class _GestionReclamationsPageState extends State<GestionReclamationsPage> {
  final _reclamationService = ReclamationService();

  Session? _session;
  bool _loading = true;
  int? _updatingId;
  String _filtreStatut = 'TOUS';

  List<dynamic> _reclamations = [];

  bool get _isAdmin => _session?.role == 'ADMIN_NATIONAL';
  bool get _isResponsable => _session?.role == 'RESPONSABLE_REGIONAL';

  static const _rolesAutorises = ['ADMIN_NATIONAL', 'RESPONSABLE_REGIONAL'];

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
    if (session == null) {
      if (mounted) Navigator.pushReplacementNamed(context, '/');
      return;
    }

    // Garde-fou : accès réservé à l'admin national et au responsable
    // régional, cohérent avec la version web (GestionReclamations.jsx).
    if (!_rolesAutorises.contains(session.role)) {
      _showSnack(
        'Accès réservé aux administrateurs et responsables régionaux.',
        erreur: true,
      );
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) Navigator.pushReplacementNamed(context, '/dashboard');
        });
      }
      return;
    }

    setState(() => _session = session);
    await _charger();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _charger() async {
    try {
      final data = (_isResponsable && _session?.regionId != null)
          ? await _reclamationService.getReclamationsParRegion(
              _session!.regionId!,
            )
          : await _reclamationService.getAllReclamations();
      setState(() => _reclamations = data);
    } catch (_) {
      _showSnack('Impossible de charger les réclamations', erreur: true);
    }
  }

  Future<void> _changerStatut(int id, String statut) async {
    setState(() => _updatingId = id);
    try {
      await _reclamationService.changerStatut(id, statut);
      _showSnack('Réclamation mise à jour.');
      await _charger();
    } catch (_) {
      _showSnack('Erreur lors de la mise à jour', erreur: true);
    } finally {
      if (mounted) setState(() => _updatingId = null);
    }
  }

  List<dynamic> get _reclamationsFiltrees {
    if (_filtreStatut == 'TOUS') return _reclamations;
    return _reclamations.where((r) => r['statut'] == _filtreStatut).toList();
  }

  int _compteur(String statut) {
    return _reclamations.where((r) => r['statut'] == statut).length;
  }

  Map<String, dynamic> _statutInfo(String? statut) {
    switch (statut) {
      case 'TRAITEE':
        return {
          'label': 'Traitée',
          'color': Colors.green,
          'icon': Icons.check_circle,
        };
      case 'REJETEE':
        return {'label': 'Rejetée', 'color': Colors.red, 'icon': Icons.cancel};
      default:
        return {
          'label': 'En attente',
          'color': Colors.amber,
          'icon': Icons.access_time,
        };
    }
  }

  String _formatDate(String? d) {
    if (d == null) return '—';
    try {
      final date = DateTime.parse(d);
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    } catch (_) {
      return '—';
    }
  }

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _compteurCard(
    String label,
    String statut,
    Color color,
    IconData icon,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.5),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.4)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: Colors.green.shade900,
                      letterSpacing: 0.5,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${_compteur(statut)}',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Colors.green.shade900,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _session == null) {
      return AppLayout(
        currentRoute: '/reclamations',
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Colors.green.shade700),
              const SizedBox(height: 16),
              Text(
                'Chargement...',
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
      currentRoute: '/reclamations',
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isAdmin
                        ? 'Gestion des Réclamations'
                        : 'Réclamations de ma région',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Colors.green.shade900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _isAdmin
                        ? 'Traitez et suivez toutes les réclamations soumises par les agriculteurs.'
                        : "Suivez les réclamations des agriculteurs de votre région${_session?.regionNom != null ? " (${_session!.regionNom})" : ""}. Le traitement reste réservé à l'administration nationale.",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.green.shade700.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),

            // Cartes compteurs
            Row(
              children: [
                _compteurCard(
                  'EN ATTENTE',
                  'EN_ATTENTE',
                  Colors.amber.shade700,
                  Icons.access_time,
                ),
                const SizedBox(width: 10),
                _compteurCard(
                  'TRAITÉES',
                  'TRAITEE',
                  Colors.green.shade700,
                  Icons.check_circle,
                ),
                const SizedBox(width: 10),
                _compteurCard(
                  'REJETÉES',
                  'REJETEE',
                  Colors.red.shade700,
                  Icons.cancel,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Filtres
            _card(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Icon(
                    Icons.filter_list,
                    size: 16,
                    color: Colors.green.shade800,
                  ),
                  Text(
                    'Filtrer :',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Colors.green.shade900,
                    ),
                  ),
                  for (final s in ['TOUS', 'EN_ATTENTE', 'TRAITEE', 'REJETEE'])
                    _filtreChip(s),
                ],
              ),
            ),

            // Liste des réclamations
            _card(
              child: _reclamationsFiltrees.isEmpty
                  ? Container(
                      padding: const EdgeInsets.all(24),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        'Aucune réclamation dans cette catégorie.',
                        style: TextStyle(
                          color: Colors.green.shade800.withOpacity(0.6),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  : Column(
                      children: _reclamationsFiltrees.map((r) {
                        final statutData = _statutInfo(r['statut']);
                        final statut = r['statut'] as String?;
                        final id = r['id'] as int;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.4),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.warning_amber_rounded,
                                    size: 15,
                                    color: Colors.orange.shade600,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      r['sujet'] ?? '',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        color: Colors.green.shade900,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          (statutData['color'] as MaterialColor)
                                              .shade100,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          statutData['icon'] as IconData,
                                          size: 12,
                                          color:
                                              (statutData['color']
                                                      as MaterialColor)
                                                  .shade800,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          statutData['label'] as String,
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            color:
                                                (statutData['color']
                                                        as MaterialColor)
                                                    .shade800,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                r['description'] ?? '',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.green.shade800,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Container(
                                height: 1,
                                color: Colors.white.withOpacity(0.5),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if ((_isAdmin || _isResponsable) &&
                                            r['agriculteur'] != null)
                                          Text(
                                            'Agriculteur : ${r['agriculteur']['prenom'] ?? ''} ${r['agriculteur']['nom'] ?? ''}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.green.shade900,
                                            ),
                                          ),
                                        Text(
                                          'Soumise le : ${_formatDate(r['dateReclamation'] ?? r['dateCreation'])}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.green.shade700
                                                .withOpacity(0.8),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (_isAdmin && statut == 'EN_ATTENTE')
                                    Wrap(
                                      spacing: 6,
                                      children: [
                                        _actionButton(
                                          label: 'Traitée',
                                          icon: Icons.check_circle,
                                          color: Colors.green,
                                          loading: _updatingId == id,
                                          onTap: () =>
                                              _changerStatut(id, 'TRAITEE'),
                                        ),
                                        _actionButton(
                                          label: 'Rejeter',
                                          icon: Icons.cancel,
                                          color: Colors.red,
                                          loading: _updatingId == id,
                                          onTap: () =>
                                              _changerStatut(id, 'REJETEE'),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filtreChip(String s) {
    final isActive = _filtreStatut == s;
    final label = switch (s) {
      'TOUS' => 'Tous',
      'EN_ATTENTE' => 'En attente',
      'TRAITEE' => 'Traitées',
      _ => 'Rejetées',
    };
    return InkWell(
      onTap: () => setState(() => _filtreStatut = s),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? Colors.green.shade700
              : Colors.white.withOpacity(0.6),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive
                ? Colors.green.shade700
                : Colors.white.withOpacity(0.4),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: isActive ? Colors.white : Colors.green.shade800,
          ),
        ),
      ),
    );
  }

  Widget _actionButton({
    required String label,
    required IconData icon,
    required Color color,
    required bool loading,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: loading ? null : onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (loading)
              const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(Colors.white),
                ),
              )
            else
              Icon(icon, size: 13, color: Colors.white),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
