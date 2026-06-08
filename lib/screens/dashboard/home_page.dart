import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../widgets/blog_post_card.dart';
import '../../widgets/common_error_widget.dart';
import '../../theme/app_theme.dart';

import '../../services/app_localizations.dart';
import '../../services/api_service.dart';
import '../../services/feed_preferences_service.dart';
import 'feed_controls_sheet.dart';

class HomePage extends StatefulWidget {
  final ScrollController scrollController;
  final ScrollController recommendedScrollController;
  final ValueChanged<bool>? onScrollChange;
  final ValueChanged<int>? onFeedTabChange;

  const HomePage({
    super.key,
    required this.scrollController,
    required this.recommendedScrollController,
    this.onScrollChange,
    this.onFeedTabChange,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin {
  static const double _tabBarHeight = 48.0;

  late TabController _tabController;
  final ScrollController _localScrollController = ScrollController();
  final FeedPreferencesService _feedPreferencesService =
      FeedPreferencesService.instance;
  bool _isScrolled = false;
  FeedPreferences _feedPreferences = FeedPreferences.defaults;
  int _feedPreferencesVersion = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabChange);
    _localScrollController.addListener(_handleScrollChange);
    widget.scrollController.addListener(_handleScrollChange);
    widget.recommendedScrollController.addListener(_handleScrollChange);

    WidgetsBinding.instance.addPostFrameCallback((_) => _handleScrollChange());
    _loadFeedPreferences();
  }

  @override
  bool get wantKeepAlive => true;

  bool _isControllerScrolled(ScrollController controller) {
    return controller.hasClients && controller.offset > 0;
  }

  bool get _isActiveFeedScrolled {
    final activeFeedController = _tabController.index == 0
        ? widget.scrollController
        : widget.recommendedScrollController;

    return _isControllerScrolled(_localScrollController) ||
        _isControllerScrolled(activeFeedController);
  }

  void _handleScrollChange() {
    if (!mounted) return;

    final scrolled = _isActiveFeedScrolled;
    if (scrolled != _isScrolled) {
      setState(() => _isScrolled = scrolled);
    }
    widget.onScrollChange?.call(scrolled);
  }

  void _handleTabChange() {
    widget.onFeedTabChange?.call(_tabController.index);
    _handleScrollChange();
  }

  Future<void> _loadFeedPreferences() async {
    final preferences = await _feedPreferencesService.load();
    if (!mounted || preferences == _feedPreferences) return;
    setState(() {
      _feedPreferences = preferences;
      _feedPreferencesVersion++;
    });
  }

  Future<void> _showFeedControls() async {
    final updated = await showModalBottomSheet<FeedPreferences>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return FeedControlsSheet(initialPreferences: _feedPreferences);
      },
    );

