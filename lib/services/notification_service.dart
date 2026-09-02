import 'package:flutter/foundation.dart';
import '../core/api_client.dart';

class NotificationService {
  final ApiClient _api = ApiClient();

  // Notifier global pour émettre le nombre de notifications non lues en temps réel
  static final ValueNotifier<int> unreadCountNotifier = ValueNotifier<int>(0);

  // Méthode utilitaire pour mettre à jour la valeur
  static void setUnreadCount(int count) {
    unreadCountNotifier.value = count;
  }

  // Méthode pour décrémenter de 1
  static void decrementUnread() {
    if (unreadCountNotifier.value > 0) {
      unreadCountNotifier.value--;
    }
  }

  Future<List<dynamic>> getNotifications(int utilisateurId) async {
    final data = await _api.get('/notifications/utilisateur/$utilisateurId');
    return data as List<dynamic>;
  }

  Future<void> marquerCommeLu(int id) async {
    await _api.put('/notifications/$id/lu', {});
  }

  Future<dynamic> creerNotification(
    int utilisateurId,
    String message, {
    String? titre,
  }) async {
    return await _api.post('/notifications', {
      'utilisateurId': utilisateurId,
      'titre': titre,
      'message': message,
    });
  }
}
