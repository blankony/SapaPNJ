import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../main.dart';
import '../../theme/app_theme.dart';
import '../../theme/avatar_helper.dart';
import 'community_detail_screen.dart';
import '../../services/app_localizations.dart';
import '../../services/api_service.dart';

class BrowseCommunitiesScreen extends StatefulWidget {
  const BrowseCommunitiesScreen({super.key});

  @override
  State<BrowseCommunitiesScreen> createState() => _BrowseCommunitiesScreenState();
}

class _BrowseCommunitiesScreenState extends State<BrowseCommunitiesScreen> {
  final ApiService _api = ApiService();
  List<Map<String, dynamic>> _communities = [];
  Set<String> _myCommunityIds = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCommunities();
  }

  Future<void> _loadCommunities() async {
    try {
      final results = await Future.wait([
        _api.getCommunities(),
        _api.getMyCommunities(),
      ]);

      if (mounted) {
        setState(() {
          _communities = results[0];
          _myCommunityIds = results[1].map((c) => c['id'] as String).toSet();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading communities: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _followCommunity(String communityId) async {
    try {
      await _api.followCommunity(communityId);
      _loadCommunities();
    } catch (e) {
      debugPrint("Error following community: $e");
    }
  }

  Future<void> _unfollowCommunity(String communityId) async {
    try {
      await _api.unfollowCommunity(communityId);
      _loadCommunities();
    } catch (e) {
      debugPrint("Error unfollowing community: $e");
    }
  }

  void _showUnfollowDialog(BuildContext context, String communityId, String communityName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Unfollow $communityName?"),
        content: const Text("Apakah Anda yakin ingin berhenti mengikuti komunitas ini?"),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Batal", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _unfollowCommunity(communityId);
            },
            child: const Text("Unfollow", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    var t = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Sorting logic
    final sortedCommunities = List<Map<String, dynamic>>.from(_communities)..sort((a, b) {
      final catA = a['category'] ?? 'casual';
      final catB = b['category'] ?? 'casual';
      final priority = {'pnj_official': 3, 'partner_official': 2, 'casual': 1};
      return (priority[catB] ?? 0).compareTo(priority[catA] ?? 0);
    });

    return Scaffold(
      appBar: AppBar(title: Text(t.translate('comm_explore_title'))),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadCommunities,
          child: ListView.builder(
            key: const PageStorageKey('browse_communities_list'),
            padding: const EdgeInsets.all(16),
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: sortedCommunities.length,
            itemBuilder: (context, index) {
              final data = sortedCommunities[index];
              final String id = data['id'];
              final String name = data['name'] ?? 'Unnamed';
              final String? imageUrl = data['image_url'];
              final String category = data['category'] ?? 'casual';
              final int followerCount = data['follower_count'] ?? 0;

              final bool isFollowing = _myCommunityIds.contains(id);

              IconData badgeIcon = Icons.tag_faces;
              Color badgeColor = Colors.grey;
              if (category == 'pnj_official') {
                badgeIcon = Icons.account_balance;
                badgeColor = SisapaTheme.blue;
              } else if (category == 'partner_official') {
                badgeIcon = Icons.verified;
                badgeColor = Colors.blueGrey;
              }

              return RepaintBoundary(
                child: Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    leading: CircleAvatar(
                      radius: 28,
                      backgroundColor: badgeColor.withOpacity(0.1),
                      backgroundImage: imageUrl != null ? CachedNetworkImageProvider(imageUrl) : null,
                      child: imageUrl == null ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: TextStyle(color: badgeColor, fontWeight: FontWeight.bold)) : null,
                    ),
                    title: Row(
                      children: [
                        Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.bold))),
                        if (category == 'pnj_official') const Icon(Icons.verified, size: 16, color: SisapaTheme.blue),
                      ],
                    ),
                    subtitle: Row(
                      children: [
                        Icon(badgeIcon, size: 12, color: badgeColor),
                        const SizedBox(width: 4),
                        Text("$followerCount ${t.translate('comm_followers_count')}", style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                    trailing: isFollowing
                      ? IconButton(
                          tooltip: "Unfollow",
                          icon: const Icon(Icons.check_circle, color: Colors.green, size: 28),
                          onPressed: () {
                            if (user != null) {
                              _showUnfollowDialog(context, id, name);
                            }
                          },
                        )
                      : IconButton(
                          tooltip: "Follow",
                          icon: const Icon(Icons.add_circle, color: SisapaTheme.blue, size: 28),
                          onPressed: () {
                            if (user != null) {
                              _followCommunity(id);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Please login to follow channels"))
                              );
                            }
                          },
                        ),
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(
                        builder: (_) => CommunityDetailScreen(communityId: id, communityData: data)
                      ));
                    },
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
