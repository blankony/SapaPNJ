import 'package:flutter/material.dart';
import 'dashboard/profile_page.dart';

class UserProfileScreen extends StatelessWidget {
  final String userId;
  const UserProfileScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return ProfilePage(
      userId: userId,
      includeScaffold: true,
    );
  }
}
