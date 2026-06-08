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
import '../../widgets/common/common_error_widget.dart';
import '../../services/overlay_service.dart';
import '../../services/voice_service.dart';
import '../../services/app_localizations.dart'; // IMPORT LOCALIZATION
import '../../widgets/common/decorative_background.dart';
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
  static const int _chatHistorySummaryInterval = 10;
  static const int _recentMessagesKeptForContext = 6;
  static const int _summaryTranscriptCharacterLimit = 7000;
  static const int _summaryCharacterLimit = 1600;
  static const int _chatMaxOutputTokens = 700;
  static const int _summaryMaxOutputTokens = 220;

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
  late GenerativeModel _summaryModel;
  late ChatSession _chatSession;
  int _historyContextRevision = 0;
  int _lastCompactedMessageCount = 0;
  int _summarizedMessageCount = 0;
  String? _conversationSummary;

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
      You are "Spirit AI", the friendly virtual assistant inside Sapa PNJ.

      Core identity:
      - App: Sapa PNJ, a Flutter social and communication platform for the Politeknik Negeri Jakarta (PNJ) community.
      - Development team: Arnold Holyridho R. (2303421041) and Arya Setiawan (2303421026). Mention this only when asked about the creator, developer, or development team.
      - Persona: energetic, helpful, polite, and concise. Use the user's language when clear; otherwise default to English.
      - Scope: You are a general-purpose assistant. Help users draft, translate, summarize, brainstorm, plan, study, write, explain, and make things even when the request is not about Sapa PNJ or PNJ.

      PNJ knowledge:
      - PNJ stands for Politeknik Negeri Jakarta, a vocational higher education institution.
      - PNJ was formerly Politeknik Universitas Indonesia/Fakultas Non-Gelar Teknologi (FNgT) and became Politeknik Negeri Jakarta based on Ministerial Decree No. 207/O/1998.
      - Main address: Jl. Prof. DR. G.A. Siwabessy, Kampus Universitas Indonesia, Depok 16425.
      - Official contact references: pnj.ac.id, penerimaan.pnj.ac.id, humas@pnj.ac.id, and phone 021-7270036 ext. 217.
      - PNJ has seven main departments: Teknik Sipil, Teknik Mesin, Teknik Elektro, Teknik Informatika & Komputer, Teknik Grafika & Penerbitan, Akuntansi, and Administrasi Niaga, plus Pascasarjana.
      - PNJ offers vocational levels including D-3/Ahli Madya, Sarjana Terapan, and Magister Terapan.
      - For current admissions, schedules, fees, announcements, or policy details, guide users to the official PNJ or penerimaan PNJ pages instead of inventing details.

      App navigation knowledge:
      - Home tab: main feed, recommended feed, top-right notifications, and the floating edit button for creating posts.
      - Community tab: user's channels, community broadcasts, browse/create communities, channel pages, and official community posting.
      - AI Assistant tab: this chat. Use the top-right history icon/end drawer for chat history and starting a new chat.
      - Search tab: posts, users, and communities. Tap the Search tab, then the app-bar search icon/input.
      - Profile tab: the user's profile, posts/reposts/replies, edit profile, follow stats, and profile verification shortcuts.
      - Side drawer: tap the app-bar avatar/menu to open Account Center, Communities, PNJ Services, Saved Posts, Settings, language/theme, and logout.
      - PNJ Services in the side drawer: SPIRIT Academia, E-Learning PNJ, Akademik PNJ, and the official PNJ website.
      - Account Center: email and Google account status, KTM verification, Admin Panel for admins, and profile/account settings.
      - Settings: Account Center, notification preferences, blocked users, About Us, language, theme, and logout.

      Behavior:
      - Do not force every answer back to PNJ or Sapa PNJ. Answer the user's actual request first.
      - When the user asks where something is located in this app, answer with direct UI steps and tab names.
      - When the user asks about PNJ, answer from the PNJ knowledge above and clearly say when the latest official page should be checked.
      - If a feature location is uncertain, give the closest likely path and say what to tap next.
      - Keep answers brief by default, but provide longer structured help when the user asks for creation, explanation, planning, or drafting.
      - Do not repeat the full chat history. If a conversation summary is present, use it silently as context.
    """);

  final Content _summaryInstruction = Content.system("""
      You summarize Spirit AI conversations for compact future context.
      Preserve user goals, preferences, app-navigation needs, decisions, unresolved requests, and important PNJ/Sapa PNJ context.
      Do not add facts that are not in the transcript.
      Keep the summary short and useful for the next assistant response.
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
        generationConfig: GenerationConfig(
          maxOutputTokens: _chatMaxOutputTokens,
        ),
        systemInstruction: _systemInstruction,
      );
      _summaryModel = GenerativeModel(
        model: 'gemini-2.5-flash',
        apiKey: _apiKey,
        generationConfig: GenerationConfig(
          maxOutputTokens: _summaryMaxOutputTokens,
          temperature: 0.2,
        ),
        systemInstruction: _summaryInstruction,
      );
      _chatSession = _model.startChat();
    } catch (e) {
      setState(() => _hasConnectionError = true);
    }
  }

  void _startNewChat() {
    _historyContextRevision++;
    setState(() {
      _messages.clear();
      _currentSessionId = null;
      _isTyping = false;
      _hasConnectionError = false;
      _chatSession = _model.startChat();
      _lastCompactedMessageCount = 0;
      _summarizedMessageCount = 0;
      _conversationSummary = null;
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

  List<Content> _buildGeminiHistory(List<ChatMessage> messages) {
    final List<Content> geminiHistory = [];
    String? lastRole;
    List<Part> bufferParts = [];

    for (final message in messages) {
      final text = message.text.trim();
      if (text.isEmpty) continue;

      final currentRole = message.isUser ? 'user' : 'model';
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

    if (lastRole != null && bufferParts.isNotEmpty) {
      geminiHistory.add(Content(lastRole, bufferParts));
    }

    return geminiHistory;
  }

  int _summaryEndIndex(List<ChatMessage> messages) {
    int summaryEnd = messages.length - _recentMessagesKeptForContext;
    if (summaryEnd <= 0) return 0;

    if (messages.first.isUser && summaryEnd.isOdd) {
      summaryEnd -= 1;
    }

    return summaryEnd;
  }

  String _truncateFromEnd(String text, int maxCharacters) {
    if (text.length <= maxCharacters) return text;
    return text.substring(text.length - maxCharacters);
  }

  String _formatTranscript(List<ChatMessage> messages) {
    final buffer = StringBuffer();
    for (final message in messages) {
      final text = message.text.trim();
      if (text.isEmpty) continue;

      final speaker = message.isUser ? 'User' : 'Spirit AI';
      buffer.writeln('$speaker: $text');
      buffer.writeln();
    }

    return _truncateFromEnd(
      buffer.toString().trim(),
      _summaryTranscriptCharacterLimit,
    );
  }

  Future<String?> _summarizeMessages(
    List<ChatMessage> messages, {
    String? previousSummary,
  }) async {
    if (messages.isEmpty && previousSummary == null) return null;

    final transcript = _formatTranscript(messages);
    final prompt =
        """
Summarize this Spirit AI conversation for future replies.

Existing summary, if any:
${previousSummary?.trim().isNotEmpty == true ? previousSummary!.trim() : 'None'}

New transcript to merge:
${transcript.isNotEmpty ? transcript : 'No new transcript.'}

Return a concise summary only.
""";

    try {
      final response = await _summaryModel.generateContent([
        Content.text(prompt),
      ]);
      final summary = response.text?.trim();
      if (summary == null || summary.isEmpty) return null;
      return _truncateFromEnd(summary, _summaryCharacterLimit);
    } catch (e) {
      debugPrint("Error summarizing chat history: $e");
      return null;
    }
  }

  Future<_GeminiHistoryContext> _buildGeminiHistoryContext(
    List<ChatMessage> messages, {
    bool forceCompact = false,
    required int lastCompactedMessageCount,
    required int summarizedMessageCount,
    required String? previousSummary,
  }) async {
    final shouldCompact =
        messages.length >= _chatHistorySummaryInterval &&
        (forceCompact ||
            messages.length - lastCompactedMessageCount >=
                _chatHistorySummaryInterval);

    if (!shouldCompact) {
      return _GeminiHistoryContext(
        history: _buildGeminiHistory(messages),
        lastCompactedMessageCount: lastCompactedMessageCount,
        summarizedMessageCount: summarizedMessageCount,
        summary: previousSummary,
      );
    }

    final summaryEnd = _summaryEndIndex(messages);
    if (summaryEnd <= summarizedMessageCount) {
      return _GeminiHistoryContext(
        history: _buildGeminiHistory(messages),
        lastCompactedMessageCount: lastCompactedMessageCount,
        summarizedMessageCount: summarizedMessageCount,
        summary: previousSummary,
      );
    }

    final messagesToSummarize = messages.sublist(
      summarizedMessageCount,
      summaryEnd,
    );
    final summary = await _summarizeMessages(
      messagesToSummarize,
      previousSummary: previousSummary,
    );

    if (summary == null) {
      return _GeminiHistoryContext(
        history: _buildGeminiHistory(messages),
        lastCompactedMessageCount: lastCompactedMessageCount,
        summarizedMessageCount: summarizedMessageCount,
        summary: previousSummary,
      );
    }

    final recentMessages = messages.sublist(summaryEnd);
    return _GeminiHistoryContext(
      history: [
        Content('user', [TextPart('Conversation summary so far:\n$summary')]),
        Content.model([
          TextPart(
            'Understood. I will use this summary as context and continue from the recent messages.',
          ),
        ]),
        ..._buildGeminiHistory(recentMessages),
      ],
      lastCompactedMessageCount: messages.length,
      summarizedMessageCount: summaryEnd,
      summary: summary,
    );
  }

  Future<void> _compactChatHistoryIfNeeded() async {
    final revision = _historyContextRevision;
    final messagesSnapshot = List<ChatMessage>.from(_messages);
    final shouldCompact =
        messagesSnapshot.length >= _chatHistorySummaryInterval &&
        messagesSnapshot.length - _lastCompactedMessageCount >=
            _chatHistorySummaryInterval;

    if (!shouldCompact) return;

    final historyContext = await _buildGeminiHistoryContext(
      messagesSnapshot,
      lastCompactedMessageCount: _lastCompactedMessageCount,
      summarizedMessageCount: _summarizedMessageCount,
      previousSummary: _conversationSummary,
    );

    if (!mounted || revision != _historyContextRevision) return;

    _chatSession = _model.startChat(history: historyContext.history);
    _lastCompactedMessageCount = historyContext.lastCompactedMessageCount;
    _summarizedMessageCount = historyContext.summarizedMessageCount;
    _conversationSummary = historyContext.summary;
  }

  Future<void> _loadChatSession(String sessionId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final loadRevision = ++_historyContextRevision;
    setState(() {
      _isLoadingHistory = true;
      _messages.clear();
      _hasConnectionError = false;
      _currentSessionId = sessionId;
      _chatSession = _model.startChat();
      _lastCompactedMessageCount = 0;
      _summarizedMessageCount = 0;
      _conversationSummary = null;
    });

    try {
      final messages = await ApiService().getChatMessages(sessionId);

      final List<ChatMessage> loadedUiMessages = [];

      for (var msg in messages) {
        final text = (msg['text'] ?? '').toString();
        final isUser = _isUserChatMessage(msg);

        loadedUiMessages.add(
          ChatMessage(
            text: text,
            isUser: isUser,
            timestamp: msg['timestamp'] != null
                ? DateTime.tryParse(msg['timestamp']) ?? DateTime.now()
                : DateTime.now(),
          ),
        );
      }

      final historyContext = await _buildGeminiHistoryContext(
        loadedUiMessages,
        forceCompact: true,
        lastCompactedMessageCount: 0,
        summarizedMessageCount: 0,
        previousSummary: null,
      );

      if (!mounted || loadRevision != _historyContextRevision) return;

      setState(() {
        _messages.addAll(loadedUiMessages);
        _isLoadingHistory = false;
        _chatSession = _model.startChat(history: historyContext.history);
        _lastCompactedMessageCount = historyContext.lastCompactedMessageCount;
        _summarizedMessageCount = historyContext.summarizedMessageCount;
        _conversationSummary = historyContext.summary;
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted || loadRevision != _historyContextRevision) return;
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
      _historyContextRevision++;
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
          _historyContextRevision++;
        });
        _scrollToBottom();
        if (user != null)
          await _saveMessageToFirestore(user.uid, aiText, false);
        unawaited(_compactChatHistoryIfNeeded());
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
          _historyContextRevision++;
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
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
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

class _GeminiHistoryContext {
  final List<Content> history;
  final int lastCompactedMessageCount;
  final int summarizedMessageCount;
  final String? summary;

  const _GeminiHistoryContext({
    required this.history,
    required this.lastCompactedMessageCount,
    required this.summarizedMessageCount,
    required this.summary,
  });
}
