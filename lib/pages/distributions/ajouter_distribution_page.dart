import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/api_client.dart';
import '../../services/distribution_service.dart';
import '../../widgets/app_layout.dart';

class AjouterDistributionPage extends StatefulWidget {
  const AjouterDistributionPage({super.key});

  @override
  State<AjouterDistributionPage> createState() =>
      _AjouterDistributionPageState();
}

class _AjouterDistributionPageState extends State<AjouterDistributionPage> {
  final _formKey = GlobalKey<FormState>();
  final _distributionService = DistributionService();

  bool _loading = false;
  bool _argsLoaded = false;

  int? _demandeId;
  String? _agriculteurNom;
  String? _programmeTitre;

  final _montantCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _preuveCtrl = TextEditingController();
  DateTime? _dateDistribution;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_argsLoaded) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map) {
        _demandeId = args['demandeId'] is int
            ? args['demandeId'] as int
            : int.tryParse(args['demandeId']?.toString() ?? "");
        _agriculteurNom = args['agriculteurNom']?.toString();
        _programmeTitre = args['programmeTitre']?.toString();
      }
      _argsLoaded = true;
    }
  }

  @override
  void dispose() {
    _montantCtrl.dispose();
    _descriptionCtrl.dispose();
    _preuveCtrl.dispose();
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

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateDistribution ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _dateDistribution = picked);
    }
  }

  Future<void> _handleSubmit() async {
    if (_demandeId == null) {
      _showSnack("Aucune demande sélectionnée.", erreur: true);
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    if (_dateDistribution == null) {
      _showSnack("Veuillez choisir une date de distribution", erreur: true);
      return;
    }

    setState(() => _loading = true);
    try {
      final session = await ApiClient().getSession();

      await _distributionService.createDistribution({
        "demandeId": _demandeId,
        "montant": num.tryParse(_montantCtrl.text) ?? 0,
        "dateDistribution": DateFormat("yyyy-MM-dd").format(_dateDistribution!),
        "description": _descriptionCtrl.text,
        "preuveDistribution": _preuveCtrl.text,
        "agentId": session?.id,
      });

      _showSnack("Distribution enregistrée avec succès");
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      _showSnack(
        "Erreur lors de l'enregistrement : ${e.message}",
        erreur: true,
      );
    } catch (_) {
      _showSnack("Erreur lors de l'enregistrement", erreur: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppLayout(
      currentRoute: "/distributions",
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.6),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withOpacity(0.4)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icon(
                          Icons.arrow_back,
                          size: 16,
                          color: Colors.green.shade800,
                        ),
                        label: Text(
                          "Retour",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade800,
                            fontSize: 13,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          alignment: Alignment.centerLeft,
                        ),
                      ),
                    ),
                    _buildHeader(),
                    const SizedBox(height: 20),
                    _buildDemandeInfo(),
                    const SizedBox(height: 8),
                    _label("Montant Distribué (Ar)"),
                    _champTexte(
                      _montantCtrl,
                      hint: "Ex: 500000",
                      required: true,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _label("Date de Distribution"),
                    InkWell(
                      onTap: _pickDate,
                      child: InputDecorator(
                        decoration: _decoration(""),
                        child: Text(
                          _dateDistribution != null
                              ? DateFormat(
                                  "d MMMM yyyy",
                                  "fr_FR",
                                ).format(_dateDistribution!)
                              : "Sélectionner une date",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _dateDistribution != null
                                ? Colors.green.shade900
                                : Colors.green.shade800.withOpacity(0.4),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _label("Description"),
                    _champTexte(
                      _descriptionCtrl,
                      hint:
                          "Détails sur la remise du matériel, des semences ou fonds...",
                      required: true,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    _label("Preuve de Distribution"),
                    _champTexte(
                      _preuveCtrl,
                      hint: "Référence ou URL du justificatif",
                    ),
                    const SizedBox(height: 20),
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
                                Text("Enregistrement..."),
                              ],
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.inventory_2_outlined, size: 16),
                                SizedBox(width: 8),
                                Text(
                                  "Valider la Distribution",
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.green.shade700,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.eco, color: Colors.white, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          "Distribution d'Aide",
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: Colors.green.shade900,
          ),
        ),
      ],
    );
  }

  Widget _buildDemandeInfo() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.green.shade50.withOpacity(0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "DEMANDE CONCERNÉE",
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
              color: Colors.green.shade800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "Demande #${_demandeId ?? '—'}",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.green.shade900,
            ),
          ),
          if (_agriculteurNom != null && _agriculteurNom!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text.rich(
                TextSpan(
                  style: TextStyle(fontSize: 12, color: Colors.green.shade700),
                  children: [
                    const TextSpan(text: "Agriculteur : "),
                    TextSpan(
                      text: _agriculteurNom,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ),
          if (_programmeTitre != null && _programmeTitre!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text.rich(
                TextSpan(
                  style: TextStyle(fontSize: 12, color: Colors.green.shade700),
                  children: [
                    const TextSpan(text: "Programme : "),
                    TextSpan(
                      text: _programmeTitre,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
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

  InputDecoration _decoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 13),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
  }

  Widget _champTexte(
    TextEditingController controller, {
    String? hint,
    bool required = false,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: _decoration(hint ?? ""),
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
