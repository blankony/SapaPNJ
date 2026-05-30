import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'screens/user_info_screen.dart';
import 'screens/dashboard/home_dashboard.dart';
import 'services/api_service.dart';

class DecisionGate extends StatefulWidget {
  const DecisionGate({super.key});

  @override
  State<DecisionGate> createState() => _DecisionGateState();
}

class _DecisionGateState extends State<DecisionGate> {
  final ApiService _api = ApiService();

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;

    // If user is null, return to loading
    if (user == null) {
       return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // 1. Check Profile Completeness (Name & NIM) via API
    return FutureBuilder<Map<String, dynamic>?>(
      future: _api.getUser(user.uid),
      builder: (context, snapshot) {
        // Loading profile check
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // Error fetching data
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(child: Text('Error: ${snapshot.error}')),
          );
        }

        // User not found in DB
        if (!snapshot.hasData || snapshot.data == null) {
           // Navigate to UserInfoScreen to complete profile
          return const UserInfoScreen(isSetupWizard: true);
        }

        final data = snapshot.data!;
        final String? name = data['name'] as String?;
        final String? nim = data['nim'] as String?;

        if (name == null || name.isEmpty || nim == null || nim.isEmpty) {
           // Navigate to UserInfoScreen to complete profile
          return const UserInfoScreen(isSetupWizard: true);
        }

        // 2. Profile complete, navigate to main dashboard
        return const HomeDashboard();
      },
    );
  }
}
