import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/api_service.dart';
import '../../services/app_cache_manager.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../widgets/side_panel.dart';
import '../../widgets/ai_history_drawer.dart';
import 'home_page.dart';
import 'ai_assistant_page.dart';
import 'search_page.dart';
import 'profile_tab_page.dart';
import '../create_post_screen.dart';
import '../community/community_list_tab.dart';
import '../../main.dart';
import '../../theme/app_theme.dart';
import '../../widgets/notification_sheet.dart';
import '../../services/overlay_service.dart';
import '../../services/notification_prefs_service.dart';
import '../../services/ai_event_bus.dart';

import '../../services/draft_service.dart';
import '../post_detail_screen.dart';
import 'home_dashboard/app_bar_avatar.dart';
import 'home_dashboard/custom_animated_bottom_bar.dart';
import 'home_dashboard/dashboard_slide_route.dart';
import 'home_dashboard/draft_menu_content.dart';
import 'home_dashboard/keep_alive_page.dart';
import 'home_dashboard/notification_button.dart';

class HomeDashboard extends StatefulWidget {
  const HomeDashboard({super.key});

  @override
  State<HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<HomeDashboard>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  // Navigation State
  int _currentTabIndex = 0;
  bool _isSearchActive = false;

  // Controllers
  late final PageController _pageController;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final ScrollController _homeScrollController = ScrollController();
  final ScrollController _recommendedScrollController = ScrollController();

  // Animations
  late AnimationController _entranceController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Persistence
  late Widget _persistentHomeTab;
  bool _hasRestoredState = false;

  // Timer & Last Notification for API Polling
  Timer? _notificationTimer;
  Map<String, dynamic>? _lastNotification;

  bool _isScrolled = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _initializeAnimations();
    _setupNotificationListener();

