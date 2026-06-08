import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/api_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/gcs_service.dart';
import '../../services/overlay_service.dart';
import '../../theme/app_theme.dart';

class KtmVerificationScreen extends StatefulWidget {
  final Map<String, dynamic> userDbData;

  const KtmVerificationScreen({super.key, required this.userDbData});

  @override
  State<KtmVerificationScreen> createState() => _KtmVerificationScreenState();
}

class _KtmVerificationScreenState extends State<KtmVerificationScreen> {
  File? _ktmImage;
  bool _isUploading = false;
  final GcsService _cloudinaryService = GcsService();

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final XFile? pickedFile = await picker.pickImage(
      maxWidth: 1920,
      maxHeight: 1920,
      source: source,
      imageQuality: 80,
    );

    if (pickedFile != null) {
      setState(() {
        _ktmImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _submitVerification() async {
    if (_ktmImage == null) {
      OverlayService().showTopNotification(
        context,
        "Please attach photo of your KTM",
        Icons.warning,
        () {},
        color: Colors.orange,
      );
      return;
    }

    setState(() => _isUploading = true);
    final user = FirebaseAuth.instance.currentUser;

    try {
      // 1. Upload Image
      final String? url = await _cloudinaryService.uploadImage(_ktmImage!);

      if (url != null && user != null) {
        // 2. Update via ApiService
        await ApiService().updateUser(user.uid, {
          'verification_status': 'pending', // pending, verified, rejected
          'ktm_image_url': url,
        });

        if (mounted) {
          OverlayService().showTopNotification(
            context,
            "Submitted for review!",
            Icons.check_circle,
            () {},
            color: Colors.green,
          );
          Navigator.pop(context);
        }
      } else {
        throw Exception("Upload failed");
      }
    } catch (e) {
      if (mounted) {
        OverlayService().showTopNotification(
          context,
          "Submission failed",
          Icons.error,
          () {},
          color: Colors.red,
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isOnCooldown = false;
    String? bannerMessage;
    Color bannerColor = Colors.orange;

    final String verificationStatus = widget.userDbData['verification_status'] ?? 'unverified';
    final int rejectionCount = widget.userDbData['ktm_rejection_count'] ?? 0;
    final String? lastRejectedAtStr = widget.userDbData['ktm_last_rejected_at'];

    if (verificationStatus == 'rejected') {
      if (rejectionCount >= 3 && lastRejectedAtStr != null) {
        final DateTime lastRejectedAt = DateTime.parse(lastRejectedAtStr).toLocal();
        final DateTime cooldownExpiry = lastRejectedAt.add(const Duration(days: 7));
        if (DateTime.now().isBefore(cooldownExpiry)) {
          isOnCooldown = true;
          final Duration diff = cooldownExpiry.difference(DateTime.now());
          bannerMessage = "You have reached the maximum of 3 attempts. Please wait ${diff.inDays} days and ${diff.inHours % 24} hours before trying again.";
          bannerColor = Colors.red;
        } else {
          bannerMessage = "You can try again. Please upload a clearer photo.";
        }
      } else {
        final int remainingAttempts = 3 - rejectionCount;
        bannerMessage = "Your previous request was rejected. You have $remainingAttempts attempts remaining. Please upload a clearer photo.";
      }
    }

    return Scaffold(
      appBar: FrostedAppBar(title: const Text("Get Verified Badge")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.verified, size: 64, color: SisapaTheme.blue),
            const SizedBox(height: 16),
            const Text(
              "Verify your Student Status",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              "Upload a clear photo of your KTM (Kartu Tanda Mahasiswa) to get the Blue Checkmark badge on your profile. This confirms you are an active student.",
              style: TextStyle(color: Colors.grey, height: 1.5),
            ),
            const SizedBox(height: 32),

            if (bannerMessage != null)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 24),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: bannerColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: bannerColor.withOpacity(0.5)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: bannerColor),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        bannerMessage,
                        style: TextStyle(color: bannerColor, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),

            if (!isOnCooldown) ...[
              // Image Picker Area
              GestureDetector(
                onTap: () => _pickImage(ImageSource.gallery),
                child: Container(
                  height: 200,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Theme.of(context).dividerColor),
                    image: _ktmImage != null
                        ? DecorationImage(
                            image: FileImage(_ktmImage!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: _ktmImage == null
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(
                              Icons.add_a_photo_outlined,
                              size: 40,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 8),
                            Text(
                              "Tap to upload KTM",
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        )
                      : null,
                ),
              ),

              if (_ktmImage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: Center(
                    child: TextButton.icon(
                      onPressed: () => _pickImage(ImageSource.camera),
                      icon: const Icon(Icons.camera_alt),
                      label: const Text("Retake Photo"),
                    ),
                  ),
                ),

              const SizedBox(height: 40),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isUploading ? null : _submitVerification,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: SisapaTheme.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: _isUploading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text("Submit Verification"),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
