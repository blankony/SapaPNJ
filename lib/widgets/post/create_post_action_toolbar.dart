import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class CreatePostActionToolbar extends StatelessWidget {
  final Widget visibilityButtonContent;
  final VoidCallback onPickImage;
  final VoidCallback onPickVideo;
  final VoidCallback onShowVisibilityPicker;
  final bool isCommunityContext;

  const CreatePostActionToolbar({
    super.key,
    required this.visibilityButtonContent,
    required this.onPickImage,
    required this.onPickVideo,
    required this.onShowVisibilityPicker,
    this.isCommunityContext = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.image, color: SisapaTheme.blue),
                onPressed: onPickImage,
                tooltip: 'Add Image',
              ),
              IconButton(
                icon: const Icon(Icons.videocam, color: SisapaTheme.blue),
                onPressed: onPickVideo,
                tooltip: 'Add Video',
              ),
              const Spacer(),
              if (!isCommunityContext)
                InkWell(
                  onTap: onShowVisibilityPicker,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Theme.of(context).dividerColor,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: visibilityButtonContent,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
