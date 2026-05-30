import 'package:flutter/material.dart';
import '../../services/app_cache_manager.dart';

import '../../services/api_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'create_community_screen.dart';
import 'community_detail_screen.dart';
import 'browse_communities_screen.dart';
import '../../widgets/blog_post_card.dart';
import '../../theme/app_theme.dart';
import '../../services/app_localizations.dart';

class CommunityListTab extends StatefulWidget {
  const CommunityListTab({super.key});

  @override
  State<CommunityListTab> createState() => _CommunityListTabState();
}

class _CommunityListTabState extends State<CommunityListTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  Route _createSlideUpRoute(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(0.0, 1.0);
        const end = Offset.zero;
        const curve = Curves.easeOutQuart;
        var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
        return SlideTransition(position: animation.drive(tween), child: child);
      },
    );
  }

  Future<List<Map<String, dynamic>>> _fetchCommunityBroadcasts() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return [];

      final communities = await ApiService().getMyCommunities();
      if (communities.isEmpty) return [];

      final List<Future<List<Map<String, dynamic>>>> futures = [];
      for (var c in communities) {
        futures.add(ApiService().getPosts(communityId: c['id'], limit: 20));
      }

      final results = await Future.wait(futures);
      final List<Map<String, dynamic>> allPosts = [];
      for (var list in results) {
        allPosts.addAll(list);
      }

      // Sort by created_at descending
      allPosts.sort((a, b) {
        final aTime = DateTime.tryParse(a['created_at'] ?? '') ?? DateTime(0);
        final bTime = DateTime.tryParse(b['created_at'] ?? '') ?? DateTime(0);
        return bTime.compareTo(aTime);
      });

      return allPosts.take(50).toList();
    } catch (e) {
      debugPrint("Error fetching broadcasts: $e");
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final user = FirebaseAuth.instance.currentUser;
    final theme = Theme.of(context);

    // LOCALIZATION
    var t = AppLocalizations.of(context)!;

    if (user == null) return Center(child: Text(t.translate('login_required'))); // "Login required"

    // Calculate tighter top padding
    final double topPadding = MediaQuery.of(context).padding.top + kToolbarHeight - 10;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CustomScrollView(
        slivers: [
          // 1. HEADER (Action Buttons)
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, topPadding, 16, 16),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOutBack,
                builder: (context, value, child) {
                  return Transform.scale(scale: value, child: child);
                },
                child: Row(
                  children: [
                    Expanded(
                      child: _buildHeaderAction(
                        context,
                        t.translate('community_discover'), // "Discover"
                        Icons.explore_outlined,
                        SisapaTheme.blue,
                        () => Navigator.push(context, _createSlideUpRoute(BrowseCommunitiesScreen())),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: _buildHeaderAction(
                        context,
                        t.translate('community_create_short'), // "Create"
                        Icons.group_add_outlined,
                        Colors.green,
                        () => Navigator.push(context, _createSlideUpRoute(CreateCommunityScreen())),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 2. YOUR CHANNELS
          FutureBuilder<List<Map<String, dynamic>>>(
            future: ApiService().getMyCommunities(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return SliverToBoxAdapter(child: SizedBox.shrink());
              }

              final myCommunities = snapshot.data!.where((c) => c['owner_uid'] == user.uid).toList();

              if (myCommunities.isEmpty) {
                return SliverToBoxAdapter(child: SizedBox.shrink());
              }

              return SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: Text(
                        t.translate('community_your_channels'), // "Your Channels"
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)
                      ),
                    ),
                    SizedBox(
                      height: 120, // Increased slightly for breathing room
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        itemCount: myCommunities.length,
                        itemBuilder: (context, index) {
                          final data = myCommunities[index];
                          final id = data['id'];

                          // Manual Staggered Animation (Without external package)
                          return TweenAnimationBuilder<Offset>(
                            tween: Tween(begin: Offset(100, 0), end: Offset.zero),
                            duration: Duration(milliseconds: 400 + (index * 100)),
                            curve: Curves.easeOutQuart,
                            builder: (context, offset, child) => Transform.translate(offset: offset, child: child),
                            child: _buildMyChannelItem(context, id, data),
                          );
                        },
                      ),
                    ),
                    Divider(height: 32, thickness: 1, color: theme.dividerColor.withOpacity(0.5)),
                  ],
                ),
              );
            },
          ),

          // 3. FEED HEADER
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 0.0),
              child: Row(
                children: [
                  Icon(Icons.dynamic_feed, color: theme.primaryColor, size: 20),
                  SizedBox(width: 8),
                  Text(t.translate('community_broadcast'), // "Broadcast Feed"
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                ],
              ),
            ),
          ),

          // 4. FEED CONTENT
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _fetchCommunityBroadcasts(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return SliverToBoxAdapter(child: SizedBox(height: 100, child: Center(child: CircularProgressIndicator())));

              final communityPosts = snapshot.data ?? [];

              if (communityPosts.isEmpty) {
                return SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: Text(t.translate('community_no_broadcasts'), // "No recent broadcasts."
                        style: TextStyle(color: theme.hintColor)))
                  )
                );
              }

              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final pData = communityPosts[index];
                    final pId = pData['id'] ?? '';

                    // Entrance Animation for Feed
                    return TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: Duration(milliseconds: 500),
                      curve: Curves.easeOut,
                      builder: (context, val, child) => Opacity(opacity: val, child: Transform.translate(offset: Offset(0, 50 * (1-val)), child: child)),
                      child: RepaintBoundary(
                        child: BlogPostCard(
                          postId: pId,
                          postData: pData,
                          isOwner: pData['user_uid'] == user.uid,
                          heroContextId: 'community_feed',
                        ),
                      ),
                    );
                  },
                  childCount: communityPosts.length,
                ),
              );
            },
          ),

          SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _buildHeaderAction(BuildContext context, String label, IconData icon, Color color, VoidCallback onTap) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.05),
              blurRadius: 10,
              offset: Offset(0, 4),
            )
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 26),
            SizedBox(height: 8),
            Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildMyChannelItem(BuildContext context, String id, Map<String, dynamic> data) {
    final String name = data['name'] ?? 'Channel';
    final String? imageUrl = data['imageUrl'];
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6.0),
      child: GestureDetector(
        onTap: () {
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => CommunityDetailScreen(communityId: id, communityData: data)
          ));
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: SisapaTheme.blue.withOpacity(0.5), width: 2),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0,2))]
              ),
              child: CircleAvatar(
                radius: 32,
                backgroundColor: theme.cardColor,
                backgroundImage: imageUrl != null ? CachedNetworkImageProvider(imageUrl, cacheManager: AppCacheManager.instance) : null,
                child: imageUrl == null ? Text(name[0].toUpperCase(), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: SisapaTheme.blue)) : null,
              ),
            ),
            SizedBox(height: 8),
            SizedBox(
              width: 75,
              child: Text(
                name,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
