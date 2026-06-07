import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../services/prediction_service.dart';
import '../../services/voice_service.dart';
import 'search/search_explore_page.dart';
import 'search/search_menu_overlay.dart';
import 'search/search_results_view.dart';

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

  Future<List<Map<String, dynamic>>>? _trendingFuture;
  Future<List<Map<String, dynamic>>>? _discoverFuture;
  Future<List<Map<String, dynamic>>>? _communityRecFuture;
  Future<List<Map<String, dynamic>>>? _peopleRecFuture;
  Future<List<Map<String, dynamic>>>? _postSearchFuture;
  Future<List<Map<String, dynamic>>>? _userSearchFuture;
  Future<List<Map<String, dynamic>>>? _communitySearchFuture;
  String _activeSearchQuery = '';

  String? get _currentUserId => FirebaseAuth.instance.currentUser?.uid;

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

    _primeContentFutures();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final results = await Future.wait([
        ApiService().getFollowing(user.uid),
        ApiService().getBlockedUsers(),
      ]);
      if (!mounted) return;

      setState(() {
        _followingIds = results[0];
        _blockedUserIds = results[1];
      });
    } catch (e) {
      debugPrint('Error fetching user cache: $e');
    }
  }

  void _primeContentFutures() {
    _trendingFuture = _fetchTrendingTopics();
    _discoverFuture = _fetchDiscoverContent();
    _communityRecFuture = _fetchCommunityRecs();
    _peopleRecFuture = _getSuggestedUsers(_currentUserId);
  }

  void _refreshContent() {
    setState(_primeContentFutures);
  }

  void _updateSearchFutures(String query) {
    if (_activeSearchQuery == query) return;

    _activeSearchQuery = query;
    if (query.isEmpty) {
      _postSearchFuture = null;
      _userSearchFuture = null;
      _communitySearchFuture = null;
      return;
    }

    _postSearchFuture = ApiService().getPosts(query: query, limit: 50);
    _userSearchFuture = ApiService().searchUsers(query);
    _communitySearchFuture = ApiService().getCommunities(query: query);
  }

  void _resetSearchState({bool clearController = true}) {
    _debounce?.cancel();
    if (clearController) _searchController.clear();
    _searchText = '';
    _searchSuggestion = null;
    _updateSearchFutures('');
  }

  Future<List<Map<String, dynamic>>> _fetchTrendingTopics() async {
    try {
      return await ApiService().getTrendingTopics();
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _fetchDiscoverContent() async {
    try {
      return await ApiService().getDiscoverRecommendations();
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _fetchCommunityRecs() async {
    try {
      return await ApiService().getRecommendedCommunities();
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _getSuggestedUsers(
    String? currentUserId,
  ) async {
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
        if (mounted && widget.isSearching) {
          FocusScope.of(context).requestFocus(_searchFocusNode);
        }
      });
    }

    if (oldWidget.isSearching && !widget.isSearching) {
      _resetSearchState();
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

    if (mounted) {
      setState(() => _isListening = true);
      _micAnimController.forward();
    }

    voiceService.startListening(
      onListeningStateChanged: (_) {},
      onResult: (text) {
        if (!mounted) return;

        String finalQuery = text;
        final lowerQuery = finalQuery.toLowerCase();

        if (lowerQuery.startsWith('cari ')) {
          finalQuery = finalQuery.substring(5);
        } else if (lowerQuery.startsWith('search for ')) {
          finalQuery = finalQuery.substring(11);
        } else if (lowerQuery.startsWith('buka ')) {
          finalQuery = finalQuery.substring(5);
        }

        if (lowerQuery.contains('profil') || lowerQuery.contains('user')) {
          _tabController.animateTo(1);
        } else if (lowerQuery.contains('komunitas') ||
            lowerQuery.contains('community')) {
          _tabController.animateTo(2);
        } else {
          _tabController.animateTo(0);
        }

        _searchController.text = finalQuery;
        _searchController.selection = TextSelection.fromPosition(
          TextPosition(offset: finalQuery.length),
        );
        _onSearchChanged(finalQuery);
      },
    );
  }

  void _stopListening() {
    if (mounted) {
      _micAnimController.reverse();
      setState(() => _isListening = false);
    }
    voiceService.stopListening();
  }

  void _onSearchChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    _debounce = Timer(const Duration(milliseconds: 400), () async {
      if (!mounted) return;

      final query = value.toLowerCase().trim();
      setState(() {
        _searchText = query;
        _searchSuggestion = null;
        _updateSearchFutures(query);
      });

      if (query.isEmpty) return;

      final suggestion = await _predictionService.getLocalPrediction(value);
      if (mounted &&
          _searchText == query &&
          suggestion != null &&
          suggestion.toLowerCase() != _searchText) {
        setState(() {
          _searchSuggestion = suggestion;
        });
      }
    });
  }

  void _applySuggestion() {
    final suggestion = _searchSuggestion;
    if (suggestion == null) return;

    _searchController.text = suggestion;
    _onSearchChanged(suggestion);
    FocusScope.of(context).unfocus();
  }

  void _clearSearch() {
    setState(() {
      _resetSearchState();
    });
    if (_isListening) _stopListening();
    if (widget.isSearching) widget.onSearchPressed();
  }

  void _onTrendingTagClicked(String tag) {
    if (!widget.isSearching) widget.onSearchPressed();

    setState(() {
      _searchController.text = tag;
      _searchText = tag.toLowerCase().trim();
      _searchSuggestion = null;
      _updateSearchFutures(_searchText);
    });
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final currentUserId = _currentUserId;
    const topAnchor = 90.0;
    final searchBarHeight = SearchMenuOverlay.heightFor(
      isSearching: widget.isSearching,
      hasSuggestion: _searchSuggestion != null,
    );
    final contentTopPadding = widget.isSearching
        ? (topAnchor + searchBarHeight)
        : topAnchor;

    return PopScope(
      canPop: !widget.isSearching,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && widget.isSearching) {
          _clearSearch();
        }
      },
      child: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.only(top: contentTopPadding),
              child: _searchText.isEmpty
                  ? SearchExplorePage(
                      isListening: _isListening,
                      currentUserId: currentUserId,
                      showAllTrending: _showAllTrending,
                      showAllDiscover: _showAllDiscover,
                      showAllPeople: _showAllPeople,
                      blockedUserIds: _blockedUserIds,
                      followingIds: _followingIds,
                      trendingFuture: _trendingFuture,
                      discoverFuture: _discoverFuture,
                      communityRecFuture: _communityRecFuture,
                      peopleRecFuture: _peopleRecFuture,
                      onRefresh: () async {
                        _refreshContent();
                        await Future.delayed(const Duration(seconds: 1));
                      },
                      onTrendingTagClicked: _onTrendingTagClicked,
                      onToggleTrending: () =>
                          setState(() => _showAllTrending = !_showAllTrending),
                      onToggleDiscover: () =>
                          setState(() => _showAllDiscover = !_showAllDiscover),
                      onTogglePeople: () =>
                          setState(() => _showAllPeople = !_showAllPeople),
                      onFollowStateChanged: _handleFollowStateChanged,
                    )
                  : SearchResultsView(
                      tabController: _tabController,
                      searchText: _searchText,
                      currentUserId: currentUserId,
                      blockedUserIds: _blockedUserIds,
                      followingIds: _followingIds,
                      postSearchFuture: _postSearchFuture,
                      userSearchFuture: _userSearchFuture,
                      communitySearchFuture: _communitySearchFuture,
                      onFollowStateChanged: _handleFollowStateChanged,
                    ),
            ),
          ),
          Positioned(
            top: topAnchor,
            left: 0,
            right: 0,
            child: Align(
              alignment: Alignment.topRight,
              child: SearchMenuOverlay(
                isSearching: widget.isSearching,
                screenWidth: screenWidth,
                controller: _searchController,
                focusNode: _searchFocusNode,
                isListening: _isListening,
                suggestion: _searchSuggestion,
                micScale: _micAnimController,
                onClearSearch: _clearSearch,
                onStartListening: _startListening,
                onStopListening: _stopListening,
                onChanged: _onSearchChanged,
                onApplySuggestion: _applySuggestion,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleFollowStateChanged(String userId, bool isFollowing) {
    setState(() {
      if (isFollowing) {
        if (!_followingIds.contains(userId)) _followingIds.add(userId);
      } else {
        _followingIds.remove(userId);
      }
    });
  }
}
