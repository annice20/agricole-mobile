import 'dart:ui';
import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../services/equipement_service.dart';
import '../../widgets/app_layout.dart';
import 'ajouter_equipement_page.dart';

class ListeEquipementsPage extends StatefulWidget {
  const ListeEquipementsPage({super.key});

  @override
  State<ListeEquipementsPage> createState() => _ListeEquipementsPageState();
}

class _ListeEquipementsPageState extends State<ListeEquipementsPage> {
  final EquipementService _service = EquipementService();

  List<dynamic> _equipements = [];
  bool _loading = true;
  String _search = "";

  @override
  void initState() {
    super.initState();
    _chargerEquipements();
  }

  Future<void> _chargerEquipements() async {
    setState(() => _loading = true);
    try {
      final data = await _service.getEquipements();
      setState(() => _equipements = data);
    } on ApiException catch (e) {
      _showSnack("Erreur lors du chargement : ${e.message}", erreur: true);
    } catch (_) {
      _showSnack("Erreur lors du chargement des équipements", erreur: true);
    } finally {
      if (mounted) setState(() => _loading = false);
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

  List<dynamic> get _filtered {
    if (_search.trim().isEmpty) return _equipements;
    final q = _search.toLowerCase();
    return _equipements.where((e) {
      final map = e as Map;
      return (map["nom"]?.toString().toLowerCase() ?? "").contains(q) ||
          (map["categorie"]?.toString().toLowerCase() ?? "").contains(q);
    }).toList();
  }

  int get _totalActifs =>
      _equipements.where((e) => (e as Map)["actif"] == true).length;

  int get _totalInactifs =>
      _equipements.where((e) => (e as Map)["actif"] != true).length;

  Future<void> _ouvrirAjout() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AjouterEquipementPage()),
    );
    _chargerEquipements();
  }

  Future<void> _ouvrirModification(Map equipement) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) =>
          _ModifierEquipementSheet(equipement: equipement, service: _service),
    );
    if (result == true) {
      _chargerEquipements();
    }
  }

  Future<void> _supprimerEquipement(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Confirmer la suppression"),
        content: const Text("Voulez-vous vraiment supprimer cet équipement ?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Annuler"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Supprimer", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _service.deleteEquipement(id);
      _showSnack("Équipement supprimé avec succès");
      _chargerEquipements();
    } on ApiException catch (e) {
      _showSnack("Erreur lors de la suppression : ${e.message}", erreur: true);
    } catch (_) {
      _showSnack("Erreur lors de la suppression", erreur: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppLayout(
      currentRoute: "/equipements",
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _chargerEquipements,
              color: Colors.green.shade800,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildHeader(),
                  const SizedBox(height: 16),
                  _buildKpiRow(),
                  const SizedBox(height: 16),
                  _buildSearchBar(),
                  const SizedBox(height: 16),
                  if (_filtered.isEmpty)
                    _buildEmptyState()
                  else
                    ..._filtered.map((e) => _buildEquipementCard(e as Map)),
                ],
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
              Row(
                children: [
                  Icon(
                    Icons.agriculture,
                    color: Colors.green.shade800,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Gestion des Équipements",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Colors.green.shade900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                "Gérez les équipements agricoles disponibles.",
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.green.shade800.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          onPressed: _ouvrirAjout,
          icon: const Icon(Icons.add, size: 16),
          label: const Text("Ajouter"),
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

  Widget _buildKpiRow() {
    return Row(
      children: [
        Expanded(
          child: _KpiCard(
            title: "Total",
            value: "${_equipements.length}",
            icon: Icons.inventory_2_outlined,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _KpiCard(
            title: "Actifs",
            value: "$_totalActifs",
            icon: Icons.check_circle_outline,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _KpiCard(
            title: "Inactifs",
            value: "$_totalInactifs",
            icon: Icons.cancel_outlined,
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return _GlassCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: [
            Icon(Icons.search, size: 18, color: Colors.green.shade700),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                onChanged: (v) => setState(() => _search = v),
                style: TextStyle(fontSize: 14, color: Colors.green.shade900),
                decoration: InputDecoration(
                  hintText: "Rechercher un équipement...",
                  hintStyle: TextStyle(
                    color: Colors.green.shade800.withOpacity(0.4),
                    fontSize: 13,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return _GlassCard(
      opacity: 0.4,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Center(
          child: Text(
            "Aucun équipement trouvé.",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.green.shade800.withOpacity(0.6),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEquipementCard(Map e) {
    final actif = e["actif"] == true;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _GlassCard(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      e["nom"]?.toString() ?? "",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Colors.green.shade900,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.edit_outlined,
                      size: 18,
                      color: Colors.blue,
                    ),
                    onPressed: () => _ouvrirModification(e),
                    tooltip: "Modifier",
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.delete_outline,
                      size: 18,
                      color: Colors.red,
                    ),
                    onPressed: () => _supprimerEquipement(e["id"] as int),
                    tooltip: "Supprimer",
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
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
                      e["categorie"]?.toString() ?? "—",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.green.shade800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: actif
                          ? Colors.green.shade200
                          : Colors.red.shade100,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      actif ? "Actif" : "Inactif",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: actif
                            ? Colors.green.shade900
                            : Colors.red.shade800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                "Quantité disponible : ${e["quantiteDisponible"] ?? 0}",
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.green.shade900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Carte "glassmorphism" réutilisable — équivalent de
/// `bg-white/50 backdrop-blur-md rounded-2xl border border-white/40`.
class _GlassCard extends StatelessWidget {
  final Widget child;
  final double opacity;

  const _GlassCard({required this.child, this.opacity = 0.5});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(opacity),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.4)),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _KpiCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade800.withOpacity(0.7),
                    letterSpacing: 0.5,
                  ),
                ),
                Icon(icon, size: 16, color: Colors.green.shade700),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Colors.green.shade900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Modale de modification — réutilise les mêmes champs que
/// AjouterEquipementPage, préremplis avec les valeurs existantes.
class _ModifierEquipementSheet extends StatefulWidget {
  final Map equipement;
  final EquipementService service;

  const _ModifierEquipementSheet({
    required this.equipement,
    required this.service,
  });

  @override
  State<_ModifierEquipementSheet> createState() =>
      _ModifierEquipementSheetState();
}

class _ModifierEquipementSheetState extends State<_ModifierEquipementSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nomCtrl;
  late final TextEditingController _categorieCtrl;
  late final TextEditingController _quantiteCtrl;
  late final TextEditingController _descriptionCtrl;
  late bool _actif;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final e = widget.equipement;
    _nomCtrl = TextEditingController(text: e["nom"]?.toString() ?? "");
    _categorieCtrl = TextEditingController(
      text: e["categorie"]?.toString() ?? "",
    );
    _quantiteCtrl = TextEditingController(
      text: e["quantiteDisponible"]?.toString() ?? "",
    );
    _descriptionCtrl = TextEditingController(
      text: e["description"]?.toString() ?? "",
    );
    _actif = e["actif"] == true;
  }

  @override
  void dispose() {
    _nomCtrl.dispose();
    _categorieCtrl.dispose();
    _quantiteCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await widget.service.modifierEquipement(widget.equipement["id"] as int, {
        "nom": _nomCtrl.text,
        "categorie": _categorieCtrl.text,
        "quantiteDisponible": int.tryParse(_quantiteCtrl.text) ?? 0,
        "description": _descriptionCtrl.text,
        "actif": _actif,
      });
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Erreur lors de la modification : ${e.message}"),
            backgroundColor: Colors.red.shade600,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Erreur lors de la modification"),
            backgroundColor: Colors.red.shade600,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.97),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Modifier l'équipement",
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: Colors.green.shade900,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                      color: Colors.green.shade800,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _label("Nom de l'équipement"),
                _champTexte(_nomCtrl, required: true),
                const SizedBox(height: 14),
                _label("Catégorie"),
                _champTexte(_categorieCtrl, required: true),
                const SizedBox(height: 14),
                _label("Quantité disponible"),
                _champTexte(
                  _quantiteCtrl,
                  required: true,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 14),
                _label("Description"),
                _champTexte(_descriptionCtrl, maxLines: 3),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Checkbox(
                      value: _actif,
                      activeColor: Colors.green.shade700,
                      onChanged: (v) => setState(() => _actif = v ?? true),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _actif = !_actif),
                        child: Text(
                          "Équipement disponible et actif",
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade900,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _loading ? null : _handleSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _loading
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : const Text(
                          "Enregistrer les modifications",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.5,
        color: Colors.green.shade900,
      ),
    ),
  );

  Widget _champTexte(
    TextEditingController controller, {
    bool required = false,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
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
      ),
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Colors.green.shade900,
      ),
      validator: required
          ? (v) => (v == null || v.isEmpty) ? "Champ requis" : null
          : null,
    );
  }
}