    // Defer state restoration until after build
    WidgetsBinding.instance.addPostFrameCallback((_) => _restoreState());
  }

  void _initializeControllers() {
    _pageController = PageController(initialPage: _currentTabIndex);

    _persistentHomeTab = KeepAlivePage(
      child: HomePage(
        scrollController: _homeScrollController,
        recommendedScrollController: _recommendedScrollController,
        onScrollChange: (scrolled) {
          if (mounted && _currentTabIndex == 0 && _isScrolled != scrolled) {
            setState(() => _isScrolled = scrolled);
          }
        },
      ),
    );

    // Save scroll positions
    _homeScrollController.addListener(() {
      if (mounted) {
        PageStorage.of(context).writeState(
          context,
          _homeScrollController.offset,
          identifier: 'scroll_pos_0',
        );
      }
    });
    _recommendedScrollController.addListener(() {
      if (mounted) {
        PageStorage.of(context).writeState(
          context,
          _recommendedScrollController.offset,
          identifier: 'scroll_pos_1',
        );
      }
    });
  }

  void _initializeAnimations() {
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _entranceController, curve: Curves.easeOut),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0.0, 0.1), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _entranceController,
            curve: Curves.easeOutQuart,
          ),
        );
  }

  void _restoreState() {
    if (_hasRestoredState) return;

    bool restoredAnyState = false;

    // Restore Tab Index
    final int? savedIndex =
        PageStorage.of(context).readState(context, identifier: 'home_tab_index')
            as int?;
    if (savedIndex != null) {
      _currentTabIndex = savedIndex;
      if (_pageController.hasClients) {
        _pageController.jumpToPage(_currentTabIndex);
      }
      restoredAnyState = true;
    }

    // Restore Scroll Positions
    final double? savedScroll0 =
        PageStorage.of(context).readState(context, identifier: 'scroll_pos_0')
            as double?;
    final double? savedScroll1 =
        PageStorage.of(context).readState(context, identifier: 'scroll_pos_1')
            as double?;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (savedScroll0 != null && _homeScrollController.hasClients) {
        _homeScrollController.jumpTo(savedScroll0);
      }
      if (savedScroll1 != null && _recommendedScrollController.hasClients) {
        _recommendedScrollController.jumpTo(savedScroll1);
      }
    });

    if (savedScroll0 != null || savedScroll1 != null) restoredAnyState = true;

    // Handle Entrance Animation
    if (restoredAnyState) {
      _entranceController.value = 1.0;
    } else {
      _entranceController.forward();
    }

    _hasRestoredState = true;
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _notificationTimer?.cancel();
    _entranceController.dispose();
    _homeScrollController.dispose();
    _recommendedScrollController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  // --- Logic & Listeners ---

  void _setupNotificationListener() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _pollNotifications();
    _notificationTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _pollNotifications();
    });
  }

  Future<void> _pollNotifications() async {
    try {
      final notifs = await ApiService().getNotifications();
      if (notifs.isNotEmpty) {
        final newest = notifs.first;
        final isUnread = newest['is_read'] == false || newest['is_read'] == 0;
        if (isUnread) {
          if (_lastNotification == null ||
              _lastNotification!['id'] != newest['id']) {
            _lastNotification = newest;
            _handleNotification(newest);
          }
        }
      }
    } catch (e) {
      debugPrint("Error polling notifications: $e");
    }
  }

  void _handleNotification(Map<String, dynamic> data) {
    if (!notificationPrefs.allNotificationsEnabled.value ||
        !notificationPrefs.headsUpEnabled.value) {
      return;
    }
    _showNotificationOverlay(data);
  }

  void _showNotificationOverlay(Map<String, dynamic> data) {
    final String type = data['type'] ?? 'info';
    String message = 'New Notification';
    IconData icon = Icons.notifications;
    String? postId = data['post_id'];

    switch (type) {
      case 'like':
        message = "Someone liked your post.";
        icon = Icons.favorite;
        break;
      case 'comment':
        message = "Someone commented on your post.";
        icon = Icons.comment;
        break;
      case 'follow':
        message = "You have a new follower!";
        icon = Icons.person_add;
        break;
      case 'upload_complete':
        message = "Media uploaded successfully.";
        icon = Icons.check_circle;
        break;
    }

    OverlayService().showTopNotification(context, message, icon, () {
      ApiService().markNotificationRead(data['id']);
      if (postId != null) {
        Navigator.push(
          context,
          DashboardSlideRoute(page: PostDetailScreen(postId: postId)),
        );
      } else if (type == 'follow') {
        _onTabSelected(4); // Go to profile
      }
    });
  }

  // --- UI Actions ---

  void _scrollToTop() {
    if (_homeScrollController.hasClients) {
      _homeScrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutQuart,
      );
    }
  }

  void _onLogoTapped() {
    if (_currentTabIndex == 0) {
      _scrollToTop();
    }
  }

  void _onTabSelected(int index) {
    // Toggle Search State
    if (index == 3 && _currentTabIndex == 3) {
      setState(() => _isSearchActive = !_isSearchActive);
    } else {
      setState(() => _isSearchActive = false);
    }

    // Page Navigation
    if ((_currentTabIndex - index).abs() > 1) {
      _pageController.jumpToPage(index);
    } else {
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }

    setState(() {
      _currentTabIndex = index;
      if (index != 0) _isScrolled = false;
      PageStorage.of(
        context,
      ).writeState(context, _currentTabIndex, identifier: 'home_tab_index');
    });
  }

  void _handleFabTap() {
    if (_currentTabIndex == 1) {
      _showCommunityPostSelector(context);
    } else {
      _showPostCreationMenu(context);
    }
  }

  // --- Dialogs & Sheets ---

  void _showNotificationPopup() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      useSafeArea: true,
      isDismissible: true,
      enableDrag: true,
      builder: (context) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => Navigator.of(context).pop(),
          child: DraggableScrollableSheet(
            initialChildSize: 0.75,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            builder: (context, scrollController) {
              return GestureDetector(
                onTap: () {},
                child: NotificationSheet(scrollController: scrollController),
              );
            },
          ),
        );
      },
    );
  }

  // --- MODIFIED: CHECK DRAFTS BEFORE SHOWING DIALOG ---
  void _showPostCreationMenu(BuildContext context) async {
    final DraftService draftService = DraftService();
    // 1. Ambil drafts terlebih dahulu
    final List<DraftPost> drafts = await draftService.getDrafts();

    if (!mounted) return;

    // 2. Cek apakah drafts kosong
    if (drafts.isEmpty) {
      // Jika kosong, langsung buka Create Post Screen tanpa dialog
      _navigateToCreatePost();
      return;
    }

    // 3. Jika ada drafts, tampilkan dialog pilihan
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.3),
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.all(20),
          child: DraftMenuContent(
            initialDrafts: drafts,
            onNewPost: () {
              Navigator.pop(ctx);
              _navigateToCreatePost();
            },
            onOpenDraft: (draft) {
              Navigator.pop(ctx);
              _navigateToCreatePost(draftData: draft);
            },
          ),
        );
      },
    );
  }

  void _showCommunityPostSelector(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return FrostedBottomSheet(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Text(
                    "Post to Community",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: FutureBuilder<List<Map<String, dynamic>>>(
                    future: ApiService().getMyCommunities(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting)
                        return Center(child: CircularProgressIndicator());

                      final list = snapshot.data ?? [];
                      if (list.isEmpty) {
                        return Center(
                          child: Text(
                            "You haven't joined any communities yet.",
                          ),
                        );
                      }

                      return ListView.builder(
                        itemCount: list.length,
                        itemBuilder: (context, index) {
                          final data = list[index];
                          final String id = data['id'];
                          final String name = data['name'] ?? 'Community';
                          final String? icon = data['image_url'];

                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: SisapaTheme.blue.withOpacity(
                                0.1,
                              ),
                              backgroundImage: icon != null
                                  ? CachedNetworkImageProvider(
                                      icon,
                                      cacheManager: AppCacheManager.instance,
                                    )
                                  : null,
                              child: icon == null
                                  ? Icon(Icons.groups, color: SisapaTheme.blue)
                                  : null,
                            ),
                            title: Text(name),
                            trailing: Icon(Icons.arrow_forward_ios, size: 14),
                            onTap: () {
                              Navigator.pop(ctx);
                              _navigateToCreatePost(
                                initialData: {
                                  'communityId': id,
                                  'communityName': name,
                                  'communityIcon': icon,
                                },
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _navigateToCreatePost({
    Map<String, dynamic>? initialData,
    DraftPost? draftData,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) =>
            CreatePostScreen(initialData: initialData, draftData: draftData),
      ),
    );
  }

  // --- Build Components ---

  List<Widget> _buildAppBarActions() {
    switch (_currentTabIndex) {
      case 0: // Home
        return [DashboardNotificationButton(onPressed: _showNotificationPopup)];
      case 2: // AI
        return [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Chat History',
            onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
          ),
        ];
      case 3: // Search
        return [
          IconButton(
            icon: _isSearchActive ? Icon(Icons.close) : Icon(Icons.search),
            onPressed: () => setState(() => _isSearchActive = !_isSearchActive),
          ),
        ];
      default:
        return [];
    }
  }

  PreferredSizeWidget? _buildAppBar(bool isDarkMode) {
    if (_currentTabIndex == 4) return null; // No AppBar on Profile

    final transparentHomeChrome = _currentTabIndex == 0 && !_isScrolled;

    return FrostedAppBar(
      blur: transparentHomeChrome ? 0.001 : FrostedGlassTokens.blurSigma,
      tint: transparentHomeChrome ? Colors.transparent : null,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDarkMode
            ? Brightness.light
            : Brightness.dark,
        statusBarBrightness: isDarkMode ? Brightness.dark : Brightness.light,
      ),
      leading: GestureDetector(
        onTap: () {
          if (hapticNotifier.value) HapticFeedback.lightImpact();
          _scaffoldKey.currentState!.openDrawer();
        },
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: AppBarAvatar(),
        ),
      ),
      title: GestureDetector(
        onTap: _onLogoTapped,
        child: Image.asset('images/app_icon.png', height: 30),
      ),
      centerTitle: true,
      actions: _buildAppBarActions(),
    );
  }

  Widget? _buildFab() {
    // Show FAB on Home (0), Community (1), and Profile (4)
    bool showFab =
        _currentTabIndex == 0 || _currentTabIndex == 1 || _currentTabIndex == 4;

    if (!showFab) return null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: FrostedSurface(
        shape: BoxShape.circle,
        tone: FrostedSurfaceTone.brand,
        blur: FrostedGlassTokens.blurSigma,
        boxShadow: FrostedGlassTokens.materialDepth(context),
        child: FloatingActionButton(
          onPressed: _handleFabTap,
          backgroundColor: Colors.transparent,
          elevation: 0,
          highlightElevation: 0,
          child: const Icon(Icons.edit_outlined, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildBody() {
    // Pages
    final pages = <Widget>[
      _persistentHomeTab,
      KeepAlivePage(child: CommunityListTab()),
      KeepAlivePage(child: AiAssistantPage()),
      KeepAlivePage(
        child: SearchPage(
          isSearching: _isSearchActive,
          onSearchPressed: () =>
              setState(() => _isSearchActive = !_isSearchActive),
        ),
      ),
      ProfileTabPage(),
    ];

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: NotificationListener<OverscrollNotification>(
          onNotification: (overscroll) {
            // Overscroll to open drawer logic
            if (overscroll.metrics.axis == Axis.horizontal) {
              if (overscroll.metrics.pixels == 0 && overscroll.overscroll < 0) {
                _scaffoldKey.currentState?.openDrawer();
              }
            }
            return false;
          },
          child: PageView(
            key: PageStorageKey('home_dashboard_pageview'),
            controller: _pageController,
            physics: NeverScrollableScrollPhysics(),
            onPageChanged: (index) {
              setState(() {
                _currentTabIndex = index;
                PageStorage.of(context).writeState(
                  context,
                  _currentTabIndex,
                  identifier: 'home_tab_index',
                );
              });
            },
            children: pages,
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavigationBar(bool isDarkMode) {
    final navBarBgColor = isDarkMode
        ? Color(0xFF15202B).withOpacity(0.85)
        : Colors.white.withOpacity(0.85);
    final inactiveIconColor = isDarkMode
        ? Colors.white
        : const Color.fromARGB(170, 0, 0, 0);
    final activeIconColor = SisapaTheme.blue;

    return FrostedSurface(
      tint: navBarBgColor,
      blur: FrostedGlassTokens.strongBlurSigma,
      border: Border(
        top: FrostedGlassTokens.subtleBorderSide(context, opacity: 0.2),
      ),
      child: CustomAnimatedBottomBar(
        selectedIndex: _currentTabIndex,
        onItemSelected: _onTabSelected,
        backgroundColor: const Color.fromARGB(0, 9, 9, 9),
        items: <BottomNavyBarItem>[
          BottomNavyBarItem(
            icon: Icon(Icons.home),
            title: Text('Home'),
            activeColor: activeIconColor,
            inactiveColor: inactiveIconColor,
          ),
          BottomNavyBarItem(
            icon: Icon(Icons.groups),
            title: Text('Community'),
            activeColor: activeIconColor,
            inactiveColor: inactiveIconColor,
          ),
          BottomNavyBarItem(
            icon: Icon(Icons.assistant),
            title: Text('AI Assistant'),
            activeColor: activeIconColor,
            inactiveColor: inactiveIconColor,
          ),
          BottomNavyBarItem(
            icon: Icon(Icons.search),
            title: Text('Search'),
            activeColor: activeIconColor,
            inactiveColor: inactiveIconColor,
          ),
          BottomNavyBarItem(
            icon: Icon(Icons.person),
            title: Text('Profile'),
            activeColor: activeIconColor,
            inactiveColor: inactiveIconColor,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      key: _scaffoldKey,
      extendBody: true,
      extendBodyBehindAppBar: true,
      endDrawer: _currentTabIndex == 2
          ? AiHistoryDrawer(
              onNewChat: () =>
                  aiPageEventBus.fire(AiPageEvent(type: AiEventType.newChat)),
              onChatSelected: (sessionId) => aiPageEventBus.fire(
                AiPageEvent(type: AiEventType.loadChat, sessionId: sessionId),
              ),
            )
          : null,
      appBar: _buildAppBar(isDarkMode),
      drawer: SidePanel(
        onProfileSelected: () => _onTabSelected(4),
        onCommunitySelected: () => _onTabSelected(1),
      ),
      floatingActionButton: _buildFab(),
      body: _buildBody(),
      bottomNavigationBar: _buildBottomNavigationBar(isDarkMode),
    );
  }
}
