import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';

import '../../core/api_client.dart';
import '../../services/financement_service.dart';
import '../../services/programme_service.dart';
import '../../widgets/app_layout.dart';

class FinancementsAgricolesPage extends StatefulWidget {
  const FinancementsAgricolesPage({super.key});

  @override
  State<FinancementsAgricolesPage> createState() =>
      _FinancementsAgricolesPageState();
}

class _FinancementsAgricolesPageState extends State<FinancementsAgricolesPage> {
  final FinancementService _financementService = FinancementService();
  final ProgrammeService _programmeService = ProgrammeService();

  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();

  List<dynamic> _financements = [];
  List<dynamic> _programmes = [];
  bool _loading = false;
  String _search = "";
  int? _editId;

  Session? _session;
  bool get _isAdmin => _session?.role == 'ADMIN_NATIONAL';

  final _organismeController = TextEditingController();
  final _montantController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime? _dateFinancement;
  int? _programmeId;

  final _montantFormat = NumberFormat("#,##0", "fr_FR");

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _organismeController.dispose();
    _montantController.dispose();
    _descriptionController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------
  // CHARGEMENT
  // ---------------------------------------------------------------

  Future<void> _init() async {
    final session = await ApiClient().getSession();
    setState(() => _session = session);
    await _chargerFinancements();
    if (_isAdmin) {
      await _chargerProgrammes();
    }
  }

