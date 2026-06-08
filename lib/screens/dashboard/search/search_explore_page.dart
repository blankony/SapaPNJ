import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../services/app_cache_manager.dart';
import '../../../services/app_localizations.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/blog_post_card.dart';
import '../../../widgets/common/common_error_widget.dart';
import '../../community/community_detail_screen.dart';
import '../../../widgets/search/user_search_tile.dart';

class SearchExplorePage extends StatelessWidget {
  final bool isListening;
  final String? currentUserId;
  final bool showAllTrending;
  final bool showAllDiscover;
  final bool showAllPeople;
  final List<String> blockedUserIds;
  final List<String> followingIds;
  final Future<List<Map<String, dynamic>>>? trendingFuture;
  final Future<List<Map<String, dynamic>>>? discoverFuture;
  final Future<List<Map<String, dynamic>>>? communityRecFuture;
  final Future<List<Map<String, dynamic>>>? peopleRecFuture;
  final RefreshCallback onRefresh;
  final ValueChanged<String> onTrendingTagClicked;
  final VoidCallback onToggleTrending;
  final VoidCallback onToggleDiscover;
  final VoidCallback onTogglePeople;
  final void Function(String userId, bool isFollowing) onFollowStateChanged;

  const SearchExplorePage({
    super.key,
    required this.isListening,
    required this.currentUserId,
    required this.showAllTrending,
    required this.showAllDiscover,
    required this.showAllPeople,
    required this.blockedUserIds,
    required this.followingIds,
    required this.trendingFuture,
    required this.discoverFuture,
    required this.communityRecFuture,
    required this.peopleRecFuture,
    required this.onRefresh,
    required this.onTrendingTagClicked,
    required this.onToggleTrending,
    required this.onToggleDiscover,
    required this.onTogglePeople,
    required this.onFollowStateChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context)!;

    return RefreshIndicator(
      notificationPredicate: (_) => !isListening,
      onRefresh: onRefresh,
      child: SingleChildScrollView(
        physics: isListening
            ? const NeverScrollableScrollPhysics()
            : const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.only(bottom: 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader(
              icon: Icons.trending_up,
              iconColor: SisapaTheme.blue,
              title: t.translate('search_trending_title'),
            ),
            _TrendingTopics(
              future: trendingFuture,
              showAll: showAllTrending,
              onToggle: onToggleTrending,
              onTagSelected: onTrendingTagClicked,
            ),
            _SectionDivider(theme: theme),
            _SectionHeader(
              icon: Icons.groups_outlined,
              iconColor: Colors.orange,
              title: t.translate('search_communities_title'),
              topPadding: 12,
              bottomPadding: 8,
            ),
            _RecommendedCommunities(future: communityRecFuture),
            _SectionDivider(theme: theme),
            _SectionHeader(
              icon: Icons.explore_outlined,
              iconColor: Colors.purple,
              title: t.translate('search_discover_title'),
              topPadding: 12,
              bottomPadding: 8,
            ),
            _DiscoverPosts(
              future: discoverFuture,
              showAll: showAllDiscover,
              currentUserId: currentUserId,
              blockedUserIds: blockedUserIds,
              onToggle: onToggleDiscover,
            ),
            _SectionDivider(theme: theme),
            _SectionHeader(
              icon: Icons.person_add_alt_1_outlined,
              iconColor: Colors.blueAccent,
              title: t.translate('search_people_title'),
              topPadding: 12,
              bottomPadding: 8,
            ),
            _SuggestedPeople(
              future: peopleRecFuture,
              showAll: showAllPeople,
              currentUserId: currentUserId,
              followingIds: followingIds,
              onToggle: onTogglePeople,
              onFollowStateChanged: onFollowStateChanged,
            ),
          ],
        ),
      ),
    );
  }
}

class _TrendingTopics extends StatelessWidget {
  final Future<List<Map<String, dynamic>>>? future;
  final bool showAll;
  final VoidCallback onToggle;
  final ValueChanged<String> onTagSelected;

