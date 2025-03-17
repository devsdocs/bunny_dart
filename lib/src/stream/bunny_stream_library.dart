import 'package:bunny_dart/bunny_dart.dart';
import 'package:cross_file/cross_file.dart';
import 'package:dio/dio.dart';

class BunnyStreamLibrary {
  static const _base = 'video.bunnycdn.com';

  // BunnyStreamCollection collection(String collectionId) =>
  //     BunnyStreamCollection(
  //       _streamKey,
  //       libraryId: _libraryId,
  //       collectionId: collectionId,
  //     );

  void _sendError(String message) {
    errorPrint(message, isPrint: _errorPrint);
  }

  Uri _libraryMethod([String? path, Map<String, dynamic>? queryParameters]) =>
      Uri.https(
        _base,
        '/library/$_libraryId${path ?? ''}',
        queryParameters?.map(
          (k, v) => MapEntry(k, v is int ? v.toString() : v),
        ),
      );

  Uri _videoMethod(
    String videoId, [
    String? path,
    Map<String, dynamic>? queryParameters,
  ]) => Uri.https(
    _base,
    '/library/$_libraryId/videos/$videoId${path ?? ''}',
    queryParameters?.map((k, v) => MapEntry(k, v is int ? v.toString() : v)),
  );

  Options get _defaultOptions => Options(headers: {'AccessKey': _streamKey});

  Options get _optionsWithPostBody => Options(
    headers: {'AccessKey': _streamKey},
    contentType: Headers.jsonContentType,
  );

  final int _libraryId;
  final String _streamKey;
  final bool _errorPrint;

  BunnyStreamLibrary(
    String streamKey, {
    required int libraryId,
    bool errorPrint = false,
  }) : _streamKey = streamKey,
       _errorPrint = errorPrint,
       _libraryId = libraryId;

  /// Get a video from the library.
  ///
  /// https://docs.bunny.net/reference/video_getvideo
  Future<Response<Map<String, dynamic>>> getVideoResponse(
    /// The video ID to retrieve.
    String videoId,
  ) async => await dio.get(_videoMethod(videoId), opt: _defaultOptions);

  Future<Video?> getVideo(String videoId) async {
    try {
      final response = await getVideoResponse(videoId);
      return Video.fromMap(response.data!);
    } catch (e, s) {
      _sendError('Error: $e\nStack: $s');
      return null;
    }
  }

  /// Update a video in the library.
  ///
  /// https://docs.bunny.net/reference/video_updatevideo
  Future<Response<Map<String, dynamic>>> updateVideoResponse(
    /// The video ID to update.
    String videoId, {

    /// The title of the video.
    String? title,

    /// The collection ID of the video.
    String? collectionId,

    /// The list of chapters available for the video
    List<VideoChapter>? chapters,

    /// The list of moments available for the video
    List<VideoMoment>? moments,

    /// The meta tags added to the video
    List<VideoMetaTag>? metaTags,
  }) async => await dio.post(
    _videoMethod(videoId),
    opt: _optionsWithPostBody,
    data: {
      if (title != null) 'title': title,
      if (collectionId != null) 'collection': collectionId,
      if (chapters != null && chapters.isNotEmpty)
        'chapters': chapters.map((e) => e.toMap).toList(),
      if (moments != null && moments.isNotEmpty)
        'moments': moments.map((e) => e.toMap).toList(),
      if (metaTags != null && metaTags.isNotEmpty)
        'metaTags': metaTags.map((e) => e.toMap).toList(),
    },
  );

  Future<CommonResponse?> updateVideo(
    String videoId, {
    String? title,
    String? collectionId,
    List<VideoChapter>? chapters,
    List<VideoMoment>? moments,
    List<VideoMetaTag>? metaTags,
  }) async {
    try {
      final response = await updateVideoResponse(
        videoId,
        title: title,
        collectionId: collectionId,
        chapters: chapters,
        moments: moments,
        metaTags: metaTags,
      );
      return CommonResponse.fromMap(response.data!);
    } catch (e, s) {
      _sendError('Error: $e\nStack: $s');
      return null;
    }
  }

  /// Delete a video from the library.
  ///
  /// https://docs.bunny.net/reference/video_deletevideo
  Future<Response<Map<String, dynamic>>> deleteVideoResponse(
    /// The video ID to delete.
    String videoId,
  ) async => await dio.delete(_videoMethod(videoId), opt: _defaultOptions);

  Future<CommonResponse?> deleteVideo(String videoId) async {
    try {
      final response = await deleteVideoResponse(videoId);
      return CommonResponse.fromMap(response.data!);
    } catch (e, s) {
      _sendError('Error: $e\nStack: $s');
      return null;
    }
  }

