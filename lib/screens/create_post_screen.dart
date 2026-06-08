import 'dart:async';
import '../services/app_cache_manager.dart';

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/api_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_compress/video_compress.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:badword_guard/badword_guard.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:image_cropper/image_cropper.dart';
import '../theme/app_theme.dart';
import '../theme/avatar_helper.dart';
import '../services/prediction_service.dart';
import '../services/gcs_service.dart';
import '../widgets/create_post_action_toolbar.dart';
import '../services/overlay_service.dart';
import '../services/draft_service.dart';
import '../services/bad_word_service.dart';
import 'create_post/background_uploader.dart';
import '../widgets/media_preview_item.dart';
import 'video_trimmer_screen.dart';
import '../services/app_localizations.dart';

final GcsService _cloudinaryService = GcsService();

class CreatePostScreen extends StatefulWidget {
  final String? postId;
  final Map<String, dynamic>? initialData;
  final DraftPost? draftData;

  const CreatePostScreen({
    super.key,
    this.postId,
    this.initialData,
    this.draftData,
  });

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final TextEditingController _postController = TextEditingController();
  final PredictionService _predictionService = PredictionService();
  final DraftService _draftService = DraftService();
  final FocusNode _postFocusNode = FocusNode();

  final LanguageChecker _badwordGuard = LanguageChecker();
  final BadWordService _badWordService = BadWordService();

  List<String> _customBadWords = [];

  bool _canPost = false;
  bool _isProcessing = false;
  String _scanStatus =
      'none'; // State for scan status: 'loading', 'success', 'none'
  bool _isSavingDraft = false;

  String _visibility = 'public';
  bool _isAccountPrivate = false;

  String _myUserName = 'Anonymous';
  String _myUserEmail = '';
  String? _myAvatarUrl;
  int _myAvatarIconId = 0;
  String _myAvatarHex = '';

  String? _communityId;
  String? _communityName;
  String? _communityIcon;
  bool _communityVerified = false;

  bool _isCommunityContext = false;
  bool _hasOfficialAuthority = false;
  bool _postAsCommunity = false;
  bool _isRestricted = false;

  String? _predictedText;
  Timer? _debounce;

  List<File> _selectedMediaFiles = [];
  List<String> _existingMediaUrls = [];
  List<String> _existingPublicIds = [];
  String? _mediaType;

  String? _currentDraftId;
  String _initialText = '';
  List<String> _initialMediaUrls = [];

  bool get _isEditing => widget.postId != null;

  @override
  void initState() {
    super.initState();
    _checkEmailVerification();
    _loadIdentity();
    _trainAiModel();
    _loadBadWords();

    if (widget.initialData != null && _isEditing) {
      _initFromPublishedPost();
    } else if (widget.draftData != null) {
      _initFromDraft(widget.draftData!);
    } else if (widget.initialData != null) {
      _communityId = widget.initialData!['communityId'];
      _communityName = widget.initialData!['communityName'];
      _communityIcon = widget.initialData!['communityIcon'];
    }
  }

  Future<void> _loadBadWords() async {
    try {
      final words = await _badWordService.fetchBadWords();
      if (mounted) {
        setState(() {
          _customBadWords = words;
        });
      }
    } catch (e) {
      debugPrint("Failed to load bad words: $e");
    }
  }

  void _initFromPublishedPost() {
    _postController.text = widget.initialData!['text'] ?? '';
    _mediaType = widget.initialData!['mediaType'];
    _visibility = widget.initialData!['visibility'] ?? 'public';

    if (widget.initialData!['mediaUrls'] != null) {
      _existingMediaUrls = List<String>.from(widget.initialData!['mediaUrls']);
    } else if (widget.initialData!['mediaUrl'] != null) {
      _existingMediaUrls = [widget.initialData!['mediaUrl']];
    }
    _checkCanPost();
  }