  const _TrendingTopics({
    required this.future,
    required this.showAll,
    required this.onToggle,
    required this.onTagSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context)!;

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingBlock(height: 100);
        }
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Text(t.translate('search_trends_error')),
          );
        }

        final trends = snapshot.data ?? [];
        if (trends.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              t.translate('search_trends_empty'),
              style: const TextStyle(color: Colors.grey),
            ),
          );
        }

        final maxItems = showAll ? 10 : 3;
        final displayedTrends = trends.take(maxItems).toList();
        final canExpand = trends.length > 3;

        return Column(
          children: [
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              itemCount: displayedTrends.length,
              separatorBuilder: (context, index) => Divider(
                height: 1,
                thickness: 0.5,
                color: theme.dividerColor.withValues(alpha: 0.3),
              ),
              itemBuilder: (context, index) {
                final tag = displayedTrends[index]['tag'];
                final count = displayedTrends[index]['count'];
                final isHashtag = tag.toString().startsWith('#');

                return ListTile(
                  dense: false,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  leading: Text(
                    '${index + 1}',
                    style: TextStyle(
                      color: theme.hintColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  title: Text(
                    tag,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: isHashtag
                          ? SisapaTheme.blue
                          : theme.textTheme.bodyLarge?.color,
                    ),
                  ),
                  subtitle: Text('$count distinct posts'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (index == 0)
                        const Padding(
                          padding: EdgeInsets.only(right: 8.0),
                          child: Icon(
                            Icons.local_fire_department,
                            color: Colors.orange,
                            size: 20,
                          ),
                        ),
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 14,
                        color: theme.hintColor,
                      ),
                    ],
                  ),
                  onTap: () => onTagSelected(tag),
                );
              },
            ),
            if (canExpand)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                child: _InlineShowMoreButton(
                  isExpanded: showAll,
                  onPressed: onToggle,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _RecommendedCommunities extends StatelessWidget {
  final Future<List<Map<String, dynamic>>>? future;

  const _RecommendedCommunities({required this.future});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingBlock(height: 100);
        }
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Text(t.translate('search_communities_error')),
          );
        }

        final recommended = snapshot.data ?? [];
        if (recommended.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              t.translate('search_communities_empty'),
              style: const TextStyle(color: Colors.grey),
            ),
          );
        }

        return SizedBox(
          height: 160,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: recommended.length > 10 ? 10 : recommended.length,
            itemBuilder: (context, index) {
              return _CommunityRecommendationCard(data: recommended[index]);
            },
          ),
        );
      },
    );
  }
}

class _DiscoverPosts extends StatelessWidget {
  final Future<List<Map<String, dynamic>>>? future;
  final bool showAll;
  final String? currentUserId;
  final List<String> blockedUserIds;
  final VoidCallback onToggle;

