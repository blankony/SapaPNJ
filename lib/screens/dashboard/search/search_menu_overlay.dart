import 'package:flutter/material.dart';

import '../../../services/app_localizations.dart';
import '../../../theme/app_theme.dart';

class SearchMenuOverlay extends StatelessWidget {
  static const double baseHeight = 70.0;
  static const double suggestionHeight = 30.0;

  final bool isSearching;
  final double screenWidth;
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isListening;
  final String? suggestion;
  final Animation<double> micScale;
  final VoidCallback onClearSearch;
  final Future<void> Function() onStartListening;
  final VoidCallback onStopListening;
  final ValueChanged<String> onChanged;
  final VoidCallback onApplySuggestion;

  const SearchMenuOverlay({
    super.key,
    required this.isSearching,
    required this.screenWidth,
    required this.controller,
    required this.focusNode,
    required this.isListening,
    required this.suggestion,
    required this.micScale,
    required this.onClearSearch,
    required this.onStartListening,
    required this.onStopListening,
    required this.onChanged,
    required this.onApplySuggestion,
  });

  static double heightFor({
    required bool isSearching,
    required bool hasSuggestion,
  }) {
    if (!isSearching) return 0.0;
    return baseHeight + (hasSuggestion ? suggestionHeight : 0.0);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final overlayHeight = heightFor(
      isSearching: isSearching,
      hasSuggestion: suggestion != null,
    );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOutQuart,
      width: isSearching ? screenWidth : 0,
      height: overlayHeight,
      child: FrostedSurface(
        borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(20)),
        tint: theme.scaffoldBackgroundColor.withValues(alpha: 0.82),
        blur: FrostedGlassTokens.controlBlurSigma,
        child: isSearching
            ? SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                child: Column(
                  children: [
                    _SearchField(
                      screenWidth: screenWidth,
                      controller: controller,
                      focusNode: focusNode,
                      isListening: isListening,
                      micScale: micScale,
                      onClearSearch: onClearSearch,
                      onStartListening: onStartListening,
                      onStopListening: onStopListening,
                      onChanged: onChanged,
                    ),
                    if (suggestion != null)
                      _SearchSuggestion(
                        suggestion: suggestion!,
                        onApplySuggestion: onApplySuggestion,
                      ),
                  ],
                ),
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  final double screenWidth;
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isListening;
  final Animation<double> micScale;
  final VoidCallback onClearSearch;
  final Future<void> Function() onStartListening;
  final VoidCallback onStopListening;
  final ValueChanged<String> onChanged;

  const _SearchField({
    required this.screenWidth,
    required this.controller,
    required this.focusNode,
    required this.isListening,
    required this.micScale,
    required this.onClearSearch,
    required this.onStartListening,
    required this.onStopListening,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context)!;

    return Container(
      width: screenWidth,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Center(
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          autofocus: false,
          readOnly: isListening,
          decoration: InputDecoration(
            hintText: isListening
                ? t.translate('search_listening')
                : t.translate('search_hint'),
            hintStyle: TextStyle(
              color: isListening ? SisapaTheme.blue : theme.hintColor,
              fontStyle: isListening ? FontStyle.italic : FontStyle.normal,
              fontWeight: isListening ? FontWeight.bold : FontWeight.normal,
            ),
            prefixIcon: const Icon(Icons.search),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (controller.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: onClearSearch,
                  ),
                _VoiceSearchButton(
                  isListening: isListening,
                  micScale: micScale,
                  onStartListening: onStartListening,
                  onStopListening: onStopListening,
                ),
              ],
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30),
              borderSide: BorderSide.none,
            ),
            filled: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 0,
            ),
          ),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _VoiceSearchButton extends StatelessWidget {
  final bool isListening;
  final Animation<double> micScale;
  final Future<void> Function() onStartListening;
  final VoidCallback onStopListening;

  const _VoiceSearchButton({
    required this.isListening,
    required this.micScale,
    required this.onStartListening,
    required this.onStopListening,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Listener(
      onPointerDown: (_) => onStartListening(),
      onPointerUp: (_) => onStopListening(),
      onPointerCancel: (_) => onStopListening(),
      child: Padding(
        padding: const EdgeInsets.only(right: 12.0, left: 4.0),
        child: ScaleTransition(
          scale: micScale,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isListening ? Colors.red : Colors.transparent,
              boxShadow: isListening
                  ? [
                      BoxShadow(
                        color: Colors.red.withValues(alpha: 0.4),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ]
                  : null,
            ),
            child: Icon(
              isListening ? Icons.mic : Icons.mic_none,
              color: isListening ? Colors.white : theme.primaryColor,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchSuggestion extends StatelessWidget {
  final String suggestion;
  final VoidCallback onApplySuggestion;

  const _SearchSuggestion({
    required this.suggestion,
    required this.onApplySuggestion,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context)!;

    return InkWell(
      onTap: onApplySuggestion,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8.0, left: 24.0, right: 24.0),
        child: Row(
          children: [
            const Icon(
              Icons.lightbulb_outline,
              size: 14,
              color: SisapaTheme.blue,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: TextStyle(
                    color: theme.textTheme.bodyMedium?.color,
                    fontSize: 13,
                  ),
                  children: [
                    TextSpan(text: t.translate('search_suggestion_prefix')),
                    TextSpan(
                      text: suggestion,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: SisapaTheme.blue,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
