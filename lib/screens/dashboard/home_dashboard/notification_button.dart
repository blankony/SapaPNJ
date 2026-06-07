import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../services/api_service.dart';
import '../../../theme/app_theme.dart';

class DashboardNotificationButton extends StatelessWidget {
  final VoidCallback onPressed;

  const DashboardNotificationButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return IconButton(
        icon: const Icon(Icons.notifications_none),
        onPressed: onPressed,
      );
    }

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: ApiService().getNotifications(),
      builder: (context, snapshot) {
        var hasUnread = false;
        if (snapshot.hasData && snapshot.data != null) {
          hasUnread = snapshot.data!.any(
            (notification) =>
                notification['is_read'] == false ||
                notification['is_read'] == 0,
          );
        }

        return Stack(
          children: [
            IconButton(
              icon: Icon(
                hasUnread ? Icons.notifications : Icons.notifications_none,
              ),
              onPressed: onPressed,
            ),
            if (hasUnread)
              const Positioned(
                top: 10,
                right: 10,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: SisapaTheme.blue,
                    shape: BoxShape.circle,
                  ),
                  child: SizedBox(width: 8, height: 8),
                ),
              ),
          ],
        );
      },
    );
  }
}
