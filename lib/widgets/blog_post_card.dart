import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter/services.dart';

import '../screens/post/post_detail_screen.dart';
import '../screens/dashboard/profile_page.dart';
import '../screens/community/community_detail_screen.dart';
import '../services/overlay_service.dart';
import '../services/app_localizations.dart';
import '../services/gcs_service.dart';
import '../main.dart';
import '../theme/app_theme.dart';

import 'blog_post_card/post_data_helpers.dart';
import 'blog_post_card/post_header.dart';
import 'blog_post_card/post_action_bar.dart';
import 'blog_post_card/post_media_section.dart';
import 'blog_post_card/post_moderation_actions.dart';
import 'blog_post_card/post_repost_header.dart';
import 'blog_post_card/post_upload_failed_notice.dart';
import 'blog_post_card/post_upload_status.dart';

class BlogPostCard extends StatefulWidget {
  final String postId;
  final Map<String, dynamic> postData;
  final bool isOwner;
  final bool isClickable;
  final bool isDetailView;
  final String heroContextId;
  final VideoPlayerController? preloadedController;
  final bool isPinned;
  final Function(String, bool)? onPinToggle;
  final String? currentProfileUserId;

  final bool isCommunityAdmin;
  final List<String> blockedUserIds;

  const BlogPostCard({
    super.key,
    required this.postId,
    required this.postData,
    required this.isOwner,
    this.isClickable = true,
    this.isDetailView = false,
    this.heroContextId = 'feed',
    this.preloadedController,
    this.isPinned = false,
    this.onPinToggle,
    this.currentProfileUserId,
    this.isCommunityAdmin = false,
    this.blockedUserIds = const [],
  });

  @override
  State<BlogPostCard> createState() => _BlogPostCardState();
}

