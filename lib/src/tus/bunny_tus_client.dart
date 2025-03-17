import 'dart:convert';

import 'package:bunny_dart/src/tus/client.dart';
import 'package:bunny_dart/src/tus/retry_scale.dart';
import 'package:crypto/crypto.dart';

/// Specialized TUS client for Bunny.net video uploads
class BunnyTusClient extends TusClient {
  /// The Bunny.net TUS upload endpoint
  static const String bunnyTusEndpoint = 'https://video.bunnycdn.com/tusupload';

  /// The API key for Bunny Stream
  final String apiKey;

  /// The library ID where the video will be placed
  final int libraryId;

  /// The video ID for the upload (must be pre-created)
  final String videoId;

  /// The title of the video
  final String title;

  /// The collection ID to upload to (optional)
  final String? collectionId;

  /// Video time in ms to extract the main video thumbnail (optional)
  final int? thumbnailTime;

  /// The expiration time of the upload in seconds since epoch
  final int expirationTime;

  /// Whether to auto-generate the authorization signature
  final bool autoGenerateSignature;

  /// The pre-generated authorization signature (if not auto-generating)
  final String? authorizationSignature;

  /// Whether to force sequential upload instead of parallel
  /// Set to true if you experience 409 Conflict errors with parallel uploads
  final bool forceSequential;

  BunnyTusClient(
    super.file, {
    super.store,
    super.maxChunkSize,
    super.retries = 3,
    super.retryScale = RetryScale.exponentialJitter,
    super.retryInterval = 5,
    super.parallelUploads = 3,
    super.connectionTimeout,
    super.receiveTimeout,
    required this.apiKey,
    required this.libraryId,
    required this.videoId,
    required this.title,
    this.collectionId,
    this.thumbnailTime,
    int? expirationTimeInSeconds,
    this.autoGenerateSignature = true,
    this.authorizationSignature,
    this.forceSequential = false,
  }) : expirationTime =
           expirationTimeInSeconds ??
           (DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600) {
    // Set up the Bunny.net TUS endpoint
    url = Uri.parse(bunnyTusEndpoint);

    // Verify we have required parameters
    if (!autoGenerateSignature && authorizationSignature == null) {
      throw ArgumentError(
        'authorizationSignature is required when autoGenerateSignature is false',
      );
    }
  }

  /// Generate the authorization signature required by Bunny.net
  /// Format: sha256(library_id + api_key + expiration_time + video_id)
  String generateAuthorizationSignature() {
    final data = '$libraryId$apiKey$expirationTime$videoId';
    final bytes = utf8.encode(data);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  @override
  Future<void> createUpload() async {
    // Set Bunny.net specific headers before creating upload
    headers = {
      'AuthorizationSignature':
          autoGenerateSignature
              ? generateAuthorizationSignature()
              : authorizationSignature!,
      'AuthorizationExpire': expirationTime.toString(),
      'VideoId': videoId,
      'LibraryId': libraryId.toString(),
    };

    // Set Bunny.net specific metadata
    metadata = {
      'filetype': _getFileType(),
      'title': title,
      if (collectionId != null) 'collection': collectionId!,
      if (thumbnailTime != null) 'thumbnailTime': thumbnailTime.toString(),
    };

    await super.createUpload();
  }

  /// Get file type based on file extension
  String _getFileType() {
    final extension = file.path.split('.').last.toLowerCase();

    switch (extension) {
      case 'mp4':
        return 'video/mp4';
      case 'mov':
        return 'video/quicktime';
      case 'avi':
        return 'video/x-msvideo';
      case 'wmv':
        return 'video/x-ms-wmv';
      case 'flv':
        return 'video/x-flv';
      case 'webm':
        return 'video/webm';
      case 'mkv':
        return 'video/x-matroska';
      default:
        return 'video/mp4'; // Default to mp4
    }
  }

  /// Start upload to Bunny.net
  Future<void> uploadToBunny({
    Function(double, Duration)? onProgress,
    Function(TusClient, Duration?)? onStart,
    Function()? onComplete,
  }) async {
    await upload(
      uri: Uri.parse(bunnyTusEndpoint),
      onProgress: onProgress,
      onStart: onStart,
      onComplete: onComplete,
      headers: headers,
      metadata: metadata,
    );
  }

  /// Helper method to create and start upload in a single call
  Future<void> startUpload({
    Function(double, Duration)? onProgress,
    Function(TusClient, Duration?)? onStart,
    Function()? onComplete,
    bool measureUploadSpeed = true,
  }) async {
    // First check if the upload is resumable
    final isResumable = await this.isResumable();

    if (!isResumable) {
      // If not resumable, create a new upload
      await createUpload();
    }

    // Force sequential uploads if requested (to avoid 409 Conflict errors)
    if (forceSequential) {
      super.parallelUploads = 1;
    }

    // Start the upload
    await uploadToBunny(
      onProgress: onProgress,
      onStart: onStart,
      onComplete: onComplete,
    );
  }
}
