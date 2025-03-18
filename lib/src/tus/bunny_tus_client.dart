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

  /// Checksum algorithm to use for upload integrity verification
  final String? checksumAlgorithm;

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

    this.checksumAlgorithm,
  }) : expirationTime =
           expirationTimeInSeconds ??
           (DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600) {
    // Force single upload for now, since Bunny.net doesn't support parallel uploads
    super.parallelUploads = 1;
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

  /// Generate checksum for the given data if a checksum algorithm is specified
  String? _generateChecksum(Uint8List data) {
    if (checksumAlgorithm == null) return null;

    switch (checksumAlgorithm!.toLowerCase()) {
      case 'sha1':
        return base64.encode(sha1.convert(data).bytes);
      case 'md5':
        return base64.encode(md5.convert(data).bytes);
      default:
        print('Unsupported checksum algorithm: $checksumAlgorithm');
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
        if (!isResumable) {
          print('Upload not resumable, creating new upload');
          createNewUpload = true;
        } else {
          // Verify the offset can be retrieved
          try {
            await _getOffset();
          } catch (e) {
            print('Failed to retrieve offset from server: $e');
            if (e.toString().contains('400')) {
              print(
                'Got 400 error checking offset, likely authorization expired',
              );
            }
            // If we get an error when checking offset, the upload URL is likely expired
            // In that case, we need to create a new upload
            createNewUpload = true;
            // Remove any stored URL since it's no longer valid
            await store?.remove(fingerprint);
          }
        }
      } catch (e) {
        print('Error checking resume status: $e');
        createNewUpload = true;
      }
    }

    // Create a new upload if needed
    if (createNewUpload) {
      try {
        print('Creating new upload for ${file.path}');
        // Make sure to clean up any existing store entry
        await store?.remove(fingerprint);
        await createUpload();
      } catch (e) {
        print('Failed to create upload: $e');
        throw Exception('Failed to create upload: $e');
      }
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
      print('Error during upload: $e');

      // If we get a 400 error, try once more with a fresh upload
      if (e.toString().contains('400') && !forceNewUpload) {
        print('Got 400 error during upload, retrying with a fresh upload');
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
    // Always get fresh authentication headers for each request
    final offsetHeaders = Map<String, String>.from(getBunnyAuthHeaders())
      ..addAll({"Tus-Resumable": tusVersion, "Cache-Control": "no-store"});

    if (uploadUrl_ == null) {
      throw ProtocolException("No upload URL available to check offset");
    }

    print('Checking offset with Bunny.net: $uploadUrl_');
    print('Using headers: $offsetHeaders');

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

      print('Offset response status: ${response.statusCode}');
      print('Offset response headers: ${response.headers.map}');

      // Check HTTP status code as per TUS spec
      if (response.statusCode == 404 ||
          response.statusCode == 410 ||
          response.statusCode == 403 ||
          response.statusCode == 400) {
        // As per TUS spec or typical error responses
        await store?.remove(fingerprint);
        throw ProtocolException(
          "Upload resource no longer available or auth expired",
          response.statusCode,
        );
      } else if (!(response.statusCode! >= 200 && response.statusCode! < 300)) {
        // Any other error status code
        throw ProtocolException(
          "Failed to retrieve offset from Bunny.net",
          response.statusCode,
        );
      }

      final int? serverOffset = parseOffset(
        response.headers.value("upload-offset"),
      );

      if (serverOffset == null) {
        throw ProtocolException(
          "Missing upload-offset header in response from Bunny.net",
        );
      }

      print('Server reported offset: $serverOffset');
      return serverOffset;
    } catch (e) {
      if (e is ProtocolException) {
        rethrow;
      }
      // Convert any other error into a ProtocolException
      print('Error getting offset: $e');
      throw ProtocolException("Error getting offset: $e", response?.statusCode);
    }
  }

  /// Override to add checksum header when uploading chunks
  @override
  Future<Uint8List> getData() async {
    final data = await super.getData();

    // Update headers with fresh authentication for each chunk
    final currentHeaders = Map<String, String>.from(getBunnyAuthHeaders());

    // If checksumAlgorithm is specified, calculate and add the checksum header
    final checksum = _generateChecksum(data);
    if (checksum != null && checksumAlgorithm != null) {
      currentHeaders['Upload-Checksum'] =
          '${checksumAlgorithm!.toLowerCase()} $checksum';
    }

    // Update the headers
    headers = currentHeaders;

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
        print('Error updating metadata on completion: $e');
      }
    }

    await super.onCompleteUpload();
  }
}
