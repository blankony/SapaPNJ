import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../theme/app_theme.dart';
import '../services/api_service.dart';

class AiHistoryDrawer extends StatefulWidget {
  final Function(String sessionId) onChatSelected;
  final VoidCallback onNewChat;

  const AiHistoryDrawer({
    super.key,
    required this.onChatSelected,
    required this.onNewChat,
  });

  @override
  State<AiHistoryDrawer> createState() => _AiHistoryDrawerState();
}

class _AiHistoryDrawerState extends State<AiHistoryDrawer> {
  final User? _user = FirebaseAuth.instance.currentUser;
  bool _isLoading = true;
  List<Map<String, dynamic>> _sessions = [];

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    if (_user == null) return;
    setState(() => _isLoading = true);
    try {
      final sessionsList = await ApiService().getChatSessions();
      if (mounted) {
        setState(() {
          _sessions = sessionsList;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteSession(String sessionId) async {
    try {
      final success = await ApiService().deleteChatSession(sessionId);
      if (success) {
        _loadSessions();
      }
    } catch (e) {
      debugPrint("Error deleting session: $e");
    }
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return "";
    try {
      final parsedDate = DateTime.parse(timestamp.toString());
      return timeago.format(parsedDate, locale: 'en_short');
    } catch (_) {
      return "";
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Drawer(
      backgroundColor: theme.scaffoldBackgroundColor,
      child: Column(
        children: [
          // --- HEADER PANEL ---
          SafeArea(
            bottom: false,
            child: Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: theme.dividerColor)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Chat History",
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: SisapaTheme.blue
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close, color: theme.hintColor),
                        onPressed: () => Navigator.pop(context),
                      )
                    ],
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      widget.onNewChat();
                    },
                    icon: const Icon(Icons.add_comment_rounded, color: Colors.white),
                    label: const Text("New Chat"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: SisapaTheme.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // --- LIST HISTORY ---
          Expanded(
            child: _user == null
                ? const Center(child: Text("Please log in."))
                : _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _sessions.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.history_toggle_off, size: 64, color: theme.hintColor.withOpacity(0.3)),
                                const SizedBox(height: 16),
                                Text("No history yet", style: TextStyle(color: theme.hintColor)),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: _sessions.length,
                            separatorBuilder: (context, index) => Divider(height: 1, color: theme.dividerColor.withOpacity(0.3)),
                            itemBuilder: (context, index) {
                              final session = _sessions[index];
                              final String sessionId = session['id'];
                              final String title = session['title'] ?? 'New Conversation';
                              final dynamic timestamp = session['last_updated'] ?? session['lastUpdated'];

                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                title: Text(
                                  title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.w500),
                                ),
                                subtitle: Text(
                                  _formatTimestamp(timestamp),
                                  style: TextStyle(fontSize: 12, color: theme.hintColor),
                                ),
                                onTap: () {
                                  Navigator.pop(context);
                                  widget.onChatSelected(sessionId);
                                },
                                trailing: IconButton(
                                  icon: Icon(Icons.delete_outline, size: 20, color: theme.hintColor),
                                  onPressed: () {
                                    showDialog(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: const Text("Delete Chat?"),
                                        content: const Text("This conversation will be deleted permanently."),
                                        actions: [
                                          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
                                          TextButton(
                                            onPressed: () {
                                              _deleteSession(sessionId);
                                              Navigator.pop(ctx);
                                            },
                                            child: const Text("Delete", style: TextStyle(color: Colors.red)),
                                          )
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
