import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;

import 'post_data_helpers.dart';

class PostRepostHeader extends StatelessWidget {
  final Map<String, dynamic> postData;
  final ValueChanged<String> onOpenReposter;

  const PostRepostHeader({
    super.key,
    required this.postData,
    required this.onOpenReposter,
  });

  String _formatTimestamp(dynamic createdAt) {
    if (createdAt == null) return 'just now';
    try {
      final parsedDate = DateTime.parse(createdAt.toString());
      return timeago.format(parsedDate, locale: 'en_short');
    } catch (_) {
      return 'just now';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reposterId = postAuthorId(postData);
    final createdAt = postData['created_at'] ?? postData['timestamp'];
    final displayName = postData['user_name'] ?? postData['userName'] ?? 'User';

    return Container(
      padding: const EdgeInsets.only(left: 36.0, bottom: 6.0),
      child: Row(
        children: [
          Icon(Icons.repeat, size: 14, color: theme.hintColor),
          const SizedBox(width: 6),
          Flexible(
            child: GestureDetector(
              onTap: reposterId == null
                  ? null
                  : () => onOpenReposter(reposterId),
              child: RichText(
                text: TextSpan(
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.hintColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  children: [
                    TextSpan(text: '$displayName '),
                    TextSpan(
                      text: 'reposted · ${_formatTimestamp(createdAt)}',
                      style: const TextStyle(fontWeight: FontWeight.normal),
                    ),
                  ],
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
