import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart'; // Pour charger les symboles régionaux (fr_FR)

import '../../core/api_client.dart';
import '../../models/aide_model.dart';
import '../../services/distribution_service.dart';
import '../../widgets/app_layout.dart';

class MesAidesPage extends StatefulWidget {
  const MesAidesPage({super.key});

  @override
  State<MesAidesPage> createState() => _MesAidesPageState();
}

class _MesAidesPageState extends State<MesAidesPage> {
  final ApiClient _apiClient = ApiClient();
  final DistributionService _distributionService = DistributionService();

  List<Aide> _aides = [];
  bool _loading = true;
  String _agriculteurNom = "";
  String? _idCible;
  String? _idFromUrl;
  String? _agriNomFromState;
  bool _argsLoaded = false;

  // Formateur de devises avec locale spécifiée
  late final NumberFormat _currencyFormat;

  @override
  void initState() {
    super.initState();
    // Initialisation synchrone / asynchrone sécurisée de la locale fr_FR
    _initLocaleAndData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_argsLoaded) {
      // On lit les paramètres depuis l'URL elle-même (settings.name), pas
      // depuis `arguments` : `arguments` ne survit pas à un rechargement
      // complet de la page (F5) en Flutter Web, contrairement à l'URL.
      final settings = ModalRoute.of(context)?.settings;
      final uri = Uri.tryParse(settings?.name ?? '');
      if (uri != null) {
        _idFromUrl = uri.queryParameters['agriculteurId'];
        _agriNomFromState = uri.queryParameters['agriNom'];
      }
      _argsLoaded = true;
    }
  }

  Future<void> _initLocaleAndData() async {
    try {
      await initializeDateFormatting('fr_FR', null);
    } catch (_) {
      // Ignorer si la locale est déjà chargée
    }
    _currencyFormat = NumberFormat('#,##0', 'fr_FR');
    await _initSessionAndFetch();
  }

  Future<void> _initSessionAndFetch() async {
    final session = await _apiClient.getSession();

    if (!mounted) return;

    if (session == null) {
      Navigator.of(context).pushReplacementNamed('/');
      return;
    }

    if (_idFromUrl != null) {
      _idCible = _idFromUrl;
      _agriculteurNom = _agriNomFromState ?? "";
    } else {
      _idCible = session.id.toString();
      _agriculteurNom =
          _agriNomFromState ??
          "${session.nom ?? ''} ${session.prenom ?? ''}".trim();
    }

    if (_idCible != null) {
      await _chargerAides(_idCible!);
    } else {
      if (mounted) {
        setState(() => _loading = false);
        _showToast("Identifiant de l'agriculteur introuvable.", isError: true);
      }
    }
  }

  Future<void> _chargerAides(String id) async {
    try {
      final data = await _distributionService.getMesAides(id);
      if (!mounted) return;

      setState(() {
        _aides = data;
        _loading = false;
      });
    } on ApiException catch (apiError) {
      if (!mounted) return;

      setState(() => _loading = false);
      _showToast(apiError.message, isError: true);

      if (apiError.statusCode == 401 || apiError.statusCode == 403) {
        await _apiClient.clearSession();
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/');
        }
      }
    } catch (error) {
      if (!mounted) return;

      setState(() => _loading = false);
      _showToast("Erreur lors du chargement des aides", isError: true);
    }
  }

  void _showToast(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
      ),
    );
  }

  double get _montantTotalRecu {
    return _aides.fold(0.0, (sum, aide) => sum + aide.montant);
  }

  bool get _estProprietaire => _idFromUrl == null;

  @override
  Widget build(BuildContext context) {
    const textDark = Color(0xFF052E16);
    const textGreenDark = Color(0xFF14532D);

    return AppLayout(
      currentRoute: '/mes-aides',
      child: _loading
          ? Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.all(40),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white.withOpacity(0.2)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            textGreenDark,
                          ),
                          strokeWidth: 4,
                        ),
                        SizedBox(height: 16),
                        Text(
                          "Extraction des allocations...",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: textGreenDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- TITRE ET EN-TÊTE DYNAMIQUE ---
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _estProprietaire
                                ? const Text(
                                    "Mes Aides",
                                    style: TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.w900,
                                      color: textGreenDark,
                                      letterSpacing: -0.5,
                                    ),
                                  )
                                : RichText(
                                    text: TextSpan(
                                      text: "Aides versées à : ",
                                      style: const TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.w900,
                                        color: textGreenDark,
                                        letterSpacing: -0.5,
                                      ),
                                      children: [
                                        TextSpan(
                                          text: _agriculteurNom.isNotEmpty
                                              ? _agriculteurNom
                                              : "l'agriculteur",
                                          style: const TextStyle(
                                            color: Color(0xFF15803D),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                            const SizedBox(height: 4),
                            Text(
                              _estProprietaire
                                  ? "Suivi de l'ensemble des subventions et dotations matérielles qui vous ont été versées."
                                  : "Suivi de l'ensemble des subventions et dotations matérielles versées à ce producteur.",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: textGreenDark.withOpacity(0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // --- CARTE KPI TOTAL DISTRIBUÉ (étirée pleine largeur) ---
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.4),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF15803D),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.attach_money,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "TOTAL DISTRIBUÉ",
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF166534),
                                    letterSpacing: 1.1,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.baseline,
                                  textBaseline: TextBaseline.alphabetic,
                                  children: [
                                    Text(
                                      _currencyFormat.format(_montantTotalRecu),
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w900,
                                        color: textDark,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(
                                          0xFFFEF08A,
                                        ).withOpacity(0.3),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        "MGA",
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF92400E),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // --- TABLEAU DES ALLOCATIONS (colonnes flexibles, pleine largeur) ---
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.4),
                          ),
                        ),
                        child: _aides.isEmpty
                            ? _buildEmptyState()
                            : _buildFlexTable(textGreenDark, textDark),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  /// Tableau à colonnes flexibles (Table + FlexColumnWidth) qui s'étire
  /// pour remplir toute la largeur disponible, contrairement à DataTable
  /// qui se dimensionne toujours à son contenu.
  Widget _buildFlexTable(Color textGreenDark, Color textDark) {
    const columnWidths = <int, TableColumnWidth>{
      0: FlexColumnWidth(2.5), // Programme
      1: FlexColumnWidth(2), // Montant
      2: FlexColumnWidth(3.5), // Description
      3: FlexColumnWidth(2), // Date
    };

    return Table(
      columnWidths: columnWidths,
      children: [
        TableRow(
          decoration: BoxDecoration(color: textGreenDark.withOpacity(0.05)),
          children: [
            _headerCell(Icons.eco, 'Programme', textGreenDark),
            _headerCell(
              Icons.attach_money,
              'Montant Allocation',
              textGreenDark,
            ),
            _headerCell(
              Icons.info_outline,
              'Description / Spécifications',
              textGreenDark,
            ),
            _headerCell(Icons.calendar_today, "Date d'octroi", textGreenDark),
          ],
        ),
        for (final aide in _aides)
          TableRow(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: textGreenDark.withOpacity(0.08)),
              ),
            ),
            children: [
              _dataCell(
                Text(
                  aide.demandeAide?.programme?.nom ?? "Programme Général",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: textGreenDark,
                  ),
                ),
              ),
              _dataCell(
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _currencyFormat.format(aide.montant),
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: textGreenDark,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      "Ariary",
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF15803D),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              _dataCell(
                Text(
                  aide.description ?? "Aucune description spécifiée",
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                  style: TextStyle(color: textDark.withOpacity(0.9)),
                ),
              ),
              _dataCell(
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF15803D).withOpacity(0.1),
                      border: Border.all(
                        color: const Color(0xFF15803D).withOpacity(0.2),
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      aide.dateDistribution != null
                          ? DateFormat(
                              'd MMMM yyyy',
                              'fr_FR',
                            ).format(aide.dateDistribution!)
                          : "Date inconnue",
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF166534),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _headerCell(IconData icon, String label, Color color) {
    return TableCell(
      verticalAlignment: TableCellVerticalAlignment.middle,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: TextStyle(fontWeight: FontWeight.bold, color: color),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dataCell(Widget child) {
    return TableCell(
      verticalAlignment: TableCellVerticalAlignment.middle,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: child,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32.0, horizontal: 16.0),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 40,
              color: const Color(0xFF15803D).withOpacity(0.4),
            ),
            const SizedBox(height: 12),
            Text(
              "Aucune aide enregistrée ou validée pour cet agriculteur.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: const Color(0xFF166534).withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
