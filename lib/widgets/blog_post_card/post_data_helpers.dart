String? postAuthorId(Map<String, dynamic> postData) {
  final id = postData['userId'] ?? postData['user_uid'] ?? postData['user_id'];
  return id?.toString();
}

String? postCommunityId(Map<String, dynamic> postData) {
  final id = postData['communityId'] ?? postData['community_id'];
  return id?.toString();
}

String? postOriginalId(Map<String, dynamic> postData) {
  final id = postData['originalPostId'] ?? postData['original_post_id'];
  return id?.toString();
}

bool isRepostPost(Map<String, dynamic> postData) {
  return postData['type'] == 'repost' ||
      postData['is_repost'] == true ||
      postData['is_repost'] == 1 ||
      postOriginalId(postData) != null;
}

List<String> postMediaUrls(Map<String, dynamic> postData) {
  if (postData['mediaUrls'] != null) {
    return List<String>.from(postData['mediaUrls']);
  }
  if (postData['media_urls'] != null) {
    return List<String>.from(postData['media_urls']);
  }
  if (postData['mediaUrl'] != null) {
    return [postData['mediaUrl'].toString()];
  }
  if (postData['media_url'] != null) {
    return [postData['media_url'].toString()];
  }
  return const [];
}

String? primaryPostMediaUrl(Map<String, dynamic> postData) {
  final mediaUrls = postMediaUrls(postData);
  return mediaUrls.isNotEmpty ? mediaUrls.first : null;
}