  /// Upload a video to the library.
  ///
  /// https://docs.bunny.net/reference/video_uploadvideo
  Future<Response<Map<String, dynamic>>> uploadVideoResponse(
    /// The video ID to be uploaded.
    String videoId, {

    /// Marks whether JIT encoding should be enabled for this video (works only when Premium Encoding is enabled), overrides library settings
    bool jitEnabled = false,

    /// Comma separated list of resolutions enabled for encoding, available options: 240p, 360p, 480p, 720p, 1080p, 1440p, 2160p
    String? resolutions,

    /// List of codecs that will be used to encode the file (overrides library settings). Available values: x264, vp9
    String? codecs,
  }) async => await dio.post(_videoMethod(videoId), opt: _defaultOptions);

  Future<CommonResponse?> uploadVideo(
    String videoId, {
    bool jitEnabled = false,
    String? resolutions,
    String? codecs,
  }) async {
    try {
      final response = await uploadVideoResponse(
        videoId,
        jitEnabled: jitEnabled,
        resolutions: resolutions,
        codecs: codecs,
      );
      return CommonResponse.fromMap(response.data!);
    } catch (e, s) {
      _sendError('Error: $e\nStack: $s');
      return null;
    }
  }

  /// Get Video Heatmap
  ///
  /// https://docs.bunny.net/reference/video_getheatmap
  Future<Response<Map<String, dynamic>>> getVideoHeatmapResponse(
    String videoId,
  ) async =>
      await dio.get(_videoMethod(videoId, '/heatmap'), opt: _defaultOptions);

  // Future<VideoHeatmap?> getVideoHeatmap(String videoId) async {
  //   try {
  //     final response = await getVideoHeatmapResponse(videoId);
  //     return VideoHeatmap.fromMap(response.data!);
  //   } catch (e,s) {
  //     return null;
  //   }
  // }

  /// Get Video play data
  ///
  /// https://docs.bunny.net/reference/video_getvideoplaydata
  Future<Response<Map<String, dynamic>>> getVideoPlayDataResponse(
    /// The video ID to retrieve.
    String videoId, {

    /// Account token.
    String? token,

    /// The expiress to retrieve.
    int expiress = 0,
  }) async => await dio.get(_videoMethod(videoId, '/play'));

  Future<VideoPlayData?> getVideoPlayData(String videoId) async {
    try {
      final response = await getVideoPlayDataResponse(videoId);
      return VideoPlayData.fromMap(response.data!);
    } catch (e, s) {
      _sendError('Error: $e\nStack: $s');
      return null;
    }
  }

  /// Get Video Statistics
  ///
  /// https://docs.bunny.net/reference/video_getvideostatistics
  Future<Response<Map<String, dynamic>>> getVideoStatisticsResponse({
    /// The start date of the statistics. If no value is passed, the last 30 days will be returned.
    DateTime? dateFrom,

    /// The end date of the statistics. If no value is passed, the last 30 days will be returned.
    DateTime? dateTo,

    /// If true, the statistics data will be returned in hourly groupping.
    bool hourly = false,

    /// The GUID of the video for which the statistics will be returned
    String? videoGuid,
  }) async => await dio.get(
    _libraryMethod('/statistics', {
      if (dateFrom != null) 'dateFrom': dateFrom.toIso8601String(),
      if (dateTo != null) 'dateTo': dateTo.toIso8601String(),
      if (hourly) 'hourly': true,
      if (videoGuid != null) 'videoGuid': videoGuid,
    }),
    opt: _defaultOptions,
  );

  // Future<VideoStatistics?> getVideoStatistics({
  //   DateTime? dateFrom,
  //   DateTime? dateTo,
  //   bool hourly = false,
  //   String? videoGuid,
  // }) async {
  //   try {
  //     final response = await getVideoStatisticsResponse(
  //       dateFrom: dateFrom,
  //       dateTo: dateTo,
  //       hourly: hourly,
  //       videoGuid: videoGuid,
  //     );
  //     return VideoStatistics.fromMap(response.data!);
  //   } catch (e,s) {
  //     return null;
  //   }
  // }

  /// Reencode Video
  ///
  /// https://docs.bunny.net/reference/video_reencodevideo
  Future<Response<Map<String, dynamic>>> reencodeVideoResponse(
    /// The video ID to reencode.
    String videoId,
  ) async =>
      await dio.post(_videoMethod(videoId, '/reencode'), opt: _defaultOptions);

  Future<Video?> reencodeVideo(String videoId) async {
    try {
      final response = await reencodeVideoResponse(videoId);
      return Video.fromMap(response.data!);
    } catch (e, s) {
      _sendError('Error: $e\nStack: $s');
      return null;
    }
  }

