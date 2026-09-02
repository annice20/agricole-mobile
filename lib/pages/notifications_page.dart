import 'package:flutter/material.dart';
import '../core/api_client.dart';
import '../widgets/app_layout.dart';
import '../services/notification_service.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  List<dynamic> _notifications = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _chargerNotifications();
  }

  Future<void> _chargerNotifications() async {
    setState(() => _loading = true);

    try {
      final session = await ApiClient().getSession();
      final idUtilisateur = session?.id;

      if (idUtilisateur == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                "Impossible de récupérer votre identifiant de session.",
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
        setState(() => _loading = false);
        return;
      }

      final data = await NotificationService().getNotifications(idUtilisateur);

      if (mounted) {
        setState(() {
          _notifications = data;
          _loading = false;
        });

        // Met à jour le compteur global avec le nombre de non-lues
        final nonLues = data.where((n) => n['lu'] == false).length;
        NotificationService.setUnreadCount(nonLues);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Impossible de charger les notifications"),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _marquerCommeLu(int id) async {
    try {
      await NotificationService().marquerCommeLu(id);

      setState(() {
        _notifications = _notifications.map((n) {
          if (n['id'] == id) {
            return {...n, 'lu': true};
          }
          return n;
        }).toList();
      });

      // Décrémente immédiatement le compteur de la cloche partout dans l'app
      NotificationService.decrementUnread();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Notification marquée comme lue"),
            backgroundColor: Color(0xFF15803D),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Erreur lors de la mise à jour"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return "";
    try {
      final date = DateTime.parse(dateStr);
      return "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} à ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppLayout(
      currentRoute: "/notifications",
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Notifications",
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: Color(0xFF14532D),
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "Consultez les informations relatives à vos demandes et aides agricoles.",
              style: TextStyle(
                fontSize: 13,
                color: const Color(0xFF166534).withOpacity(0.8),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 20),

            Expanded(
              child: _loading
                  ? _buildLoadingWidget()
                  : _notifications.isEmpty
                  ? _buildEmptyWidget()
                  : RefreshIndicator(
                      onRefresh: _chargerNotifications,
                      color: const Color(0xFF15803D),
                      child: ListView.builder(
                        itemCount: _notifications.length,
                        itemBuilder: (context, index) {
                          final notif = _notifications[index];
                          final bool estLu = notif['lu'] ?? false;
                          final int notifId = notif['id'];
                          final String message = notif['message'] ?? "";
                          final String dateEnvoi = notif['dateEnvoi'] ?? "";

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: estLu
                                  ? Colors.white.withOpacity(0.6)
                                  : const Color(0xFFFEFCE8).withOpacity(0.8),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: estLu
                                    ? Colors.white.withOpacity(0.5)
                                    : const Color(0xFFFDE047),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.03),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        message,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF052E16),
                                          height: 1.3,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        _formatDate(dateEnvoi),
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                          color: const Color(
                                            0xFF15803D,
                                          ).withOpacity(0.7),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (!estLu) ...[
                                  const SizedBox(width: 12),
                                  ElevatedButton.icon(
                                    onPressed: () => _marquerCommeLu(notifId),
                                    icon: const Icon(
                                      Icons.check_circle_outline,
                                      size: 16,
                                    ),
                                    label: const Text("Lu"),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF15803D),
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      textStyle: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingWidget() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.4)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          CircularProgressIndicator(color: Color(0xFF15803D)),
          SizedBox(height: 16),
          Text(
            "Chargement des notifications...",
            style: TextStyle(
              color: Color(0xFF14532D),
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyWidget() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.4)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.notifications_none, size: 48, color: Color(0xFF15803D)),
          SizedBox(height: 12),
          Text(
            "Aucune notification disponible",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF14532D),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
