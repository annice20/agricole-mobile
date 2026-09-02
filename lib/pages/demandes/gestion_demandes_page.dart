import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../widgets/app_layout.dart';
import '../../services/demande_aide_service.dart';

class GestionDemandesPage extends StatefulWidget {
  const GestionDemandesPage({super.key});

  @override
  State<GestionDemandesPage> createState() => _GestionDemandesPageState();
}

class _GestionDemandesPageState extends State<GestionDemandesPage> {
  final _demandeService = DemandeAideService();
  final _commentaireCtrl = TextEditingController();

  Session? _session;
  bool _loading = true;

  int? _agriculteurId;
  String _agriculteurNom = '';

  List<dynamic> _programmes = [];
  List<dynamic> _demandes = [];
  int? _programmeSelectionne;
  bool _argsResolus = false;

  // Vue régionale : responsable régional, uniquement si aucun agriculteur
  // précis n'est visé (pas d'agriculteurId dans l'URL).
  bool get _modeRegion =>
      _session?.role == 'RESPONSABLE_REGIONAL' && _agriculteurId == null;

  // Vue globale admin : admin national, uniquement si aucun agriculteur
  // précis n'est visé.
  bool get _modeGlobalAdmin =>
      _session?.role == 'ADMIN_NATIONAL' && _agriculteurId == null;

  bool get _modeListeMultiple => _modeRegion || _modeGlobalAdmin;

  @override
  void dispose() {
    _commentaireCtrl.dispose();
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_argsResolus) return;
    _argsResolus = true;

    final uri = Uri.tryParse(ModalRoute.of(context)?.settings.name ?? '');

    if (uri != null && uri.path == '/demandes') {
      _agriculteurId = int.tryParse(uri.queryParameters['agriculteurId'] ?? '');
      _agriculteurNom = uri.queryParameters['agriNom'] ?? '';
    }

