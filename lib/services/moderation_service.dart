import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'api_service.dart';

class ModerationService {

  // --- REPORTING ---

  Future<void> reportContent({
    required String targetId,
    required String targetType, // 'post', 'comment', 'user'
    required String reason,
    String? description,
  }) async {
    final user = FirebaseAuth.instance.currentUser;

    final String subject = "SAPA PNJ Report: $targetType ($reason)";
    final String body = "Reporter ID: ${user?.uid ?? 'Anonymous'}\n"
        "Target ID: $targetId\n"
        "Target Type: $targetType\n"
        "Reason: $reason\n"
        "Description: ${description ?? 'No details provided'}\n\n"
        "Time: ${DateTime.now()}\n\n"
        "Please review this content.";

    // Construct the mailto URI
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: 'arnoldholyridho@gmail.com,aryastiawn@gmail.com',
      query: _encodeQueryParameters(<String, String>{
        'subject': subject,
        'body': body,
      }),
    );

    try {
      // Try to launch the email app
      await launchUrl(emailLaunchUri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint("Could not launch email client: $e");
    }
  }

  // Helper to encode query parameters properly
  String? _encodeQueryParameters(Map<String, String> params) {
    return params.entries
        .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
  }

  // --- BLOCKING ---

  Future<void> blockUser(String targetUserId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.uid == targetUserId) return;
    await ApiService().blockUser(targetUserId);
  }

  Future<void> unblockUser(String targetUserId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await ApiService().unblockUser(targetUserId);
  }

  Stream<List<String>> streamBlockedUsers() async* {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      yield [];
      return;
    }
    // Yield first immediately
    try {
      yield await ApiService().getBlockedUsers();
    } catch (_) {
      yield [];
    }
    // Yield every 30 seconds
    yield* Stream.periodic(const Duration(seconds: 30), (_) async {
      try {
        return await ApiService().getBlockedUsers();
      } catch (_) {
        return <String>[];
      }
    }).asyncMap((event) => event);
  }
}

// Global Instance
final moderationService = ModerationService();
