import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../widgets/blog_post_card.dart';
import '../../widgets/common_error_widget.dart';
import '../../main.dart';
import '../../theme/app_theme.dart';
import '../../theme/avatar_helper.dart';
import '../dashboard/profile_page.dart';
import '../community/community_detail_screen.dart';
import '../../services/prediction_service.dart';
import '../../services/overlay_service.dart';
import '../../services/voice_service.dart';
import '../../services/api_service.dart';
import '../../services/app_localizations.dart';

class SearchPage extends StatefulWidget {
  final bool isSearching;
  final VoidCallback onSearchPressed;
  final VoidCallback? onNavigateToRecommended;

  const SearchPage({
    super.key,
    required this.isSearching,
    required this.onSearchPressed,
    this.onNavigateToRecommended,
  });

  @override
  State<SearchPage> createState() => SearchPageState();
}

class SearchPageState extends State<SearchPage> with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final PredictionService _predictionService = PredictionService();

  bool _isListening = false;

  late TabController _tabController;
  late AnimationController _micAnimController;

  String _searchText = '';
  String? _searchSuggestion;
  Timer? _debounce;

  bool _showAllTrending = false;
  bool _showAllDiscover = false;
  bool _showAllPeople = false;

  List<String> _blockedUserIds = [];
  List<String> _followingIds = [];
  bool _userDataLoaded = false;

  Future<List<Map<String, dynamic>>>? _trendingFuture;
  Future<List<Map<String, dynamic>>>? _discoverFuture;
  Future<List<Map<String, dynamic>>>? _communityRecFuture;
  Future<List<Map<String, dynamic>>>? _peopleRecFuture;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _micAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      lowerBound: 1.0,
      upperBound: 1.3,
    );

    voiceService.initialize();
    _fetchUserDataAndInitFutures();
  }

  Future<void> _fetchUserDataAndInitFutures() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final following = await ApiService().getFollowing(user.uid);
        final blocked = await ApiService().getBlockedUsers();
        if (mounted) {
          setState(() {
            _followingIds = following;
            _blockedUserIds = blocked;
          });
        }
      } catch (e) {
        debugPrint("Error fetching user cache: $e");
      }
    }

    if (mounted) {
      setState(() {
        _userDataLoaded = true;
        _refreshContent();
      });
    }
  }

  void _refreshContent() {
    setState(() {
       _trendingFuture = _fetchTrendingTopics();
       _discoverFuture = _fetchDiscoverContent();
       _communityRecFuture = _fetchCommunityRecs();
       _peopleRecFuture = _getSuggestedUsers(FirebaseAuth.instance.currentUser?.uid);
    });
  }

  Future<List<Map<String, dynamic>>> _fetchTrendingTopics() async {
     try {
       final allPosts = await ApiService().getPosts(limit: 50);
       return _predictionService.analyzeTrendingTopics(allPosts);
     } catch (e) {
       return [];
     }
  }

  Future<List<Map<String, dynamic>>> _fetchDiscoverContent() async {
     try {
        final posts = await ApiService().getPosts(limit: 100);
        final publicPosts = posts.where((p) {
          final authorId = p['user_uid'] ?? p['userId'];
          return (p['visibility'] ?? 'public') == 'public' &&
                 !_blockedUserIds.contains(authorId);
        }).toList();

        return _predictionService.getDiscoverRecommendations(
           publicPosts, FirebaseAuth.instance.currentUser?.uid ?? '', _followingIds
        );
     } catch (e) {
       return [];
     }
  }

  Future<List<Map<String, dynamic>>> _fetchCommunityRecs() async {
    try {
      final list = await ApiService().getCommunities();
      return _predictionService.getRecommendedCommunities(
        list, FirebaseAuth.instance.currentUser?.uid ?? '', _followingIds
      );
    } catch(e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _getSuggestedUsers(String? currentUserId) async {
    if (currentUserId == null) return [];
    try {
      return await ApiService().getSuggestedUsers();
    } catch (e) {
      return [];
    }
  }

  @override
  void didUpdateWidget(SearchPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSearching && !oldWidget.isSearching) {
      _tabController.index = 0;
      Future.delayed(const Duration(milliseconds: 100), () {
        if(mounted && widget.isSearching) FocusScope.of(context).requestFocus(_searchFocusNode);
      });
    }

    if (oldWidget.isSearching && !widget.isSearching) {
      _searchController.clear();
      _searchText = '';
      _searchSuggestion = null;
      _stopListening();
      FocusScope.of(context).unfocus();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _tabController.dispose();
    _micAnimController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _startListening() async {
    if (voiceService.isListening) {
      await voiceService.stopListening();
    }

    if (_searchFocusNode.hasFocus) {
      _searchFocusNode.unfocus();
      await Future.delayed(const Duration(milliseconds: 200));
    }

    if (!widget.isSearching) {
      widget.onSearchPressed();
    }

    if(mounted) {
      setState(() => _isListening = true);
      _micAnimController.forward();
    }

    voiceService.startListening(
      onListeningStateChanged: (isListening) {},
      onResult: (text) {
        if (!mounted) return;

        String finalQuery = text;
        String lowerQuery = finalQuery.toLowerCase();

        if (lowerQuery.startsWith("cari ")) finalQuery = finalQuery.substring(5);
        else if (lowerQuery.startsWith("search for ")) finalQuery = finalQuery.substring(11);
        else if (lowerQuery.startsWith("buka ")) finalQuery = finalQuery.substring(5);

        if (lowerQuery.contains("profil") || lowerQuery.contains("user")) {
          _tabController.animateTo(1);
        } else if (lowerQuery.contains("komunitas") || lowerQuery.contains("community")) {
          _tabController.animateTo(2);
        } else {
          _tabController.animateTo(0);
        }

        _searchController.text = finalQuery;
        _searchController.selection = TextSelection.fromPosition(TextPosition(offset: finalQuery.length));
        _onSearchChanged(finalQuery);
      },
    );
  }

  void _stopListening() {
    if(mounted) {
      _micAnimController.reverse();
      setState(() => _isListening = false);
    }
    voiceService.stopListening();
  }

  void _onSearchChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    _debounce = Timer(const Duration(milliseconds: 400), () async {
      if (!mounted) return;

      setState(() {
        _searchText = value.toLowerCase().trim();
        _searchSuggestion = null;
      });

      if (value.trim().isEmpty) return;

      final suggestion = await _predictionService.getLocalPrediction(value);
      if (mounted && suggestion != null && suggestion.toLowerCase() != _searchText) {
        setState(() { _searchSuggestion = suggestion; });
      }
    });
  }

  void _applySuggestion() {
    if (_searchSuggestion != null) {
      _searchController.text = _searchSuggestion!;
      _onSearchChanged(_searchSuggestion!);
      FocusScope.of(context).unfocus();
    }
  }

  void _clearSearch() {
    setState(() {
      _searchController.clear();
      _searchText = '';
      _searchSuggestion = null;
    });
    if (_isListening) _stopListening();
    if (widget.isSearching) widget.onSearchPressed();
  }

  void _onTrendingTagClicked(String tag) {
    final query = tag.startsWith('#') ? tag : tag;
    setState(() {
      _searchController.text = query;
      _searchText = query.toLowerCase();
      if (!widget.isSearching) widget.onSearchPressed();
    });
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    var t = AppLocalizations.of(context)!;
    final screenWidth = MediaQuery.of(context).size.width;
    final theme = Theme.of(context);

    final double searchBarBaseHeight = 70.0;
    final double suggestionHeight = _searchSuggestion != null ? 30.0 : 0.0;
    final double currentSearchBarHeight = widget.isSearching ? (searchBarBaseHeight + suggestionHeight) : 0.0;
    final double topAnchor = 90.0;
    final double contentTopPadding = widget.isSearching ? (topAnchor + currentSearchBarHeight) : topAnchor;

    return WillPopScope(
      onWillPop: () async {
        if (widget.isSearching) {
          _clearSearch();
          return false;
        }
        return true;
      },
      child: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.only(top: contentTopPadding),
              child: _searchText.isEmpty && !widget.isSearching
                  ? _buildExplorePage(theme, t)
                  : _buildSearchResults(theme, t),
            ),
          ),
          Positioned(
            top: topAnchor,
            left: 0, right: 0,
            child: Align(
              alignment: Alignment.topRight,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeInOutQuart,
                width: widget.isSearching ? screenWidth : 0,
                height: currentSearchBarHeight,
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(20)),
                  child: Container(
                    color: theme.scaffoldBackgroundColor,
                    child: widget.isSearching
                        ? SingleChildScrollView(
                            physics: const NeverScrollableScrollPhysics(),
                            child: Column(
                              children: [
                                Container(
                                  width: screenWidth,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  child: Center(
                                    child: TextField(
                                      controller: _searchController,
                                      focusNode: _searchFocusNode,
                                      autofocus: false,
                                      readOnly: _isListening,
                                      decoration: InputDecoration(
                                        hintText: _isListening
                                            ? t.translate('search_listening')
                                            : t.translate('search_hint'),
                                        hintStyle: TextStyle(
                                          color: _isListening ? SisapaTheme.blue : theme.hintColor,
                                          fontStyle: _isListening ? FontStyle.italic : FontStyle.normal,
                                          fontWeight: _isListening ? FontWeight.bold : FontWeight.normal,
                                        ),
                                        prefixIcon: const Icon(Icons.search),
                                        suffixIcon: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (_searchController.text.isNotEmpty)
                                              IconButton(icon: const Icon(Icons.clear), onPressed: _clearSearch),

                                            Listener(
                                              onPointerDown: (details) => _startListening(),
                                              onPointerUp: (details) => _stopListening(),
                                              onPointerCancel: (details) => _stopListening(),
                                              child: Padding(
                                                padding: const EdgeInsets.only(right: 12.0, left: 4.0),
                                                child: ScaleTransition(
                                                  scale: _micAnimController,
                                                  child: Container(
                                                    padding: const EdgeInsets.all(8),
                                                    decoration: BoxDecoration(
                                                      shape: BoxShape.circle,
                                                      color: _isListening ? Colors.red : Colors.transparent,
                                                      boxShadow: _isListening ? [
                                                        BoxShadow(color: Colors.red.withOpacity(0.4), blurRadius: 10, spreadRadius: 2)
                                                      ] : null,
                                                    ),
                                                    child: Icon(
                                                      _isListening ? Icons.mic : Icons.mic_none,
                                                      color: _isListening ? Colors.white : theme.primaryColor,
                                                      size: 24,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                                        filled: true,
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
                                      ),
                                      onChanged: _onSearchChanged,
                                    ),
                                  ),
                                ),
                                if (_searchSuggestion != null && widget.isSearching)
                                  InkWell(
                                    onTap: _applySuggestion,
                                    child: Padding(
                                      padding: const EdgeInsets.only(bottom: 8.0, left: 24.0, right: 24.0),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.lightbulb_outline, size: 14, color: SisapaTheme.blue),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: RichText(
                                              text: TextSpan(
                                                style: TextStyle(color: theme.textTheme.bodyMedium?.color, fontSize: 13),
                                                children: [
                                                  TextSpan(text: t.translate('search_suggestion_prefix')),
                                                  TextSpan(text: _searchSuggestion, style: const TextStyle(fontWeight: FontWeight.bold, color: SisapaTheme.blue)),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExplorePage(ThemeData theme, AppLocalizations t) {
    if (!_userDataLoaded) return const Center(child: CircularProgressIndicator());

    return RefreshIndicator(
      notificationPredicate: (notification) => !_isListening,
      onRefresh: () async {
        _refreshContent();
        await Future.delayed(const Duration(seconds: 1));
      },
      child: SingleChildScrollView(
        physics: _isListening
            ? const NeverScrollableScrollPhysics()
            : const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                children: [
                  const Icon(Icons.trending_up, color: SisapaTheme.blue),
                  const SizedBox(width: 8),
                  Text(t.translate('search_trending_title'),
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                ],
              ),
            ),

            FutureBuilder<List<Map<String, dynamic>>>(
              future: _trendingFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const SizedBox(height: 100, child: Center(child: CircularProgressIndicator()));
                if (snapshot.hasError) return Padding(padding: const EdgeInsets.all(16), child: Text(t.translate('search_trends_error')));

                final trends = snapshot.data ?? [];

                if (trends.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text(t.translate('search_trends_empty'), style: const TextStyle(color: Colors.grey)),
                  );
                }

                final maxItems = _showAllTrending ? 10 : 3;
                final displayedTrends = trends.take(maxItems).toList();
                final canExpand = trends.length > 3;

                return Column(
                  children: [
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: EdgeInsets.zero,
                      itemCount: displayedTrends.length,
                      separatorBuilder: (context, index) => Divider(height: 1, thickness: 0.5, color: theme.dividerColor.withOpacity(0.3)),
                      itemBuilder: (context, index) {
                        final tag = displayedTrends[index]['tag'];
                        final count = displayedTrends[index]['count'];
                        final isHashtag = tag.toString().startsWith('#');
                        final isTopTrending = index == 0;

                        return ListTile(
                          dense: false,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: Text("${index + 1}", style: TextStyle(color: theme.hintColor, fontWeight: FontWeight.bold, fontSize: 16)),
                          title: Text(tag, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isHashtag ? SisapaTheme.blue : theme.textTheme.bodyLarge?.color)),
                          subtitle: Text("$count distinct posts"),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isTopTrending) const Padding(padding: EdgeInsets.only(right: 8.0), child: Icon(Icons.local_fire_department, color: Colors.orange, size: 20)),
                              Icon(Icons.arrow_forward_ios, size: 14, color: theme.hintColor),
                            ],
                          ),
                          onTap: () => _onTrendingTagClicked(tag),
                        );
                      },
                    ),
                    if (canExpand)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                        child: InkWell(
                          onTap: () => setState(() => _showAllTrending = !_showAllTrending),
                          child: Row(
                            children: [
                              Text(
                                _showAllTrending ? t.translate('general_show_less') : t.translate('general_show_more'),
                                style: const TextStyle(color: SisapaTheme.blue, fontWeight: FontWeight.bold)
                              ),
                              Icon(_showAllTrending ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: SisapaTheme.blue, size: 16)
                            ],
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),

            Divider(thickness: 8, color: theme.dividerColor.withOpacity(0.1)),

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  const Icon(Icons.groups_outlined, color: Colors.orange),
                  const SizedBox(width: 8),
                  Text(t.translate('search_communities_title'),
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                ],
              ),
            ),

            FutureBuilder<List<Map<String, dynamic>>>(
              future: _communityRecFuture,
              builder: (context, snapshot) {
                 if (snapshot.connectionState == ConnectionState.waiting) return const SizedBox(height: 100, child: Center(child: CircularProgressIndicator()));
                 if (snapshot.hasError) return Padding(padding: const EdgeInsets.all(16), child: Text(t.translate('search_communities_error')));

                 final recommended = snapshot.data ?? [];

                 if (recommended.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(t.translate('search_communities_empty'), style: const TextStyle(color: Colors.grey)),
                    );
                 }

                 return SizedBox(
                      height: 160,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: recommended.length > 10 ? 10 : recommended.length,
                        itemBuilder: (context, index) {
                          final data = recommended[index];
                          final name = data['name'] ?? 'Community';
                          final imageUrl = data['image_url'] ?? data['imageUrl'];
                          final membersCount = data['follower_count'] ?? 0;

                          return Container(
                            width: 140,
                            margin: const EdgeInsets.all(4),
                            child: Card(
                              elevation: 2,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () {
                                  Navigator.push(context, MaterialPageRoute(
                                    builder: (_) => CommunityDetailScreen(communityId: data['id'], communityData: data)
                                  ));
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      CircleAvatar(
                                        radius: 28,
                                        backgroundColor: SisapaTheme.blue.withOpacity(0.1),
                                        backgroundImage: imageUrl != null && imageUrl.toString().isNotEmpty ? CachedNetworkImageProvider(imageUrl) : null,
                                        child: imageUrl == null || imageUrl.toString().isEmpty ? Text(name.isNotEmpty ? name[0].toUpperCase() : 'C', style: const TextStyle(fontWeight: FontWeight.bold, color: SisapaTheme.blue)) : null,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold)),
                                      Text("$membersCount ${t.translate('general_members')}", style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    );
              },
            ),

            Divider(thickness: 8, color: theme.dividerColor.withOpacity(0.1)),

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  const Icon(Icons.explore_outlined, color: Colors.purple),
                  const SizedBox(width: 8),
                  Text(t.translate('search_discover_title'),
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                ],
              ),
            ),

            FutureBuilder<List<Map<String, dynamic>>>(
              future: _discoverFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const SizedBox(height: 100, child: Center(child: CircularProgressIndicator()));
                if (snapshot.hasError) return Padding(padding: const EdgeInsets.all(16), child: CommonErrorWidget(message: t.translate('search_discover_error'), isConnectionError: true));

                final allPosts = snapshot.data ?? [];

                if (allPosts.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 32.0),
                    child: Center(child: Text(t.translate('search_discover_empty'))),
                  );
                }

                final int initialCount = 5;
                final bool showAll = _showAllDiscover;
                final int totalCount = allPosts.length;

                final int visibleCount = showAll ? totalCount : (totalCount > initialCount ? initialCount : totalCount);
                final displayedPosts = allPosts.take(visibleCount).toList();
                final bool canExpand = totalCount > initialCount;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ...displayedPosts.map((post) {
                      final authorId = post['user_uid'] ?? post['userId'];
                      return BlogPostCard(
                        postId: post['id'],
                        postData: post,
                        isOwner: authorId == FirebaseAuth.instance.currentUser?.uid,
                        heroContextId: 'discover',
                        blockedUserIds: _blockedUserIds,
                      );
                    }).toList(),

                    if (canExpand)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16.0),
                        child: Center(
                          child: TextButton.icon(
                            onPressed: () {
                              setState(() {
                                _showAllDiscover = !_showAllDiscover;
                              });
                            },
                            icon: Icon(_showAllDiscover ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down),
                            label: Text(_showAllDiscover ? t.translate('general_show_less') : t.translate('general_show_more')),
                          ),
                        ),
                      ),
                  ],
                );
              }
            ),

            Divider(thickness: 8, color: theme.dividerColor.withOpacity(0.1)),

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  const Icon(Icons.person_add_alt_1_outlined, color: Colors.blueAccent),
                  const SizedBox(width: 8),
                  Text(t.translate('search_people_title'),
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                ],
              ),
            ),

            FutureBuilder<List<Map<String, dynamic>>>(
              future: _peopleRecFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()));
                if (snapshot.hasError) return Padding(padding: const EdgeInsets.all(16), child: Text(t.translate('search_people_error')));

                final allUsers = snapshot.data ?? [];

                if (allUsers.isEmpty) return Padding(padding: const EdgeInsets.all(16.0), child: Text(t.translate('search_people_empty')));

                final int initialCount = 5;
                final bool showAll = _showAllPeople;
                final int totalCount = allUsers.length;

                final int visibleCount = showAll ? totalCount : (totalCount > initialCount ? initialCount : totalCount);
                final displayedUsers = allUsers.take(visibleCount).toList();
                final bool canExpand = totalCount > initialCount;

                return Column(
                  children: [
                    ...displayedUsers.map((user) {
                      final String userId = user['uid'] ?? user['id'] ?? '';
                      return _UserSearchTile(
                        userId: userId,
                        userData: user,
                        currentUserId: FirebaseAuth.instance.currentUser?.uid,
                      );
                    }).toList(),

                    if (canExpand)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16.0),
                        child: Center(
                          child: TextButton.icon(
                            onPressed: () {
                              setState(() {
                                _showAllPeople = !_showAllPeople;
                              });
                            },
                            icon: Icon(_showAllPeople ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down),
                            label: Text(_showAllPeople ? t.translate('general_show_less') : t.translate('general_show_more')),
                          ),
                        ),
                      ),
                  ],
                );
              }
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResults(ThemeData theme, AppLocalizations t) {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: theme.dividerColor))),
          child: TabBar(
            controller: _tabController,
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
            controller: _tabController,
            children: [_buildPostResults(t), _buildUserResults(t), _buildCommunityResults(t)],
          ),
        ),
      ],
    );
  }

  Widget _buildPostResults(AppLocalizations t) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _searchText.isNotEmpty ? ApiService().getPosts(query: _searchText, limit: 50) : Future.value(<Map<String, dynamic>>[]),
      builder: (context, snapshot) {
        if (snapshot.hasError) return CommonErrorWidget(message: t.translate('search_failed'), isConnectionError: true);
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

        if (_searchText.isEmpty) return const SizedBox();

        final posts = snapshot.data ?? [];
        final filteredPosts = posts.where((p) {
          final authorId = p['user_uid'] ?? p['userId'];
          return !_blockedUserIds.contains(authorId);
        }).toList();

        if (filteredPosts.isEmpty) return Center(child: Text('${t.translate('search_no_results')} "$_searchText"'));

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
                blockedUserIds: _blockedUserIds
            );
          },
        );
      },
    );
  }

  Widget _buildUserResults(AppLocalizations t) {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _searchText.isNotEmpty ? ApiService().searchUsers(_searchText) : Future.value(<Map<String, dynamic>>[]),
      builder: (context, snapshot) {
        if (snapshot.hasError) return CommonErrorWidget(message: t.translate('search_user_failed'), isConnectionError: true);
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

        final users = snapshot.data ?? [];
        final filteredUsers = users.where((u) => (u['uid'] ?? u['id']) != myUid).toList();

        if (filteredUsers.isEmpty) return Center(child: Text('${t.translate('search_no_results')} "$_searchText"'));

        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 100),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          itemCount: filteredUsers.length,
          itemBuilder: (context, index) {
            final user = filteredUsers[index];
            final String userId = user['uid'] ?? user['id'] ?? '';
            return _UserSearchTile(userId: userId, userData: user, currentUserId: myUid);
          },
        );
      },
    );
  }

  Widget _buildCommunityResults(AppLocalizations t) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _searchText.isNotEmpty ? ApiService().getCommunities(query: _searchText) : Future.value(<Map<String, dynamic>>[]),
      builder: (context, snapshot) {
        if (snapshot.hasError) return CommonErrorWidget(message: t.translate('search_failed'), isConnectionError: true);
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

        final communities = snapshot.data ?? [];

        if (communities.isEmpty) return Center(child: Text('${t.translate('search_no_results')} "$_searchText"'));

        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 100),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          itemCount: communities.length,
          itemBuilder: (context, index) {
            final community = communities[index];
            final String name = community['name'] ?? 'Community';
            final String? imageUrl = community['image_url'] ?? community['imageUrl'];
            final int memberCount = community['follower_count'] ?? 0;

            return ListTile(
              leading: CircleAvatar(
                backgroundImage: imageUrl != null && imageUrl.isNotEmpty ? CachedNetworkImageProvider(imageUrl) : null,
                backgroundColor: SisapaTheme.blue.withOpacity(0.1),
                child: imageUrl == null || imageUrl.isEmpty ? const Icon(Icons.groups, color: SisapaTheme.blue) : null,
              ),
              title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text("$memberCount ${t.translate('general_members')}"),
              trailing: const Icon(Icons.arrow_forward_ios, size: 14),
              onTap: () {
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => CommunityDetailScreen(communityId: community['id'], communityData: community)
                ));
              },
            );
          },
        );
      },
    );
  }
}

