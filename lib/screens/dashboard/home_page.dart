import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../widgets/blog_post_card.dart';
import '../../widgets/common_error_widget.dart';
import '../../main.dart';
import '../../theme/app_theme.dart';
import '../../theme/avatar_helper.dart';
import '../../services/prediction_service.dart';
import '../../services/app_localizations.dart';
import '../../services/api_service.dart';

class HomePage extends StatefulWidget {
  final ScrollController scrollController;
  final ScrollController recommendedScrollController;

  const HomePage({
    super.key,
    required this.scrollController,
    required this.recommendedScrollController,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ScrollController _localScrollController = ScrollController();
  bool _isScrolled = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    _localScrollController.addListener(() {
      if (_localScrollController.hasClients) {
        bool scrolled = _localScrollController.offset > 0;
        if (scrolled != _isScrolled) {
          setState(() => _isScrolled = scrolled);
        }
      }
    });
  }

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
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
            backgroundColor: Colors.transparent,
            automaticallyImplyLeading: false,
            toolbarHeight: 0,
            collapsedHeight: 0,
            expandedHeight: 0,

            bottom: PreferredSize(
              preferredSize: Size.fromHeight(48),
              child: ClipRRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                  child: Container(
                    color: theme.scaffoldBackgroundColor.withOpacity(0.85),
                    child: TabBar(
                      controller: _tabController,
                      labelColor: SisapaTheme.blue,
                      unselectedLabelColor: theme.hintColor,
                      indicatorColor: SisapaTheme.blue,
                      indicatorSize: TabBarIndicatorSize.label,
                      tabs: [
                        Tab(text: t.translate('home_recent')),
                        Tab(text: t.translate('home_recommended')),
                      ],
                    ),
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
          ),
          _PostFeedList(
            scrollController: widget.recommendedScrollController,
            feedType: 'recommended',
            refreshOffset: 60,
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

  const _PostFeedList({required this.scrollController, required this.feedType, required this.refreshOffset});

  @override
  State<_PostFeedList> createState() => _PostFeedListState();
}

class _PostFeedListState extends State<_PostFeedList> with AutomaticKeepAliveClientMixin {
  final PredictionService _aiService = PredictionService();
  final ApiService _api = ApiService();
  List<Map<String, dynamic>> _posts = [];
  Map<String, dynamic> _userData = {};
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

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() { _isLoading = true; _hasError = false; });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final results = await Future.wait([
          _api.getPosts(limit: 50),
          _api.getUser(user.uid),
        ]);
        if (mounted) {
          setState(() {
            _posts = results[0] as List<Map<String, dynamic>>;
            _userData = (results[1] as Map<String, dynamic>?) ?? {};
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() { _isLoading = false; _hasError = true; });
    }
  }

  Future<void> _refresh() async {
    await _loadData();
    if(mounted) setState(() => _refreshKey = DateTime.now().toString());
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final user = FirebaseAuth.instance.currentUser;
    final bool isRec = widget.feedType == 'recommended';

    // LOCALIZATION
    var t = AppLocalizations.of(context)!;

    if (_isLoading) return Center(child: CircularProgressIndicator());
    if (_hasError) return CommonErrorWidget(message: t.translate('home_error_loading'));

    List<Map<String, dynamic>> docs = List.from(_posts);

    // Client-side recommendation sorting if needed
    // Note: visibility filtering is now handled server-side

    if (docs.isEmpty) {
       return Center(
         child: Column(
           mainAxisAlignment: MainAxisAlignment.center,
           children: [
             Icon(Icons.feed_outlined, size: 64, color: Colors.grey.withOpacity(0.5)),
             SizedBox(height: 16),
             Text(t.translate('home_no_posts'), style: TextStyle(color: Colors.grey)),
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
