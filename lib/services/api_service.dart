import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';

/// Centralized HTTP client for the SapaPNJ REST API.
/// Replaces all direct Firebase Firestore calls.
class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  String get _baseUrl => (dotenv.env['API_BASE_URL']?.isNotEmpty == true)
      ? dotenv.env['API_BASE_URL']!
      : 'https://sapapnjapi-squd7hdv6q-et.a.run.app';

  /// Get Firebase Auth ID token for authenticated requests.
  Future<String?> _getToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    return await user.getIdToken();
  }

  /// Build authorization headers.
  Future<Map<String, String>> _headers() async {
    final token = await _getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ─────────────────────────────────────────────
  // USERS
  // ─────────────────────────────────────────────

  /// Register / create user profile.
  Future<bool> createUser({
    required String uid,
    required String email,
    required String name,
    String? nim,
  }) async {
    final resp = await http.post(
      Uri.parse('$_baseUrl/api/users'),
      headers: await _headers(),
      body: jsonEncode({'uid': uid, 'email': email, 'name': name, 'nim': nim}),
    );
    debugPrint('ApiService - POST /api/users Response: ${resp.statusCode} ${resp.body}');
    if (resp.statusCode == 409) {
      throw ApiException('nim-already-in-use', 'NIM already registered');
    }
    return resp.statusCode == 201;
  }

  static final Map<String, Map<String, dynamic>> _userCache = {};
  static final Map<String, DateTime> _userCacheTime = {};

  /// Get user profile (using MySQL backend).
  Future<Map<String, dynamic>?> getUser(String uid, {bool forceRefresh = false}) async {
    final now = DateTime.now();
    if (!forceRefresh && _userCache.containsKey(uid)) {
      if (now.difference(_userCacheTime[uid]!) < const Duration(minutes: 5)) {
        return Map<String, dynamic>.from(_userCache[uid]!);
      }
    }

    final resp = await http.get(
      Uri.parse('$_baseUrl/api/users/$uid'),
      headers: await _headers(),
    );
    debugPrint('ApiService - GET /api/users/$uid Response: ${resp.statusCode} ${resp.body}');
    if (resp.statusCode == 404) return null;
    if (resp.statusCode != 200) throw _error(resp);
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    _userCache[uid] = data;
    _userCacheTime[uid] = now;
    return data;
  }

  /// Update user profile fields.
  Future<bool> updateUser(String uid, Map<String, dynamic> fields) async {
    final resp = await http.patch(
      Uri.parse('$_baseUrl/api/users/$uid'),
      headers: await _headers(),
      body: jsonEncode(fields),
    );
    debugPrint('ApiService - PATCH /api/users/$uid Response: ${resp.statusCode} ${resp.body}');
    if (resp.statusCode == 200) {
      _userCache.remove(uid);
      return true;
    }
    return false;
  }

  /// Delete user account.
  Future<bool> deleteUser(String uid) async {
    final resp = await http.delete(
      Uri.parse('$_baseUrl/api/users/$uid'),
      headers: await _headers(),
    );
    return resp.statusCode == 200;
  }

  /// Search users by query.
  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    final resp = await http.get(
      Uri.parse('$_baseUrl/api/users?q=${Uri.encodeComponent(query)}'),
      headers: await _headers(),
    );
    if (resp.statusCode != 200) return [];
    return List<Map<String, dynamic>>.from(jsonDecode(resp.body));
  }

  /// Get suggested users to follow.
  Future<List<Map<String, dynamic>>> getSuggestedUsers() async {
    final resp = await http.get(
      Uri.parse('$_baseUrl/api/users'),
      headers: await _headers(),
    );
    if (resp.statusCode != 200) return [];
    return List<Map<String, dynamic>>.from(jsonDecode(resp.body));
  }

  /// Check NIM availability.
  Future<bool> isNimAvailable(String nim) async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final resp = await http.get(
      Uri.parse('$_baseUrl/api/users/$uid/check-nim?nim=$nim'),
      headers: await _headers(),
    );
    if (resp.statusCode != 200) return false;
    return jsonDecode(resp.body)['available'] == true;
  }

  // ─────────────────────────────────────────────
  // FOLLOW
  // ─────────────────────────────────────────────

  /// Follow a user.
  Future<Map<String, dynamic>> followUser(String targetUid) async {
    final resp = await http.post(
      Uri.parse('$_baseUrl/api/users/$targetUid/follow'),
      headers: await _headers(),
    );
    if (resp.statusCode != 200) throw _error(resp);
    return jsonDecode(resp.body);
  }

  /// Unfollow a user.
  Future<bool> unfollowUser(String targetUid) async {
    final resp = await http.delete(
      Uri.parse('$_baseUrl/api/users/$targetUid/follow'),
      headers: await _headers(),
    );
    return resp.statusCode == 200;
  }

  /// Accept a follow request.
  Future<bool> acceptFollowRequest(String senderUid) async {
    final myUid = FirebaseAuth.instance.currentUser!.uid;
    final resp = await http.post(
      Uri.parse('$_baseUrl/api/users/$myUid/follow/accept'),
      headers: await _headers(),
      body: jsonEncode({'senderUid': senderUid}),
    );
    return resp.statusCode == 200;
  }

  /// Decline a follow request.
  Future<bool> declineFollowRequest(String senderUid) async {
    final myUid = FirebaseAuth.instance.currentUser!.uid;
    final resp = await http.post(
      Uri.parse('$_baseUrl/api/users/$myUid/follow/decline'),
      headers: await _headers(),
      body: jsonEncode({'senderUid': senderUid}),
    );
    return resp.statusCode == 200;
  }

  /// Remove a follower.
  Future<bool> removeFollower(String followerUid) async {
    final myUid = FirebaseAuth.instance.currentUser!.uid;
    final resp = await http.delete(
      Uri.parse('$_baseUrl/api/users/$myUid/followers/$followerUid'),
      headers: await _headers(),
    );
    return resp.statusCode == 200;
  }

  /// Send follow request (for private accounts).
  Future<bool> sendFollowRequest(String targetUid) async {
    final resp = await http.post(
      Uri.parse('$_baseUrl/api/users/$targetUid/follow-request'),
      headers: await _headers(),
    );
    return resp.statusCode == 200;
  }

  /// Cancel a pending follow request.
  Future<bool> cancelFollowRequest(String targetUid) async {
    final resp = await http.delete(
      Uri.parse('$_baseUrl/api/users/$targetUid/follow-request'),
      headers: await _headers(),
    );
    return resp.statusCode == 200;
  }

  /// Get comments made by a user (for profile replies tab).
  Future<List<Map<String, dynamic>>> getUserComments(String uid) async {
    final resp = await http.get(
      Uri.parse('$_baseUrl/api/users/$uid/comments'),
      headers: await _headers(),
    );
    if (resp.statusCode != 200) return [];
    return List<Map<String, dynamic>>.from(jsonDecode(resp.body));
  }


  /// Get follower UIDs.
  Future<List<String>> getFollowers(String uid) async {
    final resp = await http.get(
      Uri.parse('$_baseUrl/api/users/$uid/followers'),
      headers: await _headers(),
    );
    if (resp.statusCode != 200) return [];
    return List<String>.from(jsonDecode(resp.body));
  }

  /// Get following UIDs.
  Future<List<String>> getFollowing(String uid) async {
    final resp = await http.get(
      Uri.parse('$_baseUrl/api/users/$uid/following'),
      headers: await _headers(),
    );
    if (resp.statusCode != 200) return [];
    return List<String>.from(jsonDecode(resp.body));
  }

  // ─────────────────────────────────────────────
  // POSTS
  // ─────────────────────────────────────────────

  /// Get home feed.
  Future<List<Map<String, dynamic>>> getPosts({
    String? cursor,
    int limit = 20,
    String? communityId,
    String? userUid,
    String? query,
  }) async {
    final params = <String, String>{
      'limit': limit.toString(),
      if (cursor != null) 'cursor': cursor,
      if (communityId != null) 'community_id': communityId,
      if (userUid != null) 'user_uid': userUid,
      if (query != null) 'q': query,
    };
    final uri = Uri.parse('$_baseUrl/api/posts').replace(queryParameters: params);
    final resp = await http.get(uri, headers: await _headers());
    if (resp.statusCode != 200) return [];
    return List<Map<String, dynamic>>.from(jsonDecode(resp.body));
  }

  /// Get reposts by a user.
  Future<List<Map<String, dynamic>>> getReposts(String userUid) async {
    final resp = await http.get(
      Uri.parse('$_baseUrl/api/posts/reposts?user_uid=$userUid'),
      headers: await _headers(),
    );
    if (resp.statusCode != 200) return [];
    return List<Map<String, dynamic>>.from(jsonDecode(resp.body));
  }

  /// Get a single post by ID.
  Future<Map<String, dynamic>?> getPost(String postId) async {
    final resp = await http.get(
      Uri.parse('$_baseUrl/api/posts/$postId'),
      headers: await _headers(),
    );
    if (resp.statusCode == 404) return null;
    if (resp.statusCode != 200) throw _error(resp);
    return jsonDecode(resp.body);
  }

  /// Create a new post. Returns the post ID.
  Future<String> createPost({
    String? text,
    List<String>? mediaUrls,
    String? mediaType,
    String visibility = 'public',
    String? communityId,
    String? communityName,
    String? communityIcon,
    bool communityVerified = false,
    bool isCommunityIdentity = false,
    bool isRepost = false,
    String? originalPostId,
  }) async {
    final resp = await http.post(
      Uri.parse('$_baseUrl/api/posts'),
      headers: await _headers(),
      body: jsonEncode({
        'text': text,
        'media_urls': mediaUrls,
        'media_type': mediaType,
        'visibility': visibility,
        'community_id': communityId,
        'is_community_identity': isCommunityIdentity,
        'is_repost': isRepost,
        'original_post_id': originalPostId,
      }),
    );
    if (resp.statusCode != 201) throw _error(resp);
    return jsonDecode(resp.body)['id'];
  }

  /// Edit a post.
  Future<bool> updatePost(String postId, Map<String, dynamic> fields) async {
    final resp = await http.patch(
      Uri.parse('$_baseUrl/api/posts/$postId'),
      headers: await _headers(),
      body: jsonEncode(fields),
    );
    return resp.statusCode == 200;
  }

  Future<List<Map<String, dynamic>>> getTrendingTopics() async {
    final resp = await http.get(Uri.parse('$_baseUrl/api/explore/trending'), headers: await _headers());
    if (resp.statusCode != 200) throw _error(resp);
    return List<Map<String, dynamic>>.from(jsonDecode(resp.body));
  }

  Future<List<Map<String, dynamic>>> getDiscoverRecommendations() async {
    final resp = await http.get(Uri.parse('$_baseUrl/api/explore/discover'), headers: await _headers());
    if (resp.statusCode != 200) throw _error(resp);
    return List<Map<String, dynamic>>.from(jsonDecode(resp.body));
  }

  Future<List<Map<String, dynamic>>> getPersonalizedRecommendations() async {
    final resp = await http.get(Uri.parse('$_baseUrl/api/explore/recommended'), headers: await _headers());
    if (resp.statusCode != 200) throw _error(resp);
    return List<Map<String, dynamic>>.from(jsonDecode(resp.body));
  }

  Future<List<Map<String, dynamic>>> getRecommendedCommunities() async {
    final resp = await http.get(Uri.parse('$_baseUrl/api/communities/recommended'), headers: await _headers());
    if (resp.statusCode != 200) throw _error(resp);
    return List<Map<String, dynamic>>.from(jsonDecode(resp.body));
  }

  /// Delete a post.
  Future<bool> deletePost(String postId) async {
    final resp = await http.delete(
      Uri.parse('$_baseUrl/api/posts/$postId'),
      headers: await _headers(),
    );
    return resp.statusCode == 200;
  }

  /// Toggle like on a post.
  Future<bool> toggleLike(String postId) async {
    final resp = await http.post(
      Uri.parse('$_baseUrl/api/posts/$postId/like'),
      headers: await _headers(),
    );
    if (resp.statusCode != 200) throw _error(resp);
    return jsonDecode(resp.body)['liked'];
  }

  /// Get comments for a post.
  Future<List<Map<String, dynamic>>> getComments(String postId) async {
    final resp = await http.get(
      Uri.parse('$_baseUrl/api/posts/$postId/comments'),
      headers: await _headers(),
    );
    if (resp.statusCode != 200) return [];
    return List<Map<String, dynamic>>.from(jsonDecode(resp.body));
  }

  /// Add a comment. Returns comment ID.
  Future<String> addComment(String postId, {String? text, String? mediaUrl, String? mediaType}) async {
    final resp = await http.post(
      Uri.parse('$_baseUrl/api/posts/$postId/comments'),
      headers: await _headers(),
      body: jsonEncode({'text': text, 'media_url': mediaUrl, 'media_type': mediaType}),
    );
    if (resp.statusCode != 201) throw _error(resp);
    return jsonDecode(resp.body)['id'];
  }

  /// Delete a comment.
  Future<bool> deleteComment(String postId, String commentId) async {
    final resp = await http.delete(
      Uri.parse('$_baseUrl/api/posts/$postId/comments/$commentId'),
      headers: await _headers(),
    );
    return resp.statusCode == 200;
  }

  // ─────────────────────────────────────────────
  // BOOKMARKS
  // ─────────────────────────────────────────────

  /// Get bookmarked posts.
  Future<List<Map<String, dynamic>>> getBookmarks() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final resp = await http.get(
      Uri.parse('$_baseUrl/api/users/$uid/bookmarks'),
      headers: await _headers(),
    );
    if (resp.statusCode != 200) return [];
    return List<Map<String, dynamic>>.from(jsonDecode(resp.body));
  }

  /// Toggle bookmark.
  Future<bool> toggleBookmark(String postId) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final resp = await http.post(
      Uri.parse('$_baseUrl/api/users/$uid/bookmarks/$postId'),
      headers: await _headers(),
    );
    if (resp.statusCode != 200) throw _error(resp);
    return jsonDecode(resp.body)['bookmarked'];
  }

  // ─────────────────────────────────────────────
  // NOTIFICATIONS
  // ─────────────────────────────────────────────

  /// Get notifications.
  Future<List<Map<String, dynamic>>> getNotifications() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final resp = await http.get(
      Uri.parse('$_baseUrl/api/users/$uid/notifications'),
      headers: await _headers(),
    );
    if (resp.statusCode != 200) return [];
    return List<Map<String, dynamic>>.from(jsonDecode(resp.body));
  }

  /// Mark notification as read.
  Future<bool> markNotificationRead(String notifId) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final resp = await http.patch(
      Uri.parse('$_baseUrl/api/users/$uid/notifications/$notifId'),
      headers: await _headers(),
    );
    return resp.statusCode == 200;
  }

  /// Mark all notifications as read.
  Future<bool> markAllNotificationsRead() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final resp = await http.patch(
      Uri.parse('$_baseUrl/api/users/$uid/notifications'),
      headers: await _headers(),
    );
    return resp.statusCode == 200;
  }

  /// Clear all notifications (delete history).
  Future<bool> clearNotifications() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final resp = await http.delete(
      Uri.parse('$_baseUrl/api/users/$uid/notifications'),
      headers: await _headers(),
    );
    return resp.statusCode == 200;
  }

  // ─────────────────────────────────────────────
  // BLOCKED USERS
  // ─────────────────────────────────────────────

  /// Get blocked user IDs.
  Future<List<String>> getBlockedUsers() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final resp = await http.get(
      Uri.parse('$_baseUrl/api/users/$uid/blocked'),
      headers: await _headers(),
    );
    if (resp.statusCode != 200) return [];
    return List<String>.from(jsonDecode(resp.body));
  }

  /// Block a user.
  Future<bool> blockUser(String targetUid) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final resp = await http.post(
      Uri.parse('$_baseUrl/api/users/$uid/block/$targetUid'),
      headers: await _headers(),
    );
    return resp.statusCode == 200;
  }

  /// Unblock a user.
  Future<bool> unblockUser(String targetUid) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final resp = await http.delete(
      Uri.parse('$_baseUrl/api/users/$uid/block/$targetUid'),
      headers: await _headers(),
    );
    return resp.statusCode == 200;
  }

  // ─────────────────────────────────────────────
  // COMMUNITIES
  // ─────────────────────────────────────────────

  /// Browse/search communities.
  Future<List<Map<String, dynamic>>> getCommunities({String? query, String? category}) async {
    final params = <String, String>{
      if (query != null) 'q': query,
      if (category != null) 'category': category,
    };
    final uri = Uri.parse('$_baseUrl/api/communities').replace(queryParameters: params.isEmpty ? null : params);
    final resp = await http.get(uri, headers: await _headers());
    if (resp.statusCode != 200) return [];
    return List<Map<String, dynamic>>.from(jsonDecode(resp.body));
  }

  /// Get communities the current user follows.
  Future<List<Map<String, dynamic>>> getMyCommunities() async {
    final resp = await http.get(
      Uri.parse('$_baseUrl/api/communities/my'),
      headers: await _headers(),
    );
    if (resp.statusCode != 200) return [];
    return List<Map<String, dynamic>>.from(jsonDecode(resp.body));
  }

  /// Get community details.
  Future<Map<String, dynamic>?> getCommunity(String id) async {
    final resp = await http.get(
      Uri.parse('$_baseUrl/api/communities/$id'),
      headers: await _headers(),
    );
    if (resp.statusCode == 404) return null;
    if (resp.statusCode != 200) throw _error(resp);
    return jsonDecode(resp.body);
  }

  /// Create a community. Returns the community ID.
  Future<String> createCommunity({
    required String name,
    String? description,
    String category = 'casual',
    bool isVerified = false,
    String? verificationDocUrl,
    bool allowMemberPosts = false,
  }) async {
    final resp = await http.post(
      Uri.parse('$_baseUrl/api/communities'),
      headers: await _headers(),
      body: jsonEncode({
        'name': name,
        'description': description,
        'category': category,
        'is_verified': isVerified,
        'verification_doc_url': verificationDocUrl,
        'allow_member_posts': allowMemberPosts,
      }),
    );
    if (resp.statusCode != 201) throw _error(resp);
    return jsonDecode(resp.body)['id'];
  }

  /// Update community.
  Future<bool> updateCommunity(String id, Map<String, dynamic> fields) async {
    final resp = await http.patch(
      Uri.parse('$_baseUrl/api/communities/$id'),
      headers: await _headers(),
      body: jsonEncode(fields),
    );
    return resp.statusCode == 200;
  }

  /// Delete community.
  Future<bool> deleteCommunity(String id) async {
    final resp = await http.delete(
      Uri.parse('$_baseUrl/api/communities/$id'),
      headers: await _headers(),
    );
    return resp.statusCode == 200;
  }

  /// Follow a community.
  Future<bool> followCommunity(String id) async {
    final resp = await http.post(
      Uri.parse('$_baseUrl/api/communities/$id/follow'),
      headers: await _headers(),
    );
    return resp.statusCode == 200;
  }

  /// Unfollow a community.
  Future<bool> unfollowCommunity(String id) async {
    final resp = await http.delete(
      Uri.parse('$_baseUrl/api/communities/$id/follow'),
      headers: await _headers(),
    );
    return resp.statusCode == 200;
  }

  /// Get community members.
  Future<List<Map<String, dynamic>>> getCommunityMembers(String id) async {
    final resp = await http.get(
      Uri.parse('$_baseUrl/api/communities/$id/members'),
      headers: await _headers(),
    );
    if (resp.statusCode != 200) return [];
    return List<Map<String, dynamic>>.from(jsonDecode(resp.body));
  }

  /// Update member role.
  Future<bool> updateMemberRole(String communityId, String userUid, String role) async {
    final resp = await http.patch(
      Uri.parse('$_baseUrl/api/communities/$communityId/members/$userUid'),
      headers: await _headers(),
      body: jsonEncode({'role': role}),
    );
    return resp.statusCode == 200;
  }

  /// Remove community member.
  Future<bool> removeCommunityMember(String communityId, String userUid) async {
    final resp = await http.delete(
      Uri.parse('$_baseUrl/api/communities/$communityId/members/$userUid'),
      headers: await _headers(),
    );
    return resp.statusCode == 200;
  }

  // ─────────────────────────────────────────────
  // AI CHAT SESSIONS
  // ─────────────────────────────────────────────

  /// Get chat sessions.
  Future<List<Map<String, dynamic>>> getChatSessions() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final resp = await http.get(
      Uri.parse('$_baseUrl/api/users/$uid/chat-sessions'),
      headers: await _headers(),
    );
    if (resp.statusCode != 200) return [];
    return List<Map<String, dynamic>>.from(jsonDecode(resp.body));
  }

  /// Create a chat session. Returns session ID.
  Future<String> createChatSession({String? title}) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final resp = await http.post(
      Uri.parse('$_baseUrl/api/users/$uid/chat-sessions'),
      headers: await _headers(),
      body: jsonEncode({'title': title ?? 'New Conversation'}),
    );
    if (resp.statusCode != 201) throw _error(resp);
    return jsonDecode(resp.body)['id'];
  }

  /// Delete a chat session.
  Future<bool> deleteChatSession(String sessionId) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final resp = await http.delete(
      Uri.parse('$_baseUrl/api/users/$uid/chat-sessions/$sessionId'),
      headers: await _headers(),
    );
    return resp.statusCode == 200;
  }

  /// Get chat messages for a session.
  Future<List<Map<String, dynamic>>> getChatMessages(String sessionId) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final resp = await http.get(
      Uri.parse('$_baseUrl/api/users/$uid/chat-sessions/$sessionId/messages'),
      headers: await _headers(),
    );
    if (resp.statusCode != 200) return [];
    return List<Map<String, dynamic>>.from(jsonDecode(resp.body));
  }

  /// Save message in a chat session.
  Future<bool> saveChatMessage(String sessionId, {required String text, required bool isUser}) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final resp = await http.post(
      Uri.parse('$_baseUrl/api/users/$uid/chat-sessions/$sessionId/messages'),
      headers: await _headers(),
      body: jsonEncode({'text': text, 'isUser': isUser}),
    );
    return resp.statusCode == 201;
  }

  // ─────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────

  Exception _error(http.Response resp) {
    try {
      final body = jsonDecode(resp.body);
      return ApiException(resp.statusCode.toString(), body['error'] ?? 'Unknown error');
    } catch (_) {
      return ApiException(resp.statusCode.toString(), resp.body);
    }
  }
}

/// Custom API exception with code for matching Firestore-style error handling.
class ApiException implements Exception {
  final String code;
  final String message;
  ApiException(this.code, this.message);

  @override
  String toString() => 'ApiException($code): $message';
}