  /// Add output codec to video
  ///
  /// https://docs.bunny.net/reference/video_reencodeusingcodec
  Future<Response<Map<String, dynamic>>> addOutputCodecResponse(
    /// The video ID to add output codec.
    String videoId, {

    /// The output codec to add.
    /// 0 = x264
    /// 1 = vp9
    /// 2 = hevc
    /// 3 = av1
    required int outputCodec,
  }) async => await dio.put(
    _videoMethod(videoId, '/outputs/$outputCodec'),
    data: {'outputCodec': outputCodec},
    opt: _defaultOptions,
  );

  Future<Video?> addOutputCodec(
    String videoId, {
    required int outputCodec,
  }) async {
    try {
      final response = await addOutputCodecResponse(
        videoId,
        outputCodec: outputCodec,
      );
      return Video.fromMap(response.data!);
    } catch (e, s) {
      _sendError('Error: $e\nStack: $s');
      return null;
    }
  }

  /// Repackage Video
  ///
  /// https://docs.bunny.net/reference/video_repackage
  Future<Response<Map<String, dynamic>>> repackageVideoResponse(
    /// The video ID to repackage.
    String videoId, {

    /// Marks whether previous file versions should be kept in storage, allows for faster repackage later on. Default is true.
    bool keepOriginalFiles = true,
  }) async =>
      await dio.post(_videoMethod(videoId, '/repackage'), opt: _defaultOptions);

  Future<Video?> repackageVideo(
    String videoId, {
    bool keepOriginalFiles = true,
  }) async {
    try {
      final response = await repackageVideoResponse(
        videoId,
        keepOriginalFiles: keepOriginalFiles,
      );
      return Video.fromMap(response.data!);
    } catch (e, s) {
      _sendError('Error: $e\nStack: $s');
      return null;
    }
  }

  /// List all videos in the library.
  ///
  /// https://docs.bunny.net/reference/video_list
  Future<Response<Map<String, dynamic>>> listVideosResponse({
    /// The page number to retrieve. Default is 1.
    int page = 1,

    /// The number of items to retrieve per page. Default is 100.
    int itemsPerPage = 100,

    /// The search query to filter the videos by.
    String? search,

    /// The collection ID to filter the videos by.
    String? collectionId,

    /// The category ID to filter the videos by. Default is date.
    String orderBy = 'date',
  }) async => await dio.get(
    _libraryMethod('/videos', {
      'page': page,
      'itemsPerPage': itemsPerPage,
      if (search != null) 'search': search,
      if (collectionId != null) 'collection': collectionId,
      'orderBy': orderBy,
    }),
    opt: _defaultOptions,
  );

  Future<ListVideos?> listVideos({
    int page = 1,
    int itemsPerPage = 100,
    String? search,
    String? collectionId,
    String orderBy = 'date',
  }) async {
    try {
      final response = await listVideosResponse(
        page: page,
        itemsPerPage: itemsPerPage,
        search: search,
        collectionId: collectionId,
        orderBy: orderBy,
      );
      return ListVideos.fromMap(response.data!);
    } catch (e, s) {
      _sendError('Error: $e\nStack: $s');
      return null;
    }
  }
}

extension BunnyTUSUpload on BunnyStreamLibrary {
  /// Create a video with TUS upload support
  /// First creates the video entry and then provides a TUS client for uploading
  Future<BunnyTusClient?> createVideoWithTusUpload({
    required String title,
    required XFile videoFile,
    String? collectionId,
    bool jitEnabled = false,
    String? resolutions,
    String? codecs,
    int? thumbnailTime,
    bool autoGenerateSignature = true,
    String? authorizationSignature,
    int? expirationTimeInSeconds,
    TusStore? store,
    int maxChunkSize = 512 * 1024,
    int retries = 3,
    RetryScale retryScale = RetryScale.exponentialJitter,
    int retryInterval = 5,
    int parallelUploads = 3,
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
        autoGenerateSignature: autoGenerateSignature,
        authorizationSignature: authorizationSignature,
        store: store,
        maxChunkSize: maxChunkSize,
        retries: retries,
        retryScale: retryScale,
        retryInterval: retryInterval,
        parallelUploads: parallelUploads,
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
    bool autoGenerateSignature = true,
    String? authorizationSignature,
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
      autoGenerateSignature: autoGenerateSignature,
      authorizationSignature: authorizationSignature,
      store: store,
      maxChunkSize: maxChunkSize,
      retries: retries,
      retryScale: retryScale,
      retryInterval: retryInterval,
      parallelUploads: parallelUploads,
    );
  }
}
