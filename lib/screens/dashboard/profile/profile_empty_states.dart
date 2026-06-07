import 'package:flutter/material.dart';

import '../../../services/app_localizations.dart';

class BlockedProfileBody extends StatelessWidget {
  final VoidCallback onUnblock;

  const BlockedProfileBody({super.key, required this.onUnblock});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.block, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            t.translate('profile_blocked_title'),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(
            t.translate('profile_blocked_desc'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: onUnblock,
            child: Text(t.translate('profile_unblocked')),
          ),
        ],
      ),
    );
  }
}

class PrivateAccountBody extends StatelessWidget {
  const PrivateAccountBody({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context)!;

    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: theme.dividerColor, width: 2),
            ),
            child: Icon(
              Icons.lock_outline,
              size: 48,
              color: theme.primaryColor,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            t.translate('profile_private_title'),
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            t.translate('profile_private_desc'),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
          ),
        ],
      ),
    );
  }
}
