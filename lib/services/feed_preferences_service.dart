import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum CommunityFeedScope { off, followed, all }

class FeedPreferences {
  final CommunityFeedScope recentCommunityScope;
  final CommunityFeedScope recommendedCommunityScope;
  final bool showRepostsInRecent;
  final bool showRepostsInRecommended;
  final bool recentFollowingOnly;
  final bool prioritizeFollowedCommunities;

  const FeedPreferences({
    this.recentCommunityScope = CommunityFeedScope.followed,
    this.recommendedCommunityScope = CommunityFeedScope.followed,
    this.showRepostsInRecent = true,
    this.showRepostsInRecommended = true,
    this.recentFollowingOnly = false,
    this.prioritizeFollowedCommunities = true,
  });

  static const defaults = FeedPreferences();

  FeedPreferences copyWith({
    CommunityFeedScope? recentCommunityScope,
    CommunityFeedScope? recommendedCommunityScope,
    bool? showRepostsInRecent,
    bool? showRepostsInRecommended,
    bool? recentFollowingOnly,
    bool? prioritizeFollowedCommunities,
  }) {
    return FeedPreferences(
      recentCommunityScope: recentCommunityScope ?? this.recentCommunityScope,
      recommendedCommunityScope:
          recommendedCommunityScope ?? this.recommendedCommunityScope,
      showRepostsInRecent: showRepostsInRecent ?? this.showRepostsInRecent,
      showRepostsInRecommended:
          showRepostsInRecommended ?? this.showRepostsInRecommended,
      recentFollowingOnly: recentFollowingOnly ?? this.recentFollowingOnly,
      prioritizeFollowedCommunities:
          prioritizeFollowedCommunities ?? this.prioritizeFollowedCommunities,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is FeedPreferences &&
        other.recentCommunityScope == recentCommunityScope &&
        other.recommendedCommunityScope == recommendedCommunityScope &&
        other.showRepostsInRecent == showRepostsInRecent &&
        other.showRepostsInRecommended == showRepostsInRecommended &&
        other.recentFollowingOnly == recentFollowingOnly &&
        other.prioritizeFollowedCommunities == prioritizeFollowedCommunities;
  }

  @override
  int get hashCode => Object.hash(
    recentCommunityScope,
    recommendedCommunityScope,
    showRepostsInRecent,
    showRepostsInRecommended,
    recentFollowingOnly,
    prioritizeFollowedCommunities,
  );
}

class FeedPreferencesService {
  FeedPreferencesService._();

  static final FeedPreferencesService instance = FeedPreferencesService._();

  static const _recentCommunityScopeKey = 'feed_recent_community_scope';
  static const _recommendedCommunityScopeKey =
      'feed_recommended_community_scope';
  static const _showRepostsInRecentKey = 'feed_show_reposts_recent';
  static const _showRepostsInRecommendedKey = 'feed_show_reposts_recommended';
  static const _recentFollowingOnlyKey = 'feed_recent_following_only';
  static const _prioritizeFollowedCommunitiesKey =
      'feed_prioritize_followed_communities';

  final ValueNotifier<FeedPreferences> preferences = ValueNotifier(
    FeedPreferences.defaults,
  );

  bool _loaded = false;

  Future<FeedPreferences> load() async {
    if (_loaded) return preferences.value;

    final prefs = await SharedPreferences.getInstance();
    final loaded = FeedPreferences(
      recentCommunityScope: _scopeFromString(
        prefs.getString(_recentCommunityScopeKey),
        FeedPreferences.defaults.recentCommunityScope,
      ),
      recommendedCommunityScope: _scopeFromString(
        prefs.getString(_recommendedCommunityScopeKey),
        FeedPreferences.defaults.recommendedCommunityScope,
      ),
      showRepostsInRecent:
          prefs.getBool(_showRepostsInRecentKey) ??
          FeedPreferences.defaults.showRepostsInRecent,
      showRepostsInRecommended:
          prefs.getBool(_showRepostsInRecommendedKey) ??
          FeedPreferences.defaults.showRepostsInRecommended,
      recentFollowingOnly:
          prefs.getBool(_recentFollowingOnlyKey) ??
          FeedPreferences.defaults.recentFollowingOnly,
      prioritizeFollowedCommunities:
          prefs.getBool(_prioritizeFollowedCommunitiesKey) ??
          FeedPreferences.defaults.prioritizeFollowedCommunities,
    );

    preferences.value = loaded;
    _loaded = true;
    return loaded;
  }

  Future<void> save(FeedPreferences value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _recentCommunityScopeKey,
      value.recentCommunityScope.name,
    );
    await prefs.setString(
      _recommendedCommunityScopeKey,
      value.recommendedCommunityScope.name,
    );
    await prefs.setBool(_showRepostsInRecentKey, value.showRepostsInRecent);
    await prefs.setBool(
      _showRepostsInRecommendedKey,
      value.showRepostsInRecommended,
    );
    await prefs.setBool(_recentFollowingOnlyKey, value.recentFollowingOnly);
    await prefs.setBool(
      _prioritizeFollowedCommunitiesKey,
      value.prioritizeFollowedCommunities,
    );
    preferences.value = value;
    _loaded = true;
  }

  Future<void> reset() => save(FeedPreferences.defaults);

  CommunityFeedScope _scopeFromString(
    String? raw,
    CommunityFeedScope fallback,
  ) {
    for (final scope in CommunityFeedScope.values) {
      if (scope.name == raw) return scope;
    }
    return fallback;
  }
}