class _BlogPostCardState extends State<BlogPostCard>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  final TextEditingController _editController = TextEditingController();
  late AnimationController _likeController;
  late Animation<double> _likeAnimation;
  late AnimationController _shareController;
  late Animation<double> _shareAnimation;
  late AnimationController _repostController;
  late Animation<double> _repostAnimation;

  bool _isLiked = false;
  bool _isReposted = false;
  bool _isSharing = false;
  bool _isBookmarked = false;
  int _likeCount = 0;
  int _repostCount = 0;

  late bool _localIsPinned;

  VideoPlayerController? _videoController;
  bool _isVideoOwner = false;
  bool _isVideoInitialized = false;
  bool _isVideoLoading = false;

  // [REPOST FEATURE] State Variables
  bool _isRepostWrapper = false;
  Map<String, dynamic>? _resolvedPostData;
  bool _isLoadingOriginal = false;
  String _originalError = '';

  @override
  void initState() {
    super.initState();
    _localIsPinned = widget.isPinned;

    // Setup Controllers
    _likeController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _likeAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _likeController, curve: Curves.easeInOut),
    );

    _shareController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _shareAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _shareController, curve: Curves.easeInOut),
    );

    _repostController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _repostAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _repostController, curve: Curves.easeInOut),
    );

    // Panggil setup logic utama
    _initializePostData();
  }

  // Logic inisialisasi dipisah agar bisa dipanggil ulang saat recycle widget
  void _initializePostData() {
    // Reset video state
    if (_isVideoOwner) {
      _videoController?.dispose();
      _videoController = null;
    }
    _isVideoInitialized = false;
    _isVideoOwner = false;
    _isVideoLoading = false;

    // Cek apakah ini Repost Wrapper
    final origId = postOriginalId(widget.postData);
    final isRepostType = isRepostPost(widget.postData);

    if (isRepostType && origId != null) {
      _isRepostWrapper = true;
      _resolvedPostData = null; // Reset resolved data
      _originalError = '';
      _fetchOriginalPost(origId);
    } else {
      _isRepostWrapper = false;
      _resolvedPostData = widget.postData;
      _isLoadingOriginal = false;
      _syncState();

      // Init preloaded video hanya jika BUKAN repost (video handle terpisah di repost)
      if (widget.preloadedController != null) {
        _videoController = widget.preloadedController;
        _isVideoInitialized = true;
        _isVideoOwner = false;
      }
    }
  }

  // Handle Widget Recycling (IMPORTANT for ListView)
  @override
  void didUpdateWidget(covariant BlogPostCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Jika ID berubah, berarti kartu ini sekarang menampilkan postingan berbeda
    if (oldWidget.postId != widget.postId) {
      _initializePostData();
    } else {
      // Jika ID sama tapi data berubah (misal like count update dari parent), sync saja
      if (!_isRepostWrapper && widget.postData != oldWidget.postData) {
        _resolvedPostData = widget.postData;
        _syncState();
      }
    }

    if (oldWidget.isPinned != widget.isPinned) {
      setState(() {
        _localIsPinned = widget.isPinned;
      });
    }
  }

  String get effectivePostId => _isRepostWrapper
      ? (postOriginalId(widget.postData) ?? widget.postId).toString()
      : widget.postId;
  Map<String, dynamic> get effectivePostData => _resolvedPostData ?? {};

  bool get effectiveIsOwner {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return false;
    return postAuthorId(effectivePostData) == currentUser.uid;
  }

  Future<void> _fetchOriginalPost(String originalId) async {
    if (mounted) setState(() => _isLoadingOriginal = true);
    try {
      final data = await ApiService().getPost(originalId);
      if (data != null) {
        if (mounted) {
          setState(() {
            _resolvedPostData = data;
            _isLoadingOriginal = false;
            _syncState();
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _originalError = 'Post no longer exists';
            _isLoadingOriginal = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _originalError = 'Failed to load post';
          _isLoadingOriginal = false;
        });
      }
    }
  }

  Future<void> _initializeVideo() async {
    if (_isVideoInitialized || _videoController != null || _isVideoLoading) {
      return;
    }

    final data = effectivePostData;
    final videoUrl = primaryPostMediaUrl(data);

    if (videoUrl != null) {
      setState(() => _isVideoLoading = true);

      try {
        final controller = VideoPlayerController.networkUrl(
          Uri.parse(videoUrl),
        );
        await controller.initialize();
        controller.setLooping(true);

        if (mounted) {
          setState(() {
            _videoController = controller;
            _isVideoInitialized = true;
            _isVideoOwner = true;
            _isVideoLoading = false;
          });
          _videoController!.play();
        } else {
          controller.dispose();
        }
      } catch (e) {
        if (mounted) setState(() => _isVideoLoading = false);
        debugPrint("Error initializing video: $e");
      }
    }
  }

  void _syncState() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (_resolvedPostData == null) return;

    // API returns is_liked, like_count, is_bookmarked directly
    final bool apiLiked = _resolvedPostData!['is_liked'] == true;
    final int apiLikeCount = _resolvedPostData!['like_count'] ?? 0;
    final bool apiBookmarked = _resolvedPostData!['is_bookmarked'] == true;
    // Fallback for Firestore-style data during transition
    final likesRaw = _resolvedPostData!['likes'];
    final List<dynamic> likesList = (likesRaw is Map)
        ? likesRaw.keys.toList()
        : (likesRaw as List<dynamic>? ?? []);
    final reposts = _resolvedPostData!['repostedBy'] as List? ?? [];

    if (mounted) {
      setState(() {
        _isLiked =
            apiLiked ||
            (currentUser != null && likesList.contains(currentUser.uid));
        _likeCount = apiLikeCount > 0 ? apiLikeCount : likesList.length;

        // Base isReposted on the resolved original post or local cache
        if (ApiService.repostsLoaded && currentUser != null) {
          _isReposted = ApiService.myRepostedPostIds.contains(
            effectivePostId.toString(),
          );
        } else {
          _isReposted =
              _resolvedPostData!['is_reposted'] == true ||
              _resolvedPostData!['is_reposted'] == 1 ||
              (currentUser != null && reposts.contains(currentUser.uid));
        }

        // If it's a repost wrapper created by the current user, it must be their repost!
        if (_isRepostWrapper) {
          final wrapperUserId = postAuthorId(widget.postData);
          if (currentUser != null && wrapperUserId == currentUser.uid) {
            _isReposted = true;
          }
        }

        _repostCount = _resolvedPostData!['repost_count'] ?? reposts.length;
        if (_isReposted && _repostCount == 0) {
          _repostCount = 1;
        }
        _isBookmarked = apiBookmarked;
      });
    }
  }

  @override
  void dispose() {
    _likeController.dispose();
    _shareController.dispose();
    _repostController.dispose();
    _editController.dispose();

    if (_isVideoOwner) {
      _videoController?.dispose();
    }
    super.dispose();
  }

  void _toggleLike() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    _likeController.forward().then((_) => _likeController.reverse());
    if (hapticNotifier.value) HapticFeedback.lightImpact();

    setState(() {
      _isLiked = !_isLiked;
      if (_isLiked) {
        _likeCount++;
      } else {
        _likeCount--;
      }
    });

    try {
      await ApiService().toggleLike(effectivePostId);
    } catch (e) {
      _syncState();
    }
  }

  bool _isDeleted = false; // Add to state variables if not exist

  void _toggleRepost() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    _repostController.forward().then((_) => _repostController.reverse());
    if (hapticNotifier.value) HapticFeedback.lightImpact();

    final targetId = effectivePostId;
    final wrapperUserId = postAuthorId(widget.postData);
    final isMyOwnWrapper = _isRepostWrapper && currentUser.uid == wrapperUserId;

    setState(() {
      _isReposted = !_isReposted;
      if (_isReposted) {
        ApiService.myRepostedPostIds.add(targetId.toString());
        _repostCount++;
      } else {
        ApiService.myRepostedPostIds.remove(targetId.toString());
        _repostCount = (_repostCount > 0) ? _repostCount - 1 : 0;
        if (isMyOwnWrapper) {
          _isDeleted = true; // Instantly hide from Reposts tab
        }
      }
    });

    try {
      final api = ApiService();
      if (_isReposted) {
        await api.createPost(
          isRepost: true,
          originalPostId: targetId.toString(),
          visibility: effectivePostData['visibility'] ?? 'public',
        );
      } else {
        // Find and delete the repost — the server handles repost_count decrement
        final reposts = await api.getReposts(currentUser.uid);
        for (final r in reposts) {
          final origId = r['original_post_id'] ?? r['originalPostId'];
          if (origId != null && origId.toString() == targetId.toString()) {
            await api.deletePost(r['id'].toString());
          }
        }
      }
      if (mounted) {
        _resolvedPostData!['is_reposted'] = _isReposted;
        _resolvedPostData!['repost_count'] = _repostCount;
      }
    } catch (e) {
      debugPrint("Repost Error: $e");
      if (_isReposted) {
        ApiService.myRepostedPostIds.remove(targetId.toString());
      } else {
        ApiService.myRepostedPostIds.add(targetId.toString());
      }
      _syncState();
      if (mounted) {
        setState(() {
          _isDeleted = false; // Revert hide if api fails
        });
        OverlayService().showTopNotification(
          context,
          "Failed to update repost",
          Icons.error,
          () {},
          color: Colors.red,
        );
      }
    }
  }

  void _handleBookmarkToggle(bool isCurrentlyBookmarked) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    if (hapticNotifier.value) HapticFeedback.lightImpact();
    var t = AppLocalizations.of(context)!;

    setState(() {
      _isBookmarked = !isCurrentlyBookmarked;
    });

    if (!isCurrentlyBookmarked) {
      OverlayService().showTopNotification(
        context,
        t.translate('post_bookmark_saved'),
        Icons.bookmark,
        () {},
      );
    } else {
      OverlayService().showTopNotification(
        context,
        t.translate('post_bookmark_removed'),
        Icons.bookmark_remove,
        () {},
      );
    }

    try {
      await ApiService().toggleBookmark(effectivePostId);
    } catch (e) {
      setState(() {
        _isBookmarked = isCurrentlyBookmarked;
      });
      OverlayService().showTopNotification(
        context,
        t.translate('post_bookmark_error'),
        Icons.error,
        () {},
        color: Colors.red,
      );
    }
  }

  void _toggleVisibility() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    var t = AppLocalizations.of(context)!;

    final currentVis = effectivePostData['visibility'] ?? 'public';
    String newVis;

    if (currentVis == 'private') {
      final userData = await ApiService().getUser(user.uid);
      final bool isPrivateAccount =
          userData?['is_private'] == true ||
          userData?['is_private'] == 1 ||
          userData?['isPrivate'] == true ||
          userData?['isPrivate'] == 1;
      newVis = isPrivateAccount ? 'followers' : 'public';
    } else {
      newVis = 'private';
    }

    String msg;
    IconData icon;
    Color? color;

    if (newVis == 'private') {
      msg = t.translate('vis_toast_private');
      icon = Icons.visibility_off;
    } else if (newVis == 'followers') {
      msg = t.translate('vis_toast_followers');
      icon = Icons.people;
      color = Colors.orange;
    } else {
      msg = t.translate('vis_toast_public');
      icon = Icons.public;
    }

    if (mounted) {
      OverlayService().showTopNotification(
        context,
        msg,
        icon,
        () {},
        color: color,
      );
    }

    try {
      await ApiService().updatePost(effectivePostId, {'visibility': newVis});
    } catch (e) {
      if (mounted) {
        OverlayService().showTopNotification(
          context,
          t.translate('vis_toast_fail'),
          Icons.error,
          () {},
          color: Colors.red,
        );
      }
    }
  }

  void _sharePost() {
    _shareController.forward().then((_) => _shareController.reverse());
    setState(() {
      _isSharing = true;
    });
    final text = effectivePostData['text'] ?? '';
    final name = effectivePostData['userName'] ?? 'User';

    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _isSharing = false;
        });
      }
      Share.share('Check out this post by $name: "$text"');
    });
  }

  Future<void> _deletePost() async {
    var t = AppLocalizations.of(context)!;
    final confirm =
        await showDialog<bool>(
          context: context,
          builder: (ctx) => FrostedAlertDialog(
            title: Text(t.translate('delete_post_title')),
            content: Text(t.translate('delete_post_confirm')),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(t.translate('general_cancel')),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(
                  t.translate('general_delete'),
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        ) ??
        false;
    if (confirm) {
      try {
        final mediaUrls = postMediaUrls(effectivePostData);

        for (String url in mediaUrls) {
          try {
            final match = RegExp(r'sapapnj-media-assets/(.*)').firstMatch(url);
            if (match != null) {
              final objectName = match.group(1)!;
              await GcsService().deleteResource(objectName);
            }
          } catch (e) {
            debugPrint("Failed to parse or delete media URL: $url - $e");
          }
        }

        await ApiService().deletePost(widget.postId);
        if (mounted) {
          OverlayService().showTopNotification(
            context,
            t.translate('post_deleted'),
            Icons.delete_outline,
            () {},
          );
        }
      } catch (e) {
        if (mounted) {
          OverlayService().showTopNotification(
            context,
            t.translate('post_delete_fail'),
            Icons.error,
            () {},
            color: Colors.red,
          );
        }
      }
    }
  }

  Future<void> _togglePin() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    var t = AppLocalizations.of(context)!;
    final bool newPinState = !_localIsPinned;
    setState(() {
      _localIsPinned = newPinState;
    });
    if (widget.onPinToggle != null) {
      widget.onPinToggle!(effectivePostId, newPinState);
    }
    try {
      if (!newPinState) {
        await ApiService().updateUser(user.uid, {'pinned_post_id': null});
        if (mounted) {
          OverlayService().showTopNotification(
            context,
            t.translate('profile_unpin_success'),
            Icons.push_pin_outlined,
            () {},
          );
        }
      } else {
        await ApiService().updateUser(user.uid, {
          'pinned_post_id': effectivePostId,
        });
        if (mounted) {
          OverlayService().showTopNotification(
            context,
            t.translate('profile_pin_success'),
            Icons.push_pin,
            () {},
          );
        }
      }
    } catch (e) {
      setState(() {
        _localIsPinned = !newPinState;
      });
      if (widget.onPinToggle != null) {
        widget.onPinToggle!(effectivePostId, !newPinState);
      }
      if (mounted) {
        OverlayService().showTopNotification(
          context,
          t.translate('pin_fail'),
          Icons.error,
          () {},
          color: Colors.red,
        );
      }
    }
  }

  Route _createSlideLeftRoute(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(1.0, 0.0);
        const end = Offset.zero;
        const curve = Curves.easeInOutQuart;
        var tween = Tween(
          begin: begin,
          end: end,
        ).chain(CurveTween(curve: curve));
        return SlideTransition(position: animation.drive(tween), child: child);
      },
    );
  }

  void _navigateToDetail() {
    if (!widget.isClickable) return;
    Navigator.of(context).push(
      _createSlideLeftRoute(
        PostDetailScreen(
          postId: effectivePostId,
          initialPostData: effectivePostData,
          heroContextId: widget.heroContextId,
          preloadedController: _videoController,
        ),
      ),
    );
  }

  void _navigateToSource() {
    final communityId = postCommunityId(effectivePostData);

    if (communityId != null) {
      Navigator.of(context).push(
        _createSlideLeftRoute(
          CommunityDetailScreen(
            communityId: communityId,
            communityData: const {},
          ),
        ),
      );
      return;
    }

    final postUserId = postAuthorId(effectivePostData);
    if (postUserId == null) return;

    if (effectiveIsOwner) {
      final scaffold = Scaffold.maybeOf(context);
      if (scaffold != null && scaffold.hasDrawer) {
        if (hapticNotifier.value) HapticFeedback.lightImpact();
        scaffold.openDrawer();
        return;
      }
    }
    if (widget.currentProfileUserId != null &&
        postUserId == widget.currentProfileUserId) {
      return;
    }

    Navigator.of(context).push(
      _createSlideLeftRoute(
        ProfilePage(userId: postUserId, includeScaffold: true),
      ),
    );
  }

  Future<void> _showEditDialog() async {
    var t = AppLocalizations.of(context)!;
    _editController.text = effectivePostData['text'] ?? '';
    await showDialog(
      context: context,
      builder: (context) {
        return FrostedAlertDialog(
          title: Text(t.translate('edit_post_title')),
          content: TextField(
            controller: _editController,
            maxLines: 5,
            decoration: InputDecoration(
              hintText: t.translate('edit_post_hint'),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(t.translate('general_cancel')),
            ),
            ElevatedButton(
              onPressed: _submitEdit,
              child: Text(t.translate('general_save')),
            ),
          ],
        );
      },
    );
  }

  Future<void> _submitEdit() async {
    var t = AppLocalizations.of(context)!;
    try {
      await ApiService().updatePost(effectivePostId, {
        'text': _editController.text,
      });
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        OverlayService().showTopNotification(
          context,
          t.translate('edit_post_fail'),
          Icons.error,
          () {},
          color: Colors.red,
        );
        Navigator.of(context).pop();
      }
    }
  }

  void _onMenuAction(String value) {
    if (value == 'edit') {
      _showEditDialog();
    } else if (value == 'delete') {
      _deletePost();
    } else if (value == 'pin') {
      _togglePin();
    } else if (value == 'report') {
      PostModerationActions.reportPost(
        context: context,
        postId: effectivePostId,
      );
    } else if (value == 'block') {
      PostModerationActions.blockUser(
        context: context,
        authorId: postAuthorId(effectivePostData),
      );
    } else if (value == 'toggle_visibility') {
      _toggleVisibility();
    } else if (value == 'report_community') {
      PostModerationActions.reportCommunity(
        context: context,
        communityId: postCommunityId(effectivePostData),
      );
    }
  }

  Widget _buildRepostHeader() {
    if (!_isRepostWrapper) return const SizedBox.shrink();

    return PostRepostHeader(
      postData: widget.postData,
      onOpenReposter: (reposterId) {
        Navigator.of(context).push(
          _createSlideLeftRoute(
            ProfilePage(userId: reposterId, includeScaffold: true),
          ),
        );
      },
    );
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_isDeleted) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);

    if (_isRepostWrapper) {
      if (_isLoadingOriginal) {
        return Container(
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: theme.dividerColor, width: 0.5),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildRepostHeader(),
              const SizedBox(height: 12),
              const Center(
                child: CircularProgressIndicator.adaptive(strokeWidth: 2),
              ),
            ],
          ),
        );
      }

      // [FIXED LOGIC]: Jika data asli hilang atau error, kembalikan SizedBox.shrink()
      // Ini akan membuat postingan "menghilang" dari feed alih-alih menampilkan error ghost post.
      if (_resolvedPostData == null || _originalError.isNotEmpty) {
        return const SizedBox.shrink();
      }
    }

    if (widget.blockedUserIds.contains(postAuthorId(effectivePostData))) {
      return const SizedBox.shrink();
    }
    if (_isRepostWrapper &&
        widget.blockedUserIds.contains(postAuthorId(widget.postData))) {
      return const SizedBox.shrink();
    }

    final text = effectivePostData['text'] ?? '';
    final mediaType =
        effectivePostData['mediaType'] ?? effectivePostData['media_type'];
    final isUploading = effectivePostData['isUploading'] == true;
    final uploadFailed = effectivePostData['uploadFailed'] == true;
    final int commentCount = effectivePostData['commentCount'] ?? 0;
    final mediaUrls = postMediaUrls(effectivePostData);

    if (uploadFailed) {
      return PostUploadFailedNotice(text: text);
    }

    return GestureDetector(
      onTap: (widget.isClickable && !widget.isDetailView)
          ? _navigateToDetail
          : null,
      child: FrostedSurface(
        border: Border(
          bottom: BorderSide(color: theme.dividerColor, width: 0.5),
        ),
        tint: theme.cardColor.withValues(
          alpha: theme.brightness == Brightness.dark ? 0.78 : 0.74,
        ),
        blur: FrostedGlassTokens.blurSigma,
        child: Stack(
          children: [
            if (widget.isDetailView && commentCount > 0)
              Positioned(
                left: 32,
                top: 36,
                bottom: 0,
                child: Container(width: 2, color: theme.dividerColor),
              ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildRepostHeader(),

                  PostHeader(
                    postData: effectivePostData,
                    isOwner: effectiveIsOwner,
                    isCommunityAdmin: widget.isCommunityAdmin,
                    isPinned: _localIsPinned,
                    onNavigateToSource: _navigateToSource,
                    onMenuAction: _onMenuAction,
                  ),

                  Padding(
                    padding: const EdgeInsets.only(left: 60.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (text.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text(
                              text,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontSize: widget.isDetailView ? 18 : 15,
                              ),
                              maxLines: widget.isDetailView ? null : 10,
                              overflow: widget.isDetailView
                                  ? null
                                  : TextOverflow.ellipsis,
                            ),
                          ),
                        if (isUploading)
                          const PostUploadStatus()
                        else if (mediaUrls.isNotEmpty ||
                            (text.contains('http') && !widget.isDetailView))
                          Padding(
                            padding: const EdgeInsets.only(top: 12.0),
                            child: PostMediaSection(
                              mediaUrls: mediaUrls,
                              mediaType: mediaType,
                              text: text,
                              postData: effectivePostData,
                              postId: effectivePostId,
                              heroContextId: widget.heroContextId,
                              videoController: _videoController,
                              isDetailView: widget.isDetailView,
                              isVideoInitialized: _isVideoInitialized,
                              isVideoLoading: _isVideoLoading,
                              onInitializeVideo: _initializeVideo,
                            ),
                          ),

                        if (!isUploading)
                          PostActionBar(
                            postId: effectivePostId,
                            commentCount: commentCount,
                            repostCount: _repostCount,
                            likeCount: _likeCount,
                            isReposted: _isReposted,
                            isLiked: _isLiked,
                            isBookmarked: _isBookmarked,
                            isSharing: _isSharing,
                            isDetailView: widget.isDetailView,
                            onCommentTap: _navigateToDetail,
                            onRepostTap: _toggleRepost,
                            onLikeTap: _toggleLike,
                            onShareTap: _sharePost,
                            onBookmarkTap: _handleBookmarkToggle,
                            likeAnimation: _likeAnimation,
                            repostAnimation: _repostAnimation,
                            shareAnimation: _shareAnimation,
                          ),
                      ],
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
