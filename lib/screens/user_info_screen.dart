import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/api_service.dart';
import '../auth_gate.dart';
import '../services/overlay_service.dart';
import 'setup/setup_profile_screen.dart';

class UserInfoScreen extends StatefulWidget {
  final bool isSetupWizard;
  const UserInfoScreen({super.key, this.isSetupWizard = false});

  @override
  State<UserInfoScreen> createState() => _UserInfoScreenState();
}

class _UserInfoScreenState extends State<UserInfoScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _nimController = TextEditingController();
  bool _isLoading = false;

  Future<void> _saveProfile() async {
    if (_nameController.text.isEmpty || _nimController.text.isEmpty) {
       OverlayService().showTopNotification(
         context,
         "Please fill in your name and NIM.",
         Icons.warning_amber_rounded,
         (){},
         color: Colors.orange
       );
      return;
    }

    setState(() { _isLoading = true; });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      bool success = false;
      try {
        success = await ApiService().createUser(
          uid: user.uid,
          email: user.email ?? '',
          name: _nameController.text.trim(),
          nim: _nimController.text.trim(),
        );
      } on ApiException catch (e) {
        // If it's NIM in use, rethrow so the user sees it
        if (e.code == 'nim-already-in-use') rethrow;
      } catch (e) {
        // Suppress other network errors here, we will try updating instead
      }

      // If createUser failed (user already exists), try updateUser
      if (!success) {
        success = await ApiService().updateUser(
          user.uid,
          {
            'name': _nameController.text.trim(),
            'nim': _nimController.text.trim(),
            'email': user.email ?? '',
          }
        );
      }

      if (success && mounted) {
        OverlayService().showTopNotification(
          context,
          "Profile saved.",
          Icons.check_circle,
          (){},
          color: Colors.green
        );
        if (widget.isSetupWizard) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const SetupProfileScreen()),
            (route) => false,
          );
        } else {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const AuthGate()),
            (route) => false,
          );
        }
      } else if (mounted) {
        OverlayService().showTopNotification(
          context,
          "Failed to save profile.",
          Icons.error,
          (){},
          color: Colors.red
        );
        setState(() { _isLoading = false; });
      }

    } on ApiException catch (e) {
      if (mounted) {
         OverlayService().showTopNotification(
           context,
           e.message,
           Icons.error,
           (){},
           color: Colors.red
         );
      }
      setState(() { _isLoading = false; });
    } catch (e) {
      if(mounted) {
         OverlayService().showTopNotification(
           context,
           "Failed to save profile: $e",
           Icons.error,
           (){},
           color: Colors.red
         );
      }
      setState(() { _isLoading = false; });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nimController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Complete Your Profile')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Welcome! Please complete your profile.'),
            const SizedBox(height: 20),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Full Name'),
            ),
            const SizedBox(height: 10),
             TextField(
              controller: _nimController,
              decoration: const InputDecoration(labelText: 'NIM'),
            ),
            const SizedBox(height: 30),
            if (_isLoading) const CircularProgressIndicator(),
            if (!_isLoading) ElevatedButton(
              onPressed: _saveProfile,
              child: const Text('Save & Continue'),
            ),
          ],
        ),
      ),
    );
  }
}
