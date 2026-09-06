import 'package:flutter/material.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:html' as html
    if (dart.library.io) 'dart:io'; // import conditionnel
import 'package:path_provider/path_provider.dart';

import '../../core/api_client.dart';
import '../../widgets/app_layout.dart';

// =====================================================================
// MODÈLES
// =====================================================================
class DashboardStats {
  final int agriculteurs;
  final int agriculteursTous;
  final int programmes;
  final int distributions;
  final double montantTotalFinancement;
  final List<RegionData> analyseRegionale;

  DashboardStats({
    required this.agriculteurs,
    required this.agriculteursTous,
    required this.programmes,
    required this.distributions,
    required this.montantTotalFinancement,
    required this.analyseRegionale,
  });

  factory DashboardStats.fromJson(Map<String, dynamic> json) {
    return DashboardStats(
      agriculteurs: json['agriculteurs'] ?? 0,
      agriculteursTous: json['agriculteursTous'] ?? 0,
      programmes: json['programmes'] ?? 0,
      distributions: json['distributions'] ?? 0,
      montantTotalFinancement: (json['montantTotalFinancement'] ?? 0)
          .toDouble(),
      analyseRegionale: (json['analyseRegionale'] as List<dynamic>? ?? [])
          .map((e) => RegionData.fromJson(e))
          .toList(),
    );
  }
}

class RegionData {
  final String nomRegion;
  final int totalActifs;

  RegionData({required this.nomRegion, required this.totalActifs});

  factory RegionData.fromJson(Map<String, dynamic> json) {
    return RegionData(
      nomRegion: json['nomRegion'] ?? 'Région inconnue',
      totalActifs: json['totalActifs'] ?? 0,
    );
  }
}

