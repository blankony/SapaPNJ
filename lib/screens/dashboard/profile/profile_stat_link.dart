import 'package:flutter/material.dart';

import '../../follow_list_screen.dart';

class ProfileStatLink extends StatelessWidget {
  final String userId;
  final int count;
  final String label;
  final int tabIndex;

  const ProfileStatLink({
    super.key,
    required this.userId,
    required this.count,
    required this.label,
    required this.tabIndex,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                FollowListScreen(userId: userId, initialIndex: tabIndex),
          ),
        );
      },
      child: Row(
        children: [
          Text('$count', style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: Theme.of(context).hintColor)),
        ],
      ),
    );
  }
}
