import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/api_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import '../widgets/blog_post_card.dart';
import '../widgets/comment_tile.dart';
import '../widgets/common_error_widget.dart'; // REQUIRED
import '../services/prediction_service.dart';
import '../services/gcs_service.dart';
import '../theme/app_theme.dart';
import '../services/overlay_service.dart';

final GcsService _cloudinaryService = GcsService();
final ApiService _apiService = ApiService();

class PostDetailScreen extends StatefulWidget {
  final String postId;
  final Map<String, dynamic>? initialPostData;
  final String heroContextId;
  final VideoPlayerController? preloadedController;

  const PostDetailScreen({
    super.key,
    required this.postId,
    this.initialPostData,
    this.heroContextId = 'feed',
    this.preloadedController,
  });

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final TextEditingController _commentController = TextEditingController();
  final PredictionService _predictionService = PredictionService();
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  String? _predictedText;
  Timer? _debounce;
  bool _isSending = false;
  File? _selectedMediaFile;
  String? _mediaType;

  late Future<Map<String, dynamic>?> _postFuture;
  late Future<List<Map<String, dynamic>>> _commentsFuture;

  @override
  void initState() {
    super.initState();
    _postFuture = _apiService.getPost(widget.postId);
    _commentsFuture = _apiService.getComments(widget.postId);
  }

  void _refreshComments() {
    setState(() {
      _commentsFuture = _apiService.getComments(widget.postId);
    });
  }

  void _onCommentChanged(String text) {
    if (_predictedText != null) {
      setState(() {
        _predictedText = null;
      });
    }
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      if (text.trim().isEmpty) return;
      final suggestion = await _predictionService.getLocalPrediction(text);
      if (mounted && suggestion != null && suggestion.isNotEmpty) {
        setState(() {
          _predictedText = suggestion;
        });
      }
    });
  }

  void _acceptPrediction() {
    if (_predictedText != null) {
      final currentText = _commentController.text;
      final separator = currentText.endsWith(' ') ? '' : ' ';
      final newText = "$currentText$separator$_predictedText ";
      _commentController.text = newText;
      _commentController.selection = TextSelection.fromPosition(
        TextPosition(offset: newText.length),
      );
      setState(() {
        _predictedText = null;
      });
      _onCommentChanged(newText);
    }
  }

  Future<void> _pickMedia(ImageSource source, {bool isVideo = false}) async {
    final picker = ImagePicker();
    XFile? pickedFile;
    try {
      if (isVideo) {
        pickedFile = await picker.pickVideo(source: source);
        if (pickedFile != null) {
          setState(() {
            _selectedMediaFile = File(pickedFile!.path);
            _mediaType = 'video';
          });
        }
      } else {
        pickedFile = await picker.pickImage(
          maxWidth: 1920,
          maxHeight: 1920,
          source: source,
          imageQuality: 70,
        );
        if (pickedFile != null) {
          setState(() {
            _selectedMediaFile = File(pickedFile!.path);
            _mediaType = 'image';
          });
        }
      }
    } catch (e) {
      debugPrint("Error picking media: $e");
    }
  }

  void _clearMedia() {
    setState(() {
      _selectedMediaFile = null;
      _mediaType = null;
    });
  }

  Future<void> _postComment() async {
    if ((_commentController.text.trim().isEmpty &&
            _selectedMediaFile == null) ||
        _currentUser == null ||
        _isSending)
      return;
    setState(() {
      _isSending = true;
    });

    String? mediaUrl;
    if (_selectedMediaFile != null) {
      mediaUrl = await _cloudinaryService.uploadMedia(_selectedMediaFile!);
      if (mediaUrl == null) {
        if (mounted) {
          OverlayService().showTopNotification(
            context,
            "Media upload failed",
            Icons.cloud_off,
            () {},
            color: Colors.red,
          );
          setState(() {
            _isSending = false;
          });
        }
        return;
      }
    }

    try {
      await _apiService.addComment(
        widget.postId,
        text: _commentController.text.trim(),
        mediaUrl: mediaUrl,
        mediaType: _mediaType,
      );

      if (mounted) {
        _commentController.clear();
        _clearMedia();
        _predictedText = null;
        _isSending = false;
        _refreshComments();
        FocusScope.of(context).unfocus();
      }
    } catch (e) {
      if (mounted) {
        OverlayService().showTopNotification(
          context,
          "Failed to reply",
          Icons.error,
          () {},
          color: Colors.red,
        );
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: FrostedAppBar(title: Text("Post")),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  FutureBuilder<Map<String, dynamic>?>(
                    future: _postFuture,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: CommonErrorWidget(
                            message:
                                "Failed to load post. It may have been deleted.",
                            isConnectionError: true,
                          ),
                        );
                      }

                      if (snapshot.connectionState == ConnectionState.waiting &&
                          widget.initialPostData == null) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }

                      Map<String, dynamic>? data = snapshot.hasData
                          ? snapshot.data
                          : widget.initialPostData;

                      if (data == null) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Text("Post not found or has been deleted."),
                          ),
                        );
                      }

                      return BlogPostCard(
                        postId: widget.postId,
                        postData: data,
                        isOwner:
                            (data['user_uid'] ?? data['userId']) ==
                            _currentUser?.uid,
                        isClickable: false,
                        isDetailView: true,
                        heroContextId: widget.heroContextId,
                        preloadedController: widget.preloadedController,
                      );
                    },
                  ),
                  _buildCommentList(),
                ],
              ),
            ),
          ),
          _buildCommentInput(),
        ],
      ),
    );
  }

  Widget _buildCommentList() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _commentsFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError)
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              "Could not load comments.",
              style: TextStyle(color: Colors.red),
            ),
          );
        if (snapshot.connectionState == ConnectionState.waiting)
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Center(child: CircularProgressIndicator()),
          );
        if (!snapshot.hasData || snapshot.data!.isEmpty)
          return Padding(
            padding: const EdgeInsets.all(32.0),
            child: Center(
              child: Text(
                "No replies yet. Be the first!",
                style: TextStyle(color: Colors.grey),
              ),
            ),
          );

        final docs = snapshot.data!;
        return ListView.builder(
          itemCount: docs.length,
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          itemBuilder: (context, index) {
            final data = docs[index];
            final bool isLast = index == docs.length - 1;

            return CommentTile(
              commentId: data['id'] ?? '',
              commentData: data,
              postId: widget.postId,
              isOwner:
                  (data['user_uid'] ?? data['userId']) == _currentUser?.uid,
              heroContextId: '${widget.heroContextId}_comments',
              isLast: isLast,
            );
          },
        );
      },
    );
  }

  Widget _buildCommentInput() {
    return _CommentComposer(
      controller: _commentController,
      predictedText: _predictedText,
      selectedMediaFile: _selectedMediaFile,
      mediaType: _mediaType,
      isSending: _isSending,
      onChanged: _onCommentChanged,
      onAcceptPrediction: _acceptPrediction,
      onPickMedia: () => _pickMedia(ImageSource.gallery),
      onClearMedia: _clearMedia,
      onPostComment: _postComment,
    );
  }
}

