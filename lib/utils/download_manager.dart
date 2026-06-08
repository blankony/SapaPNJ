import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import '../services/app_cache_manager.dart';
import '../theme/app_theme.dart';

class DownloadManager {
  static void startDownloadSequence({
    required OverlayState overlayState,
    required String url,
    required bool isImage,
  }) {
    final GlobalKey<_DownloadStatusOverlayState> overlayKey = GlobalKey();
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => _DownloadStatusOverlay(
        key: overlayKey,
        onDismissRequest: () {
          overlayKey.currentState?.dismissToIcon();
        },
      ),
    );

    overlayState.insert(overlayEntry);

    _processDownload(
      url: url,
      isImage: isImage,
      onSuccess: () {
        overlayKey.currentState?.handleSuccess();
        Future.delayed(const Duration(seconds: 7), () {
           if (overlayEntry.mounted) overlayEntry.remove();
        });
      },
      onFailure: (error) {
        overlayKey.currentState?.handleFailure();
        Future.delayed(const Duration(seconds: 4), () {
          if (overlayEntry.mounted) overlayEntry.remove();
        });
      },
    );
  }

  static Future<void> _processDownload({
    required String url,
    required bool isImage,
    required VoidCallback onSuccess,
    required Function(dynamic) onFailure,
  }) async {
    try {
      final File cacheFile = await AppCacheManager.instance.getSingleFile(url);
      final String dateStr = DateFormat('ddMMyy').format(DateTime.now());
      final String ext = p.extension(url).isEmpty ? (isImage ? '.jpg' : '.mp4') : p.extension(url);
      final String fileName = "SapaPNJ_$dateStr$ext";

      String basePath;
      if (isImage) {
        basePath = '/storage/emulated/0/Pictures/SapaPNJ';
      } else {
        basePath = '/storage/emulated/0/Download/SapaPNJ';
      }

      final Directory dir = Directory(basePath);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      final String savePath = '$basePath/$fileName';
      await cacheFile.copy(savePath);

      onSuccess();
    } catch (e) {
      debugPrint("Download Error: $e");
      onFailure(e);
    }
  }
}

class _DownloadStatusOverlay extends StatefulWidget {
  final VoidCallback onDismissRequest;
  const _DownloadStatusOverlay({super.key, required this.onDismissRequest});

  @override
  State<_DownloadStatusOverlay> createState() => _DownloadStatusOverlayState();
}

class _DownloadStatusOverlayState extends State<_DownloadStatusOverlay> {
  bool _isCardVisible = true;
  bool _isMiniVisible = false;
  bool _isSuccess = false;
  bool _isError = false;
  String _message = "Downloading media...";
  Timer? _autoDismissTimer;

  double get _targetTop => MediaQuery.of(context).padding.top + 10;
  double get _targetRight => 12.0;
  double get _miniRight => 60.0;

  @override
  void dispose() {
    _autoDismissTimer?.cancel();
    super.dispose();
  }

  void dismissToIcon() {
    setState(() => _isCardVisible = false);
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) setState(() => _isMiniVisible = true);
    });
  }

  void _expandToCard() {
    setState(() => _isMiniVisible = false);
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() => _isCardVisible = true);
        _autoDismissTimer?.cancel();
        _autoDismissTimer = Timer(const Duration(seconds: 2), dismissToIcon);
      }
    });
  }

  void handleSuccess() {
    setState(() { _isSuccess = true; _message = "Download Complete"; });
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

  void handleFailure() {
    setState(() { _isError = true; _message = "Download Failed"; });
    if (!_isCardVisible) setState(() => _isCardVisible = true);
  }

  @override
  Widget build(BuildContext context) {
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
                color: _isSuccess ? Colors.green : SisapaTheme.white,
                child: Container(
                  width: 36, height: 36, padding: const EdgeInsets.all(8),
                  child: _isSuccess
                    ? const Icon(Icons.check, size: 20, color: Colors.white)
                    : const CircularProgressIndicator(strokeWidth: 3, color: SisapaTheme.blue),
                ),
              ),
            ),
          ),
        ),

        AnimatedPositioned(
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOutBack,
          top: _isCardVisible ? MediaQuery.of(context).padding.top + 10 : _targetTop,
          left: _isCardVisible ? 16 : MediaQuery.of(context).size.width - 50,
          right: _isCardVisible ? 16 : _targetRight,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 300),
            opacity: _isCardVisible ? 1.0 : 0.0,
            child: Transform.scale(
              scale: _isCardVisible ? 1.0 : 0.1,
              child: Dismissible(
                key: const ValueKey("download_card_dismiss"),
                direction: DismissDirection.horizontal,
                onDismissed: (_) => widget.onDismissRequest(),
                child: Material(
                  elevation: 8,
                  borderRadius: BorderRadius.circular(12),
                  color: Theme.of(context).brightness == Brightness.dark ? SisapaTheme.darkGrey : Colors.white,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            if (_isSuccess)
                              const Icon(Icons.check_circle, color: SisapaTheme.blue)
                            else if (_isError)
                              const Icon(Icons.error, color: Colors.red)
                            else
                              const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _message,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            Container(
                              width: 4, height: 24,
                              decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(2)),
                            )
                          ],
                        ),
                        if (!_isSuccess && !_isError)
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: LinearProgressIndicator(
                              backgroundColor: SisapaTheme.blue.withValues(alpha: 0.1),
                              valueColor: const AlwaysStoppedAnimation(SisapaTheme.blue),
                            ),
                          )
                      ],
                    ),
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
