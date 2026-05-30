import 'package:flutter/foundation.dart';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:path/path.dart' as p;

/// Response model — kept identical to the old CloudinaryResponse so callers
/// don't need any changes beyond the import.
class GcsResponse {
  final String? secureUrl;
  final String? publicId;
  final String? error;

  GcsResponse({this.secureUrl, this.publicId, this.error});
}

/// Google Cloud Storage media service.
///
/// Flow:
///   1. Client asks the Cloud Function for a signed upload URL.
///   2. Client PUTs the file directly to GCS using that URL.
///   3. Cloud Function returns the final public URL.
class GcsService {
  String get _bucketName => (dotenv.env['GCS_BUCKET_NAME']?.isNotEmpty == true)
      ? dotenv.env['GCS_BUCKET_NAME']!
      : 'sapapnj-media-assets';

  String get _functionBaseUrl => (dotenv.env['GCS_FUNCTION_URL']?.isNotEmpty == true)
      ? dotenv.env['GCS_FUNCTION_URL']!
      : 'https://asia-southeast2-sapapnj-gcp.cloudfunctions.net';

  // ---------------------------------------------------------------------------
  // Convenience wrappers (same signatures as old CloudinaryService)
  // ---------------------------------------------------------------------------

  Future<String?> uploadFile(File file, String resourceType) async {
    final response = await uploadFileWithDetails(file, resourceType);
    return response.secureUrl;
  }

  Future<String?> uploadImage(File file) => uploadFile(file, 'image');
  Future<String?> uploadMedia(File file) => uploadFile(file, 'auto');

  // ---------------------------------------------------------------------------
  // Core upload — mirrors CloudinaryService.uploadFileWithDetails
  // ---------------------------------------------------------------------------

  Future<GcsResponse> uploadFileWithDetails(File file, String resourceType) async {
    if (_bucketName.isEmpty || _functionBaseUrl.isEmpty) {
      return GcsResponse(error: "GCS credentials missing.");
    }

    try {
      final fileName = p.basename(file.path);
      debugPrint("GCS: Requesting signed URL for $fileName with type $resourceType");
      // 1. Request a signed upload URL from the Cloud Function.
      final signResponse = await http.post(
        Uri.parse('$_functionBaseUrl/getSignedUploadUrl'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'fileName': fileName,
          'contentType': _resolveContentType(fileName, resourceType),
        }),
      );

      if (signResponse.statusCode != 200) {
        debugPrint('GCS sign URL failed: ${signResponse.statusCode} - body: ${signResponse.body}');
        return GcsResponse(error: 'Failed to get upload URL');
      }

      final signData = json.decode(signResponse.body);
      final String uploadUrl = signData['uploadUrl'];
      final String objectName = signData['objectName'];
      final String contentType = signData['contentType'];

      debugPrint("GCS: Got signed URL. Starting PUT request to storage.googleapis.com...");
      // 2. PUT the file directly to GCS.
      final fileBytes = await file.readAsBytes();
      final uploadResponse = await http.put(
        Uri.parse(uploadUrl),
        headers: {'Content-Type': contentType},
        body: fileBytes,
      );

      if (uploadResponse.statusCode == 200 || uploadResponse.statusCode == 201) {
        final publicUrl =
            'https://storage.googleapis.com/$_bucketName/$objectName';
        debugPrint("GCS: Upload successful. Public URL: $publicUrl");
        return GcsResponse(
          secureUrl: publicUrl,
          publicId: objectName,
        );
      } else {
        debugPrint('GCS upload failed: ${uploadResponse.statusCode} - body: ${uploadResponse.body}');
        return GcsResponse(error: 'Upload to GCS failed (${uploadResponse.statusCode})');
      }
    } catch (e, stackTrace) {
      debugPrint('GCS upload exception: $e\nStacktrace: $stackTrace');
      return GcsResponse(error: e.toString());
    }
  }

  // ---------------------------------------------------------------------------
  // Delete — mirrors CloudinaryService.deleteResource
  // ---------------------------------------------------------------------------

  Future<bool> deleteResource(String objectName, {String resourceType = 'image'}) async {
    if (_functionBaseUrl.isEmpty) {
      debugPrint("WARNING: GCS Function URL missing. Cannot delete.");
      return false;
    }

    try {
      final response = await http.post(
        Uri.parse('$_functionBaseUrl/deleteObject'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'objectName': objectName}),
      );

      if (response.statusCode == 200) {
        debugPrint("GCS: Deleted $objectName");
        return true;
      } else {
        debugPrint("GCS Delete Failed: ${response.body}");
        return false;
      }
    } catch (e) {
      debugPrint("GCS Delete Exception: $e");
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  String _resolveContentType(String fileName, String resourceType) {
    final ext = p.extension(fileName).toLowerCase();
    if (resourceType == 'image' || ['.jpg', '.jpeg', '.png', '.gif', '.webp'].contains(ext)) {
      switch (ext) {
        case '.png':
          return 'image/png';
        case '.gif':
          return 'image/gif';
        case '.webp':
          return 'image/webp';
        default:
          return 'image/jpeg';
      }
    }
    if (['.mp4', '.mov', '.avi', '.webm'].contains(ext)) {
      return 'video/${ext.substring(1)}';
    }
    return 'application/octet-stream';
  }
}