    _init();
  }

  Future<void> _init() async {
    final session = await ApiClient().getSession();
    if (session == null) {
      if (mounted) Navigator.pushReplacementNamed(context, '/');
      return;
    }
    setState(() => _session = session);

    // Si aucun agriculteur précis n'est visé ET que le rôle n'a pas de vue
    // globale (agent de terrain par exemple), on redirige comme avant.
    if (_agriculteurId == null &&
        session.role != 'RESPONSABLE_REGIONAL' &&
        session.role != 'ADMIN_NATIONAL') {
      _showSnack('Aucun agriculteur sélectionné.', erreur: true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/agriculteurs');
        }
      });
      return;
    }

    await Future.wait([_chargerDemandes(), _chargerProgrammes()]);

    if (mounted) setState(() => _loading = false);
  }

  Future<void> _chargerDemandes() async {
    try {
      // Cas responsable régional sans agriculteur précis : sa région
      if (_modeRegion) {
        if (_session?.regionId == null) {
          _showSnack('Aucune région associée à votre compte.', erreur: true);
          setState(() => _demandes = []);
          return;
        }
        final data = await _demandeService.getDemandesParRegion(
          _session!.regionId!,
        );
        setState(() => _demandes = data);
        return;
      }

      // Cas admin national sans agriculteur précis : toutes les demandes
      if (_modeGlobalAdmin) {
        final data = await _demandeService.getDemandes();
        setState(() => _demandes = data);
        return;
      }

      // Cas agent, ou admin/responsable venant d'une fiche agriculteur précise
      final data = await _demandeService.getDemandes();
      final filtered = _agriculteurId != null
          ? data.where((d) {
              final id = d['agriculteurId'] ?? d['agriculteur']?['id'];
              return id != null && id.toString() == _agriculteurId.toString();
            }).toList()
          : data;
      setState(() => _demandes = filtered);
    } catch (_) {
      _showSnack('Erreur lors du chargement des demandes', erreur: true);
    }
  }

  Future<void> _chargerProgrammes() async {
    try {
      final data = await ApiClient().get('/programmes');
      setState(() => _programmes = data as List<dynamic>);
    } catch (_) {
      _showSnack('Impossible de charger les programmes', erreur: true);
    }
  }

  Future<void> _handleSubmit() async {
    if (_programmeSelectionne == null) {
      _showSnack('Veuillez sélectionner un programme', erreur: true);
      return;
    }
    try {
      await _demandeService.createDemande({
        'commentaire': _commentaireCtrl.text,
        'statut': 'EN_ATTENTE',
        'agriculteurId': _agriculteurId,
        'programmeId': _programmeSelectionne,
      });
      _showSnack('Demande enregistrée');
      _commentaireCtrl.clear();
      setState(() => _programmeSelectionne = null);
      await _chargerDemandes();
    } catch (_) {
      _showSnack("Erreur d'enregistrement", erreur: true);
    }
  }

  Future<void> _changerStatut(int id, String statut) async {
    try {
      await _demandeService.changerStatut(id, statut);
      _showSnack('Statut mis à jour : $statut');
      await _chargerDemandes();
    } catch (_) {
      _showSnack('Erreur lors du changement de statut', erreur: true);
    }
  }

  Future<void> _supprimer(int id) async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer cette demande ?'),
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
      await _demandeService.deleteDemande(id);
      _showSnack('Demande supprimée');
      await _chargerDemandes();
    } catch (_) {
      _showSnack('Suppression impossible', erreur: true);
    }
  }

  Map<String, dynamic> _statutInfo(String? statut) {
    switch (statut) {
      case 'VALIDEE':
        return {
          'label': 'Validée',
          'color': Colors.green,
          'icon': Icons.check_circle,
        };
      case 'DISPONIBLE':
        return {
          'label': 'Disponible',
          'color': Colors.purple,
          'icon': Icons.check_circle,
        };
      case 'DISTRIBUEE':
        return {
          'label': 'Distribuée',
          'color': Colors.blue,
          'icon': Icons.inventory_2,
        };
      case 'REFUSEE':
        return {'label': 'Refusée', 'color': Colors.red, 'icon': Icons.cancel};
      default:
        return {
          'label': 'En attente',
          'color': Colors.amber,
          'icon': Icons.access_time,
        };
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

  Widget _actionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.4)),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final role = _session?.role ?? '';
    final isAdmin = role == 'ADMIN_NATIONAL';
    final isAgent = role == 'AGENT_TERRAIN';

    if (_loading) {
      return AppLayout(
        currentRoute: '/gestion-demandes',
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Colors.green.shade700),
              const SizedBox(height: 16),
              Text(
                'Chargement des demandes...',
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
      currentRoute: '/gestion-demandes',
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Demandes d'aide",
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: Colors.green.shade900,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _modeRegion
                                  ? 'Région : ${_session?.regionNom ?? "—"}'
                                  : _modeGlobalAdmin
                                  ? 'Vue nationale : toutes les régions'
                                  : 'Agriculteur : $_agriculteurNom',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Colors.green.shade700.withOpacity(0.9),
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back, size: 16),
                        label: const Text('Retour'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.green.shade900,
                          backgroundColor: Colors.white.withOpacity(0.6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Formulaire nouvelle demande — masqué en vue liste multiple
                if (!_modeListeMultiple)
                  _card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.add_circle_outline,
                              size: 18,
                              color: Colors.green.shade800,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Nouvelle demande',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Colors.green.shade900,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _commentaireCtrl,
                          maxLines: 3,
                          decoration: InputDecoration(
                            hintText: 'Commentaire sur la demande...',
                            hintStyle: const TextStyle(fontSize: 13),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Colors.green.shade200,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<int>(
                          initialValue: _programmeSelectionne,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Colors.green.shade200,
                              ),
                            ),
                            hintText: '-- Sélectionner un programme --',
                            hintStyle: const TextStyle(fontSize: 13),
                          ),
                          items: _programmes.map((p) {
                            return DropdownMenuItem<int>(
                              value: p['id'] as int,
                              child: Text(
                                '${p['titre']} — ${p['typeAide']}',
                                style: const TextStyle(fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (v) =>
                              setState(() => _programmeSelectionne = v),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.6),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.groups,
                                size: 16,
                                color: Colors.green.shade700,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _agriculteurNom,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.green.shade800,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _handleSubmit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add, size: 16),
                              SizedBox(width: 8),
                              Text(
                                'Enregistrer la demande',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                // Historique des demandes
                _card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Historique des demandes',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Colors.green.shade900,
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_demandes.isEmpty)
                        Container(
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
                            _modeRegion
                                ? 'Aucune demande enregistrée pour cette région.'
                                : _modeGlobalAdmin
                                ? 'Aucune demande enregistrée sur la plateforme.'
                                : 'Aucune demande enregistrée pour cet agriculteur.',
                            style: TextStyle(
                              color: Colors.green.shade800.withOpacity(0.6),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        )
                      else
                        Column(
                          children: _demandes.map((d) {
                            final statutData = _statutInfo(d['statut']);
                            final statut = d['statut'] as String?;
                            final id = d['id'] as int;
                            final programmeId =
                                d['programmeId'] ?? d['programme']?['id'];
                            final programme = _programmes.firstWhere(
                              (p) =>
                                  p['id'].toString() == programmeId.toString(),
                              orElse: () => null,
                            );
                            final titreProgramme = programme != null
                                ? programme['titre']
                                : (d['programme']?['titre'] ?? '#$programmeId');

                            final agriculteurDeLaLigne = d['agriculteur'];
                            final nomAgriculteurLigne =
                                agriculteurDeLaLigne is Map
                                ? '${agriculteurDeLaLigne['prenom'] ?? ''} ${agriculteurDeLaLigne['nom'] ?? ''}'
                                      .trim()
                                : '';

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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Demande #$id',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w800,
                                                color: Colors.green.shade900,
                                                fontSize: 13,
                                              ),
                                            ),
                                            // Nom de l'agriculteur — utile
                                            // seulement en vue liste multiple
                                            if (_modeListeMultiple &&
                                                nomAgriculteurLigne.isNotEmpty)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  top: 2,
                                                ),
                                                child: Text(
                                                  nomAgriculteurLigne,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w700,
                                                    color:
                                                        Colors.green.shade900,
                                                  ),
                                                ),
                                              ),
                                            const SizedBox(height: 4),
                                            if ((d['commentaire'] ?? '')
                                                .toString()
                                                .isNotEmpty)
                                              Text(
                                                d['commentaire'],
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.green.shade800,
                                                ),
                                              ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Programme : $titreProgramme',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.green.shade700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color:
                                              (statutData['color']
                                                      as MaterialColor)
                                                  .shade100,
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
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
                                  const SizedBox(height: 10),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      if (isAdmin)
                                        _actionButton(
                                          icon: Icons.delete_outline,
                                          color: Colors.red,
                                          tooltip: 'Supprimer',
                                          onTap: () => _supprimer(id),
                                        ),
                                      if (statut == 'EN_ATTENTE' && isAdmin)
                                        _actionButton(
                                          icon: Icons.check_circle_outline,
                                          color: Colors.blue,
                                          tooltip: 'Approuver',
                                          onTap: () =>
                                              _changerStatut(id, 'VALIDEE'),
                                        ),
                                      if (statut == 'EN_ATTENTE' && isAdmin)
                                        _actionButton(
                                          icon: Icons.cancel_outlined,
                                          color: Colors.red,
                                          tooltip: 'Refuser',
                                          onTap: () =>
                                              _changerStatut(id, 'REFUSEE'),
                                        ),
                                      if (statut == 'VALIDEE' && isAdmin)
                                        _actionButton(
                                          icon: Icons.check_circle_outline,
                                          color: Colors.purple,
                                          tooltip: 'Marquer comme disponible',
                                          onTap: () =>
                                              _changerStatut(id, 'DISPONIBLE'),
                                        ),
                                      if ((statut == 'VALIDEE' ||
                                              statut == 'DISPONIBLE') &&
                                          (isAdmin || isAgent))
                                        _actionButton(
                                          icon: Icons.inventory_2_outlined,
                                          color: Colors.green,
                                          tooltip:
                                              'Enregistrer une distribution',
                                          onTap: () => Navigator.pushNamed(
                                            context,
                                            '/distributions/ajouter',
                                            arguments: {
                                              'demandeId': id,
                                              'agriculteurNom':
                                                  _modeListeMultiple
                                                  ? nomAgriculteurLigne
                                                  : _agriculteurNom,
                                              'programmeTitre': titreProgramme,
                                            },
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
