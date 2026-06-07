import 'package:flutter/material.dart';

class PostUploadFailedNotice extends StatelessWidget {
  final String text;

  const PostUploadFailedNotice({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12.0),
      color: Colors.red.withValues(alpha: 0.1),
      child: Text(
        'Post upload failed: $text',
        style: const TextStyle(color: Colors.red),
      ),
    );
  }
}