  Future<void> _chargerFinancements() async {
    setState(() => _loading = true);
    try {
      final data = await _financementService.getAllFinancements();
      setState(() => _financements = data);
    } catch (_) {
      _toastError("Erreur lors du chargement des financements");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _chargerProgrammes() async {
    try {
      final data = await _programmeService.getAll();
      setState(() => _programmes = data);
    } catch (_) {
      _toastError("Erreur lors du chargement des programmes");
    }
  }

  void _toastError(String message) {
    Fluttertoast.showToast(msg: message);
  }

  void _toastSuccess(String message) {
    Fluttertoast.showToast(msg: message);
  }

  // ---------------------------------------------------------------
  // FORMULAIRE
  // ---------------------------------------------------------------

  void _resetForm() {
    setState(() {
      _editId = null;
      _organismeController.clear();
      _montantController.clear();
      _descriptionController.clear();
      _dateFinancement = null;
      _programmeId = null;
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateFinancement ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _dateFinancement = picked);
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_dateFinancement == null) {
      _toastError("Veuillez choisir une date de financement");
      return;
    }
    if (_programmeId == null) {
      _toastError("Veuillez sélectionner un programme");
      return;
    }

    final payload = {
      "organisme": _organismeController.text,
      "montant": num.tryParse(_montantController.text) ?? 0,
      "dateFinancement": DateFormat("yyyy-MM-dd").format(_dateFinancement!),
      "description": _descriptionController.text,
      "programmeId": _programmeId,
    };

    try {
      if (_editId != null) {
        await _financementService.updateFinancement(_editId!, payload);
        _toastSuccess("Financement modifié avec succès");
      } else {
        await _financementService.createFinancement(payload);
        _toastSuccess("Financement ajouté avec succès");
      }
      _resetForm();
      _chargerFinancements();
    } catch (_) {
      _toastError("Erreur lors de l'enregistrement");
    }
  }

  void _handleEdit(Map f) {
    setState(() {
      _editId = f["id"];
      _organismeController.text = f["organisme"] ?? "";
      _montantController.text = f["montant"]?.toString() ?? "";
      _descriptionController.text = f["description"] ?? "";
      _programmeId = f["programmeId"];
      _dateFinancement = DateTime.tryParse(
        f["dateFinancement"]?.toString() ?? "",
      );
    });

    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _handleDelete(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Confirmer la suppression"),
        content: const Text("Voulez-vous vraiment supprimer ce financement ?"),
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
      await _financementService.deleteFinancement(id);
      _toastSuccess("Financement supprimé avec succès");
      _chargerFinancements();
    } catch (_) {
      _toastError("Erreur lors de la suppression");
    }
  }

  // ---------------------------------------------------------------
  // HELPERS
  // ---------------------------------------------------------------

  String _programmeNom(dynamic programmeId) {
    final match = _programmes.firstWhere(
      (p) => p["id"] == programmeId,
      orElse: () => null,
    );
    return match?["titre"]?.toString() ?? "Non associé";
  }

  List<dynamic> get _filtered {
    if (_search.trim().isEmpty) return _financements;
    final q = _search.toLowerCase();
    return _financements
        .where(
          (f) => (f["organisme"]?.toString().toLowerCase() ?? "").contains(q),
        )
        .toList();
  }

  // ---------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return AppLayout(
      currentRoute: "/financements",
      child: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        children: [
          _buildHeader(),
          const SizedBox(height: 16),
          if (_isAdmin) ...[_buildFormCard(), const SizedBox(height: 16)],
          _buildSearchBar(),
          const SizedBox(height: 16),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_filtered.isEmpty)
            _buildEmptyState()
          else
            ..._filtered.map((f) => _buildFinancementCard(f as Map)),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Gestion des Financements",
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: Colors.green.shade900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _isAdmin
              ? "Gérez les subventions et financements accordés aux programmes agricoles."
              : "Consultation des subventions et financements accordés aux programmes agricoles.",
          style: TextStyle(fontSize: 13, color: Colors.green.shade700),
        ),
      ],
    );
  }

  Widget _buildFormCard() {
    return _GlassCard(
      opacity: 0.6,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.shade700,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.attach_money,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _editId != null
                        ? "Modifier un financement"
                        : "Ajouter un nouveau financement",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _label("Organisme financeur"),
              TextFormField(
                controller: _organismeController,
                decoration: _inputDecoration("Ex: Banque Mondiale, FAO..."),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? "Champ requis" : null,
              ),
              const SizedBox(height: 14),
              _label("Montant (Ar)"),
              TextFormField(
                controller: _montantController,
                keyboardType: TextInputType.number,
                decoration: _inputDecoration("Montant en Ariary"),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? "Champ requis" : null,
              ),
              const SizedBox(height: 14),
              _label("Date du financement"),
              InkWell(
                onTap: _pickDate,
                child: InputDecorator(
                  decoration: _inputDecoration(""),
                  child: Text(
                    _dateFinancement != null
                        ? DateFormat(
                            "d MMMM yyyy",
                            "fr_FR",
                          ).format(_dateFinancement!)
                        : "Sélectionner une date",
                    style: TextStyle(
                      color: _dateFinancement != null
                          ? Colors.green.shade900
                          : Colors.green.shade800.withOpacity(0.4),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _label("Programme concerné"),
              DropdownButtonFormField<int>(
                initialValue: _programmeId,
                decoration: _inputDecoration("Sélectionner un programme"),
                items: _programmes
                    .map<DropdownMenuItem<int>>(
                      (p) => DropdownMenuItem<int>(
                        value: p["id"] as int,
                        child: Text(p["titre"]?.toString() ?? ""),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _programmeId = v),
                validator: (v) => v == null ? "Champ requis" : null,
              ),
              const SizedBox(height: 14),
              _label("Description"),
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: _inputDecoration("Détails du financement..."),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _handleSubmit,
                      icon: Icon(_editId != null ? Icons.save : Icons.add),
                      label: Text(
                        _editId != null
                            ? "Mettre à jour"
                            : "Ajouter le financement",
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: _resetForm,
                    icon: const Icon(Icons.close),
                    label: const Text("Annuler"),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.green.shade900,
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                        horizontal: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.green.shade900,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.white.withOpacity(0.8),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.green.shade200),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.green.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.green.shade600, width: 2),
      ),
    );
  }

  Widget _buildSearchBar() {
    return _GlassCard(
      opacity: 0.6,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        child: Row(
          children: [
            Icon(Icons.search, size: 18, color: Colors.green.shade700),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                onChanged: (v) => setState(() => _search = v),
                style: TextStyle(fontSize: 14, color: Colors.green.shade900),
                decoration: InputDecoration(
                  hintText: "Rechercher un organisme financeur...",
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
      opacity: 0.6,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Center(
          child: Text(
            "Aucun financement trouvé.",
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.green.shade700,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFinancementCard(Map f) {
    final montant = num.tryParse(f["montant"]?.toString() ?? "0") ?? 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _GlassCard(
        opacity: 0.6,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.business_outlined,
                    size: 16,
                    color: Colors.green.shade600,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      f["organisme"]?.toString() ?? "",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Colors.green.shade900,
                      ),
                    ),
                  ),
                  if (_isAdmin) ...[
                    IconButton(
                      icon: const Icon(
                        Icons.edit_outlined,
                        size: 18,
                        color: Colors.blue,
                      ),
                      onPressed: () => _handleEdit(f),
                      tooltip: "Modifier",
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline,
                        size: 18,
                        color: Colors.red,
                      ),
                      onPressed: () => _handleDelete(f["id"] as int),
                      tooltip: "Supprimer",
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 6),
              Text(
                "${_montantFormat.format(montant)} Ar",
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: Colors.green.shade900,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 13,
                    color: Colors.green.shade600,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    f["dateFinancement"]?.toString() ?? "—",
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green.shade800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                f["programmeNom"]?.toString() ??
                    _programmeNom(f["programmeId"]),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.green.shade800,
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
/// `bg-white/60 backdrop-blur-md rounded-2xl border border-white/40`.
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
