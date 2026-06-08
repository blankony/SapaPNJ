import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_compress/video_compress.dart';

import '../../../services/api_service.dart';
import '../../../services/draft_service.dart';
import '../../../services/gcs_service.dart';
import '../../../theme/app_theme.dart';

class BackgroundUploader {
  static void startUploadSequence({
    required OverlayState overlayState,
    required String text,
    required List<File> filesToUpload,
    required List<String> existingMediaUrls,
    String? mediaType,
    required String visibility,
    required bool isEditing,
    String? postId,
    required String uid,
    required String userName,
    required String userEmail,
    required int avatarIconId,
    required String avatarHex,
    required String? profileImageUrl,
    required String? communityId,
    String? communityName,
    String? communityIcon,
    bool? communityVerified,
    bool isCommunityIdentity = false,
    String? draftIdToDelete,
    required Map<String, String> localizedStrings,
  }) {
    final overlayKey = GlobalKey<_PostUploadOverlayState>();
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => _PostUploadOverlay(
        key: overlayKey,
        onDismissRequest: () {
          overlayKey.currentState?.dismissToIcon();
        },
        initialMessage: localizedStrings['uploading'] ?? 'Uploading...',
      ),
    );

    overlayState.insert(overlayEntry);

    _processUpload(
      text,
      filesToUpload,
      existingMediaUrls,
      mediaType,
      visibility,
      isEditing,
      postId,
      uid,
      userName,
      userEmail,
      avatarIconId,
      avatarHex,
      profileImageUrl,
      communityId,
      communityName,
      communityIcon,
      communityVerified,
      isCommunityIdentity,
      draftIdToDelete,
      localizedStrings,
      (status) => overlayKey.currentState?.updateStatus(status),
      () {
        overlayKey.currentState?.handleSuccess(
          localizedStrings['posted'] ?? 'Posted',
        );
        Future.delayed(const Duration(seconds: 7), () {
          if (overlayEntry.mounted) overlayEntry.remove();
        });
      },
      (error) {
        overlayKey.currentState?.handleFailure(
          localizedStrings['failed'] ?? 'Failed',
        );
        Future.delayed(const Duration(seconds: 4), () {
          if (overlayEntry.mounted) overlayEntry.remove();
        });
      },
    );
  }

  static Future<void> _processUpload(
    String text,
    List<File> files,
    List<String> urls,
    String? type,
    String vis,
    bool edit,
    String? pid,
    String uid,
    String uName,
    String uEmail,
    int icon,
    String hex,
    String? img,
    String? comId,
    String? comName,
    String? comIcon,
    bool? comVerified,
    bool isCommunityIdentity,
    String? draftId,
    Map<String, String> locStrings,
    Function(String) onProgress,
    VoidCallback onSuccess,
    Function(dynamic) onFailure,
  ) async {
    try {
      final finalUrls = [...urls];
      if (files.isNotEmpty) {
        var count = 1;
        for (var file in files) {
          final msg = locStrings['uploading'] ?? 'Uploading...';
          onProgress('$msg ($count/${files.length})');

          var fileToUpload = file;
          if (type == 'video') {
            try {
              final info = await VideoCompress.compressVideo(
                file.path,
                quality: VideoQuality.MediumQuality,
                deleteOrigin: false,
              );
              if (info != null && info.file != null) fileToUpload = info.file!;
            } catch (e) {
              // Upload the original video if compression is unavailable.
            }
          }

          final url = await GcsService().uploadMedia(fileToUpload);
          if (url != null) {
            finalUrls.add(url);
          } else {
            onFailure(
              locStrings['uploading_error'] ??
                  'Failed to upload media. Please check your internet connection.',
            );
            return;
          }
          count++;
        }
      }

      if (finalUrls.isEmpty && text.isEmpty) {
        onFailure(locStrings['no_content'] ?? 'No content');
        return;
      }

      final api = ApiService();

      if (edit && pid != null) {
        await api.updatePost(pid, {
          'text': text,
          'media_urls': finalUrls,
          'visibility': vis,
        });
      } else {
        await api.createPost(
          text: text,
          mediaUrls: finalUrls.isNotEmpty ? finalUrls : null,
          mediaType: type,
          visibility: vis,
          communityId: comId,
          communityName: comName,
          communityIcon: comIcon,
          communityVerified: comVerified ?? false,
          isCommunityIdentity: isCommunityIdentity,
        );

        if (draftId != null) {
          await DraftService().discardDraftAfterPosting(draftId);
        }
      }

      if (type == 'video') await VideoCompress.deleteAllCache();
      onSuccess();
    } catch (e) {
      onFailure(e);
    }
  }
}

