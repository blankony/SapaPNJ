import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../services/api_service.dart';
import '../../../../services/app_cache_manager.dart';
import '../../../../services/app_localizations.dart';
import '../../../../services/overlay_service.dart';
import '../../../../theme/app_theme.dart';
import '../../../../theme/avatar_helper.dart';
import '../../screens/dashboard/profile_page.dart';

class UserSearchTile extends StatefulWidget {
  final String userId;
  final Map<String, dynamic> userData;
  final String? currentUserId;
  final bool initialIsFollowing;
  final void Function(String userId, bool isFollowing)? onFollowStateChanged;

  const UserSearchTile({
    super.key,
    required this.userId,
    required this.userData,
    this.currentUserId,
    this.initialIsFollowing = false,
    this.onFollowStateChanged,
  });

  @override
  State<UserSearchTile> createState() => _UserSearchTileState();
}

class _UserSearchTileState extends State<UserSearchTile> {
  late bool _isFollowing;

  @override
  void initState() {
    super.initState();
    _isFollowing = widget.initialIsFollowing;
  }

  @override
  void didUpdateWidget(covariant UserSearchTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.userId != oldWidget.userId ||
        widget.initialIsFollowing != oldWidget.initialIsFollowing) {
      _isFollowing = widget.initialIsFollowing;
    }
  }

  Future<void> _toggleFollow() async {
    if (widget.currentUserId == null) return;

    try {
      if (_isFollowing) {
        final success = await ApiService().unfollowUser(widget.userId);
        if (!mounted) return;
        if (success) {
          setState(() => _isFollowing = false);
          widget.onFollowStateChanged?.call(widget.userId, false);
        }
        return;
      }

      final resp = await ApiService().followUser(widget.userId);
      if (!mounted) return;

      if (resp['success'] == true) {
        setState(() => _isFollowing = true);
        widget.onFollowStateChanged?.call(widget.userId, true);

        if (resp['type'] == 'request_sent') {
          OverlayService().showTopNotification(
            context,
            'Follow request sent',
            Icons.hourglass_empty,
            () {},
          );
          setState(() => _isFollowing = false);
          widget.onFollowStateChanged?.call(widget.userId, false);
        }
      }
    } catch (e) {
      if (mounted) {
        OverlayService().showTopNotification(
          context,
          'Action failed: $e',
          Icons.error,
          () {},
          color: Colors.red,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final user = widget.userData;

    final name = user['name'] ?? 'User';
    final email = user['email'] ?? '';
    final handle = email.isNotEmpty ? '@${email.split('@')[0]}' : '';
    final int iconId = user['avatar_icon_id'] ?? user['avatarIconId'] ?? 0;
    final String? colorHex = user['avatar_hex'] ?? user['avatarHex'];
    final String? profileImageUrl =
        user['profile_image_url'] ?? user['profileImageUrl'];

    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              ProfilePage(userId: widget.userId, includeScaffold: true),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor:
                  profileImageUrl != null && profileImageUrl.isNotEmpty
                  ? Colors.transparent
                  : AvatarHelper.getColor(colorHex),
              backgroundImage:
                  profileImageUrl != null && profileImageUrl.isNotEmpty
                  ? CachedNetworkImageProvider(
                      profileImageUrl,
                      cacheManager: AppCacheManager.instance,
                    )
                  : null,
              child: profileImageUrl == null || profileImageUrl.isEmpty
                  ? Icon(
                      AvatarHelper.getIcon(iconId),
                      size: 24,
                      color: Colors.white,
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    handle,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.hintColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _FollowButton(
              isFollowing: _isFollowing,
              onPressed: _toggleFollow,
              label: _isFollowing
                  ? t.translate('community_following')
                  : t.translate('community_follow'),
            ),
          ],
        ),
      ),
    );
  }
}

class _FollowButton extends StatelessWidget {
  final bool isFollowing;
  final VoidCallback onPressed;
  final String label;

  const _FollowButton({
    required this.isFollowing,
    required this.onPressed,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (isFollowing) {
      return OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          side: BorderSide(color: theme.dividerColor),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(color: theme.textTheme.bodyMedium?.color),
        ),
      );
    }

    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: SisapaTheme.blue,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      child: Text(label),
    );
  }
}
