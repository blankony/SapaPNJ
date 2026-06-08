import 'package:flutter/material.dart';
import 'package:sapa_pnj/services/app_localizations.dart';

import '../../services/feed_preferences_service.dart';
import '../../theme/app_theme.dart';

class FeedControlsSheet extends StatefulWidget {
  final FeedPreferences initialPreferences;

  const FeedControlsSheet({super.key, required this.initialPreferences});

  @override
  State<FeedControlsSheet> createState() => _FeedControlsSheetState();
}

class _FeedControlsSheetState extends State<FeedControlsSheet> {
  late FeedPreferences _preferences;

  @override
  void initState() {
    super.initState();
    _preferences = widget.initialPreferences;
  }

  void _update(FeedPreferences value) {
    setState(() => _preferences = value);
  }

  void _apply() {
    Navigator.of(context).pop(_preferences);
  }

  void _reset() {
    setState(() => _preferences = FeedPreferences.defaults);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return FrostedBottomSheet(
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 12, 20, 16 + bottomInset),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.82,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.dividerColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Icon(Icons.tune_rounded, color: SisapaTheme.blue),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Feed controls',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: AppLocalizations.of(context)!.translate('general_close'),
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    children: [
                      _SectionHeader(title: 'Recent feed'),
                      _ScopeControl(
                        label: 'Community posts',
                        value: _preferences.recentCommunityScope,
                        onChanged: (value) => _update(
                          _preferences.copyWith(recentCommunityScope: value),
                        ),
                      ),
                      SwitchListTile(
                        value: _preferences.showRepostsInRecent,
                        onChanged: (value) => _update(
                          _preferences.copyWith(showRepostsInRecent: value),
                        ),
                        title: const Text('Show reposts'),
                        contentPadding: EdgeInsets.zero,
                      ),
                      SwitchListTile(
                        value: _preferences.recentFollowingOnly,
                        onChanged: (value) => _update(
                          _preferences.copyWith(recentFollowingOnly: value),
                        ),
                        title: const Text('People I follow only'),
                        contentPadding: EdgeInsets.zero,
                      ),
                      const SizedBox(height: 14),
                      _SectionHeader(title: 'Recommended feed'),
                      _ScopeControl(
                        label: 'Community recommendations',
                        value: _preferences.recommendedCommunityScope,
                        onChanged: (value) => _update(
                          _preferences.copyWith(
                            recommendedCommunityScope: value,
                          ),
                        ),
                      ),
                      SwitchListTile(
                        value: _preferences.showRepostsInRecommended,
                        onChanged: (value) => _update(
                          _preferences.copyWith(
                            showRepostsInRecommended: value,
                          ),
                        ),
                        title: const Text('Show reposts'),
                        contentPadding: EdgeInsets.zero,
                      ),
                      SwitchListTile(
                        value: _preferences.prioritizeFollowedCommunities,
                        onChanged: (value) => _update(
                          _preferences.copyWith(
                            prioritizeFollowedCommunities: value,
                          ),
                        ),
                        title: const Text('Prioritize followed communities'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Reset defaults',
                      icon: const Icon(Icons.restart_alt_rounded),
                      onPressed: _reset,
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(AppLocalizations.of(context)!.translate('general_cancel')),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: _apply,
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('Apply'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 10),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: SisapaTheme.blue,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ScopeControl extends StatelessWidget {
  final String label;
  final CommunityFeedScope value;
  final ValueChanged<CommunityFeedScope> onChanged;

  const _ScopeControl({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<CommunityFeedScope>(
              selected: {value},
              showSelectedIcon: false,
              onSelectionChanged: (selection) => onChanged(selection.first),
              segments: const [
                ButtonSegment(
                  value: CommunityFeedScope.off,
                  label: Text('Off'),
                  icon: Icon(Icons.visibility_off_outlined),
                ),
                ButtonSegment(
                  value: CommunityFeedScope.followed,
                  label: Text('Followed'),
                  icon: Icon(Icons.groups_2_outlined),
                ),
                ButtonSegment(
                  value: CommunityFeedScope.all,
                  label: Text('All'),
                  icon: Icon(Icons.public_rounded),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
