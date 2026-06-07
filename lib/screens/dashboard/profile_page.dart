import 'dart:async';
import 'dart:io';
import '../../services/app_cache_manager.dart';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/api_service.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';

import '../../theme/app_theme.dart';
import '../edit_profile_screen.dart';
import '../image_viewer_screen.dart';
import 'settings_page.dart';
import '../../services/overlay_service.dart';
import '../../services/gcs_service.dart';
import '../../services/moderation_service.dart';
import '../ktm_verification_screen.dart';
import '../../services/app_localizations.dart'; // IMPORT LOCALIZATION
import 'profile/department_badge.dart';
import 'profile/profile_avatar_image.dart';
import 'profile/profile_content_tabs.dart';
import 'profile/profile_empty_states.dart';
import 'profile/profile_stat_link.dart';
import 'profile/profile_tab_header_delegate.dart';

final GcsService _cloudinaryService = GcsService();
final ApiService _apiService = ApiService();

class ProfilePage extends StatefulWidget {
  final String? userId;
  final bool includeScaffold;

  const ProfilePage({super.key, this.userId, this.includeScaffold = false});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late TabController _tabController;
  final ScrollController _scrollController = ScrollController();

  late final User? _user;
  late final String _userId;

  bool _isScrolled = false;
  bool _isBioExpanded = false;

  bool _isBlocked = false;
  String? _optimisticPinnedPostId;

  // Optimistic UI and Debounce State
  Timer? _followDebounceTimer;
  bool? _baselineIsFollowing;
  bool? _baselineHasRequested;
  int? _baselineFollowerCount;

  // Loaded data
  Map<String, dynamic> _userData = {};
  bool _isLoading = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _user = FirebaseAuth.instance.currentUser;
    _userId = widget.userId ?? _user!.uid;

    _user?.reload();

    _checkBlockedStatus();
    _loadUserData();

