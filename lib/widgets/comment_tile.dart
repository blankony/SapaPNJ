import 'package:flutter/material.dart';
import '../services/app_cache_manager.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart';
import '../screens/post_detail_screen.dart';
import '../screens/dashboard/profile_page.dart';
import '../screens/image_viewer_screen.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../main.dart';
import '../theme/app_theme.dart';
import '../theme/avatar_helper.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/overlay_service.dart';
import '../services/api_service.dart';

class CommentTile extends StatefulWidget {
  final String commentId;
  final Map<String, dynamic> commentData;
  final String postId;
  final bool isOwner;
  final bool showPostContext;
  final String heroContextId;
  final String? currentProfileUserId;
  final bool isLast;

  const CommentTile({
    super.key,
    required this.commentId,
    required this.commentData,
    required this.postId,
    required this.isOwner,
    this.showPostContext = false,
    this.heroContextId = 'comment',
    this.currentProfileUserId,
    this.isLast = true,
  });

  @override
  State<CommentTile> createState() => _CommentTileState();
}

class _CommentTileState extends State<CommentTile> {
  Future<void> _shareComment() async {
    final String text = widget.commentData['text'] ?? '';
    final String? mediaUrl = widget.commentData['mediaUrl'] ?? widget.commentData['media_url'];
    final String userName = widget.commentData['user_name'] ?? widget.commentData['userName'] ?? 'User';
    final String shareText = 'Replying to post: "$text" - by $userName';

    try {
      if (mediaUrl != null && mediaUrl.isNotEmpty) {
        final file = await AppCacheManager.instance.getSingleFile(mediaUrl);
        await Share.shareXFiles([XFile(file.path)], text: shareText);
      } else {
        await Share.share(shareText);
      }
    } catch (e) {
      debugPrint('Error sharing: $e');
    }
  }

