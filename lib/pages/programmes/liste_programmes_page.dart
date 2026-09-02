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

const Map<String, IconData> _typeIcons = {
  'FINANCEMENT': Icons.attach_money,
  'SEMENCE': Icons.eco,
  'EQUIPEMENT': Icons.handyman,
  'FORMATION': Icons.school,
  'SUBVENTION': Icons.receipt_long,
  'IRRIGATION': Icons.water_drop,
};

class ListeProgrammesPage extends StatefulWidget {
  const ListeProgrammesPage({super.key});

  @override
  State<ListeProgrammesPage> createState() => _ListeProgrammesPageState();
}

class _ListeProgrammesPageState extends State<ListeProgrammesPage> {
  final _programmeService = ProgrammeService();
  final _searchCtrl = TextEditingController();

  Session? _session;
  bool _loading = true;
  List<dynamic> _programmes = [];
  String _search = "";
  String? _filterType;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
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

  Future<void> _init() async {
    final session = await ApiClient().getSession();
    if (session == null) {
      if (mounted) Navigator.pushReplacementNamed(context, '/');
      return;
    }
    setState(() => _session = session);
    await _chargerProgrammes();
  }

  Future<void> _chargerProgrammes() async {
    setState(() => _loading = true);
    try {
      final data = await _programmeService.getAll();
      setState(() => _programmes = data);
    } catch (_) {
      _showSnack('Impossible de charger les programmes', erreur: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool get _isResponsable => _session?.role == 'RESPONSABLE_REGIONAL';

  Future<void> _toggleActif(dynamic p) async {
    if (!_isResponsable) {
      _showSnack(
        "Seul le responsable régional peut modifier un programme",
        erreur: true,
      );
      return;
    }
    try {
      await _programmeService.toggleActif(
        p['id'] as int,
        !(p['actif'] == true),
      );
      _showSnack(
        !(p['actif'] == true) ? 'Programme activé' : 'Programme désactivé',
      );
      await _chargerProgrammes();
    } catch (_) {
      _showSnack('Impossible de modifier le statut', erreur: true);
    }
  }

  List<dynamic> get _filtered {
    return _programmes.where((p) {
      final q = _search.toLowerCase();
      final matchSearch =
          (p['titre'] ?? '').toString().toLowerCase().contains(q) ||
          (p['description'] ?? '').toString().toLowerCase().contains(q);
      final matchType = _filterType == null || p['typeAide'] == _filterType;
      return matchSearch && matchType;
    }).toList();
  }

  String _formatDate(dynamic v) {
    if (v == null) return '—';
    try {
      final d = DateTime.parse(v);
      return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    } catch (_) {
      return v.toString();
    }
  }

  String _formatBudget(dynamic b) {
    if (b == null) return '—';
    final n = double.tryParse('$b') ?? 0;
    return '${n.toStringAsFixed(0)} Ar';
  }

  @override
  Widget build(BuildContext context) {
    final actifs = _programmes.where((p) => p['actif'] == true).length;
    final budgetTotal = _programmes.fold<double>(
      0,
      (sum, p) => sum + (double.tryParse('${p['budget'] ?? 0}') ?? 0),
    );

    return AppLayout(
      currentRoute: '/programmes',
      child: RefreshIndicator(
        onRefresh: _chargerProgrammes,
        color: Colors.green.shade700,
        child: _loading
            ? ListView(
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.6,
                    child: Center(
                      child: CircularProgressIndicator(
                        color: Colors.green.shade700,
                      ),
                    ),
                  ),
                ],
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Programmes d'aide",
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: Colors.green.shade900,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Programmes nationaux de soutien agricole.',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Colors.green.shade700.withOpacity(0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_isResponsable)
                        IconButton(
                          tooltip: 'Nouveau programme',
                          onPressed: () async {
                            await Navigator.pushNamed(
                              context,
                              '/programmes/ajouter',
                            );
                            _chargerProgrammes();
                          },
                          icon: Icon(
                            Icons.add_circle,
                            color: Colors.green.shade700,
                            size: 32,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // KPI
                  SizedBox(
                    height: 90,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _kpiCard('Total', '${_programmes.length}'),
                        _kpiCard('Actifs', '$actifs'),
                        _kpiCard('Budget total', _formatBudget(budgetTotal)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Recherche
                  TextField(
                    controller: _searchCtrl,
                    onChanged: (v) => setState(() => _search = v),
                    decoration: InputDecoration(
                      hintText: 'Rechercher un programme...',
                      hintStyle: const TextStyle(fontSize: 13),
                      prefixIcon: Icon(
                        Icons.search,
                        size: 20,
                        color: Colors.green.shade700,
                      ),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.7),
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
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
                        borderSide: BorderSide(
                          color: Colors.green.shade500,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Filtre par type (chips horizontaux)
                  SizedBox(
                    height: 36,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _filterChip('Tous', null),
                        ..._typeLabels.entries.map(
                          (e) => _filterChip(e.value, e.key),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (_filtered.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(32),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        'Aucun programme trouvé.',
                        style: TextStyle(
                          color: Colors.green.shade800.withOpacity(0.6),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  else
                    ..._filtered.map((p) => _programmeCard(p)),
                ],
              ),
      ),
    );
  }

  Widget _filterChip(String label, String? value) {
    final selected = _filterType == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        selected: selected,
        onSelected: (_) => setState(() => _filterType = value),
        selectedColor: Colors.green.shade700,
        labelStyle: TextStyle(
          color: selected ? Colors.white : Colors.green.shade800,
          fontWeight: FontWeight.w600,
        ),
        backgroundColor: Colors.white.withOpacity(0.6),
      ),
    );
  }

  Widget _kpiCard(String label, String value) {
    return Container(
      width: 140,
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(right: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: Colors.green.shade800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: Colors.green.shade900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _programmeCard(dynamic p) {
    final type = p['typeAide'] as String?;
    final label = _typeLabels[type] ?? type ?? '—';
    final icon = _typeIcons[type] ?? Icons.eco;
    final actif = p['actif'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.55),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 12, color: Colors.green.shade800),
                    const SizedBox(width: 4),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.green.shade800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: actif ? Colors.green.shade100 : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  actif ? 'Actif' : 'Inactif',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: actif ? Colors.green.shade800 : Colors.grey.shade600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            p['titre'] ?? '',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Colors.green.shade900,
            ),
          ),
          if ((p['description'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              p['description'],
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: Colors.green.shade800.withOpacity(0.8),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                Icons.calendar_today,
                size: 12,
                color: Colors.green.shade700,
              ),
              const SizedBox(width: 6),
              Text(
                '${_formatDate(p['dateDebut'])} → ${_formatDate(p['dateFin'])}',
                style: TextStyle(fontSize: 11, color: Colors.green.shade700),
              ),
              const SizedBox(width: 16),
              Icon(Icons.attach_money, size: 12, color: Colors.green.shade700),
              const SizedBox(width: 4),
              Text(
                _formatBudget(p['budget']),
                style: TextStyle(fontSize: 11, color: Colors.green.shade700),
              ),
            ],
          ),
          if (_isResponsable) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await Navigator.pushNamed(
                        context,
                        '/programmes/modifier',
                        arguments: {'id': p['id']},
                      );
                      _chargerProgrammes();
                    },
                    icon: const Icon(Icons.edit, size: 14),
                    label: const Text(
                      'Modifier',
                      style: TextStyle(fontSize: 12),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.green.shade800,
                      side: BorderSide(color: Colors.green.shade300),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _toggleActif(p),
                    icon: Icon(
                      actif ? Icons.toggle_off : Icons.toggle_on,
                      size: 16,
                    ),
                    label: Text(
                      actif ? 'Désactiver' : 'Activer',
                      style: const TextStyle(fontSize: 12),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: actif
                          ? Colors.orange.shade700
                          : Colors.green.shade700,
                      side: BorderSide(
                        color: actif
                            ? Colors.orange.shade300
                            : Colors.green.shade300,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
