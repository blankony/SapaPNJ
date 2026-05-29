import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../main.dart';
import '../theme/app_theme.dart';
import '../theme/avatar_helper.dart';
import 'dashboard/profile_page.dart';
import '../widgets/common_error_widget.dart';
import '../services/overlay_service.dart';
import '../services/app_localizations.dart';

class FollowListScreen extends StatefulWidget {
  final String userId;
  final int initialIndex;

  const FollowListScreen({
    super.key,
    required this.userId,
    this.initialIndex = 0,
  });

  @override
  State<FollowListScreen> createState() => _FollowListScreenState();
}

class _FollowListScreenState extends State<FollowListScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<String> _followingIds = [];
  List<String> _followersIds = [];
  bool _isLoading = true;
  bool _hasError = false;

  bool get _isMe => FirebaseAuth.instance.currentUser?.uid == widget.userId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialIndex,
    );
    _fetchLists();
  }

  Future<void> _fetchLists() async {
    setState(() { _isLoading = true; _hasError = false; });
    try {
      final data = await ApiService().getUser(widget.userId);
      if (data != null) {
        if (mounted) {
          setState(() {
            _followingIds = List<String>.from(data['following'] ?? []);
            _followersIds = List<String>.from(data['followers'] ?? []);
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() { _isLoading = false; });
      }
    } catch (e) {
      debugPrint("Error fetching lists: $e");
      if (mounted) setState(() { _isLoading = false; _hasError = true; });
    }
  }

  // --- REMOVE FOLLOWER LOGIC ---
  Future<void> _removeFollower(String followerId) async {
    var t = AppLocalizations.of(context)!;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.translate('follow_remove_title')),
        content: Text(t.translate('follow_remove_content')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t.translate('general_cancel'))
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t.translate('follow_remove_btn'), style: TextStyle(color: Colors.red))
          ),
        ],
      )
    ) ?? false;

    if (!confirm) return;

    try {
      setState(() {
        _followersIds.remove(followerId);
      });

      await ApiService().removeFollower(followerId);

      if(mounted) OverlayService().showTopNotification(context, t.translate('follow_removed_msg'), Icons.person_remove, (){});

    } catch (e) {
      // Revert if failed
      _fetchLists();
      if(mounted) OverlayService().showTopNotification(context, t.translate('follow_remove_fail'), Icons.error, (){}, color: Colors.red);
    }
  }

  // Cleanup ghosts (Users that have been deleted but whose IDs are still stuck)
  void _cleanupDeadUser(String deadUserId, String listType) {
    // Handled automatically by database ON DELETE CASCADE foreign key constraints
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<String> get _mutualsIds {
    final followingSet = _followingIds.toSet();
    final followersSet = _followersIds.toSet();
    return followingSet.intersection(followersSet).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    var t = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isMe ? t.translate('follow_title_me') : t.translate('follow_title'),
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: theme.primaryColor,
          unselectedLabelColor: theme.hintColor,
          indicatorColor: theme.primaryColor,
          tabs: [
            Tab(text: t.translate('follow_tab_mutuals')),
            Tab(text: t.translate('follow_tab_following')),
            Tab(text: t.translate('follow_tab_followers')),
          ],
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _hasError
            ? CommonErrorWidget(
                message: t.translate('follow_error'),
                isConnectionError: true,
                onRetry: _fetchLists
              )
            : TabBarView(
              controller: _tabController,
              children: [
                _UserList(
                  userIds: _mutualsIds,
                  emptyMessage: t.translate('follow_no_mutuals'),
                  listType: 'mutuals',
                  onDeadUserFound: (id) {},
                ),
                _UserList(
                  userIds: _followingIds,
                  emptyMessage: t.translate('follow_no_following'),
                  listType: 'following',
                  onDeadUserFound: (id) => _cleanupDeadUser(id, 'following'),
                ),
                _UserList(
                  userIds: _followersIds,
                  emptyMessage: t.translate('follow_no_followers'),
                  listType: 'followers',
                  onDeadUserFound: (id) => _cleanupDeadUser(id, 'followers'),
                  onRemoveAction: _isMe ? _removeFollower : null,
                ),
              ],
            ),
    );
  }
}

class _UserList extends StatelessWidget {
  final List<String> userIds;
  final String emptyMessage;
  final String listType;
  final Function(String) onDeadUserFound;
  final Function(String)? onRemoveAction;

  const _UserList({
    required this.userIds,
    required this.emptyMessage,
    required this.listType,
    required this.onDeadUserFound,
    this.onRemoveAction,
  });

  @override
  Widget build(BuildContext context) {
    if (userIds.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey.withOpacity(0.5)),
            SizedBox(height: 16),
            Text(emptyMessage, style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: userIds.length,
      itemBuilder: (context, index) {
        return _UserTile(
          userId: userIds[index],
          onDeadUser: () => onDeadUserFound(userIds[index]),
          onRemove: onRemoveAction != null ? () => onRemoveAction!(userIds[index]) : null,
        );
      },
    );
  }
}

class _UserTile extends StatelessWidget {
  final String userId;
  final VoidCallback onDeadUser;
  final VoidCallback? onRemove; // Optional remove button

  const _UserTile({
    required this.userId,
    required this.onDeadUser,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    var t = AppLocalizations.of(context)!;

    return FutureBuilder<Map<String, dynamic>?>(
      future: ApiService().getUser(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SizedBox(height: 60, child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))));
        }

        if (!snapshot.hasData || snapshot.data == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            onDeadUser();
          });
          return SizedBox.shrink();
        }

        final data = snapshot.data!;

        final name = data['name'] ?? 'User';
        final email = data['email'] ?? '';
        final handle = email.isNotEmpty ? "@${email.split('@')[0]}" : "";
        final profileImageUrl = data['profile_image_url'] ?? data['profileImageUrl'];
        final int iconId = data['avatar_icon_id'] ?? data['avatarIconId'] ?? 0;
        final String? colorHex = data['avatar_hex'] ?? data['avatarHex'];

        return InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ProfilePage(userId: userId, includeScaffold: true)
              )
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: profileImageUrl != null ? Colors.transparent : AvatarHelper.getColor(colorHex),
                  backgroundImage: profileImageUrl != null ? CachedNetworkImageProvider(profileImageUrl) : null,
                  child: profileImageUrl == null ? Icon(AvatarHelper.getIcon(iconId), size: 24, color: Colors.white) : null,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      Text(handle, style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor)),
                    ],
                  ),
                ),
                // Show Remove Button if applicable
                if (onRemove != null)
                  OutlinedButton(
                    onPressed: onRemove,
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                      side: BorderSide(color: theme.dividerColor),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    child: Text(t.translate('follow_remove_btn'), style: TextStyle(color: theme.textTheme.bodyMedium?.color, fontSize: 12)),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
