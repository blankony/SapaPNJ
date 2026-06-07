import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../../services/api_service.dart';
import '../../../services/app_cache_manager.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/avatar_helper.dart';
import 'chat_message.dart';

class ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final ValueChanged<String> onSpeak;
  final ValueChanged<String> onCopy;
  final ValueChanged<String> onShare;

  const ChatBubble({
    super.key,
    required this.message,
    required this.onSpeak,
    required this.onCopy,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUser = message.isUser;

    final textColor = isUser
        ? Colors.white
        : (theme.textTheme.bodyLarge?.color ?? Colors.black);
    final bgColor = isUser ? SisapaTheme.blue : theme.cardColor;

    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Row(
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              radius: 18,
              backgroundColor: SisapaTheme.blue.withValues(alpha: 0.1),
              child: Image.asset(
                'images/app_icon.png',
                height: 20,
                color: SisapaTheme.blue,
              ),
            ),
            const SizedBox(width: 10),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isUser
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.75,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(24),
                      topRight: const Radius.circular(24),
                      bottomLeft: isUser
                          ? const Radius.circular(24)
                          : const Radius.circular(4),
                      bottomRight: isUser
                          ? const Radius.circular(4)
                          : const Radius.circular(24),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: MarkdownBody(
                    data: message.text,
                    selectable: true,
                    styleSheet: MarkdownStyleSheet(
                      p: TextStyle(color: textColor, fontSize: 15, height: 1.5),
                      strong: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.bold,
                      ),
                      listBullet: TextStyle(color: textColor),
                      code: TextStyle(
                        color: isUser ? Colors.white70 : theme.primaryColor,
                        backgroundColor: isUser
                            ? Colors.black26
                            : theme.scaffoldBackgroundColor,
                        fontFamily: 'monospace',
                        fontSize: 13,
                      ),
                      blockquote: TextStyle(
                        color: isUser ? Colors.white70 : theme.hintColor,
                      ),
                      blockquoteDecoration: BoxDecoration(
                        border: Border(
                          left: BorderSide(
                            color: isUser ? Colors.white30 : theme.dividerColor,
                            width: 3,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (!isUser)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0, left: 4.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildActionIcon(
                          context,
                          Icons.volume_up_rounded,
                          () => onSpeak(message.text),
                        ),
                        const SizedBox(width: 16),
                        _buildActionIcon(
                          context,
                          Icons.copy_rounded,
                          () => onCopy(message.text),
                        ),
                        const SizedBox(width: 16),
                        _buildActionIcon(
                          context,
                          Icons.share_rounded,
                          () => onShare(message.text),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          if (isUser) ...[const SizedBox(width: 10), const UserAvatar()],
        ],
      ),
    );
  }

  Widget _buildActionIcon(
    BuildContext context,
    IconData icon,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: Icon(
          icon,
          size: 18,
          color: Theme.of(context).hintColor.withValues(alpha: 0.6),
        ),
      ),
    );
  }
}

class UserAvatar extends StatelessWidget {
  const UserAvatar({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox(width: 32);
    return FutureBuilder<Map<String, dynamic>?>(
      future: ApiService().getUser(user.uid),
      builder: (context, snapshot) {
        String? profileUrl;
        var iconId = 0;
        String? colorHex;
        if (snapshot.hasData && snapshot.data != null) {
          final data = snapshot.data!;
          profileUrl = data['profile_image_url'] ?? data['profileImageUrl'];
          iconId = data['avatar_icon_id'] ?? data['avatarIconId'] ?? 0;
          colorHex = data['avatar_hex'] ?? data['avatarHex'];
        }
        return CircleAvatar(
          radius: 18,
          backgroundColor: profileUrl != null
              ? Colors.transparent
              : AvatarHelper.getColor(colorHex),
          backgroundImage: profileUrl != null
              ? CachedNetworkImageProvider(
                  profileUrl,
                  cacheManager: AppCacheManager.instance,
                )
              : null,
          child: profileUrl == null
              ? Icon(
                  AvatarHelper.getIcon(iconId),
                  size: 18,
                  color: Colors.white,
                )
              : null,
        );
      },
    );
  }
}
