import 'package:flutter/material.dart';
import '../services/app_cache_manager.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:cached_network_image/cached_network_image.dart';
import '../screens/post_detail_screen.dart';
import '../screens/dashboard/profile_page.dart';
import '../main.dart';
import '../theme/app_theme.dart';
import '../theme/avatar_helper.dart';
import '../services/overlay_service.dart';
import '../services/api_service.dart';
import '../services/app_localizations.dart';

class NotificationSheet extends StatefulWidget {
  final ScrollController scrollController;
  const NotificationSheet({super.key, required this.scrollController});

  @override
  State<NotificationSheet> createState() => _NotificationSheetState();
}

class _NotificationSheetState extends State<NotificationSheet> {
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  bool _isLoading = true;
  List<Map<String, dynamic>> _notifications = [];

  @override
  void initState() {
    super.initState();
    _loadNotifications();
    _markNotificationsAsRead();
  }

  Future<void> _loadNotifications() async {
    if (_currentUser == null) return;
    setState(() => _isLoading = true);
    try {
      final notifs = await ApiService().getNotifications();
      if (mounted) {
        setState(() {
          _notifications = notifs;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _markNotificationsAsRead() async {
    if (_currentUser == null) return;
    try {
      await ApiService().markAllNotificationsRead();
    } catch (_) {}
  }

  String _getGroupLabel(dynamic timestamp, AppLocalizations t) {
    if (timestamp == null) return t.translate('time_earlier');
    final now = DateTime.now();
    DateTime date;
    try {
      date = DateTime.parse(timestamp.toString());
    } catch (_) {
      return t.translate('time_earlier');
    }
    final today = DateTime(now.year, now.month, now.day);
    final notificationDate = DateTime(date.year, date.month, date.day);
    final difference = today.difference(notificationDate).inDays;

    if (difference == 0) {
      if (now.difference(date).inMinutes < 60) return t.translate('time_new');
      return t.translate('time_today');
    }
    if (difference == 1) return t.translate('time_yesterday');
    if (difference < 7) return t.translate('time_this_week');
    return t.translate('time_earlier');
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) {
      return Center(child: Text("Please log in."));
    }

    final theme = Theme.of(context);
    var t = AppLocalizations.of(context)!;

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  t.translate('notif_activity_title'),
                  style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: Icon(Icons.check_circle_outline),
                  tooltip: t.translate('notif_mark_read'),
                  onPressed: () async {
                    await _markNotificationsAsRead();
                    _loadNotifications();
                  },
                )
              ],
            ),
          ),

          Divider(height: 1),

          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : _notifications.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.notifications_none, size: 64, color: theme.hintColor.withOpacity(0.3)),
                            SizedBox(height: 16),
                            Text(t.translate('notif_empty'), style: TextStyle(color: theme.hintColor)),
                          ],
                        ),
                      )
                    : _buildNotificationsList(t, theme),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationsList(AppLocalizations t, ThemeData theme) {
    List<Widget> listItems = [];
    String? currentGroup;

    for (var data in _notifications) {
      final dynamic timestamp = data['created_at'] ?? data['timestamp'];

      if (timestamp != null) {
        String group = _getGroupLabel(timestamp, t);
        if (group != currentGroup) {
          currentGroup = group;
          listItems.add(
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
              child: Text(
                group,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.primaryColor
                ),
              ),
            )
          );
        }
      }

      final isReadVal = data['is_read'] ?? data['isRead'];
      final bool isRead = isReadVal == 1 || isReadVal == true;

      if (data['type'] == 'follow_request') {
        listItems.add(_FollowRequestTile(
          notificationId: data['id'],
          notificationData: data,
          isRead: isRead,
          onRefresh: _loadNotifications,
        ));
      } else {
        listItems.add(_NotificationTile(
          notificationData: data,
          isRead: isRead,
        ));
      }
    }

    return ListView(
      controller: widget.scrollController,
      children: listItems,
    );
  }
}

class _FollowRequestTile extends StatefulWidget {
  final String notificationId;
  final Map<String, dynamic> notificationData;
  final bool isRead;
  final VoidCallback onRefresh;

  const _FollowRequestTile({
    required this.notificationId,
    required this.notificationData,
    required this.isRead,
    required this.onRefresh,
  });

  @override
  State<_FollowRequestTile> createState() => _FollowRequestTileState();
}

class _FollowRequestTileState extends State<_FollowRequestTile> {
  bool _isProcessing = false;

