import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../services/app_cache_manager.dart';
import '../../../theme/avatar_helper.dart';

class ProfileAvatarImage extends StatelessWidget {
  final Map<String, dynamic> data;

  const ProfileAvatarImage({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final url = data['profile_image_url'] ?? data['profileImageUrl'];

    if (url != null) {
      return CircleAvatar(
        radius: 45,
        backgroundImage: CachedNetworkImageProvider(
          url,
          cacheManager: AppCacheManager.instance,
        ),
      );
    }

    return CircleAvatar(
      radius: 45,
      backgroundColor: AvatarHelper.getColor(
        data['avatar_hex'] ?? data['avatarHex'],
      ),
      child: Icon(
        AvatarHelper.getIcon(
          data['avatar_icon_id'] ?? data['avatarIconId'] ?? 0,
        ),
        size: 50,
        color: Colors.white,
      ),
    );
  }
}
