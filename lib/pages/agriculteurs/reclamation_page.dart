import 'dart:async';
import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../widgets/app_layout.dart';
import '../../services/reclamation_service.dart';

class ReclamationPage extends StatefulWidget {
  const ReclamationPage({super.key});

  @override
  State<ReclamationPage> createState() => _ReclamationPageState();
}

class _ReclamationPageState extends State<ReclamationPage> {
  final _formKey = GlobalKey<FormState>();
  final _reclamationService = ReclamationService();
  final _sujetCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();

  Session? _session;
  bool _loading = true;
  bool _submitting = false;

  // id de la fiche Agriculteur (table agriculteurs) — différent de
  // _session.id (table utilisateurs). Résolu via un endpoint dédié,
  // même pattern que MesDemandesPage.dart et GestionDemandesPage.dart.
  // C'est exactement le bug qu'on a corrigé côté web dans
  // ReclamationPage.jsx : utiliser l'id utilisateur à la place de
  // l'id agriculteur envoie une valeur invalide au backend et
  // provoque "Agriculteur introuvable".
  int? _agriculteurId;

  List<dynamic> _reclamations = [];

  // Polling toutes les 20s pour notifier l'agriculteur d'un changement
  // de statut (traitée/rejetée), même pattern que MesDemandesPage.dart.
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _sujetCtrl.dispose();
    _descriptionCtrl.dispose();
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

    if (idAgriculteur != null) {
      await _charger(idAgriculteur);
      _pollTimer?.cancel();
      _pollTimer = Timer.periodic(
        const Duration(seconds: 20),
        (_) => _verifierChangements(idAgriculteur),
      );
    }

    if (mounted) setState(() => _loading = false);
  }

  Future<void> _verifierChangements(int agriculteurId) async {
    try {
      final nouvelles = await _reclamationService.getReclamationsByAgriculteur(
        agriculteurId,
      );

      for (final nouvelle in nouvelles) {
        final ancienne = _reclamations.firstWhere(
          (r) => r['id'] == nouvelle['id'],
          orElse: () => null,
        );
        if (ancienne != null && ancienne['statut'] != nouvelle['statut']) {
          _showSnack(
            'Votre réclamation "${nouvelle['sujet']}" est passée au statut : ${nouvelle['statut']}',
          );
        }
      }

      if (mounted) setState(() => _reclamations = nouvelles);
    } catch (_) {
      // silencieux
    }
  }

  Future<void> _charger(int agriculteurId) async {
    try {
      final data = await _reclamationService.getReclamationsByAgriculteur(
        agriculteurId,
      );
      setState(() => _reclamations = data);
    } catch (_) {
      _showSnack('Impossible de charger les réclamations', erreur: true);
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_agriculteurId == null) {
      _showSnack('Votre fiche agriculteur est introuvable.', erreur: true);
      return;
    }

    setState(() => _submitting = true);
    try {
      await _reclamationService.createReclamation({
        'sujet': _sujetCtrl.text,
        'description': _descriptionCtrl.text,
        'agriculteurId': _agriculteurId,
      });
      _showSnack('Réclamation envoyée avec succès');
      _sujetCtrl.clear();
      _descriptionCtrl.clear();
      await _charger(_agriculteurId!);
    } on ApiException catch (e) {
      _showSnack("Erreur lors de l'envoi : ${e.message}", erreur: true);
    } catch (_) {
      _showSnack("Erreur lors de l'envoi", erreur: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _supprimer(int id) async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer cette réclamation ?'),
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
      await _reclamationService.deleteReclamation(id);
      _showSnack('Réclamation supprimée');
      if (_agriculteurId != null) await _charger(_agriculteurId!);
    } catch (_) {
      _showSnack('Suppression impossible', erreur: true);
    }
  }

  Map<String, dynamic> _statutInfo(String? statut) {
    switch (statut) {
      case 'RESOLU':
      case 'TRAITEE':
        return {
          'label': 'Résolu',
          'color': Colors.green,
          'icon': Icons.check_circle,
        };
      case 'REJETE':
      case 'REJETEE':
        return {'label': 'Rejeté', 'color': Colors.red, 'icon': Icons.cancel};
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
      const mois = [
        'janvier',
        'février',
        'mars',
        'avril',
        'mai',
        'juin',
        'juillet',
        'août',
        'septembre',
        'octobre',
        'novembre',
        'décembre',
      ];
      return '${date.day} ${mois[date.month - 1]} ${date.year}';
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

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return AppLayout(
        currentRoute: '/reclamations/nouvelle',
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
      currentRoute: '/reclamations/nouvelle',
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
                        'Réclamations',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: Colors.green.shade900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Signalez un problème concernant vos aides agricoles.',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.green.shade700.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ),

                if (_agriculteurId == null)
                  _card(
                    child: Container(
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
                    ),
                  )
                else ...[
                  // Formulaire nouvelle réclamation
                  _card(
                    child: Form(
                      key: _formKey,
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
                                'Nouvelle réclamation',
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
                            controller: _sujetCtrl,
                            decoration: InputDecoration(
                              labelText: 'Sujet',
                              hintText:
                                  'Ex: Aide non reçue, montant incorrect...',
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
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Champ requis'
                                : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _descriptionCtrl,
                            maxLines: 5,
                            decoration: InputDecoration(
                              labelText: 'Description',
                              hintText: 'Décrivez votre problème en détail...',
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
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Champ requis'
                                : null,
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
                                      Icon(Icons.warning_amber, size: 16),
                                      SizedBox(width: 8),
                                      Text(
                                        'Envoyer la réclamation',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Liste des réclamations
                  _card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Mes réclamations',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Colors.green.shade900,
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (_reclamations.isEmpty)
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
                              'Aucune réclamation enregistrée.',
                              style: TextStyle(
                                color: Colors.green.shade800.withOpacity(0.6),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          )
                        else
                          Column(
                            children: _reclamations.map((r) {
                              final statutData = _statutInfo(r['statut']);
                              final id = r['id'] as int;
                              final statut = r['statut'] as String?;

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
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.warning_amber_rounded,
                                                size: 14,
                                                color: Colors.orange.shade600,
                                              ),
                                              const SizedBox(width: 6),
                                              Expanded(
                                                child: Text(
                                                  r['sujet'] ?? '',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w800,
                                                    color:
                                                        Colors.green.shade900,
                                                    fontSize: 13,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            r['description'] ?? '',
                                            maxLines: 3,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.green.shade800,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            'Envoyée le ${_formatDate(r['dateCreation'])}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.green.shade700
                                                  .withOpacity(0.7),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
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
                                        if (statut == 'EN_ATTENTE') ...[
                                          const SizedBox(height: 8),
                                          InkWell(
                                            onTap: () => _supprimer(id),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            child: Container(
                                              padding: const EdgeInsets.all(6),
                                              decoration: BoxDecoration(
                                                color: Colors.red.withOpacity(
                                                  0.1,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                border: Border.all(
                                                  color: Colors.red.withOpacity(
                                                    0.4,
                                                  ),
                                                ),
                                              ),
                                              child: const Icon(
                                                Icons.delete_outline,
                                                size: 16,
                                                color: Colors.red,
                                              ),
                                            ),
                                          ),
                                        ],
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
