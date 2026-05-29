import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../main.dart';
import '../../theme/app_theme.dart';
import '../../theme/avatar_helper.dart';
import '../dashboard/profile_page.dart';
import '../../services/overlay_service.dart';
import '../../services/api_service.dart';
import '../../services/app_localizations.dart';

class CommunityMembersScreen extends StatefulWidget {
  final String communityId;
  final Map<String, dynamic> communityData;
  final bool isStaff;

  const CommunityMembersScreen({
    super.key,
    required this.communityId,
    required this.communityData,
    required this.isStaff,
  });

  @override
  State<CommunityMembersScreen> createState() => _CommunityMembersScreenState();
}

class _CommunityMembersScreenState extends State<CommunityMembersScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  List<Map<String, dynamic>> _members = [];
  Map<String, dynamic>? _communityData;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final membersList = await ApiService().getCommunityMembers(widget.communityId);
      final communityDetails = await ApiService().getCommunity(widget.communityId);
      if (mounted) {
        setState(() {
          _members = membersList;
          _communityData = communityDetails;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        OverlayService().showTopNotification(context, "Error loading members", Icons.error, (){}, color: Colors.red);
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // LOCALIZATION
    var t = AppLocalizations.of(context)!;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(t.translate('community_members')),
          centerTitle: true,
        ),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final ownerId = _communityData?['owner_uid'] ?? '';
    final followers = _members.where((m) => m['role'] == 'follower' && m['uid'] != ownerId).toList();
    final staff = _members.where((m) => m['role'] != 'follower' || m['uid'] == ownerId).toList();

    // Sort staff: owner first, then admins, then editors, then moderators
    staff.sort((a, b) {
      if (a['uid'] == ownerId) return -1;
      if (b['uid'] == ownerId) return 1;

      final roleOrder = {'admin': 1, 'editor': 2, 'moderator': 3, 'follower': 4};
      final orderA = roleOrder[a['role']] ?? 5;
      final orderB = roleOrder[b['role']] ?? 5;
      return orderA.compareTo(orderB);
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(t.translate('community_members')),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          labelColor: SisapaTheme.blue,
          unselectedLabelColor: theme.hintColor,
          indicatorSize: TabBarIndicatorSize.label,
          tabs: [
            Tab(text: t.translate('profile_followers')),
            Tab(text: "Admins & Staff"),
          ],
        ),
      ),
      body: Stack(
        children: [
          Positioned(
            top: 50,
            right: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: SisapaTheme.blue.withOpacity(isDark ? 0.05 : 0.03),
              ),
            ),
          ),
          TabBarView(
            controller: _tabController,
            children: [
              _FollowersList(followersList: followers),
              _StaffList(staffList: staff, ownerId: ownerId),
            ],
          ),
        ],
      ),
    );
  }
}

class _FollowersList extends StatelessWidget {
  final List<Map<String, dynamic>> followersList;

  const _FollowersList({required this.followersList});

  @override
  Widget build(BuildContext context) {
    var t = AppLocalizations.of(context)!;

    if (followersList.isEmpty) {
      return Center(
        child: Text(
          "${t.translate('search_no_results')} ${t.translate('profile_followers')}",
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      itemCount: followersList.length,
      itemBuilder: (context, index) {
        final member = followersList[index];
        return _DelayedSlideFade(
          delay: index * 50,
          child: _UserTile(userData: member),
        );
      },
    );
  }
}

class _StaffList extends StatelessWidget {
  final List<Map<String, dynamic>> staffList;
  final String ownerId;

  const _StaffList({required this.staffList, required this.ownerId});

  @override
  Widget build(BuildContext context) {
    if (staffList.isEmpty) {
      return Center(
        child: Text(
          "No staff members found",
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.all(16),
      itemCount: staffList.length,
      separatorBuilder: (_, __) => Divider(height: 1),
      itemBuilder: (context, index) {
        final member = staffList[index];
        final String userId = member['uid'] ?? '';
        final bool isOwner = userId == ownerId;
        final String role = member['role'] ?? 'follower';

        String roleTitle = isOwner ? 'Owner' : 'Member';
        Color roleColor = Colors.grey;

        if (isOwner) {
          roleTitle = 'Owner';
          roleColor = Colors.red;
        } else if (role == 'admin') {
          roleTitle = 'Admin';
          roleColor = Colors.blue;
        } else if (role == 'editor') {
          roleTitle = 'Editor';
          roleColor = Colors.green;
        } else if (role == 'moderator') {
          roleTitle = 'Moderator';
          roleColor = Colors.orange;
        }

        return _DelayedSlideFade(
          delay: index * 50,
          child: _UserTile(
            userData: member,
            roleBadge: Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: roleColor, borderRadius: BorderRadius.circular(8)),
              child: Text(roleTitle, style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
          ),
        );
      },
    );
  }
}

class _DelayedSlideFade extends StatefulWidget {
  final Widget child;
  final int delay;

  const _DelayedSlideFade({required this.child, required this.delay});

  @override
  State<_DelayedSlideFade> createState() => _DelayedSlideFadeState();
}

class _DelayedSlideFadeState extends State<_DelayedSlideFade> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<Offset> _slideAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _slideAnim = Tween<Offset>(begin: Offset(0, 0.2), end: Offset.zero).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));

    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _animController.forward();
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: widget.child,
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  final Map<String, dynamic> userData;
  final Widget? roleBadge;

  const _UserTile({required this.userData, this.roleBadge});

  @override
  Widget build(BuildContext context) {
    final String userId = userData['uid'] ?? '';
    final String name = userData['name'] ?? 'User';
    final String email = userData['email'] ?? '';
    final String? url = userData['profile_image_url'];
    final int iconId = userData['avatar_icon_id'] ?? userData['avatarIconId'] ?? 0;
    final String? colorHex = userData['avatar_hex'] ?? userData['avatarHex'];

    return ListTile(
      contentPadding: EdgeInsets.symmetric(vertical: 4),
      leading: CircleAvatar(
        backgroundImage: url != null && url.isNotEmpty ? CachedNetworkImageProvider(url) : null,
        backgroundColor: AvatarHelper.getColor(colorHex),
        child: url == null || url.isEmpty ? Icon(AvatarHelper.getIcon(iconId), color: Colors.white) : null,
      ),
      title: Row(
        children: [
          Text(name, style: TextStyle(fontWeight: FontWeight.bold)),
          if (roleBadge != null) ...[SizedBox(width: 8), roleBadge!],
        ],
      ),
      subtitle: Text("@${email.split('@')[0]}"),
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProfilePage(userId: userId, includeScaffold: true))),
    );
  }
}