    if (updated == null || updated == _feedPreferences) return;
    await _feedPreferencesService.save(updated);
    if (!mounted) return;
    setState(() {
      _feedPreferences = updated;
      _feedPreferencesVersion++;
    });
  }

  @override
  void didUpdateWidget(covariant HomePage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.scrollController != widget.scrollController) {
      oldWidget.scrollController.removeListener(_handleScrollChange);
      widget.scrollController.addListener(_handleScrollChange);
    }
    if (oldWidget.recommendedScrollController !=
        widget.recommendedScrollController) {
      oldWidget.recommendedScrollController.removeListener(_handleScrollChange);
      widget.recommendedScrollController.addListener(_handleScrollChange);
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _localScrollController.removeListener(_handleScrollChange);
    widget.scrollController.removeListener(_handleScrollChange);
    widget.recommendedScrollController.removeListener(_handleScrollChange);
    _tabController.dispose();
    _localScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    var t = AppLocalizations.of(context)!;

    return NestedScrollView(
      controller: _localScrollController,
      headerSliverBuilder: (context, innerBoxIsScrolled) {
        return [
          SliverAppBar(
            pinned: true,
            floating: true,
            snap: true,
            elevation: 0,
            scrolledUnderElevation: 0,
            shadowColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            backgroundColor: Colors.transparent,
            automaticallyImplyLeading: false,
            toolbarHeight: 0,
            collapsedHeight: 0,
            expandedHeight: 0,

            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(_tabBarHeight),
              child: FrostedLayer(
                blur: _isScrolled ? FrostedGlassTokens.controlBlurSigma : 0.001,
                tint: _isScrolled
                    ? theme.scaffoldBackgroundColor.withValues(alpha: 0.82)
                    : Colors.transparent,
                child: SizedBox(
                  height: _tabBarHeight,
                  child: Row(
                    children: [
                      Expanded(
                        child: TabBar(
                          controller: _tabController,
                          labelColor: SisapaTheme.blue,
                          unselectedLabelColor: theme.hintColor,
                          indicatorColor: SisapaTheme.blue,
                          indicatorSize: TabBarIndicatorSize.label,
                          dividerColor: Colors.transparent,
                          dividerHeight: 0,
                          tabs: [
                            Tab(text: t.translate('home_recent')),
                            Tab(text: t.translate('home_recommended')),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 48,
                        child: IconButton(
                          tooltip: 'Feed controls',
                          icon: const Icon(Icons.tune_rounded),
                          color: _feedPreferences == FeedPreferences.defaults
                              ? theme.hintColor
                              : SisapaTheme.blue,
                          onPressed: _showFeedControls,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ];
      },
      body: TabBarView(
        controller: _tabController,
        children: [
          _PostFeedList(
            scrollController: widget.scrollController,
            feedType: 'recent',
            refreshOffset: 60,
            feedPreferences: _feedPreferences,
            feedPreferencesVersion: _feedPreferencesVersion,
          ),
          _PostFeedList(
            scrollController: widget.recommendedScrollController,
            feedType: 'recommended',
            refreshOffset: 60,
            feedPreferences: _feedPreferences,
            feedPreferencesVersion: _feedPreferencesVersion,
          ),
        ],
      ),
    );
  }
}

class _PostFeedList extends StatefulWidget {
  final ScrollController scrollController;
  final String feedType;
  final double refreshOffset;
  final FeedPreferences feedPreferences;
  final int feedPreferencesVersion;

  const _PostFeedList({
    required this.scrollController,
    required this.feedType,
    required this.refreshOffset,
    required this.feedPreferences,
    required this.feedPreferencesVersion,
  });

  @override
  State<_PostFeedList> createState() => _PostFeedListState();
}

class _PostFeedListState extends State<_PostFeedList>
    with AutomaticKeepAliveClientMixin {
  final ApiService _api = ApiService();
  List<Map<String, dynamic>> _posts = [];
  bool _isLoading = true;
  bool _hasError = false;
  String _refreshKey = '';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didUpdateWidget(covariant _PostFeedList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.feedPreferencesVersion != widget.feedPreferencesVersion) {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final posts = widget.feedType == 'recommended'
            ? await _api.getPersonalizedRecommendations(
                feedPreferences: widget.feedPreferences,
              )
            : await _api.getPosts(
                limit: 50,
                feedPreferences: widget.feedPreferences,
              );
        if (mounted) {
          setState(() {
            _posts = posts;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  Future<void> _refresh() async {
    await _loadData();
    if (mounted) setState(() => _refreshKey = DateTime.now().toString());
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final user = FirebaseAuth.instance.currentUser;

    // LOCALIZATION
    var t = AppLocalizations.of(context)!;

    if (_isLoading) return Center(child: CircularProgressIndicator());
    if (_hasError) {
      return CommonErrorWidget(message: t.translate('home_error_loading'));
    }

    List<Map<String, dynamic>> docs = List.from(_posts);

    // Client-side recommendation sorting if needed
    // Note: visibility filtering is now handled server-side

    if (docs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.feed_outlined,
              size: 64,
              color: Colors.grey.withValues(alpha: 0.5),
            ),
            SizedBox(height: 16),
            Text(
              t.translate('home_no_posts'),
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      edgeOffset: widget.refreshOffset,
      child: ListView.builder(
        key: PageStorageKey('${widget.feedType}_$_refreshKey'),
        controller: widget.scrollController,
        padding: EdgeInsets.only(top: 10, bottom: 100),
        itemCount: docs.length,
        itemBuilder: (context, index) {
          final post = docs[index];
          return BlogPostCard(
            postId: post['id'] ?? '',
            postData: post,
            isOwner: post['user_uid'] == user?.uid,
          );
        },
      ),
    );
  }
}
