import 'dart:async';
import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../widgets/app_layout.dart';
import '../../services/demande_aide_service.dart';

class MesDemandesPage extends StatefulWidget {
  const MesDemandesPage({super.key});

  @override
  State<MesDemandesPage> createState() => _MesDemandesPageState();
}

class _MesDemandesPageState extends State<MesDemandesPage> {
  final _formKey = GlobalKey<FormState>();
  final _demandeService = DemandeAideService();
  final _commentaireCtrl = TextEditingController();

  Session? _session;
  bool _loading = true;
  bool _submitting = false;

  // id de la fiche Agriculteur (table agriculteurs) — différent de
  // _session.id (table utilisateurs) ! Relation @OneToOne séparée côté
  // backend, donc récupéré via un endpoint dédié avant tout usage.
  int? _agriculteurId;

  List<dynamic> _programmes = [];
  List<dynamic> _demandes = [];
  int? _programmeSelectionne;

  // Polling automatique du statut des demandes toutes les 20s,
  // pour que l'agriculteur voie les changements (validée/refusée/disponible)
  // sans avoir à rouvrir la page manuellement. Équivalent du useEffect
  // avec setInterval dans MesDemandes.jsx.
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _commentaireCtrl.dispose();
    super.dispose();
  }

  void _showSnack(String message, {bool erreur = false, bool info = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: erreur
            ? Colors.red.shade600
            : info
            ? Colors.blue.shade600
            : Colors.green.shade700,
      ),
    );
  }

  Future<int?> _chargerAgriculteurId(int utilisateurId) async {
    try {
      final data = await ApiClient().get(
        '/agriculteurs/utilisateur/$utilisateurId',
      );
      return (data as Map<String, dynamic>)['id'] as int?;
    } catch (_) {
      _showSnack(
        'Impossible de retrouver votre fiche agriculteur. Contactez un agent de terrain.',
        erreur: true,
      );
      return null;
    }
  }

  Future<void> _init() async {
    final session = await ApiClient().getSession();
    if (session == null) {
      if (mounted) Navigator.pushReplacementNamed(context, '/');
      return;
    }
    setState(() => _session = session);

    final idAgriculteur = await _chargerAgriculteurId(session.id);
    setState(() => _agriculteurId = idAgriculteur);

    await Future.wait([
      if (idAgriculteur != null) _chargerDemandes(idAgriculteur),
      _chargerProgrammes(),
    ]);

    if (mounted) setState(() => _loading = false);

    // On ne démarre le polling qu'une fois la fiche agriculteur confirmée,
    // même logique que la dépendance [currentUser.id] côté web.
    if (idAgriculteur != null) {
      _pollTimer?.cancel();
      _pollTimer = Timer.periodic(
        const Duration(seconds: 20),
        (_) => _verifierChangements(idAgriculteur),
      );
    }
  }

  Future<void> _verifierChangements(int agriculteurId) async {
    try {
      final data = await _demandeService.getDemandes();
      final mesDemandes = data.where((d) {
        final id = d['agriculteurId'] ?? d['agriculteur']?['id'];
        return id != null && id.toString() == agriculteurId.toString();
      }).toList();

      // Comparaison avec l'état précédent pour détecter un changement de statut
      for (final nouvelle in mesDemandes) {
        final ancienne = _demandes.firstWhere(
          (d) => d['id'] == nouvelle['id'],
          orElse: () => null,
        );
        if (ancienne != null && ancienne['statut'] != nouvelle['statut']) {
          _showSnack(
            "Votre demande #${nouvelle['id']} est passée au statut : ${nouvelle['statut']}",
            info: true,
          );
        }
      }

      if (mounted) setState(() => _demandes = mesDemandes);
    } catch (_) {
      // silencieux, comme pour le compteur de notifs dans la navbar
    }
  }

  Future<void> _chargerProgrammes() async {
    try {
      final data = await ApiClient().get('/programmes');
      final liste = (data as List<dynamic>)
          .where((p) => p['actif'] == true)
          .toList();
      setState(() => _programmes = liste);
    } catch (_) {
      _showSnack(
        'Impossible de charger les programmes disponibles',
        erreur: true,
      );
    }
  }

  Future<void> _chargerDemandes(int agriculteurId) async {
    try {
      final data = await _demandeService.getDemandes();
      final mesDemandes = data.where((d) {
        final id = d['agriculteurId'] ?? d['agriculteur']?['id'];
        return id != null && id.toString() == agriculteurId.toString();
      }).toList();
      setState(() => _demandes = mesDemandes);
    } catch (_) {
      _showSnack('Erreur lors du chargement de vos demandes', erreur: true);
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_programmeSelectionne == null) {
      _showSnack('Veuillez sélectionner un programme', erreur: true);
      return;
    }
    if (_agriculteurId == null) {
      _showSnack('Votre fiche agriculteur est introuvable.', erreur: true);
      return;
    }

    setState(() => _submitting = true);
    try {
      await _demandeService.createDemande({
        'commentaire': _commentaireCtrl.text,
        'statut': 'EN_ATTENTE',
        'agriculteurId': _agriculteurId,
        'programmeId': _programmeSelectionne,
      });
      _showSnack('Votre demande a bien été envoyée');
      _commentaireCtrl.clear();
      setState(() => _programmeSelectionne = null);
      await _chargerDemandes(_agriculteurId!);
    } on ApiException catch (e) {
      _showSnack("Erreur lors de l'envoi : ${e.message}", erreur: true);
    } catch (_) {
      _showSnack("Erreur lors de l'envoi de la demande", erreur: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
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

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return AppLayout(
        currentRoute: '/mes-demandes',
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Colors.green.shade700),
              const SizedBox(height: 16),
              Text(
                'Chargement de vos demandes...',
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
      currentRoute: '/mes-demandes',
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mes demandes d\'aide',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: Colors.green.shade900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Soumettez une nouvelle demande et suivez vos demandes précédentes.',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.green.shade700.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ),

                _card(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.eco,
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

                        if (_agriculteurId == null)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: Text(
                              "Votre fiche agriculteur est introuvable. Contactez un agent de terrain pour vérifier votre inscription.",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.red.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          )
                        else if (_programmes.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.3),
                              ),
                            ),
                            child: Text(
                              "Aucun programme d'aide n'est actuellement disponible.",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.green.shade800.withOpacity(0.7),
                              ),
                            ),
                          )
                        else ...[
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
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.green.shade200,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.green.shade500,
                                  width: 2,
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
                            validator: (v) => v == null ? 'Champ requis' : null,
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
                                  _session?.nom ?? '',
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

                          TextFormField(
                            controller: _commentaireCtrl,
                            maxLines: 3,
                            decoration: InputDecoration(
                              hintText:
                                  'Précisez votre besoin (surface concernée, urgence, contexte...)',
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
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.green.shade200,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.green.shade500,
                                  width: 2,
                                ),
                              ),
                            ),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.green.shade900,
                            ),
                          ),
                          const SizedBox(height: 16),

                          ElevatedButton(
                            onPressed: _submitting ? null : _handleSubmit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green.shade700,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _submitting
                                ? Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: const [
                                      SizedBox(
                                        height: 16,
                                        width: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation(
                                            Colors.white,
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: 10),
                                      Text('Envoi en cours...'),
                                    ],
                                  )
                                : const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.send, size: 16),
                                      SizedBox(width: 8),
                                      Text(
                                        'Envoyer la demande',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                _card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Historique de mes demandes',
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
                            "Vous n'avez encore soumis aucune demande.",
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
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Demande #${d['id']}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            color: Colors.green.shade900,
                                            fontSize: 13,
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
                                        if ((d['commentaire'] ?? '')
                                            .toString()
                                            .isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            d['commentaire'],
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.green.shade800,
                                            ),
                                          ),
                                        ],
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
