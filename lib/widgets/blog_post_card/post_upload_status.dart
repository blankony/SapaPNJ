import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class PostUploadStatus extends StatelessWidget {
  const PostUploadStatus({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Uploading media...',
            style: TextStyle(
              color: SisapaTheme.blue,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: null,
            backgroundColor: Theme.of(context).dividerColor,
            valueColor: AlwaysStoppedAnimation<Color>(SisapaTheme.blue),
          ),
          const SizedBox(height: 4),
          Text('Processing...', style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
