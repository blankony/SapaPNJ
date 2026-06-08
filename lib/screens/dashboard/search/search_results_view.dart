import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../services/app_cache_manager.dart';
import '../../../services/app_localizations.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/blog_post_card.dart';
import '../../../widgets/common_error_widget.dart';
import '../../community/community_detail_screen.dart';
import '../../../widgets/user_search_tile.dart';

class SearchResultsView extends StatelessWidget {
  final TabController tabController;
  final String searchText;
  final String? currentUserId;
  final List<String> blockedUserIds;
  final List<String> followingIds;
  final Future<List<Map<String, dynamic>>>? postSearchFuture;
  final Future<List<Map<String, dynamic>>>? userSearchFuture;
  final Future<List<Map<String, dynamic>>>? communitySearchFuture;
  final void Function(String userId, bool isFollowing) onFollowStateChanged;

  const SearchResultsView({
    super.key,
    required this.tabController,
    required this.searchText,
    required this.currentUserId,
    required this.blockedUserIds,
    required this.followingIds,
    required this.postSearchFuture,
    required this.userSearchFuture,
    required this.communitySearchFuture,
    required this.onFollowStateChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context)!;

    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: theme.dividerColor)),
          ),
          child: TabBar(
            controller: tabController,
            labelColor: theme.primaryColor,
            unselectedLabelColor: theme.hintColor,
            indicatorColor: theme.primaryColor,
            tabs: [
              Tab(text: t.translate('search_tab_posts')),
              Tab(text: t.translate('search_tab_users')),
              Tab(text: t.translate('search_tab_communities')),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: tabController,
            children: [
              _PostResults(
                searchText: searchText,
                currentUserId: currentUserId,
                blockedUserIds: blockedUserIds,
                searchFuture: postSearchFuture,
              ),
              _UserResults(
                searchText: searchText,
                currentUserId: currentUserId,
                followingIds: followingIds,
                searchFuture: userSearchFuture,
                onFollowStateChanged: onFollowStateChanged,
              ),
              _CommunityResults(
                searchText: searchText,
                searchFuture: communitySearchFuture,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PostResults extends StatelessWidget {
  final String searchText;
  final String? currentUserId;
  final List<String> blockedUserIds;
  final Future<List<Map<String, dynamic>>>? searchFuture;

  const _PostResults({
    required this.searchText,
    required this.currentUserId,
    required this.blockedUserIds,
    required this.searchFuture,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    if (searchText.isEmpty) return const SizedBox.shrink();

    final future = searchFuture;
    if (future == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return CommonErrorWidget(
            message: t.translate('search_failed'),
            isConnectionError: true,
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final posts = snapshot.data ?? [];
        final filteredPosts = posts.where((post) {
          final authorId = post['user_uid'] ?? post['userId'];
          return !blockedUserIds.contains(authorId);
        }).toList();

        if (filteredPosts.isEmpty) {
          return _EmptySearchResult(searchText: searchText);
        }

        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 100),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          itemCount: filteredPosts.length,
          itemBuilder: (context, index) {
            final post = filteredPosts[index];
            final authorId = post['user_uid'] ?? post['userId'];
            return BlogPostCard(
              postId: post['id'],
              postData: post,
              isOwner: authorId == currentUserId,
              heroContextId: 'search_results',
              blockedUserIds: blockedUserIds,
            );
          },
        );
      },
    );
  }
}

class _UserResults extends StatelessWidget {
  final String searchText;
  final String? currentUserId;
  final List<String> followingIds;
  final Future<List<Map<String, dynamic>>>? searchFuture;
  final void Function(String userId, bool isFollowing) onFollowStateChanged;

  const _UserResults({
    required this.searchText,
    required this.currentUserId,
    required this.followingIds,
    required this.searchFuture,
    required this.onFollowStateChanged,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    if (searchText.isEmpty) return const SizedBox.shrink();

    final future = searchFuture;
    if (future == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return CommonErrorWidget(
            message: t.translate('search_user_failed'),
            isConnectionError: true,
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final users = snapshot.data ?? [];
        final filteredUsers = users
            .where((user) => (user['uid'] ?? user['id']) != currentUserId)
            .toList();

        if (filteredUsers.isEmpty) {
          return _EmptySearchResult(searchText: searchText);
        }

        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 100),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          itemCount: filteredUsers.length,
          itemBuilder: (context, index) {
            final user = filteredUsers[index];
            final String userId = user['uid'] ?? user['id'] ?? '';
            return UserSearchTile(
              userId: userId,
              userData: user,
              currentUserId: currentUserId,
              initialIsFollowing: followingIds.contains(userId),
              onFollowStateChanged: onFollowStateChanged,
            );
          },
        );
      },
    );
  }
}

class _CommunityResults extends StatelessWidget {
  final String searchText;
  final Future<List<Map<String, dynamic>>>? searchFuture;

  const _CommunityResults({
    required this.searchText,
    required this.searchFuture,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    if (searchText.isEmpty) return const SizedBox.shrink();

    final future = searchFuture;
    if (future == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return CommonErrorWidget(
            message: t.translate('search_failed'),
            isConnectionError: true,
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final communities = snapshot.data ?? [];
        if (communities.isEmpty) {
          return _EmptySearchResult(searchText: searchText);
        }

        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 100),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          itemCount: communities.length,
          itemBuilder: (context, index) {
            return _CommunityResultTile(community: communities[index]);
          },
        );
      },
    );
  }
}

class _CommunityResultTile extends StatelessWidget {
  final Map<String, dynamic> community;

  const _CommunityResultTile({required this.community});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final String name = community['name'] ?? 'Community';
    final String? imageUrl = community['image_url'] ?? community['imageUrl'];
    final int memberCount = community['follower_count'] ?? 0;

    return ListTile(
      leading: CircleAvatar(
        backgroundImage: imageUrl != null && imageUrl.isNotEmpty
            ? CachedNetworkImageProvider(
                imageUrl,
                cacheManager: AppCacheManager.instance,
              )
            : null,
        backgroundColor: SisapaTheme.blue.withValues(alpha: 0.1),
        child: imageUrl == null || imageUrl.isEmpty
            ? const Icon(Icons.groups, color: SisapaTheme.blue)
            : null,
      ),
      title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text("$memberCount ${t.translate('general_members')}"),
      trailing: const Icon(Icons.arrow_forward_ios, size: 14),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CommunityDetailScreen(
              communityId: community['id'],
              communityData: community,
            ),
          ),
        );
      },
    );
  }
}

class _EmptySearchResult extends StatelessWidget {
  final String searchText;

  const _EmptySearchResult({required this.searchText});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    return Center(
      child: Text('${t.translate('search_no_results')} "$searchText"'),
    );
  }
}