  void _initFromDraft(DraftPost draft) {
    _currentDraftId = draft.id;
    _postController.text = draft.text;
    _mediaType = draft.mediaType;
    _visibility = draft.visibility;
    _existingMediaUrls = List<String>.from(draft.mediaUrls);
    _existingPublicIds = List<String>.from(draft.publicIds);
    _initialText = draft.text;
    _initialMediaUrls = List<String>.from(draft.mediaUrls);

    if (draft.communityId != null) {
      _communityId = draft.communityId;
      _communityName = draft.communityName;
      _communityIcon = draft.communityIcon;
      _isCommunityContext = true;
    }
    _checkCanPost();
  }

  bool _hasChanges() {
    bool textChanged = _postController.text.trim() != _initialText.trim();
    bool mediaChanged =
        _selectedMediaFiles.isNotEmpty ||
        _existingMediaUrls.length != _initialMediaUrls.length;
    return textChanged || mediaChanged;
  }

  Future<void> _checkEmailVerification() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await user.reload();
      } catch (_) {}
      if (!user.emailVerified) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          var t = AppLocalizations.of(context)!;
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => FrostedAlertDialog(
              title: Row(
                children: [
                  Icon(Icons.mark_email_unread, color: Colors.orange),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      t.translate('verify_required'),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              content: Text(t.translate('verify_email_msg')),
              actions: [
                TextButton(
                  onPressed: () {
                    user.sendEmailVerification();
                    Navigator.pop(context);
                    Navigator.pop(context);
                    OverlayService().showTopNotification(
                      context,
                      t.translate('post_verify_sent'),
                      Icons.check,
                      () {},
                    );
                  },
                  child: Text(t.translate('verify_resend')),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pop(context);
                  },
                  child: Text(t.translate('general_close')),
                ),
              ],
            ),
          );
        });
      }
    }
  }

  Future<void> _loadIdentity() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final api = ApiService();

    try {
      final data = await api.getUser(user.uid);
      if (data != null && mounted) {
        setState(() {
          _myUserName = data['name'] ?? 'User';
          _myUserEmail = user.email ?? '';
          _myAvatarIconId = data['avatar_icon_id'] ?? 0;
          _myAvatarHex = data['avatar_hex'] ?? '';
          _myAvatarUrl = data['profile_image_url'];
          _isAccountPrivate =
              data['is_private'] == true ||
              data['is_private'] == 1 ||
              data['isPrivate'] == true ||
              data['isPrivate'] == 1;
        });
      }
    } catch (_) {}

    if (_communityId != null) {
      _isCommunityContext = true;
      _visibility = 'public';
      try {
        final data = await api.getCommunity(_communityId!);
        if (data != null) {
          _communityVerified =
              data['is_verified'] == true ||
              data['is_verified'] == 1 ||
              data['isVerified'] == true ||
              data['isVerified'] == 1;
          final bool allowMembers =
              data['allow_member_posts'] == true ||
              data['allow_member_posts'] == 1 ||
              data['allowMemberPosts'] == true ||
              data['allowMemberPosts'] == 1;
          final String ownerId = data['owner_uid'] ?? '';
          final List admins = data['admins'] ?? [];
          final List editors = data['editors'] ?? [];
          final bool isStaff =
              ownerId == user.uid ||
              admins.contains(user.uid) ||
              editors.contains(user.uid);

          if (mounted) {
            setState(() {
              _hasOfficialAuthority = isStaff;
              _postAsCommunity = isStaff;
              _communityName = data['name'];
              _communityIcon = data['image_url'];
            });
          }

          if (!allowMembers && !isStaff) {
            if (mounted) {
              setState(() => _isRestricted = true);
              var t = AppLocalizations.of(context)!;
              OverlayService().showTopNotification(
                context,
                t.translate('post_restricted_admin'),
                Icons.lock,
                () {},
                color: Colors.red,
              );
              Navigator.pop(context);
            }
          }
        }
      } catch (e) {
        debugPrint("Error checking community permissions: $e");
      }
    } else if (!_isEditing && widget.draftData == null) {
      if (mounted)
        setState(() {
          _visibility = _isAccountPrivate ? 'followers' : 'public';
        });
    }
  }

  void _checkCanPost() {
    final textNotEmpty = _postController.text.trim().isNotEmpty;
    final hasMedia =
        _selectedMediaFiles.isNotEmpty || _existingMediaUrls.isNotEmpty;
    setState(() => _canPost = textNotEmpty || hasMedia);
  }

  Future<void> _trainAiModel() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final posts = await ApiService().getPosts(userUid: user.uid, limit: 20);
      List<String> postHistory = posts
          .map((p) => (p['text'] ?? '').toString())
          .toList();
      _predictionService.learnFromUserPosts(postHistory);
    } catch (_) {}
  }

  // --- CEK IMAGE SAFETY (UPDATED) ---
  Future<bool> _checkImageSafety() async {
    if (_mediaType != 'image' || _selectedMediaFiles.isEmpty) return true;

    // START LOADING
    setState(() {
      _isProcessing = true;
      _scanStatus = 'loading';
    });

    var t = AppLocalizations.of(context)!;

    try {
      final apiKey = dotenv.env['GEMINI_API_KEY'];
      if (apiKey == null || apiKey.isEmpty) {
        debugPrint("API Key missing, skipping visual check.");
        setState(() => _isProcessing = false);
        return true;
      }

      final model = GenerativeModel(
        model: 'gemini-2.5-flash',
        apiKey: apiKey,
        safetySettings: [
          SafetySetting(HarmCategory.harassment, HarmBlockThreshold.medium),
          SafetySetting(HarmCategory.hateSpeech, HarmBlockThreshold.medium),
          SafetySetting(
            HarmCategory.sexuallyExplicit,
            HarmBlockThreshold.medium,
          ),
          SafetySetting(
            HarmCategory.dangerousContent,
            HarmBlockThreshold.medium,
          ),
        ],
      );

      int limit = _selectedMediaFiles.length > 3
          ? 3
          : _selectedMediaFiles.length;

      for (int i = 0; i < limit; i++) {
        final File imageFile = _selectedMediaFiles[i];
        final Uint8List imageBytes = await imageFile.readAsBytes();

        String mimeType = 'image/jpeg';
        if (imageFile.path.toLowerCase().endsWith('.png')) {
          mimeType = 'image/png';
        } else if (imageFile.path.toLowerCase().endsWith('.webp')) {
          mimeType = 'image/webp';
        }

        final promptText =
            "Deskripsikan objek utama gambar ini dengan sangat singkat (max 1 kalimat).";

        final content = [
          Content.multi([TextPart(promptText), DataPart(mimeType, imageBytes)]),
        ];

        try {
          final response = await model.generateContent(content);

          if (response.text != null && response.text!.isNotEmpty) {
            continue; // Safe
          } else {
            // UNSAFE: Matikan loading segera dan tampilkan popup
            if (mounted) {
              setState(() => _isProcessing = false);
              _showRejectDialog(t.translate('post_sensitive_content'));
            }
            return false;
          }
        } catch (e) {
          // ERROR/BLOCKED: Matikan loading segera dan tampilkan popup
          if (mounted) {
            setState(() => _isProcessing = false);
            _showRejectDialog(t.translate('post_sensitive_content'));
          }
          return false;
        }
      }

      // --- ALL SAFE: Show Checkmark Animation ---
      if (mounted) {
        setState(() => _scanStatus = 'success');
      }

      // Delay agar user melihat checkmark
      await Future.delayed(const Duration(milliseconds: 1200));

      if (mounted) {
        setState(() => _isProcessing = false);
      }
      return true;
    } catch (e) {
      debugPrint("System Error in Image Check: $e");
      // System error (network etc) -> Fail open (allow) or closed? Usually fail open for user exp.
      if (mounted) setState(() => _isProcessing = false);
      return true;
    }
  }

  // --- CEK TEKS ---
  bool _checkTextForBadWords(String text, {bool silent = false}) {
    if (_badwordGuard.containsBadLanguage(text)) {
      if (!silent) {
        var t = AppLocalizations.of(context)!;
        _showRejectDialog(t.translate('post_bad_words'));
      }
      return true;
    }

    final lowerText = text.toLowerCase();
    for (var badWord in _customBadWords) {
      final cleanWord = badWord.trim();
      if (cleanWord.isEmpty) continue;

      if (lowerText == cleanWord ||
          lowerText.contains(" $cleanWord ") ||
          lowerText.startsWith("$cleanWord ") ||
          lowerText.endsWith(" $cleanWord")) {
        if (!silent) {
          var t = AppLocalizations.of(context)!;
          _showRejectDialog("${t.translate('post_bad_words')} ($cleanWord)");
        }
        return true;
      }
    }
    return false;
  }

  void _showRejectDialog(String reason) {
    var t = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => FrostedAlertDialog(
        title: Row(
          children: [
            Icon(Icons.gpp_bad, color: Colors.red),
            SizedBox(width: 8),
            Text(t.translate('general_rejected')),
          ],
        ),
        content: Text(
          "${t.translate('post_rejected_desc')}\n\nReason: $reason",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              t.translate('general_edit'),
              style: TextStyle(color: SisapaTheme.blue),
            ),
          ),
        ],
      ),
    );
  }

  void _onTextChanged(String text) {
    _checkCanPost();
    _predictedText = null;
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      if (text.trim().isEmpty) return;
      final suggestion = await _predictionService.getLocalPrediction(text);
      if (mounted && suggestion != null && suggestion.isNotEmpty)
        setState(() => _predictedText = suggestion);
    });
  }

  void _acceptPrediction() {
    if (_predictedText != null) {
      final newText = "${_postController.text.trimRight()} $_predictedText ";
      _postController.text = newText;
      _postController.selection = TextSelection.fromPosition(
        TextPosition(offset: newText.length),
      );
      setState(() {
        _predictedText = null;
        _canPost = true;
      });
      _onTextChanged(newText);
    }
  }

  void _showMediaSourceSelection({required bool isVideo}) {
    var t = AppLocalizations.of(context)!;
    FocusScope.of(context).unfocus();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return FrostedBottomSheet(
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.camera_alt),
                  title: Text(t.translate('profile_camera')),
                  onTap: () {
                    Navigator.pop(context);
                    _pickMedia(ImageSource.camera, isVideo: isVideo);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library),
                  title: Text(t.translate('profile_gallery')),
                  onTap: () {
                    Navigator.pop(context);
                    _pickMedia(ImageSource.gallery, isVideo: isVideo);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<File?> _cropImage(File imageFile) async {
    var t = AppLocalizations.of(context)!;
    try {
      CroppedFile? croppedFile = await ImageCropper().cropImage(
        sourcePath: imageFile.path,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: t.translate('post_crop_image'),
            toolbarColor: SisapaTheme.blue,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.original,
            lockAspectRatio: false,
          ),
          IOSUiSettings(title: t.translate('post_crop_image')),
        ],
      );
      if (croppedFile != null) return File(croppedFile.path);
    } catch (e) {
      debugPrint("Crop error: $e");
    }
    return null;
  }

  Future<void> _pickMedia(ImageSource source, {bool isVideo = false}) async {
    final picker = ImagePicker();
    try {
      if (isVideo) {
        final XFile? pickedFile = await picker.pickVideo(
          source: source,
          maxDuration: const Duration(minutes: 10),
        );
        if (pickedFile != null && mounted) {
          final result = await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => VideoTrimmerScreen(file: File(pickedFile.path)),
            ),
          );
          if (result != null && result['file'] is File) {
            setState(() {
              _mediaType = 'video';
              _selectedMediaFiles = [result['file']];
              _existingMediaUrls = [];
              _existingPublicIds = [];
              _checkCanPost();
            });
          }
        }
      } else {
        if (source == ImageSource.gallery) {
          final List<XFile> pickedFiles = await picker.pickMultiImage(
            imageQuality: 80,
          );
          if (pickedFiles.isNotEmpty) {
            List<File> croppedFiles = [];
            for (var xfile in pickedFiles) {
              File? cropped = await _cropImage(File(xfile.path));
              if (cropped != null) croppedFiles.add(cropped);
            }
            if (croppedFiles.isNotEmpty) {
              setState(() {
                if (_mediaType == 'video') {
                  _selectedMediaFiles = [];
                  _existingMediaUrls = [];
                  _existingPublicIds = [];
                }
                _mediaType = 'image';
                _selectedMediaFiles.addAll(croppedFiles);
                _checkCanPost();
              });
            }
          }
        } else {
          final XFile? pickedFile = await picker.pickImage(
            maxWidth: 1920,
            maxHeight: 1920,
            source: source,
            imageQuality: 80,
          );
          if (pickedFile != null) {
            File? cropped = await _cropImage(File(pickedFile.path));
            if (cropped != null) {
              setState(() {
                if (_mediaType == 'video') {
                  _selectedMediaFiles = [];
                  _existingMediaUrls = [];
                  _existingPublicIds = [];
                }
                _mediaType = 'image';
                _selectedMediaFiles.add(cropped);
                _checkCanPost();
              });
            }
          }
        }
      }
    } catch (e) {
      debugPrint("Error picking media: $e");
    }
  }

  void _removeFile(int index) {
    setState(() {
      _selectedMediaFiles.removeAt(index);
      _checkCanPost();
      if (_selectedMediaFiles.isEmpty && _existingMediaUrls.isEmpty)
        _mediaType = null;
    });
  }

  void _removeExistingUrl(int index) {
    setState(() {
      _existingMediaUrls.removeAt(index);
      if (_existingPublicIds.length > index) _existingPublicIds.removeAt(index);
      _checkCanPost();
      if (_selectedMediaFiles.isEmpty && _existingMediaUrls.isEmpty)
        _mediaType = null;
    });
  }

  void _showVisibilityPicker() {
    var t = AppLocalizations.of(context)!;
    FocusScope.of(context).unfocus();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return FrostedBottomSheet(
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    t.translate('post_visibility_title'),
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                if (_isAccountPrivate) ...[
                  ListTile(
                    leading: const Icon(Icons.people, color: SisapaTheme.blue),
                    title: Text(t.translate('profile_followers')),
                    subtitle: Text(t.translate('post_vis_followers_desc')),
                    trailing: _visibility == 'followers'
                        ? const Icon(Icons.check, color: SisapaTheme.blue)
                        : null,
                    onTap: () {
                      setState(() => _visibility = 'followers');
                      Navigator.pop(context);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.public, color: Colors.grey),
                    title: Text(t.translate('post_vis_public')),
                    subtitle: Text(t.translate('post_vis_private_warn')),
                    enabled: false,
                  ),
                ] else ...[
                  ListTile(
                    leading: const Icon(Icons.public, color: SisapaTheme.blue),
                    title: Text(t.translate('post_vis_public')),
                    subtitle: Text(t.translate('post_vis_public_desc')),
                    trailing: _visibility == 'public'
                        ? const Icon(Icons.check, color: SisapaTheme.blue)
                        : null,
                    onTap: () {
                      setState(() => _visibility = 'public');
                      Navigator.pop(context);
                    },
                  ),
                ],
                ListTile(
                  leading: const Icon(Icons.lock, color: Colors.red),
                  title: Text(t.translate('post_vis_me')),
                  trailing: _visibility == 'private'
                      ? const Icon(Icons.check, color: SisapaTheme.blue)
                      : null,
                  onTap: () {
                    setState(() => _visibility = 'private');
                    Navigator.pop(context);
                  },
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildVisibilityButtonContent() {
    var t = AppLocalizations.of(context)!;
    IconData icon;
    String label;
    Color color = SisapaTheme.blue;

    if (_visibility == 'private') {
      icon = Icons.lock;
      label = t.translate('post_vis_me');
      color = Colors.red;
    } else if (_visibility == 'followers') {
      icon = Icons.people;
      label = t.translate('profile_followers');
    } else {
      icon = Icons.public;
      label = t.translate('post_vis_public');
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
        const SizedBox(width: 4),
        Icon(Icons.keyboard_arrow_down, color: color, size: 18),
      ],
    );
  }

  Future<bool> _onWillPop() async {
    var t = AppLocalizations.of(context)!;
    if (!_canPost && _currentDraftId == null) return true;
    if (_currentDraftId != null && !_hasChanges()) return true;

    if (_isEditing) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => FrostedAlertDialog(
          title: Text(t.translate('post_discard_title')),
          content: Text(t.translate('post_discard_desc')),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(t.translate('post_keep_editing')),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(
                t.translate('post_discard'),
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        ),
      );
      return confirm ?? false;
    }

    final String title = _currentDraftId != null
        ? t.translate('post_draft_update_title')
        : t.translate('post_draft_save_title');
    final String content = _currentDraftId != null
        ? t.translate('post_draft_update_desc')
        : t.translate('post_draft_save_desc');

    final result = await showDialog<String>(
      context: context,
      builder: (context) => FrostedAlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop('discard'),
            child: Text(
              t.translate('post_discard'),
              style: TextStyle(color: Colors.red),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop('cancel'),
            child: Text(t.translate('general_cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop('save'),
            style: ElevatedButton.styleFrom(
              backgroundColor: SisapaTheme.blue,
              foregroundColor: Colors.white,
            ),
            child: Text(t.translate('general_save')),
          ),
        ],
      ),
    );

    if (result == 'save') {
      await _saveToDrafts();
      return true;
    } else if (result == 'discard') {
      return true;
    }
    return false;
  }

  Future<void> _saveToDrafts() async {
    setState(() => _isSavingDraft = true);
    var t = AppLocalizations.of(context)!;
    try {
      List<String> finalUrls = [..._existingMediaUrls];
      List<String> finalPublicIds = [..._existingPublicIds];

      if (_selectedMediaFiles.isNotEmpty) {
        OverlayService().showTopNotification(
          context,
          t.translate('post_draft_uploading'),
          Icons.cloud_upload,
          () {},
        );
        for (var file in _selectedMediaFiles) {
          File fileToUp = file;
          if (_mediaType == 'video') {
            try {
              final MediaInfo? info = await VideoCompress.compressVideo(
                file.path,
                quality: VideoQuality.MediumQuality,
                deleteOrigin: false,
              );
              if (info != null && info.file != null) fileToUp = info.file!;
            } catch (e) {}
          }
          final response = await _cloudinaryService.uploadFileWithDetails(
            fileToUp,
            _mediaType == 'video' ? 'video' : 'auto',
          );
          if (response.secureUrl != null) {
            finalUrls.add(response.secureUrl!);
            if (response.publicId != null)
              finalPublicIds.add(response.publicId!);
          }
        }
      }

      final draft = DraftPost(
        id: _currentDraftId ?? DateTime.now().millisecondsSinceEpoch.toString(),
        text: _postController.text,
        mediaUrls: finalUrls,
        publicIds: finalPublicIds,
        mediaType: _mediaType,
        visibility: _visibility,
        timestamp: DateTime.now().millisecondsSinceEpoch,
        communityId: _communityId,
        communityName: _communityName,
        communityIcon: _communityIcon,
      );

      await _draftService.saveDraft(draft);
      if (mounted)
        OverlayService().showTopNotification(
          context,
          t.translate('post_draft_saved'),
          Icons.save,
          () {},
          color: Colors.green,
        );
    } catch (e) {
      if (mounted)
        OverlayService().showTopNotification(
          context,
          t.translate('post_draft_failed'),
          Icons.error,
          () {},
          color: Colors.red,
        );
    } finally {
      if (mounted) setState(() => _isSavingDraft = false);
    }
  }

  Future<void> _submitPost() async {
    if (!_canPost) return;

    var t = AppLocalizations.of(context)!;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final text = _postController.text;

    // --- 1. FILTER TEKS (Caption) ---
    if (_checkTextForBadWords(text)) {
      return;
    }

    // --- 2. FILTER GAMBAR (Visual Detector AI) ---
    final isImageSafe = await _checkImageSafety();
    if (!isImageSafe) return;

    FocusScope.of(context).unfocus();
    Navigator.of(context).pop();

    final OverlayState? overlayState = Overlay.maybeOf(context);

    final Map<String, String> localizedStrings = {
      'uploading': t.translate('post_uploading_count'),
      'no_content': t.translate('post_no_content'),
      'posted': t.translate('post_success'),
      'failed': t.translate('post_failed'),
    };

    final String communityNameSafe =
        _communityName ?? t.translate('general_community');
    final String myUserNameSafe = _myUserName == 'Anonymous'
        ? t.translate('general_anonymous')
        : _myUserName;

    if (overlayState != null) {
      BackgroundUploader.startUploadSequence(
        overlayState: overlayState,
        text: _postController.text,
        filesToUpload: _selectedMediaFiles,
        existingMediaUrls: _existingMediaUrls,
        mediaType: _mediaType,
        visibility: _visibility,
        isEditing: _isEditing,
        postId: widget.postId,
        uid: user.uid,
        userName: _postAsCommunity ? communityNameSafe : myUserNameSafe,
        userEmail: _myUserEmail,
        avatarIconId: _postAsCommunity ? 0 : _myAvatarIconId,
        avatarHex: _postAsCommunity ? '' : _myAvatarHex,
        profileImageUrl: _postAsCommunity ? _communityIcon : _myAvatarUrl,
        communityId: _communityId,
        communityName: _communityName,
        communityIcon: _communityIcon,
        communityVerified: _communityVerified,
        isCommunityIdentity: _postAsCommunity,
        draftIdToDelete: _currentDraftId,
        localizedStrings: localizedStrings,
      );
    }
  }

  @override
  void dispose() {
    _postController.dispose();
    _postFocusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isRestricted) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    var t = AppLocalizations.of(context)!;

    final String? currentAvatarUrl = _postAsCommunity
        ? _communityIcon
        : _myAvatarUrl;
    final String currentDisplayName = _postAsCommunity
        ? (_communityName ?? t.translate('general_community'))
        : (_myUserName == 'Anonymous'
              ? t.translate('general_anonymous')
              : _myUserName);

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        appBar: FrostedAppBar(
          leading: IconButton(
            icon: Icon(Icons.close, color: theme.primaryColor),
            onPressed: () async {
              if (await _onWillPop()) {
                if (mounted) Navigator.of(context).pop();
              }
            },
          ),
          title: _isCommunityContext
              ? Row(
                  children: [
                    const Icon(Icons.groups, color: SisapaTheme.blue, size: 20),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        _communityName ?? t.translate('general_community'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                )
              : Text(
                  _isEditing
                      ? t.translate('post_edit_title')
                      : t.translate('post_create_title'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
          centerTitle: false,
          actions: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: ElevatedButton(
                onPressed: _canPost && !_isProcessing && !_isSavingDraft
                    ? _submitPost
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: SisapaTheme.blue,
                  foregroundColor: Colors.white,
                  shape: const StadiumBorder(),
                ),
                child: Text(t.translate('post_button')),
              ),
            ),
          ],
        ),
        body: Stack(
          children: [
            Positioned.fill(
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                  top: 16,
                  left: 16,
                  right: 16,
                  bottom: safeBottom + 88,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_hasOfficialAuthority)
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: theme.cardColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: theme.dividerColor),
                        ),
                        child: Row(
                          children: [
                            Text(
                              t.translate('post_identity_label'),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            const Spacer(),
                            ChoiceChip(
                              label: Text(t.translate('post_identity_me')),
                              selected: !_postAsCommunity,
                              onSelected: (val) =>
                                  setState(() => _postAsCommunity = false),
                              visualDensity: VisualDensity.compact,
                            ),
                            const SizedBox(width: 8),
                            ChoiceChip(
                              label: Text(t.translate('nav_community')),
                              selected: _postAsCommunity,
                              onSelected: (val) =>
                                  setState(() => _postAsCommunity = true),
                              selectedColor: SisapaTheme.blue.withOpacity(0.2),
                              labelStyle: TextStyle(
                                color: _postAsCommunity
                                    ? SisapaTheme.blue
                                    : null,
                              ),
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                        ),
                      ),

                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: currentAvatarUrl != null
                              ? Colors.transparent
                              : AvatarHelper.getColor(_myAvatarHex),
                          backgroundImage: currentAvatarUrl != null
                              ? CachedNetworkImageProvider(
                                  currentAvatarUrl,
                                  cacheManager: AppCacheManager.instance,
                                )
                              : null,
                          child: currentAvatarUrl == null
                              ? (_postAsCommunity
                                    ? const Icon(
                                        Icons.groups,
                                        color: Colors.white,
                                      )
                                    : Icon(
                                        AvatarHelper.getIcon(_myAvatarIconId),
                                        color: Colors.white,
                                      ))
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                currentDisplayName,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: _postAsCommunity
                                      ? SisapaTheme.blue
                                      : null,
                                ),
                              ),
                              if (_isCommunityContext)
                                Text(
                                  _postAsCommunity
                                      ? t.translate('post_as_comm_id')
                                      : "${t.translate('post_in_comm')} $_communityName",
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),

                              TextField(
                                controller: _postController,
                                focusNode: _postFocusNode,
                                onChanged: _onTextChanged,
                                autofocus: !_isEditing,
                                maxLines: null,
                                style: const TextStyle(fontSize: 18),
                                decoration: InputDecoration(
                                  hintText: _postAsCommunity
                                      ? t.translate('post_hint_official')
                                      : t.translate('post_hint'),
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                ),
                              ),

                              if (_existingMediaUrls.isNotEmpty ||
                                  _selectedMediaFiles.isNotEmpty)
                                Container(
                                  height: 100,
                                  margin: const EdgeInsets.only(top: 10),
                                  child: ListView(
                                    scrollDirection: Axis.horizontal,
                                    children: [
                                      ..._existingMediaUrls.asMap().entries.map(
                                        (e) => MediaPreviewItem(
                                          imageProvider:
                                              CachedNetworkImageProvider(
                                                e.value,
                                                cacheManager:
                                                    AppCacheManager.instance,
                                              ),
                                          onRemove: () =>
                                              _removeExistingUrl(e.key),
                                          isVideo: _mediaType == 'video',
                                        ),
                                      ),
                                      ..._selectedMediaFiles
                                          .asMap()
                                          .entries
                                          .map(
                                            (e) => MediaPreviewItem(
                                              imageProvider: FileImage(e.value),
                                              onRemove: () =>
                                                  _removeFile(e.key),
                                              isVideo: _mediaType == 'video',
                                            ),
                                          ),
                                    ],
                                  ),
                                ),

                              if (_predictedText != null)
                                GestureDetector(
                                  onTap: _acceptPrediction,
                                  child: Container(
                                    margin: const EdgeInsets.only(top: 8),
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: SisapaTheme.blue.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      "${t.translate('search_suggestion_prefix')} $_predictedText",
                                      style: const TextStyle(
                                        color: SisapaTheme.blue,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            Positioned(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 0,
              right: 0,
              child: CreatePostActionToolbar(
                isCommunityContext: _isCommunityContext,
                visibilityButtonContent: _buildVisibilityButtonContent(),
                onPickImage: () => _showMediaSourceSelection(isVideo: false),
                onPickVideo: () => _showMediaSourceSelection(isVideo: true),
                onShowVisibilityPicker: _showVisibilityPicker,
              ),
            ),

            // --- LOADING BLOCKING SCREEN (WITH ANIMATION) ---
            if (_isProcessing)
              Positioned.fill(
                child: Container(
                  color: Colors.black54, // Latar belakang semi-transparan
                  child: Center(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: _scanStatus == 'success'
                          ? Column(
                              key: const ValueKey('success'),
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.check_circle,
                                  color: Colors.green,
                                  size: 60,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  t.translate('general_success'),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              key: const ValueKey('loading'),
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const CircularProgressIndicator(
                                  color: Colors.white,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  t.translate('post_scan_images'),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}