  Future<void> _handleRequest(bool isAccepted) async {
    setState(() => _isProcessing = true);
    final senderId = widget.notificationData['sender_uid'] ?? widget.notificationData['senderId'];
    var t = AppLocalizations.of(context)!;

    try {
      bool success = false;
      if (isAccepted) {
        success = await ApiService().acceptFollowRequest(senderId);
      } else {
        success = await ApiService().declineFollowRequest(senderId);
      }

      if (success) {
        if (isAccepted && mounted) {
          OverlayService().showTopNotification(context, t.translate('notif_req_accepted'), Icons.person_add, (){}, color: Colors.green);
        }
        // Mark current notification as read to clean up
        await ApiService().markNotificationRead(widget.notificationId);
        widget.onRefresh();
      } else {
        throw Exception("Request failed");
      }
    } catch (e) {
      if (mounted) {
        OverlayService().showTopNotification(context, t.translate('notif_req_error'), Icons.error, (){}, color: Colors.red);
      }
      setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final String name = widget.notificationData['sender_name'] ?? "Someone";
    final String? profileUrl = widget.notificationData['sender_avatar'];
    var t = AppLocalizations.of(context)!;

    return Container(
      color: widget.isRead ? Colors.transparent : theme.primaryColor.withOpacity(0.05),
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: theme.dividerColor,
                backgroundImage: profileUrl != null && profileUrl.isNotEmpty ? CachedNetworkImageProvider(profileUrl, cacheManager: AppCacheManager.instance) : null,
                child: profileUrl == null || profileUrl.isEmpty ? Icon(Icons.person, color: Colors.white) : null,
              ),
              SizedBox(width: 16),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: theme.textTheme.bodyMedium,
                    children: [
                      TextSpan(text: name, style: TextStyle(fontWeight: FontWeight.bold)),
                      TextSpan(text: " ${t.translate('notif_req_body')}"),
                    ],
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (_isProcessing)
                SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              else ...[
                OutlinedButton(
                  onPressed: () => _handleRequest(false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: BorderSide(color: Colors.red.withOpacity(0.5))
                  ),
                  child: Text(t.translate('notif_req_decline'))
                ),
                SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () => _handleRequest(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: SisapaTheme.blue,
                    foregroundColor: Colors.white
                  ),
                  child: Text(t.translate('notif_req_confirm'))
                ),
              ]
            ],
          )
        ],
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final Map<String, dynamic> notificationData;
  final bool isRead;

  const _NotificationTile({
    required this.notificationData,
    required this.isRead,
  });

  void _navigateToTarget(BuildContext context) {
    final String type = notificationData['type'];
    final String? postId = notificationData['post_id'] ?? notificationData['postId'];
    final String senderId = notificationData['sender_uid'] ?? notificationData['senderId'];

    Navigator.of(context).pop();

    if (type == 'follow' || type == 'request_accepted') {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ProfilePage(userId: senderId, includeScaffold: true),
      ));
    } else if (postId != null && (type == 'like' || type == 'repost' || type == 'comment')) {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => PostDetailScreen(postId: postId),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final String senderId = notificationData['sender_uid'] ?? notificationData['senderId'] ?? '';
    var t = AppLocalizations.of(context)!;

    if (senderId == 'system' || senderId.isEmpty) {
      return _buildSystemTile(context, theme, t);
    }

    final String name = notificationData['sender_name'] ?? "Someone";
    final String? profileUrl = notificationData['sender_avatar'];
    return _buildUserTile(context, theme, name, profileUrl, t);
  }

  Widget _buildSystemTile(BuildContext context, ThemeData theme, AppLocalizations t) {
    final String type = notificationData['type'];
    final String text = notificationData['post_text_snippet'] ?? notificationData['postTextSnippet'] ?? '';
    final dynamic timestamp = notificationData['created_at'] ?? notificationData['timestamp'];

    IconData icon = Icons.info;
    Color color = theme.primaryColor;
    String title = t.translate('notif_sys_title');

    if (type == 'upload_complete') {
      icon = Icons.cloud_done;
      color = Colors.green;
      title = t.translate('notif_upload_title');
    }

    return Container(
      color: isRead ? Colors.transparent : theme.primaryColor.withOpacity(0.05),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.1),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 4),
            Text(text, maxLines: 2, overflow: TextOverflow.ellipsis),
            if (timestamp != null)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  timeago.format(DateTime.parse(timestamp.toString())),
                  style: TextStyle(fontSize: 12, color: theme.hintColor),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserTile(BuildContext context, ThemeData theme, String name, String? profileUrl, AppLocalizations t) {
    final String type = notificationData['type'];
    final String snippet = notificationData['post_text_snippet'] ?? notificationData['postTextSnippet'] ?? '';
    final dynamic timestamp = notificationData['created_at'] ?? notificationData['timestamp'];

    IconData badgeIcon;
    Color badgeColor;
    String actionText;

    switch (type) {
      case 'like':
        badgeIcon = Icons.favorite;
        badgeColor = Colors.pink;
        actionText = t.translate('action_liked');
        break;
      case 'repost':
        badgeIcon = Icons.repeat;
        badgeColor = Colors.green;
        actionText = t.translate('action_reposted');
        break;
      case 'comment':
        badgeIcon = Icons.chat_bubble;
        badgeColor = SisapaTheme.blue;
        actionText = t.translate('action_replied');
        break;
      case 'follow':
        badgeIcon = Icons.person_add;
        badgeColor = Colors.purple;
        actionText = t.translate('action_followed');
        break;
      case 'request_accepted':
        badgeIcon = Icons.check_circle;
        badgeColor = Colors.teal;
        actionText = t.translate('action_accepted');
        break;
      default:
        badgeIcon = Icons.notifications;
        badgeColor = Colors.grey;
        actionText = t.translate('action_interacted');
    }

    return InkWell(
      onTap: () => _navigateToTarget(context),
      child: Container(
        color: isRead ? Colors.transparent : theme.primaryColor.withOpacity(0.05),
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: theme.dividerColor,
                  backgroundImage: profileUrl != null && profileUrl.isNotEmpty ? CachedNetworkImageProvider(profileUrl, cacheManager: AppCacheManager.instance) : null,
                  child: profileUrl == null || profileUrl.isEmpty ? Icon(Icons.person, color: Colors.white) : null,
                ),
                Positioned(
                  bottom: -2,
                  right: -2,
                  child: Container(
                    padding: EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: badgeColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: theme.scaffoldBackgroundColor, width: 2),
                    ),
                    child: Icon(badgeIcon, size: 12, color: Colors.white),
                  ),
                )
              ],
            ),

            SizedBox(width: 16),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      style: theme.textTheme.bodyMedium,
                      children: [
                        TextSpan(
                          text: name,
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        TextSpan(text: " $actionText"),
                      ],
                    ),
                  ),
                  if (snippet.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        snippet,
                        style: TextStyle(color: theme.hintColor),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  if (timestamp != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        timeago.format(DateTime.parse(timestamp.toString())),
                        style: TextStyle(color: theme.hintColor, fontSize: 12),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
