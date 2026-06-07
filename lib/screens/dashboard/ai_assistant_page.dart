import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/api_service.dart';
import 'package:share_plus/share_plus.dart';
import '../../main.dart';
import '../../theme/app_theme.dart';
import '../../services/ai_event_bus.dart';
import '../../widgets/common_error_widget.dart';
import '../../services/overlay_service.dart';
import '../../services/voice_service.dart';
import '../../services/app_localizations.dart'; // IMPORT LOCALIZATION
import '../../widgets/decorative_background.dart';
import 'ai_assistant/chat_bubble.dart';
import 'ai_assistant/chat_message.dart';
import 'ai_assistant/tts_manager.dart';

// --- MAIN PAGE ---
class AiAssistantPage extends StatefulWidget {
  const AiAssistantPage({super.key});

  @override
  State<AiAssistantPage> createState() => _AiAssistantPageState();
}

class _AiAssistantPageState extends State<AiAssistantPage>
    with TickerProviderStateMixin {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];

  bool _isTyping = false;
  bool _isLoadingHistory = false;
  bool _hasConnectionError = false;

  // --- VOICE STATE ---
  bool _isRecording = false;
  late AnimationController _micScaleController;

  String? _currentSessionId;
  StreamSubscription? _eventBusSubscription;

  final String _apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
  late GenerativeModel _model;
  late ChatSession _chatSession;

  late AnimationController _typingController;
  late TTSManager _ttsManager;

  // MODIFIED: Use JSON Keys instead of hardcoded strings
  final List<Map<String, dynamic>> _allSuggestions = [
    {'text': "ai_sugg_pnj", 'icon': Icons.school_outlined},
    {'text': "ai_sugg_bio", 'icon': Icons.edit_note},
    {'text': "ai_sugg_facilities", 'icon': Icons.map_outlined},
    {'text': "ai_sugg_scholarship", 'icon': Icons.school},
    {'text': "ai_sugg_orgs", 'icon': Icons.groups_outlined},
    {'text': "ai_sugg_calendar", 'icon': Icons.calendar_month_outlined},
    {'text': "ai_sugg_library", 'icon': Icons.access_time},
    {'text': "ai_sugg_admin", 'icon': Icons.contact_support_outlined},
    {'text': "ai_sugg_translate", 'icon': Icons.translate},
    {'text': "ai_sugg_email", 'icon': Icons.email_outlined},
  ];
  late List<Map<String, dynamic>> _activeSuggestions;

  final Content _systemInstruction = Content.system("""
      You are "Spirit AI", a friendly, intelligent, and spirited virtual assistant for the Politeknik Negeri Jakarta (PNJ) community app "Sapa PNJ".
      Your Persona: Name: Spirit AI, Tone: Energetic, helpful, polite. Language: English (default), adapt to user.
      Your Capabilities: Answer questions about campus life, academics, facilities. Assist drafting emails/bios. Provide support.
    """);

  @override
  void initState() {
    super.initState();
    _initModel();
    _ttsManager = TTSManager();
    _ttsManager.initialize();
    voiceService.initialize();

    _allSuggestions.shuffle();
    _activeSuggestions = _allSuggestions.take(3).toList();

    _typingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();

    _micScaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
      lowerBound: 1.0,
      upperBound: 1.25,
    );

    _eventBusSubscription = aiPageEventBus.stream.listen((event) {
      if (event.type == AiEventType.newChat) {
        _startNewChat();
      } else if (event.type == AiEventType.loadChat &&
          event.sessionId != null) {
        _loadChatSession(event.sessionId!);
      }
    });
  }

  @override
  void dispose() {
    _eventBusSubscription?.cancel();
    _textController.dispose();
    _scrollController.dispose();
    _typingController.dispose();
    _micScaleController.dispose();
    _ttsManager.dispose();
    if (_isRecording) voiceService.stopListening();
    super.dispose();
  }

  Future<void> _speak(String text) async {
    await _ttsManager.speak(context, text);
  }

  // --- VOICE INPUT HELPERS ---
  void _startRecording() {
    _ttsManager.stop();
    setState(() => _isRecording = true);
    _micScaleController.forward();
    if (hapticNotifier.value) HapticFeedback.heavyImpact();

    voiceService.startListening(
      onListeningStateChanged: (isListening) {},
      onResult: (text) {
        if (!mounted) return;
        setState(() {
          _textController.text = text;
          _textController.selection = TextSelection.fromPosition(
            TextPosition(offset: text.length),
          );
        });
      },
    );
  }

  void _stopRecording() {
    setState(() => _isRecording = false);
    _micScaleController.reverse();
    voiceService.stopListening();
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    // LOCALIZATION
    var t = AppLocalizations.of(context)!;
    OverlayService().showTopNotification(
      context,
      t.translate('ai_copied'),
      Icons.copy_rounded,
      () {},
    ); // "Copied to clipboard"
  }

  void _shareResponse(String text) {
    Share.share(text);
  }

  void _initModel() {
    if (_apiKey.isEmpty) {
      setState(() => _hasConnectionError = true);
      return;
    }
    try {
      _model = GenerativeModel(
        model: 'gemini-2.5-flash',
        apiKey: _apiKey,
        systemInstruction: _systemInstruction,
      );
      _chatSession = _model.startChat();
    } catch (e) {
      setState(() => _hasConnectionError = true);
    }
  }

  void _startNewChat() {
    setState(() {
      _messages.clear();
      _currentSessionId = null;
      _isTyping = false;
      _hasConnectionError = false;
      _chatSession = _model.startChat();
      _allSuggestions.shuffle();
      _activeSuggestions = _allSuggestions.take(3).toList();
      _ttsManager.stop();
    });
  }

  bool _isUserChatMessage(Map<String, dynamic> msg) {
    final rawValue = msg['is_user'] ?? msg['isUser'];
    if (rawValue is bool) return rawValue;
    if (rawValue is num) return rawValue != 0;
    if (rawValue is String) {
      final normalized = rawValue.trim().toLowerCase();
      return normalized == 'true' || normalized == '1';
    }
    return false;
  }

  Future<void> _loadChatSession(String sessionId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      _isLoadingHistory = true;
      _messages.clear();
      _hasConnectionError = false;
      _currentSessionId = sessionId;
    });

    try {
      final messages = await ApiService().getChatMessages(sessionId);

      final List<ChatMessage> loadedUiMessages = [];
      final List<Content> geminiHistory = [];
      String? lastRole;
      List<Part> bufferParts = [];

      for (var msg in messages) {
        final text = (msg['text'] ?? '').toString();
        final isUser = _isUserChatMessage(msg);
        final String currentRole = isUser ? 'user' : 'model';

        loadedUiMessages.add(
          ChatMessage(
            text: text,
            isUser: isUser,
            timestamp: msg['timestamp'] != null
                ? DateTime.tryParse(msg['timestamp']) ?? DateTime.now()
                : DateTime.now(),
          ),
        );

        if (lastRole == null) {
          lastRole = currentRole;
          bufferParts.add(TextPart(text));
        } else if (lastRole == currentRole) {
          bufferParts.add(TextPart("\n\n$text"));
        } else {
          geminiHistory.add(Content(lastRole, [...bufferParts]));
          lastRole = currentRole;
          bufferParts = [TextPart(text)];
        }
      }
      if (lastRole != null && bufferParts.isNotEmpty)
        geminiHistory.add(Content(lastRole, bufferParts));

      setState(() {
        _messages.addAll(loadedUiMessages);
        _isLoadingHistory = false;
        _chatSession = _model.startChat(history: geminiHistory);
      });
      _scrollToBottom();
    } catch (e) {
      setState(() {
        _isLoadingHistory = false;
        _hasConnectionError = true;
      });
    }
  }

  Future<void> _handleSubmitted(String text) async {
    _textController.clear();
    if (text.trim().isEmpty) return;

    // LOCALIZATION
    var t = AppLocalizations.of(context)!;

    _ttsManager.stop();
    final user = FirebaseAuth.instance.currentUser;

    setState(() {
      _messages.add(
        ChatMessage(text: text, isUser: true, timestamp: DateTime.now()),
      );
      _isTyping = true;
      _hasConnectionError = false;
    });
    _scrollToBottom();

    if (user != null) await _saveMessageToFirestore(user.uid, text, true);

    try {
      final response = await _chatSession.sendMessage(Content.text(text));
      final aiText =
          response.text ??
          t.translate('ai_error_catch'); // "I didn't catch that."

      if (mounted) {
        setState(() {
          _isTyping = false;
          _messages.add(
            ChatMessage(text: aiText, isUser: false, timestamp: DateTime.now()),
          );
        });
        _scrollToBottom();
        if (user != null)
          await _saveMessageToFirestore(user.uid, aiText, false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isTyping = false;
          _messages.add(
            ChatMessage(
              text: t.translate('ai_error_connection'),
              isUser: false,
              timestamp: DateTime.now(),
            ),
          ); // "Connection error..."
        });
        _scrollToBottom();
      }
    }
  }

  Future<void> _saveMessageToFirestore(
    String uid,
    String text,
    bool isUser,
  ) async {
    try {
      if (_currentSessionId == null) {
        String title = text.replaceAll('\n', ' ');
        if (title.length > 30) title = "${title.substring(0, 30)}...";
        if (!isUser) title = "New Chat";
        final newSessionId = await ApiService().createChatSession(title: title);
        _currentSessionId = newSessionId;
      }
      await ApiService().saveChatMessage(
        _currentSessionId!,
        text: text,
        isUser: isUser,
      );
    } catch (e) {
      debugPrint("Error saving chat message: $e");
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutQuart,
        );
      }
    });
  }

  void _handleHorizontalSwipe(DragEndDetails details) {
    if (details.primaryVelocity! > 0)
      Scaffold.of(context).openDrawer();
    else if (details.primaryVelocity! < 0)
      Scaffold.of(context).openEndDrawer();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // LOCALIZATION
    var t = AppLocalizations.of(context)!;

    if (_isLoadingHistory)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_hasConnectionError && _messages.isEmpty) {
      return Scaffold(
        body: CommonErrorWidget(
          message: t.translate(
            'ai_error_connect_spirit',
          ), // "Unable to connect..."
          isConnectionError: true,
          onRetry: () => _startNewChat(),
        ),
      );
    }

    return GestureDetector(
      onHorizontalDragEnd: _handleHorizontalSwipe,
      child: Scaffold(
        body: Stack(
          children: [
            if (_messages.isEmpty) ...[
              const Positioned.fill(child: DecorativeBackground()),
            ],
            Column(
              children: [
                Expanded(
                  child: _messages.isEmpty
                      ? _buildEmptyState(theme, isDark, t)
                      : _buildChatList(theme, isDark, t),
                ),
                _buildInputArea(theme, isDark, t),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, bool isDark, AppLocalizations t) {
    return SingleChildScrollView(
      child: Container(
        height: MediaQuery.of(context).size.height,
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(height: kToolbarHeight + 40),
            Container(
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.cardColor,
                boxShadow: [
                  BoxShadow(
                    color: SisapaTheme.blue.withOpacity(0.25),
                    blurRadius: 30,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Image.asset('images/app_icon.png', height: 70, width: 70),
            ),
            const SizedBox(height: 32),
            Text(
              "Spirit AI",
              style: theme.textTheme.displayMedium?.copyWith(
                fontWeight: FontWeight.w900,
                color: SisapaTheme.blue,
              ),
            ),
            Text(
              t.translate('ai_subtitle'),
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.hintColor,
                fontWeight: FontWeight.normal,
              ),
            ), // "Your Virtual Assistant"
            const SizedBox(height: 40),
            Column(
              children: _activeSuggestions.map((suggestion) {
                // Translate the key from the list
                String displayText = t.translate(suggestion['text']);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: _buildShortcutCard(
                    theme,
                    displayText,
                    suggestion['icon'] as IconData,
                  ),
                );
              }).toList(),
            ),
            Spacer(flex: 3),
          ],
        ),
      ),
    );
  }

  Widget _buildShortcutCard(ThemeData theme, String text, IconData icon) {
    return InkWell(
      onTap: () => _handleSubmitted(text),
      borderRadius: BorderRadius.circular(16),
      child: FrostedSurface(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        borderRadius: BorderRadius.circular(16),
        tint: theme.cardColor.withOpacity(
          theme.brightness == Brightness.dark ? 0.78 : 0.74,
        ),
        blur: FrostedGlassTokens.blurSigma,
        border: Border.all(color: theme.dividerColor.withOpacity(0.5)),
        boxShadow: FrostedGlassTokens.materialDepth(context),
        child: Row(
          children: [
            Icon(icon, color: SisapaTheme.blue, size: 20),
            SizedBox(width: 16),
            Expanded(
              child: Text(
                text,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 12, color: theme.hintColor),
          ],
        ),
      ),
    );
  }

  Widget _buildChatList(ThemeData theme, bool isDark, AppLocalizations t) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, kToolbarHeight + 60, 16, 16),
      itemCount: _messages.length + (_isTyping ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _messages.length) return _buildTypingIndicator(theme, t);
        return ChatBubble(
          message: _messages[index],
          onSpeak: _speak,
          onCopy: _copyToClipboard,
          onShare: _shareResponse,
        );
      },
    );
  }

  Widget _buildTypingIndicator(ThemeData theme, AppLocalizations t) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, left: 0),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: SisapaTheme.blue.withOpacity(0.1),
            child: Image.asset(
              'images/app_icon.png',
              height: 16,
              color: SisapaTheme.blue,
            ),
          ),
          SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(20),
                bottomRight: Radius.circular(20),
                bottomLeft: Radius.circular(20),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 5,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: FadeTransition(
              opacity: _typingController,
              child: Text(
                t.translate('ai_thinking'),
                style: TextStyle(color: theme.hintColor, fontSize: 12),
              ),
            ), // "Thinking..."
          ),
        ],
      ),
    );
  }

  // --- MODIFIED INPUT AREA: Unified Button ---
  Widget _buildInputArea(ThemeData theme, bool isDark, AppLocalizations t) {
    final bool hasText = _textController.text.trim().isNotEmpty;
    // Show Mic if no text OR if actively recording (so button doesn't switch while holding)
    final bool showMic = !hasText || _isRecording;

    return FrostedSurface(
      padding: EdgeInsets.fromLTRB(
        12,
        12,
        12,
        MediaQuery.of(context).padding.bottom + 12,
      ),
      tint: theme.scaffoldBackgroundColor.withOpacity(isDark ? 0.86 : 0.82),
      blur: FrostedGlassTokens.strongBlurSigma,
      border: Border(
        top: FrostedGlassTokens.subtleBorderSide(context, opacity: 0.24),
      ),
      child: Row(
        children: [
          // Expanded Input
          Expanded(
            child: FrostedSurface(
              borderRadius: BorderRadius.circular(30),
              tint: (isDark ? SisapaTheme.darkGrey : SisapaTheme.extraLightGrey)
                  .withOpacity(isDark ? 0.36 : 0.68),
              blur: FrostedGlassTokens.controlBlurSigma,
              child: TextField(
                controller: _textController,
                onSubmitted: _isTyping ? null : _handleSubmitted,
                // --- UPDATE STATE ON CHANGE ---
                onChanged: (val) {
                  setState(() {}); // Updates the button state
                },
                textCapitalization: TextCapitalization.sentences,
                style: TextStyle(fontSize: 16),
                decoration: InputDecoration(
                  hintText: _isRecording
                      ? t.translate('ai_listening') // "Listening..."
                      : t.translate('ai_hint'), // "Ask Spirit AI..."
                  hintStyle: TextStyle(
                    color: _isRecording ? SisapaTheme.blue : theme.hintColor,
                    fontWeight: _isRecording
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  isDense: true,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // --- DYNAMIC BUTTON (Mic or Send) ---
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, animation) =>
                ScaleTransition(scale: animation, child: child),
            child: showMic
                ? Listener(
                    key: const ValueKey('mic_btn'),
                    onPointerDown: (_) => _startRecording(),
                    onPointerUp: (_) => _stopRecording(),
                    onPointerCancel: (_) => _stopRecording(),
                    child: ScaleTransition(
                      scale: _micScaleController,
                      child: FrostedSurface(
                        padding: EdgeInsets.all(12),
                        shape: BoxShape.circle,
                        tint: (_isRecording ? Colors.red : theme.cardColor)
                            .withOpacity(
                              _isRecording ? 0.84 : (isDark ? 0.78 : 0.74),
                            ),
                        blur: FrostedGlassTokens.controlBlurSigma,
                        border: Border.all(
                          color: _isRecording ? Colors.red : theme.dividerColor,
                        ),
                        child: Icon(
                          _isRecording ? Icons.mic : Icons.mic_none_rounded,
                          color: _isRecording
                              ? Colors.white
                              : theme.primaryColor,
                          size: 24,
                        ),
                      ),
                    ),
                  )
                : GestureDetector(
                    key: const ValueKey('send_btn'),
                    onTap: _isTyping
                        ? null
                        : () => _handleSubmitted(_textController.text),
                    child: FrostedSurface(
                      padding: EdgeInsets.all(12),
                      shape: BoxShape.circle,
                      tint: (_isTyping ? theme.disabledColor : SisapaTheme.blue)
                          .withOpacity(_isTyping ? 0.7 : 0.82),
                      blur: FrostedGlassTokens.controlBlurSigma,
                      boxShadow: _isTyping
                          ? null
                          : FrostedGlassTokens.materialDepth(context),
                      child: Icon(
                        Icons.send_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
