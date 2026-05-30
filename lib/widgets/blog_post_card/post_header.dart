import 'package:flutter/material.dart';
import '../../services/app_cache_manager.dart';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../theme/app_theme.dart';
import '../../theme/avatar_helper.dart';
import '../../services/app_localizations.dart';

class PostHeader extends StatelessWidget {
  final Map<String, dynamic> postData;
  final bool isOwner;
  final bool isCommunityAdmin;
  final bool isPinned;
  final VoidCallback onNavigateToSource;
  final Function(String) onMenuAction;

  const PostHeader({
    super.key,
    required this.postData,
    required this.isOwner,
    required this.isCommunityAdmin,
    required this.isPinned,
    required this.onNavigateToSource,
    required this.onMenuAction,
  });

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return "just now";
    if (postData['isUploading'] == true) return "Uploading...";
    if (postData['uploadFailed'] == true) return "Failed";
    try {
      final parsedDate = DateTime.parse(timestamp.toString());
      return timeago.format(parsedDate, locale: 'en_short');
    } catch (_) {
      return "just now";
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context)!;
    final timeAgo = _formatTimestamp(postData['created_at'] ?? postData['timestamp']);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isPinned)
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0, left: 36.0),
            child: Row(
              children: [
                Icon(Icons.push_pin, size: 14, color: theme.hintColor),
                const SizedBox(width: 4),
                Text(
                  t.translate('post_pinned'),
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: theme.hintColor),
                ),
              ],
            ),
          ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAvatar(context),
            const SizedBox(width: 12),
            Expanded(child: _buildHeaderContent(context, theme, timeAgo)),
          ],
        ),
      ],
    );
  }

  Widget _buildAvatar(BuildContext context) {
    final bool isCommunityPost = postData['is_community_identity'] == 1 ||
        postData['is_community_identity'] == true ||
        postData['isCommunityPost'] == true;
    final String? communityId = postData['community_id'] ?? postData['communityId'];

    if (communityId != null && isCommunityPost) {
      final String? displayImg = postData['community_image_url'] ?? postData['communityIcon'];

      return GestureDetector(
        onTap: onNavigateToSource,
        child: CircleAvatar(
          radius: 24,
          backgroundColor: SisapaTheme.blue.withOpacity(0.1),
          backgroundImage: displayImg != null && displayImg.isNotEmpty ? CachedNetworkImageProvider(displayImg, cacheManager: AppCacheManager.instance) : null,
          child: displayImg == null || displayImg.isEmpty
              ? const Icon(Icons.groups, size: 26, color: SisapaTheme.blue)
              : null,
        ),
      );
    }

    final String? profileImageUrl = postData['profile_image_url'] ?? postData['profileImageUrl'];
    final int iconId = postData['avatar_icon_id'] ?? postData['avatarIconId'] ?? 0;
    final String? colorHex = postData['avatar_hex'] ?? postData['avatarHex'];
    final Color avatarBgColor = AvatarHelper.getColor(colorHex);

    return GestureDetector(
      onTap: onNavigateToSource,
      child: CircleAvatar(
        radius: 24,
        backgroundColor: profileImageUrl != null && profileImageUrl.isNotEmpty ? Colors.transparent : avatarBgColor,
        backgroundImage: profileImageUrl != null && profileImageUrl.isNotEmpty ? CachedNetworkImageProvider(profileImageUrl, cacheManager: AppCacheManager.instance) : null,
        child: profileImageUrl == null || profileImageUrl.isEmpty
            ? Icon(AvatarHelper.getIcon(iconId), size: 26, color: Colors.white)
            : null,
      ),
    );
  }

  Widget _buildHeaderContent(BuildContext context, ThemeData theme, String timeAgo) {
    final String? communityId = postData['community_id'] ?? postData['communityId'];
    final bool isCommunityPost = postData['is_community_identity'] == 1 ||
        postData['is_community_identity'] == true ||
        postData['isCommunityPost'] == true;
    final bool isVerified = postData['community_verified'] == 1 ||
        postData['community_verified'] == true ||
        postData['communityVerified'] == true;

    // 1. OFFICIAL COMMUNITY POST
    if (communityId != null && isCommunityPost) {
      final String comName = postData['community_name'] ?? postData['communityName'] ?? 'Community';
      final String userName = postData['user_name'] ?? postData['userName'] ?? 'Member';

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: GestureDetector(
                        onTap: onNavigateToSource,
                        child: Text(comName, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                      ),
                    ),
                    if (isVerified) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.verified, size: 14, color: SisapaTheme.blue),
                    ],
                  ],
                ),
              ),
              _buildMetaRow(context, timeAgo),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 2.0),
            child: Row(
              children: [
                Icon(Icons.person, size: 12, color: theme.hintColor),
                const SizedBox(width: 4),
                Flexible(
                  child: Text("Posted by $userName", style: TextStyle(color: theme.hintColor, fontSize: 11), overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ),
        ],
      );
    }

    // 2. PERSONAL POST IN COMMUNITY
    if (communityId != null && !isCommunityPost) {
      final String userName = postData['user_name'] ?? postData['userName'] ?? 'User';
      final String comName = postData['community_name'] ?? postData['communityName'] ?? 'Community';

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: onNavigateToSource,
                  child: Text(userName, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                ),
              ),
              _buildMetaRow(context, timeAgo),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 2.0),
            child: Row(
              children: [
                Flexible(
                  child: Text("in $comName", style: TextStyle(color: theme.hintColor, fontSize: 11, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          )
        ],
      );
    }

    // 3. STANDARD USER POST
    final String userName = postData['user_name'] ?? postData['userName'] ?? 'User';
    final String email = postData['user_email'] ?? postData['userEmail'] ?? 'user';
    final String handle = "@${email.split('@')[0]}";
    final String visibility = postData['visibility'] ?? 'public';
    final bool isPrivate = visibility == 'private';
    final bool isFollowersOnly = visibility == 'followers';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Flexible(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: GestureDetector(
                      onTap: onNavigateToSource,
                      child: Text(userName, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                    ),
                  ),
                  if (isPrivate) ...[
                    const SizedBox(width: 4),
                    Icon(Icons.lock, size: 14, color: theme.hintColor),
                  ] else if (isFollowersOnly) ...[
                    const SizedBox(width: 4),
                    Icon(Icons.people, size: 14, color: theme.hintColor),
                  ],
                ],
              ),
            ),
            _buildMetaRow(context, timeAgo),
          ],
        ),
        Text(handle, style: TextStyle(color: theme.hintColor, fontSize: 13), overflow: TextOverflow.ellipsis),
      ],
    );
  }

  Widget _buildMetaRow(BuildContext context, String timeAgo) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(width: 4),
        Padding(
          padding: const EdgeInsets.only(top: 2.0),
          child: Text("· $timeAgo", style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12)),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 4.0),
          child: SizedBox(
            width: 24,
            height: 24,
            child: _buildOptionsButton(context),
          ),
        ),
      ],
    );
  }

  Widget _buildOptionsButton(BuildContext context) {
    var t = AppLocalizations.of(context)!;
    return PopupMenuButton<String>(
      padding: EdgeInsets.zero,
      icon: Icon(Icons.more_horiz, color: Theme.of(context).hintColor, size: 18),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      color: Theme.of(context).cardColor,
      onSelected: onMenuAction,
      itemBuilder: (context) {
        final List<PopupMenuEntry<String>> options = [];

        // CASE 1: Author
        if (isOwner) {
          final isPrivate = (postData['visibility'] ?? 'public') == 'private';
          options.addAll([
            PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_outlined, size: 20, color: Theme.of(context).textTheme.bodyLarge?.color), const SizedBox(width: 12), Text(t.translate('menu_edit'))])),
            PopupMenuItem(value: 'toggle_visibility', child: Row(children: [Icon(isPrivate ? Icons.public : Icons.lock_outline, size: 20, color: Theme.of(context).textTheme.bodyLarge?.color), const SizedBox(width: 12), Text(isPrivate ? t.translate('menu_unhide') : t.translate('menu_hide'))])),
            PopupMenuItem(value: 'pin', child: Row(children: [Icon(isPinned ? Icons.push_pin : Icons.push_pin_outlined, size: 20, color: Theme.of(context).textTheme.bodyLarge?.color), const SizedBox(width: 12), Text(isPinned ? t.translate('menu_unpin') : t.translate('menu_pin'))])),
            const PopupMenuDivider(),
            PopupMenuItem(value: 'delete', child: Row(children: [const Icon(Icons.delete_outline, size: 20, color: Colors.red), const SizedBox(width: 12), Text(t.translate('menu_delete'), style: const TextStyle(color: Colors.red))])),
          ]);
        }
        // CASE 2: Community Admin
        else if (isCommunityAdmin) {
          options.addAll([
            PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_outlined, size: 20, color: Theme.of(context).textTheme.bodyLarge?.color), const SizedBox(width: 12), Text(t.translate('menu_edit_admin'))])),
            PopupMenuItem(value: 'delete', child: Row(children: [const Icon(Icons.delete_outline, size: 20, color: Colors.red), const SizedBox(width: 12), Text(t.translate('menu_delete_admin'), style: const TextStyle(color: Colors.red))])),
            const PopupMenuDivider(),
            PopupMenuItem(value: 'report', child: Row(children: [Icon(Icons.flag_outlined, size: 20, color: Theme.of(context).textTheme.bodyLarge?.color), const SizedBox(width: 12), Text(t.translate('menu_report'))])),
            PopupMenuItem(value: 'block', child: Row(children: [const Icon(Icons.block, size: 20, color: Colors.red), const SizedBox(width: 12), Text(t.translate('menu_block'), style: const TextStyle(color: Colors.red))])),
          ]);
        }
        // CASE 3: Viewer
        else {
          options.addAll([
            PopupMenuItem(value: 'report', child: Row(children: [Icon(Icons.flag_outlined, size: 20, color: Theme.of(context).textTheme.bodyLarge?.color), const SizedBox(width: 12), Text(t.translate('menu_report'))])),
            PopupMenuItem(value: 'block', child: Row(children: [const Icon(Icons.block, size: 20, color: Colors.red), const SizedBox(width: 12), Text(t.translate('menu_block'), style: const TextStyle(color: Colors.red))])),
          ]);
        }

        final String? communityId = postData['community_id'] ?? postData['communityId'];
        if (communityId != null) {
          options.add(PopupMenuItem(value: 'report_community', child: Row(children: [const Icon(Icons.flag, size: 20, color: Colors.orange), const SizedBox(width: 12), Text(t.translate('menu_report_comm'))])));
        }

        return options;
      },
    );
  }
}
