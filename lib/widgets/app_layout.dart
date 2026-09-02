import 'dart:async';
import 'package:flutter/material.dart';
import '../core/api_client.dart';
import '../services/notification_service.dart';

class AppLayout extends StatefulWidget {
  final Widget child;
  final String currentRoute;
  final Function(String)? onNavigate;
  final String? userRole;
  final String? userName;
  final int notifNonLues;
  final VoidCallback? onLogout;

  const AppLayout({
    super.key,
    required this.child,
    required this.currentRoute,
    this.onNavigate,
    this.userRole,
    this.userName,
    this.notifNonLues = 0,
    this.onLogout,
  });

  @override
  State<AppLayout> createState() => _AppLayoutState();
}

class _AppLayoutState extends State<AppLayout> {
  Session? _session;
  bool _sidebarOpen = false;
  int _notifNonLues = 0;

  // Rafraîchissement automatique du compteur de notifications toutes les
  // 30s, même pattern que le useEffect + setInterval de MyNavbar.jsx.
  // Sans ça, la cloche ne se met à jour qu'au remontage du widget (donc
  // au changement de page ou au reload), pas en temps réel.
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _chargerSession();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _chargerSession() async {
    final session = await ApiClient().getSession();
    if (mounted) {
      setState(() => _session = session);
    }
    if (session != null) {
      _chargerNotifications(session.id); // premier appel immédiat
      _pollTimer?.cancel();
      _pollTimer = Timer.periodic(
        const Duration(seconds: 30),
        (_) => _chargerNotifications(session.id),
      );
    }
  }

  Future<void> _chargerNotifications(int utilisateurId) async {
    try {
      final list = await NotificationService().getNotifications(utilisateurId);
      final nonLues = list.where((n) => n['lu'] == false).length;
      if (mounted) {
        setState(() => _notifNonLues = nonLues);
        // Synchronise le notifier global avec le total actuel
        NotificationService.setUnreadCount(nonLues);
      }
    } catch (_) {}
  }