class _CommentComposer extends StatelessWidget {
  final TextEditingController controller;
  final String? predictedText;
  final File? selectedMediaFile;
  final String? mediaType;
  final bool isSending;
  final ValueChanged<String> onChanged;
  final VoidCallback onAcceptPrediction;
  final VoidCallback onPickMedia;
  final VoidCallback onClearMedia;
  final VoidCallback onPostComment;

  const _CommentComposer({
    required this.controller,
    required this.predictedText,
    required this.selectedMediaFile,
    required this.mediaType,
    required this.isSending,
    required this.onChanged,
    required this.onAcceptPrediction,
    required this.onPickMedia,
    required this.onClearMedia,
    required this.onPostComment,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final safeBottom = MediaQuery.paddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: keyboardInset),
      child: Container(
        padding: EdgeInsets.only(
          left: 12.0,
          right: 12.0,
          bottom: safeBottom + 12.0,
          top: 12.0,
        ),
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          border: Border(top: BorderSide(color: theme.dividerColor)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (predictedText != null)
              GestureDetector(
                onTap: onAcceptPrediction,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  margin: EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: SisapaTheme.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.auto_awesome,
                        size: 14,
                        color: SisapaTheme.blue,
                      ),
                      SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          "Suggested: ...$predictedText",
                          style: TextStyle(
                            color: SisapaTheme.blue,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            if (selectedMediaFile != null)
              Container(
                margin: EdgeInsets.only(bottom: 10),
                height: 100,
                width: 100,
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: mediaType == 'video'
                          ? Container(
                              color: Colors.black,
                              child: Center(
                                child: Icon(
                                  Icons.videocam,
                                  color: Colors.white,
                                ),
                              ),
                            )
                          : Image.file(
                              selectedMediaFile!,
                              fit: BoxFit.cover,
                              width: 100,
                              height: 100,
                            ),
                    ),
                    Positioned(
                      top: 2,
                      right: 2,
                      child: GestureDetector(
                        onTap: onClearMedia,
                        child: CircleAvatar(
                          radius: 10,
                          backgroundColor: Colors.black54,
                          child: Icon(
                            Icons.close,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                IconButton(
                  onPressed: onPickMedia,
                  icon: Icon(
                    Icons.add_photo_alternate_outlined,
                    color: SisapaTheme.blue,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(minWidth: 40, minHeight: 40),
                ),
                Expanded(
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: theme.brightness == Brightness.dark
                          ? SisapaTheme.darkGrey.withOpacity(0.2)
                          : SisapaTheme.extraLightGrey,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: TextField(
                      controller: controller,
                      onChanged: onChanged,
                      decoration: InputDecoration(
                        hintText: "Post your reply",
                        hintStyle: TextStyle(color: theme.hintColor),
                        filled: false,
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 4),
                      ),
                      maxLines: 4,
                      minLines: 1,
                    ),
                  ),
                ),
                SizedBox(width: 8),
                isSending
                    ? Padding(
                        padding: const EdgeInsets.all(10.0),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : Container(
                        decoration: BoxDecoration(
                          color: SisapaTheme.blue,
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          onPressed: onPostComment,
                          icon: Icon(
                            Icons.send_rounded,
                            size: 20,
                            color: Colors.white,
                          ),
                          padding: EdgeInsets.all(10),
                          constraints: BoxConstraints(),
                        ),
                      ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
