import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/app_theme.dart';
import '../theme/avatar_helper.dart';
import '../services/app_cache_manager.dart';
import '../services/app_localizations.dart';

class CreatePostAuthorHeader extends StatelessWidget {
  final bool hasOfficialAuthority;
  final bool postAsCommunity;
  final ValueChanged<bool> onPostAsCommunityChanged;
  final String? currentAvatarUrl;
  final String myAvatarHex;
  final int myAvatarIconId;
  final String currentDisplayName;
  final bool isCommunityContext;
  final String? communityName;

  const CreatePostAuthorHeader({
    super.key,
    required this.hasOfficialAuthority,
    required this.postAsCommunity,
    required this.onPostAsCommunityChanged,
    required this.currentAvatarUrl,
    required this.myAvatarHex,
    required this.myAvatarIconId,
    required this.currentDisplayName,
    required this.isCommunityContext,
    required this.communityName,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasOfficialAuthority)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.dividerColor),
            ),
            child: Row(
              children: [
                Text(
                  t.translate('post_identity_label'),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const Spacer(),
                ChoiceChip(
                  label: Text(t.translate('post_identity_me')),
                  selected: !postAsCommunity,
                  onSelected: (val) => onPostAsCommunityChanged(false),
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: Text(t.translate('nav_community')),
                  selected: postAsCommunity,
                  onSelected: (val) => onPostAsCommunityChanged(true),
                  selectedColor: SisapaTheme.blue.withValues(alpha: 0.2),
                  labelStyle: TextStyle(
                    color: postAsCommunity ? SisapaTheme.blue : null,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: currentAvatarUrl != null
                  ? Colors.transparent
                  : AvatarHelper.getColor(myAvatarHex),
              backgroundImage: currentAvatarUrl != null
                  ? CachedNetworkImageProvider(
                      currentAvatarUrl!,
                      cacheManager: AppCacheManager.instance,
                    )
                  : null,
              child: currentAvatarUrl == null
                  ? (postAsCommunity
                      ? const Icon(
                          Icons.groups,
                          color: Colors.white,
                        )
                      : Icon(
                          AvatarHelper.getIcon(myAvatarIconId),
                          color: Colors.white,
                        ))
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    currentDisplayName,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: postAsCommunity ? SisapaTheme.blue : null,
                    ),
                  ),
                  if (isCommunityContext)
                    Text(
                      postAsCommunity
                          ? t.translate('post_as_comm_id')
                          : "${t.translate('post_in_comm')} $communityName",
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