// =====================================================================
// PAGE DASHBOARD
// =====================================================================
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final ApiClient _api = ApiClient();

  DashboardStats? _stats;
  bool _loading = true;
  bool _exportLoading = false;

  String _role = '';
  String? _regionNom;

  bool get _isAdmin => _role == 'ADMIN_NATIONAL';
  bool get _isResponsable => _role == 'RESPONSABLE_REGIONAL';

  @override
  void initState() {
    super.initState();
    _initialiser();
  }

  Future<void> _initialiser() async {
    final session = await ApiClient().getSession();
    setState(() {
      _role = session?.role ?? '';
      _regionNom = session?.regionNom;
    });
    await _chargerDashboard();
  }

  Future<void> _chargerDashboard() async {
    setState(() => _loading = true);
    try {
      final data = await _api.get("/dashboard");
      setState(() {
        _stats = DashboardStats.fromJson(data);
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showToast(e.message, isError: true);
      if (e.statusCode == 401 || e.statusCode == 403) {
        Navigator.pushReplacementNamed(context, "/");
      }
    } catch (e) {
      setState(() => _loading = false);
      _showToast("Impossible de charger les statistiques", isError: true);
    }
  }

  Future<void> _handleExportPDF() async {
    setState(() => _exportLoading = true);
    _showToast("Génération du rapport PDF en cours...");
    try {
      final bytes = await _api.getBytes("/rapports/national/pdf");
      final now = DateTime.now().toIso8601String().substring(0, 10);
      final nomFichier = 'rapport-agricole-national-$now.pdf';

      if (kIsWeb) {
        final blob = html.Blob([bytes], 'application/pdf');
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.document.createElement('a') as html.AnchorElement
          ..href = url
          ..setAttribute('download', nomFichier)
          ..click();
        html.Url.revokeObjectUrl(url);
      } else {
        final dir = await getApplicationDocumentsDirectory();
        final file = File('${dir.path}/$nomFichier');
        await file.writeAsBytes(bytes);
        _showToast("Rapport sauvegardé : ${file.path}");
        return;
      }

      _showToast("Rapport téléchargé avec succès.");
    } on ApiException catch (e) {
      _showToast(e.message, isError: true);
    } catch (e) {
      _showToast("Impossible de générer le rapport PDF", isError: true);
    } finally {
      if (mounted) setState(() => _exportLoading = false);
    }
  }

  Future<void> _handleExportPDFRegional() async {
    setState(() => _exportLoading = true);
    _showToast("Génération du rapport PDF en cours...");
    try {
      final bytes = await _api.getBytes("/rapports/regional/pdf");
      final now = DateTime.now().toIso8601String().substring(0, 10);
      final nomFichier = 'rapport-agricole-regional-$now.pdf';

      if (kIsWeb) {
        final blob = html.Blob([bytes], 'application/pdf');
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.document.createElement('a') as html.AnchorElement
          ..href = url
          ..setAttribute('download', nomFichier)
          ..click();
        html.Url.revokeObjectUrl(url);
      } else {
        final dir = await getApplicationDocumentsDirectory();
        final file = File('${dir.path}/$nomFichier');
        await file.writeAsBytes(bytes);
        _showToast("Rapport sauvegardé : ${file.path}");
        return;
      }

      _showToast("Rapport téléchargé avec succès.");
    } on ApiException catch (e) {
      _showToast(e.message, isError: true);
    } catch (e) {
      _showToast("Impossible de générer le rapport PDF", isError: true);
    } finally {
      if (mounted) setState(() => _exportLoading = false);
    }
  }

  void _showToast(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade600 : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: isError ? 4 : 3),
      ),
    );
  }

  String _formatMontant(double montant) {
    if (montant >= 1000000000) {
      return "${(montant / 1000000000).toStringAsFixed(1)}Mrd";
    } else if (montant >= 1000000) {
      return "${(montant / 1000000).toStringAsFixed(1)}M";
    } else if (montant >= 1000) {
      return "${(montant / 1000).toStringAsFixed(0)}K";
    }
    return montant.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return AppLayout(
        currentRoute: "/dashboard",
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Color(0xFF16A34A)),
              SizedBox(height: 16),
              Text(
                "Analyse des données...",
                style: TextStyle(
                  color: Color(0xFF14532D),
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_stats == null) {
      return AppLayout(
        currentRoute: "/dashboard",
        child: Center(
          child: Container(
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.7),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "Échec de synchronisation",
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Impossible de se connecter aux données.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF14532D)),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _chargerDashboard,
                  child: const Text("Réessayer"),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final stats = _stats!;
    final totalEngagements = stats.programmes + stats.distributions;
    final tauxProgrammes = totalEngagements > 0
        ? (stats.programmes / totalEngagements * 100).round()
        : 0;
    final tauxDistributions = totalEngagements > 0
        ? (stats.distributions / totalEngagements * 100).round()
        : 0;

    return AppLayout(
      currentRoute: "/dashboard",
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text(
              _isResponsable
                  ? "Analyse & Indicateurs Régionaux"
                  : "Analyse & Indicateurs Nationaux",
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Color(0xFF14532D),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _isResponsable
                  ? "Aperçu analytique régional${_regionNom != null ? " ($_regionNom)" : ""}, synchronisé avec PostgreSQL."
                  : "Aperçu analytique national synchronisé avec PostgreSQL.",
              style: TextStyle(
                fontSize: 12,
                color: Colors.green.shade800.withOpacity(0.8),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 24),

            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.4,
              children: [
                _KpiCard(
                  label: "Producteurs actifs",
                  value: "${stats.agriculteurs}",
                  subtitle: "sur ${stats.agriculteursTous} inscrits",
                  icon: Icons.people,
                ),
                _KpiCard(
                  label: "Programmes d'aide",
                  value: "${stats.programmes}",
                  subtitle: "Subventions actives",
                  icon: Icons.eco,
                ),
                _KpiCard(
                  label: "Distributions",
                  value: "${stats.distributions}",
                  subtitle: "Campagnes terminées",
                  icon: Icons.inventory_2,
                ),
                _KpiCard(
                  label: "Financements",
                  value: _formatMontant(stats.montantTotalFinancement),
                  subtitle: _isResponsable ? "Ariary (national)" : "Ariary",
                  icon: Icons.attach_money,
                  subtitleColor: const Color(0xFF92400E),
                  subtitleBg: const Color(0xFFFEF3C7),
                ),
              ],
            ),
            const SizedBox(height: 20),

            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.pie_chart, color: Color(0xFF14532D), size: 20),
                      SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          "Répartition des actions enregistrées",
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF14532D),
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _BarRow(
                    label: "Part des Programmes d'Aides",
                    pct: tauxProgrammes,
                  ),
                  const SizedBox(height: 14),
                  _BarRow(
                    label: "Part des Distributions Concrètes",
                    pct: tauxDistributions,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.map, color: Color(0xFF14532D), size: 20),
                      SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          "Densité Régionale (Bénéficiaires Actifs)",
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF14532D),
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  stats.analyseRegionale.isEmpty
                      ? Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.green.shade200),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Center(
                            child: Text(
                              "Aucun bénéficiaire actif répertorié.",
                              style: TextStyle(
                                color: Color(0xFF4B5563),
                                fontSize: 13,
                              ),
                            ),
                          ),
                        )
                      : GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 10,
                                mainAxisSpacing: 10,
                                childAspectRatio: 2.2,
                              ),
                          itemCount: stats.analyseRegionale.length,
                          itemBuilder: (context, index) {
                            final region = stats.analyseRegionale[index];
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.4),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      region.nomRegion,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                        color: Color(0xFF14532D),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF15803D),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      "${region.totalActifs} actifs",
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Export PDF — admin national et responsable régional ────
            if (_isAdmin || _isResponsable)
              _Card(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.description,
                                color: Color(0xFF14532D),
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  _isAdmin
                                      ? "Génération de Rapports Agricoles Nationaux"
                                      : "Génération de Rapport Régional",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF14532D),
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _isAdmin
                                ? "Extraction automatisée des données pour archivage légal."
                                : "Extraction automatisée des indicateurs de votre région.",
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF15803D),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _exportLoading
                          ? null
                          : (_isAdmin
                              ? _handleExportPDF
                              : _handleExportPDFRegional),
                      icon: _exportLoading
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.download, size: 16),
                      label: const Text("PDF"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF14532D),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// =====================================================================
// WIDGETS RÉUTILISABLES
// =====================================================================
class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color? subtitleColor;
  final Color? subtitleBg;

  const _KpiCard({
    required this.label,
    required this.value,
    required this.subtitle,
    required this.icon,
    this.subtitleColor,
    this.subtitleBg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF15803D),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Color(0xFF15803D),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Colors.white, size: 16),
              ),
            ],
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: Color(0xFF14532D),
            ),
          ),
          Container(
            padding: subtitleBg != null
                ? const EdgeInsets.symmetric(horizontal: 6, vertical: 2)
                : EdgeInsets.zero,
            decoration: subtitleBg != null
                ? BoxDecoration(
                    color: subtitleBg,
                    borderRadius: BorderRadius.circular(6),
                  )
                : null,
            child: Text(
              subtitle,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: subtitleColor ?? const Color(0xFF15803D),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BarRow extends StatelessWidget {
  final String label;
  final int pct;

  const _BarRow({required this.label, required this.pct});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF14532D),
                ),
              ),
            ),
            Text(
              "$pct%",
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF14532D),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: pct / 100,
            minHeight: 10,
            backgroundColor: const Color(0xFF14532D).withOpacity(0.1),
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF15803D)),
          ),
        ),
      ],
    );
  }
}