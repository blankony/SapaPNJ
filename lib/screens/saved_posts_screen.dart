import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/api_service.dart';
import '../widgets/blog_post_card.dart';
import '../widgets/common_error_widget.dart';
import '../main.dart';
import '../theme/app_theme.dart';
import '../theme/avatar_helper.dart';

class SavedPostsScreen extends StatefulWidget {
  const SavedPostsScreen({super.key});

  @override
  State<SavedPostsScreen> createState() => _SavedPostsScreenState();
}

class _SavedPostsScreenState extends State<SavedPostsScreen> {
  late Future<List<Map<String, dynamic>>> _bookmarksFuture;

  @override
  void initState() {
    super.initState();
    _refreshBookmarks();
  }

  void _refreshBookmarks() {
    setState(() {
      _bookmarksFuture = ApiService().getBookmarks();
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Scaffold(body: Center(child: Text("Please log in")));

    return Scaffold(
      appBar: AppBar(
        title: const Text("Saved Posts"),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          _refreshBookmarks();
          await _bookmarksFuture.catchError((_) => <Map<String, dynamic>>[]);
        },
        color: SisapaTheme.blue,
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _bookmarksFuture,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
               return CommonErrorWidget(message: "Error loading bookmarks", isConnectionError: true);
            }
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final posts = snapshot.data ?? [];

            if (posts.isEmpty) {
               return ListView(
                 physics: const AlwaysScrollableScrollPhysics(),
                 children: [
                   SizedBox(height: MediaQuery.of(context).size.height * 0.3),
                   Center(
                     child: Column(
                       mainAxisAlignment: MainAxisAlignment.center,
                       children: [
                         Icon(Icons.bookmark_border, size: 64, color: Theme.of(context).hintColor.withOpacity(0.5)),
                         const SizedBox(height: 16),
                         Text("No saved posts yet", style: TextStyle(color: Theme.of(context).hintColor)),
                       ],
                     ),
                   ),
                 ],
               );
            }

            return ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: posts.length,
              itemBuilder: (context, index) {
                final postData = posts[index];
                final postId = postData['id'] ?? '';

                return BlogPostCard(
                  postId: postId,
                  postData: postData,
                  isOwner: postData['user_uid'] == user.uid || postData['userId'] == user.uid,
                  heroContextId: 'saved_posts', // Unique hero tag context
                );
              },
            );
          },
        ),
      ),
    );
  }
}