class _UserSearchTile extends StatefulWidget {
  final String userId;
  final Map<String, dynamic> userData;
  final String? currentUserId;

  const _UserSearchTile({
    required this.userId,
    required this.userData,
    this.currentUserId,
  });

  @override
  State<_UserSearchTile> createState() => _UserSearchTileState();
}

class _UserSearchTileState extends State<_UserSearchTile> {
  bool _isFollowing = false;

  @override
  void initState() {
    super.initState();
    _checkFollowStatus();
  }

  @override
  void didUpdateWidget(covariant _UserSearchTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.userData != oldWidget.userData) {
      _checkFollowStatus();
    }
  }

  void _checkFollowStatus() async {
    if (widget.currentUserId == null) return;
    try {
      final following = await ApiService().getFollowing(widget.currentUserId!);
      if (mounted) {
        setState(() {
          _isFollowing = following.contains(widget.userId);
        });
      }
    } catch (_) {}
  }

  Future<void> _toggleFollow() async {
    if (widget.currentUserId == null) return;
    try {
      if (_isFollowing) {
        final success = await ApiService().unfollowUser(widget.userId);
        if (success) {
          setState(() => _isFollowing = false);
        }
      } else {
        final resp = await ApiService().followUser(widget.userId);
        if (resp['success'] == true) {
          setState(() => _isFollowing = true);
          if (resp['type'] == 'request_sent') {
            OverlayService().showTopNotification(context, "Follow request sent", Icons.hourglass_empty, (){});
            setState(() => _isFollowing = false);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        OverlayService().showTopNotification(context, "Action failed: $e", Icons.error, (){}, color: Colors.red);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    var t = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    final name = widget.userData['name'] ?? 'User';
    final email = widget.userData['email'] ?? '';
    final handle = email.isNotEmpty ? "@${email.split('@')[0]}" : "";
    final int iconId = widget.userData['avatar_icon_id'] ?? widget.userData['avatarIconId'] ?? 0;
    final String? colorHex = widget.userData['avatar_hex'] ?? widget.userData['avatarHex'];
    final String? profileImageUrl = widget.userData['profile_image_url'] ?? widget.userData['profileImageUrl'];

    return InkWell(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProfilePage(userId: widget.userId, includeScaffold: true))),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
                radius: 24,
                backgroundColor: profileImageUrl != null && profileImageUrl.isNotEmpty ? Colors.transparent : AvatarHelper.getColor(colorHex),
                backgroundImage: profileImageUrl != null && profileImageUrl.isNotEmpty ? CachedNetworkImageProvider(profileImageUrl) : null,
                child: profileImageUrl == null || profileImageUrl.isEmpty ? Icon(AvatarHelper.getIcon(iconId), size: 24, color: Colors.white) : null
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
              Text(handle, style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor)),
            ])),
            const SizedBox(width: 8),
            _isFollowing
              ? OutlinedButton(
                  onPressed: _toggleFollow,
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 16), side: BorderSide(color: theme.dividerColor), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                  child: Text(t.translate('community_following'), style: TextStyle(color: theme.textTheme.bodyMedium?.color))
                )
              : ElevatedButton(
                  onPressed: _toggleFollow,
                  style: ElevatedButton.styleFrom(backgroundColor: SisapaTheme.blue, foregroundColor: Colors.white, elevation: 0, padding: const EdgeInsets.symmetric(horizontal: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                  child: Text(t.translate('community_follow'))
                )
          ],
        ),
      ),
    );
  }
}
