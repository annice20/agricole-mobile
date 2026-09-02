import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/api_client.dart';
import '../../services/distribution_service.dart';
import '../../widgets/app_layout.dart';

class ListeDistributionsPage extends StatefulWidget {
  const ListeDistributionsPage({super.key});

  @override
  State<ListeDistributionsPage> createState() => _ListeDistributionsPageState();
}

class _ListeDistributionsPageState extends State<ListeDistributionsPage> {
  final DistributionService _service = DistributionService();

  List<dynamic> _distributions = [];
  bool _loading = true;
  String _search = "";

  Session? _session;
  bool get _isResponsable => _session?.role == 'RESPONSABLE_REGIONAL';

  final _montantFormat = NumberFormat("#,##0", "fr_FR");
  final _dateFormat = DateFormat("d MMMM yyyy", "fr_FR");

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final session = await ApiClient().getSession();
    setState(() => _session = session);
    await _fetchDistributions();
  }

  Future<void> _fetchDistributions() async {
    setState(() => _loading = true);
    try {
      final data = (_isResponsable && _session?.regionId != null)
          ? await _service.getDistributionsParRegion(_session!.regionId!)
          : await _service.getDistributions();
      setState(() => _distributions = data);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Impossible de charger les distributions"),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ---------------------------------------------------------------
  // HELPERS
  // ---------------------------------------------------------------

  Map<String, dynamic>? _agriculteur(Map d) =>
      d["demandeAide"]?["agriculteur"] as Map<String, dynamic>?;

  String _agriculteurNom(Map d) {
    final a = _agriculteur(d);
    if (a == null) return "—";
    final prenom = a["prenom"] ?? "";
    final nom = a["nom"] ?? "";
    final full = "$prenom $nom".trim();
    return full.isEmpty ? "—" : full;
  }

  String _programmeTitre(Map d) =>
      d["demandeAide"]?["programme"]?["titre"]?.toString() ?? "—";

  String _formatMontant(dynamic montant) {
    final value = double.tryParse(montant?.toString() ?? "0") ?? 0;
    return _montantFormat.format(value);
  }

  String _formatDate(dynamic dateStr) {
    if (dateStr == null) return "—";
    try {
      return _dateFormat.format(DateTime.parse(dateStr.toString()));
    } catch (_) {
      return "—";
    }
  }

  List<dynamic> get _filtered {
    if (_search.trim().isEmpty) return _distributions;
    final q = _search.toLowerCase();
    return _distributions.where((d) {
      final map = d as Map;
      return _agriculteurNom(map).toLowerCase().contains(q) ||
          _programmeTitre(map).toLowerCase().contains(q) ||
          (map["description"]?.toString().toLowerCase() ?? "").contains(q);
    }).toList();
  }

  double get _montantTotal => _distributions.fold(
    0.0,
    (sum, d) => sum + (double.tryParse(d["montant"]?.toString() ?? "0") ?? 0),
  );

  int get _distributionsCeMois {
    final debutMois = DateTime(DateTime.now().year, DateTime.now().month, 1);
    return _distributions.where((d) {
      final dateStr = d["dateDistribution"];
      if (dateStr == null) return false;
      final date = DateTime.tryParse(dateStr.toString());
      return date != null && !date.isBefore(debutMois);
    }).length;
  }

  int get _agriculteursUniques {
    final ids = <dynamic>{};
    for (final d in _distributions) {
      final id = _agriculteur(d as Map)?["id"];
      if (id != null) ids.add(id);
    }
    return ids.length;
  }

  // ---------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return AppLayout(
      currentRoute: "/distributions",
      child: RefreshIndicator(
        onRefresh: _fetchDistributions,
        color: Colors.green.shade800,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildHeader(),
                  const SizedBox(height: 16),
                  _buildStatsGrid(),
                  const SizedBox(height: 16),
                  _buildSearchBar(),
                  const SizedBox(height: 16),
                  if (_filtered.isEmpty)
                    _buildEmptyState()
                  else
                    ..._filtered.map((d) => _buildDistributionCard(d as Map)),
                ],
              ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Suivi des distributions",
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: Colors.green.shade900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _isResponsable
              ? "Historique des aides distribuées dans votre région${_session?.regionNom != null ? " (${_session!.regionNom})" : ""}."
              : "Historique complet des aides effectivement distribuées aux agriculteurs.",
          style: TextStyle(
            fontSize: 13,
            color: Colors.green.shade800.withOpacity(0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsGrid() {
    final stats = [
      ("Total distributions", "${_distributions.length}", null),
      ("Montant total distribué", _formatMontant(_montantTotal), "Ar"),
      ("Distributions ce mois", "$_distributionsCeMois", null),
      ("Agriculteurs bénéficiaires", "$_agriculteursUniques", null),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: stats
          .map(
            (s) => _GlassCard(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      s.$1,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade800,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            s.$2,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: Colors.green.shade900,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (s.$3 != null) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.amber.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              s.$3!,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.amber.shade900,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          )
          .toList(),
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
                  hintText:
                      "Rechercher par agriculteur, programme ou description...",
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
            "Aucune distribution trouvée.",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.green.shade800.withOpacity(0.6),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDistributionCard(Map d) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _GlassCard(
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _showDetailSheet(d),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _agriculteurNom(d),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Colors.green.shade900,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.remove_red_eye_outlined,
                      size: 18,
                      color: Colors.green.shade700,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
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
                    _programmeTitre(d),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.green.shade800,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.attach_money,
                          size: 14,
                          color: Colors.green.shade700,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          "${_formatMontant(d["montant"])} Ar",
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: Colors.green.shade900,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 13,
                          color: Colors.green.shade700,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatDate(d["dateDistribution"]),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.green.shade800.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                if (d["preuveDistribution"] != null &&
                    d["preuveDistribution"].toString().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.description_outlined,
                          size: 12,
                          color: Colors.green.shade800,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          d["preuveDistribution"].toString(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.green.shade900,
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
      ),
    );
  }

  void _showDetailSheet(Map d) {
    final a = _agriculteur(d);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _DistributionDetailSheet(
        agriculteurNom: _agriculteurNom(d),
        telephone: a?["telephone"]?.toString(),
        region: a?["region"]?.toString(),
        programme: _programmeTitre(d),
        montant: "${_formatMontant(d["montant"])} Ar",
        date: _formatDate(d["dateDistribution"]),
        description: d["description"]?.toString(),
        preuve: d["preuveDistribution"]?.toString(),
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

class _DistributionDetailSheet extends StatelessWidget {
  final String agriculteurNom;
  final String? telephone;
  final String? region;
  final String programme;
  final String montant;
  final String date;
  final String? description;
  final String? preuve;

  const _DistributionDetailSheet({
    required this.agriculteurNom,
    this.telephone,
    this.region,
    required this.programme,
    required this.montant,
    required this.date,
    this.description,
    this.preuve,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.95),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Détails de la distribution",
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
            const Divider(height: 24),
            _detailRow(
              Icons.people_outline,
              "Agriculteur bénéficiaire",
              agriculteurNom,
            ),
            if (telephone != null && telephone!.isNotEmpty)
              _detailRow(Icons.phone_outlined, "Téléphone", telephone!),
            if (region != null && region!.isNotEmpty)
              _detailRow(Icons.place_outlined, "Région", region!),
            _detailRow(
              Icons.inventory_2_outlined,
              "Programme d'aide",
              programme,
            ),
            _detailRow(Icons.attach_money, "Montant distribué", montant),
            _detailRow(
              Icons.calendar_today_outlined,
              "Date de distribution",
              date,
            ),
            if (description != null && description!.isNotEmpty)
              _detailRow(
                Icons.description_outlined,
                "Description",
                description!,
              ),
            _detailRow(
              Icons.receipt_long_outlined,
              "Référence / preuve de distribution",
              (preuve != null && preuve!.isNotEmpty)
                  ? preuve!
                  : "Aucune référence fournie",
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.green.shade700),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade800.withOpacity(0.7),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.green.shade900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
