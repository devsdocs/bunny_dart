import 'dart:convert';
import 'dart:developer' show log;
import 'dart:io';
import 'dart:typed_data';

import 'package:bunny_dart/bunny_dart.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

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

  /// Checksum algorithm to use for upload integrity verification
  final String? checksumAlgorithm;

  /// Tracks when this upload will expire, if server provides expiration info
  DateTime? _uploadExpires;

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
    this.checksumAlgorithm,
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

  /// Get the required Bunny.net authorization headers
  Map<String, String> getBunnyAuthHeaders() {
    return {
      'AuthorizationSignature':
          autoGenerateSignature
              ? generateAuthorizationSignature()
              : authorizationSignature!,
      'AuthorizationExpire': expirationTime.toString(),
      'VideoId': videoId,
      'LibraryId': libraryId.toString(),
    };
  }

  @override
  Future<void> createUpload() async {
    // Set Bunny.net specific headers before creating upload
    headers = getBunnyAuthHeaders();

    // Set Bunny.net specific metadata
    metadata = {
      'filetype': _getFileType(),
      'title': title,
      if (collectionId != null) 'collection': collectionId!,
      if (thumbnailTime != null) 'thumbnailTime': thumbnailTime.toString(),
    };

    // If we're storing metadata for future use, save it now
    if (store is BunnyTusFileStore) {
      final metadataStore = store! as BunnyTusFileStore;
      await metadataStore.setMetadata(fingerprint, {
        'videoId': videoId,
        'libraryId': libraryId,
        'title': title,
        'expirationTime': expirationTime,
        if (collectionId != null) 'collectionId': collectionId,
        if (thumbnailTime != null) 'thumbnailTime': thumbnailTime,
      });
    }

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
    Function(int, int, double, Duration)? onProgress,
    Function(TusClient, Duration?)? onStart,
    Function()? onComplete,
    bool measureUploadSpeed = false,
  }) async {
    await upload(
      uri: Uri.parse(bunnyTusEndpoint),
      onProgress: onProgress,
      onStart: onStart,
      onComplete: onComplete,
      headers: headers,
      metadata: metadata,
      measureUploadSpeed: measureUploadSpeed,
    );
  }

  /// Check if the upload is expired
  bool _isUploadExpired() {
    if (_uploadExpires == null) return false;
    return DateTime.now().isAfter(_uploadExpires!);
  }

  /// Parse the Upload-Expires header
  void _parseUploadExpires(Map<String, List<String>> headers) {
    final expiresHeader = headers['upload-expires']?.first;
    if (expiresHeader != null) {
      try {
        // Parse RFC 7231 datetime format
        _uploadExpires = DateTime.parse(expiresHeader);
        log('Upload will expire at: $_uploadExpires');
      } catch (e) {
        log('Failed to parse Upload-Expires header: $e');
      }
    }
  }

  /// Generate checksum for the given data if a checksum algorithm is specified
  String? _generateChecksum(Uint8List data) {
    if (checksumAlgorithm == null) return null;

    switch (checksumAlgorithm!.toLowerCase()) {
      case 'sha1':
        return base64.encode(sha1.convert(data).bytes);
      case 'md5':
        return base64.encode(md5.convert(data).bytes);
      default:
        log('Unsupported checksum algorithm: $checksumAlgorithm');
        return null;
    }
  }

  /// Helper method to create and start upload in a single call
  Future<void> startUpload({
    Function(int, int, double, Duration)? onProgress,
    Function(TusClient, Duration?)? onStart,
    Function()? onComplete,
    bool measureUploadSpeed = false,
    bool forceNewUpload = false,
  }) async {
    bool createNewUpload = forceNewUpload;

    // Check if the upload is resumable
    if (!createNewUpload) {
      try {
        final isResumable = await this.isResumable();
        if (!isResumable || _isUploadExpired()) {
          log('Upload not resumable or expired, creating new upload');
          createNewUpload = true;
        } else {
          // Verify the offset can be retrieved
          try {
            await _getOffset();
          } catch (e) {
            log('Failed to retrieve offset from server: $e');
            // If we get an error when checking offset, the upload URL is likely expired
            // In that case, we need to create a new upload
            createNewUpload = true;
            // Remove any stored URL since it's no longer valid
            await store?.remove(fingerprint);
          }
        }
      } catch (e) {
        log('Error checking resume status: $e');
        createNewUpload = true;
      }
    }

    // Create a new upload if needed
    if (createNewUpload) {
      try {
        // Make sure to clean up any existing store entry
        await store?.remove(fingerprint);
        await createUpload();
      } catch (e) {
        throw Exception('Failed to create upload: $e');
      }
    }

    // Force sequential uploads if requested (to avoid 409 Conflict errors)
    if (forceSequential) {
      super.parallelUploads = 1;
    }

    // Start the upload
    try {
      await uploadToBunny(
        onProgress: onProgress,
        onStart: onStart,
        onComplete: onComplete,
        measureUploadSpeed: measureUploadSpeed,
      );
    } catch (e) {
      // If we get a 400 error, try once more with a fresh upload
      if (e.toString().contains('400') && !forceNewUpload) {
        log('Got 400 error during upload, retrying with a fresh upload');
        await store?.remove(fingerprint);
        await createUpload();

        await uploadToBunny(
          onProgress: onProgress,
          onStart: onStart,
          onComplete: onComplete,
          measureUploadSpeed: measureUploadSpeed,
        );
      } else {
        rethrow;
      }
    }
  }

  /// Add this function to handle checking offset specifically for Bunny.net
  Future<int> _getOffset() async {
    // Ensure we have both basic TUS headers and Bunny.net authorization headers
    final offsetHeaders = Map<String, String>.from(getBunnyAuthHeaders())
      ..addAll({
        "Tus-Resumable": tusVersion,
        // Add Cache-Control header as per TUS spec to prevent caching
        "Cache-Control": "no-store",
      });

    if (uploadUrl_ == null) {
      throw ProtocolException("No upload URL available to check offset");
    }

    // Make sure connection is properly closed after error
    Response? response;
    try {
      response = await getClient().headUri(
        uploadUrl_!,
        options: Options(
          headers: offsetHeaders,
          validateStatus: (status) => true, // Handle status codes manually
          receiveTimeout: receiveTimeout,
          sendTimeout: connectionTimeout,
        ),
        cancelToken: cancelToken,
      );

      // Check HTTP status code as per TUS spec
      if (response.statusCode == 404 ||
          response.statusCode == 410 ||
          response.statusCode == 403) {
        // As per TUS spec, these status codes indicate the resource is gone
        await store?.remove(fingerprint);
        throw ProtocolException(
          "Upload resource no longer available",
          response.statusCode,
        );
      } else if (!(response.statusCode! >= 200 && response.statusCode! < 300)) {
        // Any other error status code
        throw ProtocolException(
          "Failed to retrieve offset from Bunny.net",
          response.statusCode,
        );
      }

      // Parse Upload-Expires header if present
      _parseUploadExpires(response.headers.map);

      final int? serverOffset = parseOffset(
        response.headers.value("upload-offset"),
      );

      if (serverOffset == null) {
        throw ProtocolException(
          "Missing upload-offset header in response from Bunny.net",
        );
      }

      return serverOffset;
    } catch (e) {
      if (e is ProtocolException) {
        rethrow;
      }
      // Convert any other error into a ProtocolException
      throw ProtocolException("Error getting offset: $e", response?.statusCode);
    }
  }

  /// Override the base isResumable to ensure we have a fingerprint
  /// and valid stored URL before attempting to resume
  @override
  Future<bool> isResumable() async {
    try {
      fileSize = await file.length();
      pauseUpload_ = false;
      uploadCancelled = false;

      if (!resumingEnabled || fingerprint.isEmpty) {
        return false;
      }

      uploadUrl_ = await store?.get(fingerprint);

      if (uploadUrl_ == null) {
        return false;
      }

      // Verify the URL doesn't contain any invalid characters
      // that could cause problems with Bunny.net
      final String urlStr = uploadUrl_.toString();
      if (urlStr.contains(' ') ||
          urlStr.contains('\n') ||
          !urlStr.startsWith('http')) {
        log('Invalid TUS URL found in store, removing: $urlStr');
        await store?.remove(fingerprint);
        return false;
      }

      // Check if we have saved metadata about expiration
      if (store is BunnyTusFileStore) {
        final metadataStore = store! as BunnyTusFileStore;
        final metadata = await metadataStore.getMetadata(fingerprint);

        if (metadata != null && metadata.containsKey('uploadExpires')) {
          try {
            _uploadExpires = DateTime.parse(
              metadata['uploadExpires'] as String,
            );
            if (_isUploadExpired()) {
              log('Stored upload is expired based on metadata');
              await store?.remove(fingerprint);
              return false;
            }
          } catch (e) {
            log('Error parsing stored expiration time: $e');
          }
        }
      }

      return true;
    } on FileSystemException {
      throw Exception('Cannot find file to upload');
    } catch (e) {
      log('Error checking if upload is resumable: $e');
      return false;
    }
  }

  /// Implement the termination extension to delete uploads
  Future<bool> terminateUpload() async {
    if (uploadUrl_ == null) {
      log('No upload URL to terminate');
      return false;
    }

    try {
      final terminateHeaders = Map<String, String>.from(getBunnyAuthHeaders())
        ..addAll({"Tus-Resumable": tusVersion});

      final response = await getClient().deleteUri(
        uploadUrl_!,
        options: Options(
          headers: terminateHeaders,
          validateStatus: (status) => true,
        ),
        cancelToken: cancelToken,
      );

      if (response.statusCode == 204) {
        await store?.remove(fingerprint);
        return true;
      } else {
        log('Failed to terminate upload: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      log('Error terminating upload: $e');
      return false;
    }
  }

  /// Override to add checksum header when uploading chunks
  @override
  Future<Uint8List> getData() async {
    final data = await super.getData();

    // If checksumAlgorithm is specified, calculate and add the checksum header
    final checksum = _generateChecksum(data);
    if (checksum != null && checksumAlgorithm != null) {
      final currentHeaders = Map<String, String>.from(headers ?? {});
      currentHeaders['Upload-Checksum'] =
          '${checksumAlgorithm!.toLowerCase()} $checksum';
      headers = currentHeaders;
    }

    return data;
  }

  /// Override onCompleteUpload to save additional metadata about the completed upload
  @override
  Future<void> onCompleteUpload() async {
    // Update metadata to mark upload as complete
    if (store is BunnyTusFileStore) {
      final metadataStore = store! as BunnyTusFileStore;
      final metadata = await metadataStore.getMetadata(fingerprint) ?? {};
      metadata['completed'] = true;
      metadata['completedAt'] = DateTime.now().toIso8601String();

      try {
        await metadataStore.setMetadata(fingerprint, metadata);
      } catch (e) {
        log('Error updating metadata on completion: $e');
      }
    }

    await super.onCompleteUpload();
  }
}
