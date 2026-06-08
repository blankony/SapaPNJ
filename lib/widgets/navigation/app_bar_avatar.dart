import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../../services/api_service.dart';
import '../../../../services/app_cache_manager.dart';
import '../../../../theme/avatar_helper.dart';

class AppBarAvatar extends StatelessWidget {
  const AppBarAvatar({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return const SizedBox();

    return FutureBuilder<Map<String, dynamic>?>(
      future: ApiService().getUser(currentUserId),
      builder: (context, snapshot) {
        var iconId = 0;
        String? colorHex;
        String? profileImageUrl;

        if (snapshot.hasData && snapshot.data != null) {
          final data = snapshot.data!;
          iconId = data['avatar_icon_id'] ?? 0;
          colorHex = data['avatar_hex'];
          profileImageUrl = data['profile_image_url'];
        }

        return CircleAvatar(
          radius: 18,
          backgroundColor: profileImageUrl != null
              ? Colors.transparent
              : AvatarHelper.getColor(colorHex),
          backgroundImage: profileImageUrl != null
              ? CachedNetworkImageProvider(
                  profileImageUrl,
                  cacheManager: AppCacheManager.instance,
                )
              : null,
          child: profileImageUrl == null
              ? Icon(
                  AvatarHelper.getIcon(iconId),
                  size: 20,
                  color: Colors.white,
                )
              : null,
        );
      },
    );
  }
}