    _tabController = TabController(length: 3, vsync: this, initialIndex: 0);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _tabController.index = 0;
    });

    _scrollController.addListener(_scrollListener);
  }

  @override
  void reassemble() {
    super.reassemble();
    if (_tabController.index != 0) {
      _tabController.index = 0;
    }
  }

  void _checkBlockedStatus() async {
    if (_user == null) return;
    moderationService.streamBlockedUsers().listen((blockedList) {
      if (mounted) {
        setState(() {
          _isBlocked = blockedList.contains(_userId);
        });
      }
    });
  }

  void _scrollListener() {
    if (_scrollController.hasClients) {
      final bool scrolled = _scrollController.offset > (120.0 - kToolbarHeight);
      if (scrolled != _isScrolled) {
        setState(() {
          _isScrolled = scrolled;
        });
      }
    }
  }

  void _handlePinToggle(String postId, bool isPinned) {
    setState(() {
      _optimisticPinnedPostId = isPinned ? postId : '';
    });

    // LOCALIZATION
    var t = AppLocalizations.of(context)!;

    if (isPinned) {
      OverlayService().showTopNotification(
        context,
        t.translate('profile_pin_success'),
        Icons.push_pin,
        () {},
      );
    } else {
      OverlayService().showTopNotification(
        context,
        t.translate('profile_unpin_success'),
        Icons.push_pin_outlined,
        () {},
      );
    }
  }

  void _openFullImage(BuildContext context, String url, String heroTag) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black,
        pageBuilder: (_, _, _) => ImageViewerScreen(
          imageUrl: url,
          heroTag: heroTag,
          mediaType: 'image',
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  OverlayEntry _showUploadingOverlay() {
    // LOCALIZATION
    var t = AppLocalizations.of(context)!;

    OverlayEntry entry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 10,
        left: 16,
        right: 16,
        child: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(12),
          color: Theme.of(context).cardColor,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: SisapaTheme.blue,
                      ),
                    ),
                    SizedBox(width: 12),
                    Text(
                      t.translate('profile_uploading'),
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                SizedBox(height: 10),
                LinearProgressIndicator(
                  backgroundColor: SisapaTheme.blue.withValues(alpha: 0.1),
                  valueColor: AlwaysStoppedAnimation(SisapaTheme.blue),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(entry);
    return entry;
  }

  Future<void> _loadUserData({bool forceRefresh = false}) async {
    try {
      final data = await _apiService.getUser(
        _userId,
        forceRefresh: forceRefresh,
      );
      if (mounted && data != null) {
        setState(() {
          _userData = data;
          _isLoading = false;
        });
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showImageSourceSelection({required bool isBanner}) {
    // LOCALIZATION
    var t = AppLocalizations.of(context)!;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return FrostedBottomSheet(
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                SizedBox(height: 16),
                ListTile(
                  leading: Icon(Icons.camera_alt, color: SisapaTheme.blue),
                  title: Text(t.translate('profile_camera')),
                  onTap: () {
                    Navigator.pop(context);
                    _pickAndUploadImage(
                      isBanner: isBanner,
                      source: ImageSource.camera,
                    );
                  },
                ),
                ListTile(
                  leading: Icon(Icons.photo_library, color: SisapaTheme.blue),
                  title: Text(t.translate('profile_gallery')),
                  onTap: () {
                    Navigator.pop(context);
                    _pickAndUploadImage(
                      isBanner: isBanner,
                      source: ImageSource.gallery,
                    );
                  },
                ),
                SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickAndUploadImage({
    required bool isBanner,
    required ImageSource source,
  }) async {
    // LOCALIZATION
    var t = AppLocalizations.of(context)!;

    final picker = ImagePicker();
    final XFile? pickedFile = await picker.pickImage(
      maxWidth: 1920,
      maxHeight: 1920,
      source: source,
      imageQuality: 70,
    );
    if (pickedFile == null) return;

    final croppedFile = await ImageCropper().cropImage(
      sourcePath: pickedFile.path,
      compressQuality: 70,
      aspectRatio: isBanner
          ? CropAspectRatio(ratioX: 3, ratioY: 1)
          : CropAspectRatio(ratioX: 1, ratioY: 1),
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: isBanner
              ? t.translate('profile_crop_banner')
              : t.translate('profile_crop_avatar'),
          toolbarColor: SisapaTheme.blue,
          toolbarWidgetColor: Colors.white,
          initAspectRatio: isBanner
              ? CropAspectRatioPreset.ratio3x2
              : CropAspectRatioPreset.square,
          lockAspectRatio: true,
        ),
        IOSUiSettings(
          title: isBanner
              ? t.translate('profile_crop_banner')
              : t.translate('profile_crop_avatar'),
          aspectRatioLockEnabled: true,
        ),
      ],
    );
    if (croppedFile == null) return;

    final OverlayEntry loadingOverlay = _showUploadingOverlay();
    try {
      final String? downloadUrl = await _cloudinaryService.uploadImage(
        File(croppedFile.path),
      );
      loadingOverlay.remove();
      if (downloadUrl != null) {
        final Map<String, dynamic> updateData = {};
        if (isBanner) {
          updateData['banner_image_url'] = downloadUrl;
        } else {
          updateData['profile_image_url'] = downloadUrl;
          updateData['avatar_icon_id'] = -1;
        }

        await _apiService.updateUser(_userId, updateData);
        await _loadUserData(); // refresh
        if (mounted) {
          OverlayService().showTopNotification(
            context,
            t.translate('profile_update_success'),
            Icons.check_circle,
            () {},
            color: Colors.green,
          );
        }
      }
    } catch (e) {
      try {
        loadingOverlay.remove();
      } catch (_) {}
      if (mounted) {
        OverlayService().showTopNotification(
          context,
          t.translate('profile_upload_fail'),
          Icons.error,
          () {},
          color: Colors.red,
        );
      }
    }
  }

  void _showBannerOptions(
    BuildContext context,
    String? currentBannerUrl,
    String heroTag,
  ) {
    var t = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return FrostedBottomSheet(
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                SizedBox(height: 16),
                if (currentBannerUrl != null && currentBannerUrl.isNotEmpty)
                  ListTile(
                    leading: Icon(
                      Icons.visibility_outlined,
                      color: SisapaTheme.blue,
                    ),
                    title: Text(t.translate('profile_view_banner')),
                    onTap: () {
                      Navigator.pop(context);
                      _openFullImage(context, currentBannerUrl, heroTag);
                    },
                  ),
                ListTile(
                  leading: Icon(
                    Icons.photo_library_outlined,
                    color: SisapaTheme.blue,
                  ),
                  title: Text(t.translate('profile_change_banner')),
                  onTap: () {
                    Navigator.pop(context);
                    _showImageSourceSelection(isBanner: true);
                  },
                ),
                SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showProfileOptions(
    BuildContext context,
    String? currentImageUrl,
    String heroTag,
  ) {
    var t = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return FrostedBottomSheet(
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                SizedBox(height: 16),
                if (currentImageUrl != null && currentImageUrl.isNotEmpty)
                  ListTile(
                    leading: Icon(
                      Icons.visibility_outlined,
                      color: SisapaTheme.blue,
                    ),
                    title: Text(t.translate('profile_view_photo')),
                    onTap: () {
                      Navigator.pop(context);
                      _openFullImage(context, currentImageUrl, heroTag);
                    },
                  ),
                ListTile(
                  leading: Icon(
                    Icons.photo_library_outlined,
                    color: SisapaTheme.blue,
                  ),
                  title: Text(t.translate('profile_change_photo')),
                  onTap: () {
                    Navigator.pop(context);
                    _showImageSourceSelection(isBanner: false);
                  },
                ),
                SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  void _toggleFollowOptimistic(bool isPrivate) {
    if (_user == null) return;
    var t = AppLocalizations.of(context)!;

    final myUid = _user.uid;
    List<dynamic> currentFollowers = List<dynamic>.from(
      _userData['followers'] ?? [],
    );

    if (_followDebounceTimer == null || !_followDebounceTimer!.isActive) {
      _baselineIsFollowing = currentFollowers.contains(myUid);
      _baselineHasRequested = _userData['has_follow_request'] == true;
      _baselineFollowerCount =
          _userData['follower_count'] ??
          _userData['followerCount'] ??
          currentFollowers.length;
    }

    final currentOptimisticFollowing = currentFollowers.contains(myUid);
    final currentOptimisticRequested = _userData['has_follow_request'] == true;
    int currentFollowerCount =
        _userData['follower_count'] ??
        _userData['followerCount'] ??
        currentFollowers.length;

    setState(() {
      if (currentOptimisticFollowing) {
        currentFollowers.remove(myUid);
        _userData['followers'] = currentFollowers;
        _userData['follower_count'] = (currentFollowerCount > 0)
            ? currentFollowerCount - 1
            : 0;
        _userData['followerCount'] = _userData['follower_count'];
      } else if (currentOptimisticRequested) {
        _userData['has_follow_request'] = false;
      } else {
        if (isPrivate) {
          _userData['has_follow_request'] = true;
        } else {
          currentFollowers.add(myUid);
          _userData['followers'] = currentFollowers;
          _userData['follower_count'] = currentFollowerCount + 1;
          _userData['followerCount'] = _userData['follower_count'];
        }
      }
    });

    _followDebounceTimer?.cancel();
    _followDebounceTimer = Timer(const Duration(milliseconds: 1500), () async {
      final finalFollowers = List<dynamic>.from(_userData['followers'] ?? []);
      final finalOptimisticFollowing = finalFollowers.contains(myUid);
      final finalOptimisticRequested = _userData['has_follow_request'] == true;

      try {
        if (finalOptimisticFollowing && _baselineIsFollowing == false) {
          await _apiService.followUser(_userId);
        } else if (!finalOptimisticFollowing && _baselineIsFollowing == true) {
          await _apiService.unfollowUser(_userId);
        } else if (finalOptimisticRequested && _baselineHasRequested == false) {
          await _apiService.sendFollowRequest(_userId);
        } else if (!finalOptimisticRequested && _baselineHasRequested == true) {
          await _apiService.cancelFollowRequest(_userId);
        }
        await _loadUserData(forceRefresh: true);
      } catch (e) {
        if (mounted) {
          setState(() {
            if (_baselineIsFollowing == true &&
                !currentFollowers.contains(myUid)) {
              currentFollowers.add(myUid);
            } else if (_baselineIsFollowing == false &&
                currentFollowers.contains(myUid)) {
              currentFollowers.remove(myUid);
            }
            _userData['followers'] = currentFollowers;
            _userData['has_follow_request'] = _baselineHasRequested;
            _userData['follower_count'] = _baselineFollowerCount;
            _userData['followerCount'] = _baselineFollowerCount;
          });
          OverlayService().showTopNotification(
            context,
            "${t.translate('profile_action_fail')}: Gagal mengubah status, periksa jaringan Anda.",
            Icons.wifi_off,
            () {},
            color: Colors.red,
          );
        }
      }
    });
  }

  void _shareProfile(String name) {
    var t = AppLocalizations.of(context)!;
    // Simple localization, assuming name doesn't need translation
    SharePlus.instance.share(
      ShareParams(text: t.translate('profile_share_text')),
    );
  }

  Future<void> _toggleBlock() async {
    var t = AppLocalizations.of(context)!;
    if (_isBlocked) {
      await moderationService.unblockUser(_userId);
      if (mounted) {
        OverlayService().showTopNotification(
          context,
          t.translate('profile_unblocked'),
          Icons.check_circle,
          () {},
        );
      }
    } else {
      final confirm =
          await showDialog<bool>(
            context: context,
            builder: (ctx) => FrostedAlertDialog(
              title: Text(t.translate('profile_block_confirm_title')),
              content: Text(t.translate('profile_block_confirm_desc')),
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
                ), // Using general_delete as "Block" action often red
              ],
            ),
          ) ??
          false;
      if (confirm) {
        await moderationService.blockUser(_userId);
        if (mounted) {
          OverlayService().showTopNotification(
            context,
            t.translate('profile_blocked'),
            Icons.block,
            () {},
          );
        }
      }
    }
  }

  void _reportUser() {
    var t = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) {
        return FrostedSimpleDialog(
          title: Text(t.translate('profile_report_title')),
          children: [
            SimpleDialogOption(
              onPressed: () => _submitReport('Spam'),
              child: Text(t.translate('profile_report_spam')),
            ),
            SimpleDialogOption(
              onPressed: () => _submitReport('Impersonation'),
              child: Text(t.translate('profile_report_imperson')),
            ),
            SimpleDialogOption(
              onPressed: () => _submitReport('Inappropriate Profile'),
              child: Text(t.translate('profile_report_inappr')),
            ),
            Padding(
              padding: EdgeInsets.all(8),
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(t.translate('general_cancel')),
              ),
            ),
          ],
        );
      },
    );
  }

  void _submitReport(String reason) {
    Navigator.pop(context);
    moderationService.reportContent(
      targetId: _userId,
      targetType: 'user',
      reason: reason,
    );
    // LOCALIZATION
    var t = AppLocalizations.of(context)!;
    OverlayService().showTopNotification(
      context,
      t.translate('profile_report_submitted'),
      Icons.flag,
      () {},
    );
  }

  Future<void> _signOut(BuildContext context) async {
    var t = AppLocalizations.of(context)!;
    final didConfirm =
        await showDialog<bool>(
          context: context,
          builder: (context) => FrostedAlertDialog(
            title: Text(t.translate('settings_logout')),
            content: Text(t.translate('settings_logout_confirm')),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(t.translate('general_cancel')),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(
                  t.translate('settings_logout'),
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        ) ??
        false;
    if (didConfirm) {
      await FirebaseAuth.instance.signOut();
      if (context.mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String _formatJoinedDate(dynamic rawDate) {
    var t = AppLocalizations.of(context)!;
    if (rawDate == null) return t.translate('profile_joined_unknown');

    DateTime? dateTime;
    if (rawDate is String) {
      dateTime = DateTime.tryParse(rawDate);
    }

    if (dateTime == null) return t.translate('profile_joined_unknown');
    return '${t.translate('profile_joined')} ${DateFormat('MMMM yyyy').format(dateTime)}';
  }

  Future<void> _handleRefresh() async {
    try {
      await _user?.reload();
    } catch (_) {}
    await _loadUserData(forceRefresh: true);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    var t = AppLocalizations.of(context)!;

    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    final double topPadding = MediaQuery.of(context).padding.top;
    final double pinnedHeaderHeight = topPadding + kToolbarHeight;

    if (_isLoading) {
      return widget.includeScaffold
          ? Scaffold(body: Center(child: CircularProgressIndicator()))
          : Center(child: CircularProgressIndicator());
    }

    final data = _userData;
    final name = data['name'] ?? 'User';

    final bool isMyProfile = _user?.uid == _userId;
    final bool isPrivateAccount =
        data['is_private'] == true ||
        data['is_private'] == 1 ||
        data['isPrivate'] == true ||
        data['isPrivate'] == 1;
    final List<dynamic> followers = data['followers'] ?? [];
    final bool amIFollowing = followers.contains(_user?.uid);

    final bool canViewProfile =
        isMyProfile || !isPrivateAccount || amIFollowing;

    final String verificationStatus =
        data['verification_status'] ?? data['verificationStatus'] ?? 'none';
    final bool isVerified = verificationStatus == 'verified';

    Widget content = RefreshIndicator(
      onRefresh: _handleRefresh,
      color: SisapaTheme.blue,
      edgeOffset: pinnedHeaderHeight,
      notificationPredicate: (notification) => true,
      child: NestedScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              pinned: true,
              elevation: 0,
              scrolledUnderElevation: 0,
              expandedHeight: 218.0,
              backgroundColor: Colors.transparent,
              iconTheme: IconThemeData(
                color: isDarkMode ? SisapaTheme.white : SisapaTheme.blue,
              ),
              automaticallyImplyLeading: widget.includeScaffold,

              title: AnimatedOpacity(
                opacity: _isScrolled ? 1.0 : 0.0,
                duration: Duration(milliseconds: 200),
                child: Row(
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        color: isDarkMode
                            ? SisapaTheme.white
                            : SisapaTheme.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (isVerified) ...[
                      SizedBox(width: 4),
                      Icon(Icons.verified, size: 16, color: SisapaTheme.blue),
                    ] else if (isPrivateAccount) ...[
                      SizedBox(width: 4),
                      Icon(
                        Icons.lock,
                        size: 16,
                        color: isDarkMode
                            ? SisapaTheme.white
                            : SisapaTheme.black,
                      ),
                    ],
                  ],
                ),
              ),
              centerTitle: false,
              actions: [_buildActionMenu(context, data, isMyProfile)],
              flexibleSpace: FlexibleSpaceBar(
                background: _buildHeaderFlexibleSpace(
                  context,
                  data,
                  isMyProfile,
                  isPrivateAccount,
                  amIFollowing,
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: _buildProfileInfoBody(context, data, isMyProfile),
            ),

            if (!_isBlocked && canViewProfile)
              SliverPersistentHeader(
                pinned: true,
                delegate: ProfileTabHeaderDelegate(
                  TabBar(
                    controller: _tabController,
                    tabs: [
                      Tab(text: t.translate('profile_posts')),
                      Tab(text: t.translate('profile_reposts')),
                      Tab(text: t.translate('profile_replies')),
                    ],
                    labelColor: theme.primaryColor,
                    unselectedLabelColor: theme.hintColor,
                    indicatorColor: theme.primaryColor,
                    overlayColor: WidgetStateProperty.all(Colors.transparent),
                    dividerColor: Colors.transparent,
                  ),
                  isDarkMode ? Color(0xFF15202B) : SisapaTheme.white,
                ),
              ),
          ];
        },

        body: _isBlocked
            ? BlockedProfileBody(onUnblock: _toggleBlock)
            : (!canViewProfile)
            ? const PrivateAccountBody()
            : TabBarView(
                controller: _tabController,
                children: [
                  ProfilePostsTab(
                    userId: _userId,
                    userData: _userData,
                    optimisticPinnedPostId: _optimisticPinnedPostId,
                    onPinToggle: _handlePinToggle,
                  ),
                  ProfileRepostsTab(userId: _userId),
                  ProfileRepliesTab(userId: _userId),
                ],
              ),
      ),
    );

    return widget.includeScaffold
        ? Scaffold(extendBodyBehindAppBar: true, body: content)
        : content;
  }

  // --- Header Components ---

  Widget _buildActionMenu(
    BuildContext context,
    Map<String, dynamic> data,
    bool isMyProfile,
  ) {
    var t = AppLocalizations.of(context)!;
    final name = data['name'] ?? '';
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert),
      onSelected: (value) {
        if (value == 'share') _shareProfile(name);
        if (value == 'settings') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => SettingsPage()),
          );
        }
        if (value == 'logout') _signOut(context);
        if (value == 'block') _toggleBlock();
        if (value == 'report') _reportUser();
      },
      itemBuilder: (context) => isMyProfile
          ? [
              PopupMenuItem(
                value: 'share',
                child: Text(t.translate('profile_menu_share')),
              ),
              PopupMenuItem(
                value: 'settings',
                child: Text(t.translate('profile_menu_settings')),
              ),
              PopupMenuItem(
                value: 'logout',
                child: Text(
                  t.translate('settings_logout'),
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ]
          : [
              PopupMenuItem(
                value: 'share',
                child: Text(t.translate('profile_menu_share_account')),
              ),
              PopupMenuItem(
                value: 'report',
                child: Text(t.translate('profile_report_title')),
              ),
              PopupMenuItem(
                value: 'block',
                child: Text(
                  _isBlocked
                      ? t.translate('profile_unblocked')
                      : t.translate('general_delete'),
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
    );
  }

  Widget _buildHeaderFlexibleSpace(
    BuildContext context,
    Map<String, dynamic> data,
    bool isMyProfile,
    bool isPrivate,
    bool amIFollowing,
  ) {
    final theme = Theme.of(context);
    var t = AppLocalizations.of(context)!;

    final String? bannerImageUrl =
        data['banner_image_url'] ?? data['bannerImageUrl'];
    final String? profileImageUrl =
        data['profile_image_url'] ?? data['profileImageUrl'];
    final String? dept = data['department'];
    final String? prodi = data['study_program'] ?? data['studyProgram'];
    final String? deptCode = data['department_code'] ?? data['departmentCode'];

    return Stack(
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 150,
          child: GestureDetector(
            onTap: () {
              if (isMyProfile) {
                _showBannerOptions(context, bannerImageUrl, 'banner');
              } else if (bannerImageUrl != null && !_isBlocked) {
                _openFullImage(context, bannerImageUrl, 'banner');
              }
            },
            child: Hero(
              tag: 'banner',
              child: Container(
                color: SisapaTheme.darkGrey,
                child: bannerImageUrl != null
                    ? CachedNetworkImage(
                        cacheManager: AppCacheManager.instance,
                        imageUrl: bannerImageUrl,
                        fit: BoxFit.cover,
                        memCacheWidth: 800,
                        errorWidget: (context, url, error) =>
                            Container(color: SisapaTheme.darkGrey),
                      )
                    : (isMyProfile
                          ? Center(
                              child: Icon(
                                Icons.camera_alt,
                                color: Colors.white,
                              ),
                            )
                          : null),
              ),
            ),
          ),
        ),

        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: MediaQuery.of(context).padding.top + kToolbarHeight,
          child: FrostedLayer(
            tint: theme.scaffoldBackgroundColor.withValues(
              alpha: theme.brightness == Brightness.dark ? 0.78 : 0.74,
            ),
          ),
        ),

        Positioned(
          top: 120,
          left: 16,
          child: GestureDetector(
            onTap: () {
              if (isMyProfile) {
                _showProfileOptions(context, profileImageUrl, 'avatar');
              } else if (profileImageUrl != null && !_isBlocked) {
                _openFullImage(context, profileImageUrl, 'avatar');
              }
            },
            child: Hero(
              tag: 'avatar',
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 49,
                    backgroundColor: theme.scaffoldBackgroundColor,
                    child: ProfileAvatarImage(data: data),
                  ),
                ],
              ),
            ),
          ),
        ),

        Positioned(
          top: 156,
          right: 16,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (deptCode != null) ...[
                DepartmentBadge(
                  code: deptCode,
                  fullDeptName: dept,
                  fullProdiName: prodi,
                ),
                SizedBox(width: 8),
              ],
              isMyProfile
                  ? OutlinedButton(
                      onPressed: () async {
                        if (await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => EditProfileScreen(),
                              ),
                            ) ==
                            true) {
                          setState(() {});
                        }
                      },
                      style: OutlinedButton.styleFrom(shape: StadiumBorder()),
                      child: Text(t.translate('profile_edit')),
                    )
                  : _isBlocked
                  ? ElevatedButton(
                      onPressed: _toggleBlock,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                      child: Text(t.translate('profile_unblocked')),
                    )
                  : _buildFollowButton(isPrivate, amIFollowing),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFollowButton(bool isPrivate, bool amIFollowing) {
    var t = AppLocalizations.of(context)!;
    if (amIFollowing) {
      return OutlinedButton(
        onPressed: () => _toggleFollowOptimistic(isPrivate),
        child: Text(t.translate('profile_unfollow')),
      );
    }

    if (!isPrivate) {
      return ElevatedButton(
        onPressed: () => _toggleFollowOptimistic(false),
        style: ElevatedButton.styleFrom(
          backgroundColor: SisapaTheme.blue,
          foregroundColor: Colors.white,
        ),
        child: Text(t.translate('community_follow')),
      );
    }

    // For private accounts, check follow request status from API data
    final bool hasRequested = _userData['has_follow_request'] == true;
    if (hasRequested) {
      return OutlinedButton(
        onPressed: () => _toggleFollowOptimistic(true),
        style: OutlinedButton.styleFrom(
          backgroundColor: Theme.of(context).cardColor,
          side: BorderSide(color: Theme.of(context).dividerColor),
        ),
        child: Text(
          t.translate('profile_requested'),
          style: TextStyle(color: Theme.of(context).hintColor),
        ),
      );
    }

    return ElevatedButton(
      onPressed: () => _toggleFollowOptimistic(true),
      style: ElevatedButton.styleFrom(
        backgroundColor: SisapaTheme.blue,
        foregroundColor: Colors.white,
      ),
      child: Text(t.translate('community_follow')),
    );
  }

  Widget _buildProfileInfoBody(
    BuildContext context,
    Map<String, dynamic> data,
    bool isMyProfile,
  ) {
    final theme = Theme.of(context);
    var t = AppLocalizations.of(context)!;

    final String name = data['name'] ?? 'Name';
    final String handle = "@${(data['email'] ?? '').split('@')[0]}";
    final String displayBio = _isBioExpanded
        ? (data['bio'] ?? '')
        : ((data['bio'] ?? '').length > 100
              ? (data['bio'] ?? '').substring(0, 100) + '...'
              : (data['bio'] ?? ''));

    final String verificationStatus =
        data['verification_status'] ?? data['verificationStatus'] ?? 'none';
    final bool isVerified = verificationStatus == 'verified';
    final bool isPending = verificationStatus == 'pending';

    bool showEmailVerifyBtn = false;
    bool showKtmVerifyBtn = false;

    if (isMyProfile) {
      if (_user != null && !_user.emailVerified) {
        showEmailVerifyBtn = true;
      } else if (!isVerified && !isPending) {
        showKtmVerifyBtn = true;
      }
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  name,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isVerified) ...[
                SizedBox(width: 4),
                Icon(Icons.verified, size: 22, color: SisapaTheme.blue),
              ] else if (data['is_private'] == true ||
                  data['is_private'] == 1 ||
                  data['isPrivate'] == true ||
                  data['isPrivate'] == 1) ...[
                SizedBox(width: 6),
                Icon(
                  Icons.lock,
                  size: 22,
                  color: theme.textTheme.titleLarge?.color,
                ),
              ],
            ],
          ),
          Text(handle, style: theme.textTheme.titleSmall),

          // --- VERIFICATION BUTTONS ---
          if (showEmailVerifyBtn)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: InkWell(
                onTap: () async {
                  try {
                    await _user!.sendEmailVerification();
                    if (!context.mounted) return;
                    OverlayService().showTopNotification(
                      context,
                      t.translate('profile_verify_sent'),
                      Icons.mark_email_read,
                      () {},
                    );
                  } catch (e) {
                    if (!context.mounted) return;
                    OverlayService().showTopNotification(
                      context,
                      t.translate('profile_verify_wait'),
                      Icons.timer,
                      () {},
                      color: Colors.orange,
                    );
                  }
                },
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.red),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.warning, size: 16, color: Colors.red),
                      SizedBox(width: 6),
                      Text(
                        t.translate('profile_verify_email'),
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else if (isPending)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.orange),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.hourglass_top, size: 16, color: Colors.orange),
                    SizedBox(width: 6),
                    Text(
                      t.translate('profile_verify_pending'),
                      style: TextStyle(
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else if (showKtmVerifyBtn)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: InkWell(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => KtmVerificationScreen()),
                ),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: SisapaTheme.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: SisapaTheme.blue),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.verified_outlined,
                        size: 16,
                        color: SisapaTheme.blue,
                      ),
                      SizedBox(width: 6),
                      Text(
                        t.translate('profile_verify_get'),
                        style: TextStyle(
                          color: SisapaTheme.blue,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          SizedBox(height: 8),
          if (!_isBlocked) ...[
            Text(
              displayBio.isEmpty ? t.translate('profile_no_bio') : displayBio,
              style: theme.textTheme.bodyLarge,
            ),
            if ((data['bio'] ?? '').length > 100)
              GestureDetector(
                onTap: () => setState(() => _isBioExpanded = !_isBioExpanded),
                child: Text(
                  _isBioExpanded
                      ? t.translate('general_show_less')
                      : t.translate('general_show_more'),
                  style: TextStyle(
                    color: SisapaTheme.blue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 14, color: theme.hintColor),
                SizedBox(width: 4),
                Text(
                  _formatJoinedDate(data['created_at'] ?? data['createdAt']),
                  style: theme.textTheme.titleSmall,
                ),
              ],
            ),
            SizedBox(height: 8),
            Row(
              children: [
                ProfileStatLink(
                  userId: _userId,
                  count: (data['following'] ?? []).length,
                  label: t.translate('profile_following'),
                  tabIndex: 1,
                ),
                SizedBox(width: 16),
                ProfileStatLink(
                  userId: _userId,
                  count: (data['followers'] ?? []).length,
                  label: t.translate('profile_followers'),
                  tabIndex: 2,
                ),
              ],
            ),
            SizedBox(height: 16),
          ],
        ],
      ),
    );
  }
}
