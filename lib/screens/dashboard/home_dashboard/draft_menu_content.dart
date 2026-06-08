import 'package:flutter/material.dart';
import 'package:sapa_pnj/services/app_localizations.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../services/draft_service.dart';
import '../../../theme/app_theme.dart';

class DraftMenuContent extends StatefulWidget {
  final List<DraftPost> initialDrafts;
  final VoidCallback onNewPost;
  final ValueChanged<DraftPost> onOpenDraft;

  const DraftMenuContent({
    super.key,
    required this.initialDrafts,
    required this.onNewPost,
    required this.onOpenDraft,
  });

  @override
  State<DraftMenuContent> createState() => _DraftMenuContentState();
}

class _DraftMenuContentState extends State<DraftMenuContent> {
  late List<DraftPost> _localDrafts;

  @override
  void initState() {
    super.initState();
    _localDrafts = widget.initialDrafts.take(3).toList();
  }

  Future<void> _deleteDraft(String id, int index) async {
    setState(() {
      _localDrafts.removeAt(index);
    });
    await DraftService().deleteDraft(id);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF15202B) : Colors.white;

    return FrostedSurface(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      borderRadius: BorderRadius.circular(24),
      tint: bgColor.withValues(alpha: isDark ? 0.86 : 0.82),
      blur: FrostedGlassTokens.strongBlurSigma,
      border: Border.all(color: theme.dividerColor.withValues(alpha: 0.5)),
      boxShadow: FrostedGlassTokens.materialDepth(context),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Create Post',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          _buildNewPostButton(),
          if (_localDrafts.isNotEmpty) ...[
            const SizedBox(height: 24),
            _buildDraftsHeader(theme),
            const SizedBox(height: 8),
            _buildDraftsList(theme),
          ] else ...[
            const SizedBox(height: 16),
            Center(
              child: Text(
                'No drafts saved',
                style: TextStyle(color: theme.hintColor),
              ),
            ),
          ],
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.translate('general_cancel'), style: TextStyle(color: theme.hintColor)),
          ),
        ],
      ),
    );
  }

  Widget _buildNewPostButton() {
    return ElevatedButton.icon(
      onPressed: widget.onNewPost,
      icon: const Icon(Icons.add, color: Colors.white),
      label: Text(AppLocalizations.of(context)!.translate('post_create_new'), style: TextStyle(fontSize: 16)),
      style: ElevatedButton.styleFrom(
        backgroundColor: SisapaTheme.blue,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 0,
      ),
    );
  }

  Widget _buildDraftsHeader(ThemeData theme) {
    return Row(
      children: [
        Text(
          'Recent Drafts',
          style: TextStyle(
            color: theme.hintColor,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
        const Spacer(),
        Text(
          '${_localDrafts.length}/3',
          style: TextStyle(color: theme.hintColor, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildDraftsList(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.3)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: List.generate(_localDrafts.length, (index) {
            final draft = _localDrafts[index];
            final isLast = index == _localDrafts.length - 1;
            return Column(
              children: [
                _buildDraftItem(draft, index, theme),
                if (!isLast) const Divider(height: 1, indent: 60),
              ],
            );
          }),
        ),
      ),
    );
  }

  Widget _buildDraftItem(DraftPost draft, int index, ThemeData theme) {
    return Dismissible(
      key: Key(draft.id),
      direction: DismissDirection.startToEnd,
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        color: Colors.red,
        child: const Row(
          children: [
            Icon(Icons.delete, color: Colors.white),
            SizedBox(width: 8),
            Text(
              'Delete',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      onDismissed: (_) => _deleteDraft(draft.id, index),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: SisapaTheme.blue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            draft.mediaUrls.isNotEmpty ? Icons.image : Icons.text_fields,
            color: SisapaTheme.blue,
            size: 20,
          ),
        ),
        title: Text(
          draft.text.isEmpty ? 'Untitled Draft' : draft.text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          timeago.format(DateTime.fromMillisecondsSinceEpoch(draft.timestamp)),
          style: const TextStyle(fontSize: 11),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: 12,
          color: theme.hintColor,
        ),
        onTap: () => widget.onOpenDraft(draft),
      ),
    );
  }
}
