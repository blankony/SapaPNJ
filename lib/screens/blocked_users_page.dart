import 'package:flutter/material.dart';
import '../services/app_cache_manager.dart';

import 'package:cached_network_image/cached_network_image.dart';
import '../../services/moderation_service.dart';
import '../../services/api_service.dart';
import '../../main.dart';
import '../../theme/app_theme.dart';
import '../../theme/avatar_helper.dart';

class BlockedUsersPage extends StatelessWidget {
  const BlockedUsersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Blocked Accounts"),
      ),
      body: StreamBuilder<List<String>>(
        stream: moderationService.streamBlockedUsers(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          final blockedIds = snapshot.data ?? [];

          if (blockedIds.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.block, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text("You haven't blocked anyone.", style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: blockedIds.length,
            itemBuilder: (context, index) {
              final userId = blockedIds[index];
              return FutureBuilder<Map<String, dynamic>?>(
                future: ApiService().getUser(userId),
                builder: (context, userSnapshot) {
                  if (!userSnapshot.hasData || userSnapshot.data == null) return SizedBox.shrink();

                  final data = userSnapshot.data!;
                  final name = data['name'] ?? 'Unknown User';
                  final email = data['email'] ?? '';
                  final handle = email.isNotEmpty ? "@${email.split('@')[0]}" : "";
                  final profileImageUrl = data['profile_image_url'] ?? data['profileImageUrl'];
                  final iconId = data['avatar_icon_id'] ?? data['avatarIconId'] ?? 0;
                  final colorHex = data['avatar_hex'] ?? data['avatarHex'];

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: profileImageUrl != null && profileImageUrl.isNotEmpty ? Colors.transparent : AvatarHelper.getColor(colorHex),
                      backgroundImage: profileImageUrl != null && profileImageUrl.isNotEmpty ? CachedNetworkImageProvider(profileImageUrl, cacheManager: AppCacheManager.instance) : null,
                      child: profileImageUrl == null || profileImageUrl.isEmpty ? Icon(AvatarHelper.getIcon(iconId), color: Colors.white, size: 20) : null,
                    ),
                    title: Text(name),
                    subtitle: Text(handle),
                    trailing: OutlinedButton(
                      onPressed: () async {
                        await moderationService.unblockUser(userId);
                      },
                      child: Text("Unblock"),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
