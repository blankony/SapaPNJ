import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../services/api_service.dart';
import '../../../services/app_localizations.dart';
import '../../../widgets/blog_post_card.dart';
import '../../../widgets/post/comment_tile.dart';
import '../../../widgets/common/common_error_widget.dart';

final ApiService _apiService = ApiService();

class ProfilePostsTab extends StatelessWidget {
  final String userId;
  final Map<String, dynamic> userData;
  final String? optimisticPinnedPostId;
  final void Function(String postId, bool isPinned) onPinToggle;

  const ProfilePostsTab({
    super.key,
    required this.userId,
    required this.userData,
    required this.optimisticPinnedPostId,
    required this.onPinToggle,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final firestorePinned =
        userData['pinned_post_id'] ?? userData['pinnedPostId'];
    final activePinnedId = optimisticPinnedPostId == ''
        ? null
        : (optimisticPinnedPostId ?? firestorePinned);

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _apiService.getPosts(userUid: userId, limit: 50),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return CommonErrorWidget(
            message: t.translate('profile_load_posts_fail'),
            isConnectionError: true,
          );
        }

        final slivers = <Widget>[];
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          slivers.add(
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        } else {
          final allPosts = snapshot.data ?? [];
          final visiblePosts = allPosts.where(_canShowPost).toList();

          if (visiblePosts.isEmpty) {
            slivers.add(
              SliverFillRemaining(
                child: Center(child: Text(t.translate('profile_no_posts'))),
              ),
            );
          } else {
            _movePinnedPostToTop(visiblePosts, activePinnedId);
            slivers.add(
              SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final postData = visiblePosts[index];
                  final postId = postData['id'] ?? '';

                  return BlogPostCard(
                    key: ValueKey(postId),
                    postId: postId,
                    postData: postData,
                    isOwner: _isCurrentUserPost(postData),
                    heroContextId: 'profile_posts',
                    isPinned: postId == activePinnedId,
                    onPinToggle: onPinToggle,
                    currentProfileUserId: userId,
                  );
                }, childCount: visiblePosts.length),
              ),
            );
            slivers.add(const SliverToBoxAdapter(child: SizedBox(height: 80)));
          }
        }

        return _ProfileTabScrollView(slivers: slivers);
      },
    );
  }

  bool _canShowPost(Map<String, dynamic> data) {
    final isRepost =
        data['is_repost'] == true ||
        data['is_repost'] == 1 ||
        data['original_post_id'] != null ||
        data['originalPostId'] != null;
    if (isRepost) return false;

    final isCommunityIdentityPost =
        data['is_community_identity'] == true ||
        data['is_community_identity'] == 1 ||
        data['isCommunityPost'] == true;
    if (isCommunityIdentityPost) return false;

    final visibility = data['visibility'] ?? 'public';
    final ownerId = data['user_uid'] ?? data['userId'];
    if (visibility == 'public') return true;
    if (visibility == 'followers') return true;
    if (visibility == 'private' &&
        ownerId == FirebaseAuth.instance.currentUser?.uid) {
      return true;
    }
    return false;
  }

  void _movePinnedPostToTop(
    List<Map<String, dynamic>> posts,
    String? activePinnedId,
  ) {
    if (activePinnedId == null) return;

    final index = posts.indexWhere((data) => data['id'] == activePinnedId);
    if (index == -1) return;

    final pinned = posts.removeAt(index);
    posts.insert(0, pinned);
  }
}

class ProfileRepliesTab extends StatelessWidget {
  final String userId;

  const ProfileRepliesTab({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _apiService.getUserComments(userId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return CommonErrorWidget(
            message: t.translate('profile_load_replies_fail'),
            isConnectionError: true,
          );
        }

        final slivers = <Widget>[];
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          slivers.add(
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        } else {
          final docs = snapshot.data ?? [];
          if (docs.isEmpty) {
            slivers.add(
              SliverFillRemaining(
                child: Center(child: Text(t.translate('profile_no_replies'))),
              ),
            );
          } else {
            slivers.add(
              SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final data = docs[index];
                  final parentPostId =
                      data['post_id'] ?? data['originalPostId'] ?? '';

                  return Theme(
                    data: Theme.of(context).copyWith(
                      listTileTheme: const ListTileThemeData(
                        minVerticalPadding: 0,
                        visualDensity: VisualDensity.compact,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 0,
                        ),
                      ),
                    ),
                    child: CommentTile(
                      key: ValueKey(data['id'] ?? index),
                      commentId: data['id'] ?? '',
                      commentData: data,
                      postId: parentPostId,
                      isOwner: true,
                      showPostContext: true,
                      heroContextId: 'profile_replies',
                      currentProfileUserId: userId,
                    ),
                  );
                }, childCount: docs.length),
              ),
            );
            slivers.add(const SliverToBoxAdapter(child: SizedBox(height: 80)));
          }
        }

        return _ProfileTabScrollView(slivers: slivers);
      },
    );
  }
}

class ProfileRepostsTab extends StatelessWidget {
  final String userId;

  const ProfileRepostsTab({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _apiService.getReposts(userId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return CommonErrorWidget(
            message: t.translate('profile_load_reposts_fail'),
            isConnectionError: true,
          );
        }

        final slivers = <Widget>[];
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          slivers.add(
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        } else {
          final allPosts = snapshot.data ?? [];
          if (allPosts.isEmpty) {
            slivers.add(
              SliverFillRemaining(
                child: Center(child: Text(t.translate('profile_no_reposts'))),
              ),
            );
          } else {
            slivers.add(
              SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final postData = Map<String, dynamic>.from(allPosts[index]);
                  final postId = postData['id'] ?? '';

                  if (userId == FirebaseAuth.instance.currentUser?.uid) {
                    postData['is_reposted'] = true;
                  }

                  return BlogPostCard(
                    key: ValueKey('repost_$postId'),
                    postId: postId,
                    postData: postData,
                    isOwner: _isCurrentUserPost(postData),
                    heroContextId: 'profile_reposts',
                    currentProfileUserId: userId,
                  );
                }, childCount: allPosts.length),
              ),
            );
            slivers.add(const SliverToBoxAdapter(child: SizedBox(height: 80)));
          }
        }

        return _ProfileTabScrollView(slivers: slivers);
      },
    );
  }
}

class _ProfileTabScrollView extends StatelessWidget {
  final List<Widget> slivers;

  const _ProfileTabScrollView({required this.slivers});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      slivers: slivers,
    );
  }
}

bool _isCurrentUserPost(Map<String, dynamic> postData) {
  return (postData['user_uid'] ?? postData['userId']) ==
      FirebaseAuth.instance.currentUser?.uid;
}
