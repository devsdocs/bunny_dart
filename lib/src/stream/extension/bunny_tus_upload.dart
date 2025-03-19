part of '../bunny_stream_library.dart';

extension BunnyTUSUpload on BunnyStreamLibrary {
  Future<BunnyTusClient?> createVideoWithTusUpload({
    required String title,
    required XFile videoFile,
    String? collectionId,
    int? thumbnailTime,
    int? expirationTimeInSeconds,
    TusStore? store,
    int maxChunkSize = 512 * 1024,
    int retries = 3,
    RetryScale retryScale = RetryScale.exponentialJitter,
    int retryInterval = 5,
  }) async {
    try {
      // First create the video entry to get the ID
      final response = await dio.post(
        _libraryMethod('/videos'),
        opt: _optionsWithPostBody,
        data: {
          'title': title,
          if (collectionId != null) 'collectionId': collectionId,
        },
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Failed to create video: ${response.statusCode}');
      }

      // Extract the video ID from the response
      final String videoId = response.data!['guid'] as String;

      // Create and return the TUS client for this video
      return BunnyTusClient(
        videoFile,
        apiKey: _streamKey,
        libraryId: _libraryId,
        videoId: videoId,
        title: title,
        collectionId: collectionId,
        thumbnailTime: thumbnailTime,
        expirationTimeInSeconds: expirationTimeInSeconds,
        store: store,
        maxChunkSize: maxChunkSize,
        retries: retries,
        retryScale: retryScale,
        retryInterval: retryInterval,
      );
    } catch (e, s) {
      _sendError('Error creating video for TUS upload: $e\nStack: $s');
      return null;
    }
  }

  /// Create a TUS client for an existing video
  BunnyTusClient getTusClientForVideo({
    required String videoId,
    required String title,
    required XFile videoFile,
    String? collectionId,
    int? thumbnailTime,
    int? expirationTimeInSeconds,
    TusStore? store,
    int maxChunkSize = 512 * 1024,
    int retries = 3,
    RetryScale retryScale = RetryScale.exponentialJitter,
    int retryInterval = 5,
    int parallelUploads = 3,
  }) {
    return BunnyTusClient(
      videoFile,
      apiKey: _streamKey,
      libraryId: _libraryId,
      videoId: videoId,
      title: title,
      collectionId: collectionId,
      thumbnailTime: thumbnailTime,
      expirationTimeInSeconds: expirationTimeInSeconds,
      store: store,
      maxChunkSize: maxChunkSize,
      retries: retries,
      retryScale: retryScale,
      retryInterval: retryInterval,
    );
  }
}
