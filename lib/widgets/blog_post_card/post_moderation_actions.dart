import 'package:flutter/material.dart';

import '../../services/app_localizations.dart';
import '../../services/moderation_service.dart';
import '../../services/overlay_service.dart';
import '../../theme/app_theme.dart';

class PostModerationActions {
  const PostModerationActions._();

  static void reportPost({
    required BuildContext context,
    required String postId,
  }) {
    final t = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (dialogContext) {
        return FrostedSimpleDialog(
          title: Text(t.translate('report_post_title')),
          children: [
            SimpleDialogOption(
              onPressed: () =>
                  _submitPostReport(context, dialogContext, postId, 'Spam'),
              child: Text(t.translate('report_reason_spam')),
            ),
            SimpleDialogOption(
              onPressed: () => _submitPostReport(
                context,
                dialogContext,
                postId,
                'Harassment',
              ),
              child: Text(t.translate('report_reason_harass')),
            ),
            SimpleDialogOption(
              onPressed: () => _submitPostReport(
                context,
                dialogContext,
                postId,
                'Inappropriate Content',
              ),
              child: Text(t.translate('report_reason_inappropriate')),
            ),
            SimpleDialogOption(
              onPressed: () => _submitPostReport(
                context,
                dialogContext,
                postId,
                'Misinformation',
              ),
              child: Text(t.translate('report_reason_misinfo')),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(t.translate('general_cancel')),
              ),
            ),
          ],
        );
      },
    );
  }

  static void reportCommunity({
    required BuildContext context,
    required String? communityId,
  }) {
    if (communityId == null) return;

    final t = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (dialogContext) {
        return FrostedSimpleDialog(
          title: Text(t.translate('report_comm_title')),
          children: [
            SimpleDialogOption(
              onPressed: () => _submitCommunityReport(
                context,
                dialogContext,
                communityId,
                'Spam',
              ),
              child: Text(t.translate('report_reason_spam')),
            ),
            SimpleDialogOption(
              onPressed: () => _submitCommunityReport(
                context,
                dialogContext,
                communityId,
                'Harassment',
              ),
              child: Text(t.translate('report_reason_harass')),
            ),
            SimpleDialogOption(
              onPressed: () => _submitCommunityReport(
                context,
                dialogContext,
                communityId,
                'Inappropriate Content',
              ),
              child: Text(t.translate('report_reason_inappropriate')),
            ),
            SimpleDialogOption(
              onPressed: () => _submitCommunityReport(
                context,
                dialogContext,
                communityId,
                'Misinformation',
              ),
              child: Text(t.translate('report_reason_misinfo')),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(t.translate('general_cancel')),
              ),
            ),
          ],
        );
      },
    );
  }

  static Future<void> blockUser({
    required BuildContext context,
    required String? authorId,
  }) async {
    if (authorId == null) return;

    final t = AppLocalizations.of(context)!;
    final didConfirm =
        await showDialog<bool>(
          context: context,
          builder: (context) => FrostedAlertDialog(
            title: Text(t.translate('block_user_title')),
            content: Text(t.translate('block_user_confirm')),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(t.translate('general_cancel')),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(
                  t.translate('general_delete'),
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        ) ??
        false;

    if (!didConfirm || !context.mounted) return;

    await moderationService.blockUser(authorId);
    if (!context.mounted) return;

    OverlayService().showTopNotification(
      context,
      t.translate('user_blocked'),
      Icons.block,
      () {},
    );
  }

  static void _submitPostReport(
    BuildContext context,
    BuildContext dialogContext,
    String postId,
    String reason,
  ) {
    final t = AppLocalizations.of(context)!;
    Navigator.pop(dialogContext);
    moderationService.reportContent(
      targetId: postId,
      targetType: 'post',
      reason: reason,
    );
    OverlayService().showTopNotification(
      context,
      t.translate('report_submitted'),
      Icons.flag,
      () {},
    );
  }

  static void _submitCommunityReport(
    BuildContext context,
    BuildContext dialogContext,
    String communityId,
    String reason,
  ) {
    final t = AppLocalizations.of(context)!;
    Navigator.pop(dialogContext);
    moderationService.reportContent(
      targetId: communityId,
      targetType: 'community',
      reason: reason,
    );
    OverlayService().showTopNotification(
      context,
      t.translate('report_comm_submitted'),
      Icons.flag,
      () {},
    );
  }
}
