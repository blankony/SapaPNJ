import 'package:flutter/material.dart';

import '../../services/app_localizations.dart';
import '../../theme/app_theme.dart';

class VerifiedBadgeButton extends StatelessWidget {
  final double iconSize;
  final double tapTargetSize;
  final VoidCallback? onGetVerified;

  const VerifiedBadgeButton({
    super.key,
    this.iconSize = 22,
    this.tapTargetSize = 32,
    this.onGetVerified,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    return Tooltip(
      message: t.translate('profile_verified_badge_tooltip'),
      child: SizedBox(
        width: tapTargetSize,
        height: tapTargetSize,
        child: IconButton(
          constraints: BoxConstraints(
            minWidth: tapTargetSize,
            minHeight: tapTargetSize,
          ),
          padding: EdgeInsets.zero,
          splashRadius: tapTargetSize / 2,
          icon: Icon(Icons.verified, size: iconSize, color: SisapaTheme.blue),
          onPressed: () => showVerifiedBadgeInfoDialog(
            context,
            onGetVerified: onGetVerified,
          ),
        ),
      ),
    );
  }
}

Future<void> showVerifiedBadgeInfoDialog(
  BuildContext context, {
  VoidCallback? onGetVerified,
}) {
  final t = AppLocalizations.of(context)!;

  return showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return FrostedAlertDialog(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.verified, color: SisapaTheme.blue),
            const SizedBox(width: 8),
            Flexible(child: Text(t.translate('profile_verified_badge_title'))),
          ],
        ),
        content: Text(t.translate('profile_verified_badge_desc')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(t.translate('general_close')),
          ),
          if (onGetVerified != null)
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                onGetVerified();
              },
              child: Text(t.translate('get_verified_badge')),
            ),
        ],
      );
    },
  );
}
