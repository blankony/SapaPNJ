import 'package:flutter/material.dart';

class MediaPreviewItem extends StatelessWidget {
  final ImageProvider imageProvider;
  final VoidCallback onRemove;
  final bool isVideo;

  const MediaPreviewItem({
    super.key,
    required this.imageProvider,
    required this.onRemove,
    required this.isVideo,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          width: 100,
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(8),
            image: !isVideo
                ? DecorationImage(image: imageProvider, fit: BoxFit.cover)
                : null,
          ),
          child: isVideo
              ? const Center(
                  child: Icon(Icons.play_circle_fill, color: Colors.white),
                )
              : null,
        ),
        Positioned(
          top: 4,
          right: 12,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, size: 14, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}
