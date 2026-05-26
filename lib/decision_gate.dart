import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'screens/user_info_screen.dart';
import 'screens/dashboard/home_dashboard.dart';

// Instances

class DecisionGate extends StatefulWidget {
  const DecisionGate({super.key});

  @override
  State<DecisionGate> createState() => _DecisionGateState();
}

class _DecisionGateState extends State<DecisionGate> {

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;

    // If user is null, return to loading
    if (user == null) {
       return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // 1. Check Profile Completeness (Name & NIM) in Firestore
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
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

        // Document not found, or 'name'/'nim' fields are null or empty
        if (!snapshot.hasData || !snapshot.data!.exists) {
           // Navigate to UserInfoScreen to complete profile
          return const UserInfoScreen();
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final String? name = data['name'] as String?;
        final String? nim = data['nim'] as String?;

        if (name == null || name.isEmpty || nim == null || nim.isEmpty) {
           // Navigate to UserInfoScreen to complete profile
          return const UserInfoScreen();
        }

        // 2. Profile complete, navigate to main dashboard
        // Users can now enter even if email is not verified.
        return const HomeDashboard();
      },
    );
  }
}