  const _DiscoverPosts({
    required this.future,
    required this.showAll,
    required this.currentUserId,
    required this.blockedUserIds,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingBlock(height: 100);
        }
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: CommonErrorWidget(
              message: t.translate('search_discover_error'),
              isConnectionError: true,
            ),
          );
        }

        final allPosts = snapshot.data ?? [];
        if (allPosts.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 32.0,
            ),
            child: Center(child: Text(t.translate('search_discover_empty'))),
          );
        }

        const initialCount = 5;
        final totalCount = allPosts.length;
        final visibleCount = showAll
            ? totalCount
            : (totalCount > initialCount ? initialCount : totalCount);
        final displayedPosts = allPosts.take(visibleCount).toList();
        final canExpand = totalCount > initialCount;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...displayedPosts.map((post) {
              final authorId = post['user_uid'] ?? post['userId'];
              return BlogPostCard(
                postId: post['id'],
                postData: post,
                isOwner: authorId == currentUserId,
                heroContextId: 'discover',
                blockedUserIds: blockedUserIds,
              );
            }),
            if (canExpand)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Center(
                  child: _CenteredShowMoreButton(
                    isExpanded: showAll,
                    onPressed: onToggle,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _SuggestedPeople extends StatelessWidget {
  final Future<List<Map<String, dynamic>>>? future;
  final bool showAll;
  final String? currentUserId;
  final List<String> followingIds;
  final VoidCallback onToggle;
  final void Function(String userId, bool isFollowing) onFollowStateChanged;

  const _SuggestedPeople({
    required this.future,
    required this.showAll,
    required this.currentUserId,
    required this.followingIds,
    required this.onToggle,
    required this.onFollowStateChanged,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(),
            ),
          );
        }
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Text(t.translate('search_people_error')),
          );
        }

        final allUsers = snapshot.data ?? [];
        if (allUsers.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(t.translate('search_people_empty')),
          );
        }

        const initialCount = 5;
        final totalCount = allUsers.length;
        final visibleCount = showAll
            ? totalCount
            : (totalCount > initialCount ? initialCount : totalCount);
        final displayedUsers = allUsers.take(visibleCount).toList();
        final canExpand = totalCount > initialCount;

        return Column(
          children: [
            ...displayedUsers.map((user) {
              final String userId = user['uid'] ?? user['id'] ?? '';
              return UserSearchTile(
                userId: userId,
                userData: user,
                currentUserId: currentUserId,
                initialIsFollowing: followingIds.contains(userId),
                onFollowStateChanged: onFollowStateChanged,
              );
            }),
            if (canExpand)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Center(
                  child: _CenteredShowMoreButton(
                    isExpanded: showAll,
                    onPressed: onToggle,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _CommunityRecommendationCard extends StatelessWidget {
  final Map<String, dynamic> data;

  const _CommunityRecommendationCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context)!;
    final name = data['name'] ?? 'Community';
    final imageUrl = data['image_url'] ?? data['imageUrl'];
    final membersCount = data['follower_count'] ?? 0;

    return Container(
      width: 140,
      margin: const EdgeInsets.all(4),
      child: FrostedSurface(
        margin: const EdgeInsets.all(4.0),
        borderRadius: BorderRadius.circular(12),
        tint: theme.cardColor.withValues(
          alpha: theme.brightness == Brightness.dark ? 0.78 : 0.74,
        ),
        blur: FrostedGlassTokens.blurSigma,
        border: Border.all(
          color: FrostedGlassTokens.subtleBorderSide(context).color,
        ),
        boxShadow: FrostedGlassTokens.materialDepth(context),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CommunityDetailScreen(
                    communityId: data['id'],
                    communityData: data,
                  ),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: SisapaTheme.blue.withValues(alpha: 0.1),
                    backgroundImage:
                        imageUrl != null && imageUrl.toString().isNotEmpty
                        ? CachedNetworkImageProvider(
                            imageUrl,
                            cacheManager: AppCacheManager.instance,
                          )
                        : null,
                    child: imageUrl == null || imageUrl.toString().isEmpty
                        ? Text(
                            name.isNotEmpty ? name[0].toUpperCase() : 'C',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: SisapaTheme.blue,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '$membersCount ${t.translate('general_members')}',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final double topPadding;
  final double bottomPadding;

  const _SectionHeader({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.topPadding = 0,
    this.bottomPadding = 12,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(16, topPadding, 16, bottomPadding),
      child: Row(
        children: [
          Icon(icon, color: iconColor),
          const SizedBox(width: 8),
          Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionDivider extends StatelessWidget {
  final ThemeData theme;

  const _SectionDivider({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Divider(
      thickness: 8,
      color: theme.dividerColor.withValues(alpha: 0.1),
    );
  }
}

class _LoadingBlock extends StatelessWidget {
  final double height;

  const _LoadingBlock({required this.height});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}

class _InlineShowMoreButton extends StatelessWidget {
  final bool isExpanded;
  final VoidCallback onPressed;

  const _InlineShowMoreButton({
    required this.isExpanded,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    return InkWell(
      onTap: onPressed,
      child: Row(
        children: [
          Text(
            isExpanded
                ? t.translate('general_show_less')
                : t.translate('general_show_more'),
            style: const TextStyle(
              color: SisapaTheme.blue,
              fontWeight: FontWeight.bold,
            ),
          ),
          Icon(
            isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
            color: SisapaTheme.blue,
            size: 16,
          ),
        ],
      ),
    );
  }
}

class _CenteredShowMoreButton extends StatelessWidget {
  final bool isExpanded;
  final VoidCallback onPressed;

  const _CenteredShowMoreButton({
    required this.isExpanded,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(
        isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
      ),
      label: Text(
        isExpanded
            ? t.translate('general_show_less')
            : t.translate('general_show_more'),
      ),
    );
  }
}
