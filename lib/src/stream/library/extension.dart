part of 'library.dart';

/// Helper methods for the BunnyStreamLibrary
extension BunnyStreamLibraryHelper on BunnyStreamLibrary {
  /// Get all videos from the library recursively
  Future<List<Video>> getAllVideos({
    int itemsPerPageArg = 1000,
    int page = 1,
  }) async {
    // 1000 is the maximum itemsPerPage
    final itemsPerPage = itemsPerPageArg.clamp(1, 1000);
    final videos = <Video>[];
    final fetch = await listVideos(itemsPerPage: itemsPerPage, page: page);

    if (fetch == null || fetch.items == null) {
      return videos;
    }
    if (fetch.items!.isEmpty) {
      return videos;
    }

    videos.addAll(fetch.items!);

    final hasMoreItems = page * itemsPerPage < fetch.totalItems;

    if (hasMoreItems) {
      final nextPage = page + 1;
      final nextVideos = await getAllVideos(
        itemsPerPageArg: itemsPerPage,
        page: nextPage,
      );
      videos.addAll(nextVideos);
    }

    return videos;
  }
}

/// Extension for the BunnyStreamLibrary to handle TUS uploads
extension BunnyTUSUpload on BunnyStreamLibrary {
  /// Create a video and return a TUS client for the upload
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
        rawRequest._libraryMethod('/videos'),
        opt: rawRequest._optionsWithPostBody,
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
