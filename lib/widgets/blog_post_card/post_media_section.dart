import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'post_media_preview.dart';

class PostMediaSection extends StatelessWidget {
  final List<String> mediaUrls;
  final String? mediaType;
  final String text;
  final Map<String, dynamic> postData;
  final String postId;
  final String heroContextId;
  final VideoPlayerController? videoController;
  final bool isDetailView;
  final bool isVideoInitialized;
  final bool isVideoLoading;
  final VoidCallback onInitializeVideo;

  const PostMediaSection({
    super.key,
    required this.mediaUrls,
    required this.mediaType,
    required this.text,
    required this.postData,
    required this.postId,
    required this.heroContextId,
    required this.videoController,
    required this.isDetailView,
    required this.isVideoInitialized,
    required this.isVideoLoading,
    required this.onInitializeVideo,
  });

  bool get _hasRenderableContent {
    return mediaUrls.isNotEmpty || (text.contains('http') && !isDetailView);
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasRenderableContent) {
      return const SizedBox.shrink();
    }

    if (mediaType == 'video' && !isVideoInitialized) {
      return GestureDetector(
        onTap: onInitializeVideo,
        child: Stack(
          alignment: Alignment.center,
          children: [
            PostMediaPreview(
              mediaUrls: mediaUrls,
              mediaType: mediaType,
              text: text,
              postData: postData,
              postId: postId,
              heroContextId: heroContextId,
              videoController: null,
            ),
            Container(
              color: Colors.black26,
              child: Center(
                child: isVideoLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Icon(
                        Icons.play_circle_fill,
                        size: 64,
                        color: Colors.white70,
                      ),
              ),
            ),
          ],
        ),
      );
    }

    return PostMediaPreview(
      mediaUrls: mediaUrls,
      mediaType: mediaType,
      text: text,
      postData: postData,
      postId: postId,
      heroContextId: heroContextId,
      videoController: videoController,
    );
  }
}