class _PostUploadOverlay extends StatefulWidget {
  final VoidCallback onDismissRequest;
  final String initialMessage;

  const _PostUploadOverlay({
    super.key,
    required this.onDismissRequest,
    required this.initialMessage,
  });

  @override
  State<_PostUploadOverlay> createState() => _PostUploadOverlayState();
}

class _PostUploadOverlayState extends State<_PostUploadOverlay> {
  bool _isCardVisible = true;
  bool _isMiniVisible = false;
  bool _isSuccess = false;
  bool _isError = false;
  bool _dismissedBySwipe = false;
  late String _message;
  Timer? _autoDismissTimer;

  @override
  void initState() {
    super.initState();
    _message = widget.initialMessage;
  }

  double get _targetTop => MediaQuery.of(context).padding.top + 10;

  double get _targetRight => 12.0;

  double get _miniRight => 60.0;

  @override
  void dispose() {
    _autoDismissTimer?.cancel();
    super.dispose();
  }

  void updateStatus(String status) {
    if (!mounted) return;
    setState(() => _message = status);
  }

  void dismissToIcon() {
    setState(() => _isCardVisible = false);
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) setState(() => _isMiniVisible = true);
    });
  }

  void _expandToCard() {
    setState(() {
      _isMiniVisible = false;
    });
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _isCardVisible = true;
          _dismissedBySwipe = false;
        });
        _autoDismissTimer?.cancel();
        _autoDismissTimer = Timer(const Duration(seconds: 2), dismissToIcon);
      }
    });
  }

  void handleSuccess(String msg) {
    setState(() {
      _isSuccess = true;
      _message = msg;
    });
    if (_isMiniVisible) {
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted) setState(() => _isMiniVisible = false);
      });
    } else if (_isCardVisible) {
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted) setState(() => _isCardVisible = false);
      });
    }
  }

  void handleFailure(String msg) {
    setState(() {
      _isError = true;
      _message = msg;
    });
    if (!_isCardVisible) setState(() => _isCardVisible = true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Stack(
      children: [
        AnimatedPositioned(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutQuart,
          top: _targetTop,
          right: _isMiniVisible ? _miniRight : _targetRight,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 300),
            opacity: _isMiniVisible ? 1.0 : 0.0,
            child: GestureDetector(
              onTap: _expandToCard,
              child: Material(
                elevation: 4,
                shape: const CircleBorder(),
                color: _isSuccess ? Colors.green : theme.cardColor,
                child: Container(
                  width: 36,
                  height: 36,
                  padding: const EdgeInsets.all(8),
                  child: _isSuccess
                      ? const Icon(Icons.check, size: 20, color: Colors.white)
                      : const CircularProgressIndicator(
                          strokeWidth: 3,
                          color: SisapaTheme.blue,
                        ),
                ),
              ),
            ),
          ),
        ),
        AnimatedPositioned(
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOutBack,
          top: _isCardVisible ? _targetTop : -100,
          left: 16,
          right: _targetRight,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 300),
            opacity: _isCardVisible ? 1.0 : 0.0,
            child: _dismissedBySwipe
                ? const SizedBox.shrink()
                : Dismissible(
                    key: const ValueKey('upload_card_dismiss'),
                    direction: DismissDirection.horizontal,
                    onDismissed: (_) {
                      setState(() => _dismissedBySwipe = true);
                      widget.onDismissRequest();
                    },
                    child: Material(
                      elevation: 8,
                      borderRadius: BorderRadius.circular(12),
                      color: theme.cardColor,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            if (_isSuccess)
                              const Icon(
                                Icons.check_circle,
                                color: SisapaTheme.blue,
                              )
                            else if (_isError)
                              const Icon(Icons.error, color: Colors.red)
                            else
                              const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _message,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: theme.textTheme.bodyLarge?.color,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}
