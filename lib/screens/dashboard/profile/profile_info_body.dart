import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../theme/app_theme.dart';
import '../../../services/app_localizations.dart';
import '../../../services/overlay_service.dart';
import '../../../utils/format_utils.dart';
import 'profile_stat_link.dart';
import '../../../widgets/profile/verified_badge_button.dart';

class ProfileInfoBody extends StatelessWidget {
  final Map<String, dynamic> userData;
  final bool isMyProfile;
  final bool isBioExpanded;
  final bool isBlocked;
  final String userId;
  final User? currentUser;
  final VoidCallback onToggleBio;
  final VoidCallback onGetVerified;

  const ProfileInfoBody({
    super.key,
    required this.userData,
    required this.isMyProfile,
    required this.isBioExpanded,
    required this.isBlocked,
    required this.userId,
    required this.currentUser,
    required this.onToggleBio,
    required this.onGetVerified,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    var t = AppLocalizations.of(context)!;

    final String name = userData['name'] ?? 'Name';
    final String handle = "@${(userData['email'] ?? '').split('@')[0]}";
    final String displayBio = isBioExpanded
        ? (userData['bio'] ?? '')
        : ((userData['bio'] ?? '').length > 100
              ? (userData['bio'] ?? '').substring(0, 100) + '...'
              : (userData['bio'] ?? ''));

    final String verificationStatus =
        userData['verification_status'] ??
        userData['verificationStatus'] ??
        'none';
    final bool isVerified = verificationStatus == 'verified';
    final bool isPending = verificationStatus == 'pending';

    bool showEmailVerifyBtn = false;
    bool showKtmVerifyBtn = false;

    if (isMyProfile) {
      if (currentUser != null && !currentUser!.emailVerified) {
        showEmailVerifyBtn = true;
      } else if (!isVerified && !isPending) {
        showKtmVerifyBtn = true;
      }
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  name,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isVerified) ...[
                const SizedBox(width: 2),
                VerifiedBadgeButton(
                  onGetVerified: isMyProfile ? null : onGetVerified,
                ),
              ] else if (userData['is_private'] == true ||
                  userData['is_private'] == 1 ||
                  userData['isPrivate'] == true ||
                  userData['isPrivate'] == 1) ...[
                const SizedBox(width: 6),
                Icon(
                  Icons.lock,
                  size: 22,
                  color: theme.textTheme.titleLarge?.color,
                ),
              ],
            ],
          ),
          Text(handle, style: theme.textTheme.titleSmall),

          // --- VERIFICATION BUTTONS ---
          if (showEmailVerifyBtn)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: InkWell(
                onTap: () async {
                  try {
                    await currentUser!.sendEmailVerification();
                    if (!context.mounted) return;
                    OverlayService().showTopNotification(
                      context,
                      t.translate('profile_verify_sent'),
                      Icons.mark_email_read,
                      () {},
                    );
                  } catch (e) {
                    if (!context.mounted) return;
                    OverlayService().showTopNotification(
                      context,
                      t.translate('profile_verify_wait'),
                      Icons.timer,
                      () {},
                      color: Colors.orange,
                    );
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.red),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.warning, size: 16, color: Colors.red),
                      const SizedBox(width: 6),
                      Text(
                        t.translate('profile_verify_email'),
                        style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else if (isPending)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.orange),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.hourglass_top,
                      size: 16,
                      color: Colors.orange,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      t.translate('profile_verify_pending'),
                      style: const TextStyle(
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else if (showKtmVerifyBtn)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: InkWell(
                onTap: onGetVerified,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: SisapaTheme.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: SisapaTheme.blue),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.verified_outlined,
                        size: 16,
                        color: SisapaTheme.blue,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        t.translate('profile_verify_get'),
                        style: const TextStyle(
                          color: SisapaTheme.blue,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          const SizedBox(height: 8),
          if (!isBlocked) ...[
            Text(
              displayBio.isEmpty ? t.translate('profile_no_bio') : displayBio,
              style: theme.textTheme.bodyLarge,
            ),
            if ((userData['bio'] ?? '').length > 100)
              GestureDetector(
                onTap: onToggleBio,
                child: Text(
                  isBioExpanded
                      ? t.translate('general_show_less')
                      : t.translate('general_show_more'),
                  style: const TextStyle(
                    color: SisapaTheme.blue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 14, color: theme.hintColor),
                const SizedBox(width: 4),
                Text(
                  FormatUtils.formatJoinedDate(
                    userData['created_at'] ?? userData['createdAt'],
                    unknownText: t.translate('profile_joined_unknown'),
                    joinedPrefix: t.translate('profile_joined'),
                  ),
                  style: theme.textTheme.titleSmall,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                ProfileStatLink(
                  userId: userId,
                  count: (userData['following'] ?? []).length,
                  label: t.translate('profile_following'),
                  tabIndex: 1,
                ),
                const SizedBox(width: 16),
                ProfileStatLink(
                  userId: userId,
                  count: (userData['followers'] ?? []).length,
                  label: t.translate('profile_followers'),
                  tabIndex: 2,
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }
}
