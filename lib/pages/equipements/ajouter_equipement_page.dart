import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../widgets/app_layout.dart';
import '../../services/equipement_service.dart';

class AjouterEquipementPage extends StatefulWidget {
  const AjouterEquipementPage({super.key});

  @override
  State<AjouterEquipementPage> createState() => _AjouterEquipementPageState();
}

class _AjouterEquipementPageState extends State<AjouterEquipementPage> {
  final _formKey = GlobalKey<FormState>();
  final _equipementService = EquipementService();

  bool _loading = false;

  final _nomCtrl = TextEditingController();
  final _categorieCtrl = TextEditingController();
  final _quantiteCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  bool _actif = true;

  @override
  void dispose() {
    _nomCtrl.dispose();
    _categorieCtrl.dispose();
    _quantiteCtrl.dispose();
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

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      await _equipementService.ajouterEquipement({
        'nom': _nomCtrl.text,
        'categorie': _categorieCtrl.text,
        'quantiteDisponible': int.tryParse(_quantiteCtrl.text) ?? 0,
        'description': _descriptionCtrl.text,
        'actif': _actif,
      });
      _showSnack('Équipement ajouté avec succès');
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      _showSnack("Erreur lors de l'ajout : ${e.message}", erreur: true);
    } catch (_) {
      _showSnack("Erreur lors de l'ajout", erreur: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppLayout(
      currentRoute: '/equipements/ajouter',
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
                    _buildHeader(),
                    const SizedBox(height: 24),
                    _label('Nom de l\'équipement'),
                    _champTexte(
                      _nomCtrl,
                      hint: 'Ex : Tracteur, Motopompe...',
                      required: true,
                    ),
                    const SizedBox(height: 16),
                    _label('Catégorie'),
                    _champTexte(
                      _categorieCtrl,
                      hint: 'Ex : Mécanisation, Irrigation...',
                      required: true,
                    ),
                    const SizedBox(height: 16),
                    _label('Quantité disponible'),
                    _champTexte(
                      _quantiteCtrl,
                      hint: '0',
                      required: true,
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),
                    _label('Description'),
                    _champTexte(
                      _descriptionCtrl,
                      hint:
                          'Description détaillée des spécificités techniques de l\'équipement...',
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
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
                              'Équipement disponible et actif immédiatement',
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
                                Text('Enregistrement...'),
                              ],
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.save, size: 16),
                                SizedBox(width: 8),
                                Text(
                                  "Enregistrer l'équipement",
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
          child: const Icon(Icons.agriculture, color: Colors.white, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          'Ajouter un équipement',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: Colors.green.shade900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Enregistrez un nouvel équipement agricole dans le système de gestion.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            color: Colors.green.shade700.withOpacity(0.8),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
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
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 13),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
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
          ? (v) => (v == null || v.isEmpty) ? 'Champ requis' : null
          : null,
    );
  }
}
