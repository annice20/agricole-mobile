import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../widgets/app_layout.dart';
import '../../services/programme_service.dart';

const Map<String, String> _typeLabels = {
  'FINANCEMENT': 'Financement',
  'SEMENCE': 'Distribution de semences',
  'EQUIPEMENT': 'Matériel agricole',
  'FORMATION': 'Formation technique',
  'SUBVENTION': 'Subvention',
  'IRRIGATION': 'Irrigation',
};

// Mode création si aucun argument, mode modification si {"id": <int>}
// Navigator.pushNamed(context, '/programmes/modifier', arguments: {"id": p['id']});
// Navigator.pushNamed(context, '/programmes/ajouter');
class AjouterModifierProgrammePage extends StatefulWidget {
  const AjouterModifierProgrammePage({super.key});

  @override
  State<AjouterModifierProgrammePage> createState() =>
      _AjouterModifierProgrammePageState();
}

class _AjouterModifierProgrammePageState
    extends State<AjouterModifierProgrammePage> {
  final _formKey = GlobalKey<FormState>();
  final _programmeService = ProgrammeService();

  final _titreCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _budgetCtrl = TextEditingController();
  final _dateDebutCtrl = TextEditingController();
  final _dateFinCtrl = TextEditingController();

  String _typeAide = 'FINANCEMENT';
  bool _actif = true;
  bool _loading = false;
  bool _chargementInitial = true;
  bool _argsLoaded = false;
  int? _programmeId;

  bool get _modeModification => _programmeId != null;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_argsLoaded) {
      final args = ModalRoute.of(context)!.settings.arguments;
      if (args is Map && args['id'] != null) {
        _programmeId = args['id'] as int;
      }
      _argsLoaded = true;
      if (_modeModification) {
        _chargerProgramme();
      } else {
        setState(() => _chargementInitial = false);
      }
    }
  }

  @override
  void dispose() {
    _titreCtrl.dispose();
    _descriptionCtrl.dispose();
    _budgetCtrl.dispose();
    _dateDebutCtrl.dispose();
    _dateFinCtrl.dispose();
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

  Future<void> _chargerProgramme() async {
    try {
      final p = await _programmeService.getById(_programmeId!);
      _titreCtrl.text = p['titre'] ?? '';
      _descriptionCtrl.text = p['description'] ?? '';
      _typeAide = p['typeAide'] ?? 'FINANCEMENT';
      _actif = p['actif'] == true;
      _budgetCtrl.text = p['budget'] != null ? '${p['budget']}' : '';
      _dateDebutCtrl.text = (p['dateDebut'] ?? '').toString().split('T').first;
      _dateFinCtrl.text = (p['dateFin'] ?? '').toString().split('T').first;
    } on ApiException catch (e) {
      _showSnack(
        'Impossible de charger le programme : ${e.message}',
        erreur: true,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      _showSnack('Impossible de charger le programme', erreur: true);
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _chargementInitial = false);
    }
  }

  Future<void> _selectionnerDate(TextEditingController controller) async {
    final now = DateTime.now();
    DateTime initial;
    try {
      initial = controller.text.isNotEmpty
          ? DateTime.parse(controller.text)
          : now;
    } catch (_) {
      initial = now;
    }
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 10),
    );
    if (date != null) {
      controller.text =
          '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    final donnees = <String, dynamic>{
      'titre': _titreCtrl.text,
      'description': _descriptionCtrl.text,
      'typeAide': _typeAide,
      'actif': _actif,
      'budget': _budgetCtrl.text.isNotEmpty
          ? double.tryParse(_budgetCtrl.text)
          : null,
      'dateDebut': _dateDebutCtrl.text.isNotEmpty ? _dateDebutCtrl.text : null,
      'dateFin': _dateFinCtrl.text.isNotEmpty ? _dateFinCtrl.text : null,
    };

    try {
      if (_modeModification) {
        await _programmeService.update(_programmeId!, donnees);
        _showSnack('Programme mis à jour avec succès');
      } else {
        await _programmeService.create(donnees);
        _showSnack('Programme créé avec succès');
      }
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      _showSnack("Échec de l'enregistrement : ${e.message}", erreur: true);
    } catch (_) {
      _showSnack("Échec de l'enregistrement", erreur: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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

  InputDecoration _inputDecoration({String? hint, Widget? suffixIcon}) =>
      InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 13),
        suffixIcon: suffixIcon,
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
      );

  @override
  Widget build(BuildContext context) {
    if (_chargementInitial) {
      return AppLayout(
        currentRoute: '/programmes',
        child: Center(
          child: CircularProgressIndicator(color: Colors.green.shade700),
        ),
      );
    }

    return AppLayout(
      currentRoute: '/programmes',
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
                    Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green.shade700,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            _modeModification ? Icons.edit : Icons.add_circle,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _modeModification
                              ? 'Modifier le programme'
                              : 'Nouveau programme',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: Colors.green.shade900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    _label('Titre du programme'),
                    TextFormField(
                      controller: _titreCtrl,
                      decoration: _inputDecoration(hint: 'Ex : Semences 2026'),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.green.shade900,
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Champ requis'
                          : null,
                    ),
                    const SizedBox(height: 16),

                    _label('Description'),
                    TextFormField(
                      controller: _descriptionCtrl,
                      maxLines: 3,
                      decoration: _inputDecoration(
                        hint: 'Détails du programme...',
                      ),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.green.shade900,
                      ),
                    ),
                    const SizedBox(height: 16),

                    _label("Type d'aide"),
                    DropdownButtonFormField<String>(
                      initialValue: _typeAide,
                      decoration: _inputDecoration(),
                      items: _typeLabels.entries
                          .map(
                            (e) => DropdownMenuItem(
                              value: e.key,
                              child: Text(e.value),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _typeAide = v!),
                    ),
                    const SizedBox(height: 16),

                    _label('Budget (Ar)'),
                    TextFormField(
                      controller: _budgetCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: _inputDecoration(hint: 'Ex : 5000000'),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.green.shade900,
                      ),
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _label('Date de début'),
                              TextFormField(
                                controller: _dateDebutCtrl,
                                readOnly: true,
                                onTap: () => _selectionnerDate(_dateDebutCtrl),
                                decoration: _inputDecoration(
                                  hint: 'AAAA-MM-JJ',
                                  suffixIcon: const Icon(
                                    Icons.calendar_today,
                                    size: 16,
                                  ),
                                ),
                                style: const TextStyle(fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _label('Date de fin'),
                              TextFormField(
                                controller: _dateFinCtrl,
                                readOnly: true,
                                onTap: () => _selectionnerDate(_dateFinCtrl),
                                decoration: _inputDecoration(
                                  hint: 'AAAA-MM-JJ',
                                  suffixIcon: const Icon(
                                    Icons.calendar_today,
                                    size: 16,
                                  ),
                                ),
                                style: const TextStyle(fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                      ],
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
                              'Programme actif et disponible immédiatement',
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
                          : Text(
                              _modeModification
                                  ? 'Enregistrer les modifications'
                                  : 'Créer le programme',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
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
}
