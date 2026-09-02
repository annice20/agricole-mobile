import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../widgets/app_layout.dart';
import '../../services/notification_service.dart';

class RappelAdministratifPage extends StatefulWidget {
  const RappelAdministratifPage({super.key});

  @override
  State<RappelAdministratifPage> createState() =>
      _RappelAdministratifPageState();
}

class _RappelAdministratifPageState extends State<RappelAdministratifPage> {
  final _formKey = GlobalKey<FormState>();
  final _notificationService = NotificationService();

  final _titreCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();

  Session? _session;
  bool _verificationSession = true;
  bool _loading = false;
  DateTime? _dateEcheance;

  @override
  void initState() {
    super.initState();
    _verifierAcces();
  }

  @override
  void dispose() {
    _titreCtrl.dispose();
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

  Future<void> _verifierAcces() async {
    final session = await ApiClient().getSession();
    // Accès réservé au Responsable régional côté mobile (l'Administrateur
    // national reste exclusivement sur le web, cf. choix de conception acté).
    if (session == null || session.role != 'RESPONSABLE_REGIONAL') {
      _showSnack('Accès réservé aux responsables régionaux.', erreur: true);
      if (mounted) Navigator.pushReplacementNamed(context, '/dashboard');
      return;
    }
    setState(() {
      _session = session;
      _verificationSession = false;
    });
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateEcheance ?? now,
      firstDate: now,
      lastDate: DateTime(now.year + 5),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(primary: Colors.green.shade700),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _dateEcheance = picked);
    }
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      final echeanceTexte = _dateEcheance != null
          ? ' — échéance : ${_formatDate(_dateEcheance!)}'
          : '';
      final description = _descriptionCtrl.text.trim();
      final messageFinal =
          '[Rappel] ${_titreCtrl.text}${description.isNotEmpty ? ' : $description' : ''}$echeanceTexte';

      await _notificationService.creerNotification(_session!.id, messageFinal);

      _showSnack('Rappel configuré avec succès');
      _titreCtrl.clear();
      _descriptionCtrl.clear();
      setState(() => _dateEcheance = null);
    } on ApiException catch (e) {
      _showSnack('Erreur : ${e.message}', erreur: true);
    } catch (_) {
      _showSnack('Erreur lors de la création du rappel', erreur: true);
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

  InputDecoration _inputDecoration({String? hint}) => InputDecoration(
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

  @override
  Widget build(BuildContext context) {
    if (_verificationSession) {
      return AppLayout(
        currentRoute: '/rappel-administratif',
        child: Center(
          child: CircularProgressIndicator(color: Colors.green.shade700),
        ),
      );
    }

    return AppLayout(
      currentRoute: '/rappel-administratif',
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
                    // Header
                    Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green.shade700,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.notifications_active,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Configurer un rappel administratif',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: Colors.green.shade900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Créez un pense-bête pour vous-même concernant une '
                          'tâche administrative à ne pas oublier.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.green.shade700.withOpacity(0.8),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    _label("Objet du rappel"),
                    TextFormField(
                      controller: _titreCtrl,
                      decoration: _inputDecoration(
                        hint: 'Ex : Relancer la distribution des semences',
                      ),
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

                    _label("Détails (optionnel)"),
                    TextFormField(
                      controller: _descriptionCtrl,
                      maxLines: 3,
                      decoration: _inputDecoration(
                        hint: 'Précisez le contexte, le dossier concerné...',
                      ),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.green.shade900,
                      ),
                    ),
                    const SizedBox(height: 16),

                    _label("Date d'échéance (optionnel)"),
                    InkWell(
                      onTap: _pickDate,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 16,
                              color: Colors.green.shade700,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              _dateEcheance != null
                                  ? _formatDate(_dateEcheance!)
                                  : 'Choisir une date',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: _dateEcheance != null
                                    ? Colors.green.shade900
                                    : Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ),
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
                                Text('Enregistrement...'),
                              ],
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.send, size: 16),
                                SizedBox(width: 8),
                                Text(
                                  'Configurer le rappel',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                    ),
                    const SizedBox(height: 8),

                    TextButton(
                      onPressed: () =>
                          Navigator.pushNamed(context, '/notifications'),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.notifications_outlined,
                            size: 14,
                            color: Colors.green.shade800,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Voir mes rappels dans Notifications',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.green.shade800,
                            ),
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
}