  Future<void> _deleteComment() async {
    final didConfirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Delete Reply"),
        content: Text("Are you sure you want to delete this reply?"),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text("Cancel")),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: Text("Delete")),
        ],
      ),
    ) ?? false;
    if (!didConfirm) return;
    try {
      final success = await ApiService().deleteComment(widget.postId, widget.commentId);
      if (success) {
        if (mounted) OverlayService().showTopNotification(context, "Reply deleted", Icons.delete_outline, (){});
      } else {
        throw Exception("Delete failed");
      }
    } catch (e) {
      if (mounted) {
        OverlayService().showTopNotification(context, "Failed to delete", Icons.error, (){}, color: Colors.red);
      }
    }
  }

  void _navigateToOriginalPost() async {
    if (!widget.showPostContext) return;
    try {
      final post = await ApiService().getPost(widget.postId);
      if (post != null && mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => PostDetailScreen(
              postId: widget.postId,
              initialPostData: post,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint("Error loading parent post: $e");
    }
  }

  void _navigateToUserProfile() {
    final commentUserId = widget.commentData['user_uid'] ?? widget.commentData['userId'];
    if (commentUserId == null) return;
    if (commentUserId == FirebaseAuth.instance.currentUser?.uid) return;

    if (widget.currentProfileUserId != null && commentUserId == widget.currentProfileUserId) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ProfilePage(userId: commentUserId, includeScaffold: true),
      ),
    );
  }

  void _openMediaViewer(String url, String? type) {
    final String heroTag = '${widget.heroContextId}_${widget.commentId}_$url';

    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black,
        pageBuilder: (_, __, ___) => ImageViewerScreen(
          imageUrl: url,
          mediaType: type,
          heroTag: heroTag,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        }
      ),
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return "just now";
    try {
      final parsedDate = DateTime.parse(timestamp.toString());
      return timeago.format(parsedDate, locale: 'en_short');
    } catch (_) {
      return "just now";
    }
  }

  @override
  Widget build(BuildContext context) {
    final String? profileImageUrl = widget.commentData['profile_image_url'] ?? widget.commentData['profileImageUrl'];

    if (widget.showPostContext) {
      return FutureBuilder<Map<String, dynamic>?>(
        future: ApiService().getPost(widget.postId),
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data == null) return SizedBox.shrink();
          final parentData = snapshot.data!;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildParentPostSnippet(context, parentData),
              _buildReplyTile(context, isThreaded: true, profileImageUrl: profileImageUrl),
            ],
          );
        },
      );
    }
    return _buildReplyTile(context, isThreaded: true, profileImageUrl: profileImageUrl);
  }

  Widget _buildParentPostSnippet(BuildContext context, Map<String, dynamic> parentData) {
    final theme = Theme.of(context);
    final String parentName = parentData['user_name'] ?? parentData['userName'] ?? 'Unknown';
    final String parentText = parentData['text'] ?? '';

    final int parentIconId = parentData['avatar_icon_id'] ?? parentData['avatarIconId'] ?? 0;
    final String? parentColorHex = parentData['avatar_hex'] ?? parentData['avatarHex'];
    final Color parentAvatarBg = AvatarHelper.getColor(parentColorHex);
    final String? parentProfileImageUrl = parentData['profile_image_url'] ?? parentData['profileImageUrl'];

    Widget parentAvatarWidget;
    if (parentProfileImageUrl != null && parentProfileImageUrl.isNotEmpty) {
      parentAvatarWidget = CircleAvatar(
        radius: 16,
        backgroundColor: Colors.transparent,
        backgroundImage: CachedNetworkImageProvider(parentProfileImageUrl, cacheManager: AppCacheManager.instance),
      );
    } else {
      parentAvatarWidget = CircleAvatar(
        radius: 16,
        backgroundColor: parentAvatarBg,
        child: Icon(AvatarHelper.getIcon(parentIconId), size: 16, color: Colors.white),
      );
    }

    return InkWell(
      onTap: _navigateToOriginalPost,
      child: Container(
        color: theme.cardColor,
        padding: EdgeInsets.fromLTRB(12, 12, 16, 0),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 40,
                child: Column(
                  children: [
                    parentAvatarWidget,
                    Expanded(
                      child: Container(
                        width: 2,
                        color: theme.dividerColor,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("$parentName • Original Post", style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic)),
                    SizedBox(height: 2),
                    Text(
                      parentText,
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis
                    ),
                    SizedBox(height: 8),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReplyTile(BuildContext context, {required bool isThreaded, String? profileImageUrl}) {
    final data = widget.commentData;
    final theme = Theme.of(context);
    final String userName = data['user_name'] ?? data['userName'] ?? 'Anonymous';
    final String text = data['text'] ?? '';
    final dynamic timestamp = data['created_at'] ?? data['timestamp'];

    final String? mediaUrl = data['media_url'] ?? data['mediaUrl'];
    final String? mediaType = data['media_type'] ?? data['mediaType'];

    final int iconId = data['avatar_icon_id'] ?? data['avatarIconId'] ?? 0;
    final String? colorHex = data['avatar_hex'] ?? data['avatarHex'];
    final Color avatarBg = AvatarHelper.getColor(colorHex);

    Widget avatarWidget;
    if (profileImageUrl != null && profileImageUrl.isNotEmpty) {
      avatarWidget = CircleAvatar(
        radius: 18,
        backgroundColor: Colors.transparent,
        backgroundImage: CachedNetworkImageProvider(profileImageUrl, cacheManager: AppCacheManager.instance),
      );
    } else {
      avatarWidget = CircleAvatar(
        radius: 18,
        backgroundColor: avatarBg,
        child: Icon(AvatarHelper.getIcon(iconId), size: 20, color: Colors.white),
      );
    }

    return InkWell(
      onTap: _navigateToOriginalPost,
      child: Container(
        color: theme.cardColor,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 48,
                color: Colors.transparent,
                child: isThreaded
                  ? CustomPaint(
                      painter: ThreadLinePainter(
                        context: context,
                        isLast: widget.isLast,
                      ),
                    )
                  : null,
              ),

              Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: GestureDetector(
                    onTap: _navigateToUserProfile,
                    child: avatarWidget,
                  ),
                ),
              ),

              SizedBox(width: 10),

              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: _navigateToUserProfile,
                              child: Text(
                                userName,
                                style: theme.textTheme.titleMedium,
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          ),
                          SizedBox(width: 8),
                          Text(
                            _formatTimestamp(timestamp),
                            style: theme.textTheme.titleSmall,
                          ),
                          if (widget.isOwner)
                            _buildOptionsButton(),
                        ],
                      ),
                      SizedBox(height: 2),
                      if (text.isNotEmpty)
                        Text(text, style: theme.textTheme.bodyLarge),

                      if (mediaUrl != null && mediaUrl.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
                          child: GestureDetector(
                            onTap: () => _openMediaViewer(mediaUrl, mediaType),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                height: 150,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: Colors.black,
                                  border: Border.all(color: theme.dividerColor.withOpacity(0.3)),
                                ),
                                child: mediaType == 'video'
                                    ? Center(child: Icon(Icons.play_circle_fill, color: Colors.white, size: 40))
                                    : Hero(
                                        tag: '${widget.heroContextId}_${widget.commentId}_$mediaUrl',
                                        child: CachedNetworkImage(cacheManager: AppCacheManager.instance, 
                                          imageUrl: mediaUrl,
                                          fit: BoxFit.cover,
                                          memCacheWidth: 400,
                                          placeholder: (context, url) => Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                          errorWidget: (context, url, error) => Icon(Icons.error, color: Colors.grey),
                                        ),
                                      ),
                                ),
                            ),
                          ),
                        ),

                      Padding(
                        padding: const EdgeInsets.only(top: 8.0, bottom: 4.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            _buildActionButton(
                              icon: Icons.share_outlined,
                              text: "Share",
                              color: null,
                              onTap: _shareComment
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String? text,
    required Color? color,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final iconColor = color ?? theme.hintColor;
    Widget iconWidget = Icon(icon, size: 18, color: iconColor);
    return InkWell(
      onTap: onTap,
      child: Row(
        children: [
          iconWidget,
          if (text != null)
            Padding(
              padding: const EdgeInsets.only(left: 4.0),
              child: Text(
                text,
                style: TextStyle(color: iconColor, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildOptionsButton() {
    return InkWell(
      onTap: () {
        showModalBottomSheet(
          context: context,
          builder: (context) {
            return Container(
              child: Wrap(
                children: [
                  ListTile(
                    leading: Icon(Icons.delete_outline, color: Colors.red),
                    title: Text('Delete Reply', style: TextStyle(color: Colors.red)),
                    onTap: () {
                      Navigator.of(context).pop();
                      _deleteComment();
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
      child: Icon(Icons.more_horiz, color: Theme.of(context).textTheme.titleSmall?.color, size: 18),
    );
  }
}

class ThreadLinePainter extends CustomPainter {
  final BuildContext context;
  final bool isLast;

  ThreadLinePainter({required this.context, required this.isLast});

  @override
  void paint(Canvas canvas, Size size) {
    final theme = Theme.of(context);
    final paint = Paint()
      ..color = theme.dividerColor
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final double x = 32.0;
    final double avatarCenterY = 26.0;
    final double curveRadius = 12.0;

    Path path = Path();
    path.moveTo(x, 0);

    if (isLast) {
      path.lineTo(x, avatarCenterY - curveRadius);
      path.quadraticBezierTo(x, avatarCenterY, x + curveRadius, avatarCenterY);
      path.lineTo(size.width, avatarCenterY);
    } else {
      path.lineTo(x, size.height);

      Path branchPath = Path();
      branchPath.moveTo(x, avatarCenterY - curveRadius);
      branchPath.quadraticBezierTo(x, avatarCenterY, x + curveRadius, avatarCenterY);
      branchPath.lineTo(size.width, avatarCenterY);

      canvas.drawPath(branchPath, paint);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant ThreadLinePainter oldDelegate) {
    return oldDelegate.isLast != isLast;
  }
}