  Future<void> _handleLogout() async {
    if (widget.onLogout != null) {
      widget.onLogout!();
      return;
    }
    await ApiClient().clearSession();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, "/");
  }

  void _navigate(String route) {
    setState(() => _sidebarOpen = false);
    if (widget.onNavigate != null) {
      widget.onNavigate!(route);
    } else if (widget.currentRoute != route) {
      Navigator.pushReplacementNamed(context, route);
    }
  }

  String get _role => widget.userRole ?? _session?.role ?? "";
  bool get _isAdmin => _role == "ADMIN_NATIONAL";
  bool get _isResponsable => _role == "RESPONSABLE_REGIONAL";
  bool get _isAgent => _role == "AGENT_TERRAIN";
  bool get _isAgriculteur => _role == "AGRICULTEUR";

  @override
  Widget build(BuildContext context) {
    final nomAffiche = widget.userName ?? _session?.nom ?? "Utilisateur";
    final countNotifs = widget.notifNonLues > 0
        ? widget.notifNonLues
        : _notifNonLues;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFD1FAE5), Color(0xFF6EE7A8)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _Header(
                userName: nomAffiche,
                userRole: _role,
                notifNonLues: countNotifs,
                onMenuTap: () => setState(() => _sidebarOpen = !_sidebarOpen),
                onNotifTap: () => _navigate("/notifications"),
              ),
              Expanded(
                child: Stack(
                  children: [
                    widget.child,
                    if (_sidebarOpen)
                      GestureDetector(
                        onTap: () => setState(() => _sidebarOpen = false),
                        child: Container(color: Colors.black.withOpacity(0.3)),
                      ),
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeInOut,
                      left: _sidebarOpen ? 0 : -260,
                      top: 0,
                      bottom: 0,
                      width: 260,
                      child: _Sidebar(
                        isAdmin: _isAdmin,
                        isResponsable: _isResponsable,
                        isAgent: _isAgent,
                        isAgriculteur: _isAgriculteur,
                        currentRoute: widget.currentRoute,
                        onNavigate: _navigate,
                        onLogout: _handleLogout,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String userName;
  final String userRole;
  final int notifNonLues;
  final VoidCallback onMenuTap;
  final VoidCallback onNotifTap;

  const _Header({
    required this.userName,
    required this.userRole,
    required this.notifNonLues,
    required this.onMenuTap,
    required this.onNotifTap,
  });

  @override
  Widget build(BuildContext context) {
    final roleFormatted = userRole.replaceAll("_", " ");
    final initiales = userName.length >= 2
        ? userName.substring(0, 2).toUpperCase()
        : userName.toUpperCase();

    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.4),
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.2)),
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.menu, color: Color(0xFF14532D)),
            onPressed: onMenuTap,
            padding: EdgeInsets.zero,
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFF15803D),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.eco, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 8),
          const Text(
            "Plateforme Agricole",
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Color(0xFF14532D),
            ),
          ),
          const Spacer(),
          ValueListenableBuilder<int>(
            valueListenable: NotificationService.unreadCountNotifier,
            builder: (context, countReel, child) {
              // Récupère le nombre en temps réel s'il est défini, sinon utilise notifNonLues
              final count =
                  NotificationService.unreadCountNotifier.value > 0 ||
                      countReel > 0
                  ? countReel
                  : notifNonLues;

              return Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.notifications_outlined,
                      color: Color(0xFF14532D),
                    ),
                    onPressed: onNotifTap,
                  ),
                  if (count > 0)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          count > 9 ? "9+" : "$count",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(width: 4),
          Row(
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    userName,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF14532D),
                    ),
                  ),
                  Text(
                    roleFormatted,
                    style: TextStyle(
                      fontSize: 10,
                      color: const Color(0xFF15803D).withOpacity(0.8),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFF15803D),
                child: Text(
                  initiales,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  final bool isAdmin;
  final bool isResponsable;
  final bool isAgent;
  final bool isAgriculteur;
  final String currentRoute;
  final void Function(String) onNavigate;
  final VoidCallback onLogout;

  const _Sidebar({
    required this.isAdmin,
    required this.isResponsable,
    required this.isAgent,
    required this.isAgriculteur,
    required this.currentRoute,
    required this.onNavigate,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF14532D),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 12,
            offset: Offset(4, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(12, 8, 12, 12),
                    child: Text(
                      "MENU PRINCIPAL",
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF86EFAC),
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  if (isAdmin || isResponsable)
                    _NavItem(
                      icon: Icons.dashboard_outlined,
                      label: "Tableau de bord",
                      route: "/dashboard",
                      currentRoute: currentRoute,
                      onTap: onNavigate,
                    ),
                  if (isAdmin || isAgent || isResponsable)
                    _NavItem(
                      icon: Icons.people_outline,
                      label: "Agriculteurs",
                      route: "/agriculteurs",
                      currentRoute: currentRoute,
                      onTap: onNavigate,
                    ),
                  if (isAdmin || isResponsable)
                    _NavItem(
                      icon: Icons.build_outlined,
                      label: "Équipements",
                      route: "/equipements",
                      currentRoute: currentRoute,
                      onTap: onNavigate,
                    ),
                  if (isResponsable)
                    _NavItem(
                      icon: Icons.handshake_outlined,
                      label: "Bénéficiaires Régionaux",
                      route: "/beneficiaires-regionaux",
                      currentRoute: currentRoute,
                      onTap: onNavigate,
                    ),
                  if (isAdmin || isResponsable || isAgriculteur || isAgent)
                    _NavItem(
                      icon: Icons.eco_outlined,
                      label: "Programmes d'aide",
                      route: "/programmes",
                      currentRoute: currentRoute,
                      onTap: onNavigate,
                    ),
                  if (isAdmin || isResponsable)
                    _NavItem(
                      icon: Icons.account_balance_wallet_outlined,
                      label: "Financements",
                      route: "/financements",
                      currentRoute: currentRoute,
                      onTap: onNavigate,
                    ),
                  if (isAdmin || isResponsable)
                    _NavItem(
                      icon: Icons.warning_amber_outlined,
                      label: "Réclamations",
                      route: "/reclamations",
                      currentRoute: currentRoute,
                      onTap: onNavigate,
                    ),
                  if (isAgent || isResponsable)
                    _NavItem(
                      icon: Icons.map_outlined,
                      label: "GPS",
                      route: "/carte",
                      currentRoute: currentRoute,
                      onTap: onNavigate,
                    ),
                  if (isAdmin)
                    _NavItem(
                      icon: Icons.inventory_2_outlined,
                      label: "Répartition des aides",
                      route: "/repartition",
                      currentRoute: currentRoute,
                      onTap: onNavigate,
                    ),
                  if (isResponsable || isAgent)
                    _NavItem(
                      icon: Icons.local_shipping_outlined,
                      label: "Suivi des distributions",
                      route: "/distributions",
                      currentRoute: currentRoute,
                      onTap: onNavigate,
                    ),
                  if (isResponsable)
                    _NavItem(
                      icon: Icons.notifications_active_outlined,
                      label: "Rappel administratif",
                      route: "/rappel-administratif",
                      currentRoute: currentRoute,
                      onTap: onNavigate,
                    ),
                  if (isAgriculteur) ...[
                    _NavItem(
                      icon: Icons.fact_check_outlined,
                      label: "Mes demandes",
                      route: "/mes-demandes",
                      currentRoute: currentRoute,
                      onTap: onNavigate,
                    ),
                    _NavItem(
                      icon: Icons.inventory_2_outlined,
                      label: "Mes aides",
                      route: "/mes-aides",
                      currentRoute: currentRoute,
                      onTap: onNavigate,
                    ),
                    _NavItem(
                      icon: Icons.description_outlined,
                      label: "Mes réclamations",
                      route: "/reclamations/nouvelle",
                      currentRoute: currentRoute,
                      onTap: onNavigate,
                    ),
                    _NavItem(
                      icon: Icons.notifications_outlined,
                      label: "Notifications",
                      route: "/notifications",
                      currentRoute: currentRoute,
                      onTap: onNavigate,
                    ),
                  ],
                  if (isAdmin)
                    _NavItem(
                      icon: Icons.settings_outlined,
                      label: "Configuration (Admin)",
                      route: "/creer-utilisateur",
                      currentRoute: currentRoute,
                      onTap: onNavigate,
                    ),
                  _NavItem(
                    icon: Icons.person_outline,
                    label: "Mon Profil",
                    route: "/profil",
                    currentRoute: currentRoute,
                    onTap: onNavigate,
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: InkWell(
              onTap: onLogout,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.red.shade900.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.red.shade900.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.logout,
                      color: Color(0xFFFCA5A5),
                      size: 18,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      "Se déconnecter",
                      style: TextStyle(
                        color: Colors.red.shade200,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String route;
  final String currentRoute;
  final void Function(String) onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.route,
    required this.currentRoute,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = currentRoute == route;
    return InkWell(
      onTap: () => onTap(route),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: isActive ? Colors.white.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: isActive ? Colors.white : const Color(0xFFBBF7D0),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isActive ? Colors.white : const Color(0xFFBBF7D0),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
