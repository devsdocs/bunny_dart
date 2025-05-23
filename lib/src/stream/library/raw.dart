part of 'library.dart';

const videoBase = 'video.bunnycdn.com';

class _BunnyStreamLibrary {
  _BunnyStreamLibrary(String streamKey, {required int libraryId})
    : _streamKey = streamKey,
      _libraryId = libraryId;

  final int _libraryId;
  final String _streamKey;

  Options get _defaultOptions => Options(headers: {'AccessKey': _streamKey});

  Options get _optionsWithPostBody => Options(
    headers: {'AccessKey': _streamKey},
    contentType: Headers.jsonContentType,
  );

  Uri _libraryMethod([String? path, Map<String, dynamic>? queryParameters]) =>
      Uri.https(
        videoBase,
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
    videoBase,
    '/library/$_libraryId/videos/$videoId${path ?? ''}',
    queryParameters?.map((k, v) => MapEntry(k, v is int ? v.toString() : v)),
  );

  /// Get a video from the library.
  ///
  /// https://docs.bunny.net/reference/video_getvideo
  Future<Response<Map<String, dynamic>>> getVideo(
    /// The video ID to retrieve.
    String videoId,
  ) async => await dio.get(_videoMethod(videoId), opt: _defaultOptions);

  /// Update a video in the library.
  ///
  /// https://docs.bunny.net/reference/video_updatevideo
  Future<Response<Map<String, dynamic>>> updateVideo(
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

  /// Delete a video from the library.
  ///
  /// https://docs.bunny.net/reference/video_deletevideo
  Future<Response<Map<String, dynamic>>> deleteVideo(
    /// The video ID to delete.
    String videoId,
  ) async => await dio.delete(_videoMethod(videoId), opt: _defaultOptions);

  /// Upload a video to the library.
  ///
  /// https://docs.bunny.net/reference/video_uploadvideo
  Future<Response<Map<String, dynamic>>> uploadVideo(
    /// The video ID to be uploaded.
    String videoId, {

    /// Marks whether JIT encoding should be enabled for this video (works only when Premium Encoding is enabled), overrides library settings
    bool jitEnabled = false,

    /// Comma separated list of resolutions enabled for encoding, available options: 240p, 360p, 480p, 720p, 1080p, 1440p, 2160p
    String? resolutions,

    /// List of codecs that will be used to encode the file (overrides library settings). Available values: x264, vp9
    String? codecs,
  }) async => await dio.post(_videoMethod(videoId), opt: _defaultOptions);

  /// Get Video Heatmap
  ///
  /// https://docs.bunny.net/reference/video_getheatmap
  Future<Response<Map<String, dynamic>>> getVideoHeatmap(
    String videoId,
  ) async =>
      await dio.get(_videoMethod(videoId, '/heatmap'), opt: _defaultOptions);

  /// Get Video play data
  ///
  /// https://docs.bunny.net/reference/video_getvideoplaydata
  Future<Response<Map<String, dynamic>>> getVideoPlayData(
    /// The video ID to retrieve.
    String videoId, {

    /// Account token.
    String? token,

    /// The expiress to retrieve.
    int expiress = 0,
  }) async => await dio.get(_videoMethod(videoId, '/play'));

  /// Get Video Statistics
  ///
  /// https://docs.bunny.net/reference/video_getvideostatistics
  Future<Response<Map<String, dynamic>>> getVideoStatistics({
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

  /// Reencode Video
  ///
  /// https://docs.bunny.net/reference/video_reencodevideo
  Future<Response<Map<String, dynamic>>> reencodeVideo(
    /// The video ID to reencode.
    String videoId,
  ) async =>
      await dio.post(_videoMethod(videoId, '/reencode'), opt: _defaultOptions);

  /// Add output codec to video
  ///
  /// https://docs.bunny.net/reference/video_reencodeusingcodec
  Future<Response<Map<String, dynamic>>> addOutputCodec(
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

  /// Repackage Video
  ///
  /// https://docs.bunny.net/reference/video_repackage
  Future<Response<Map<String, dynamic>>> repackageVideo(
    /// The video ID to repackage.
    String videoId, {

    /// Marks whether previous file versions should be kept in storage, allows for faster repackage later on. Default is true.
    bool keepOriginalFiles = true,
  }) async =>
      await dio.post(_videoMethod(videoId, '/repackage'), opt: _defaultOptions);

  /// List all videos in the library.
  ///
  /// https://docs.bunny.net/reference/video_list
  Future<Response<Map<String, dynamic>>> listVideos({
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

  /// Create a new video in the library.
  ///
  /// https://docs.bunny.net/reference/video_createvideo
  Future<Response<Map<String, dynamic>>> createVideo({
    /// The title of the video.
    required String title,

    /// The ID of the collection where the video will be put
    String? collectionId,

    /// Video time in ms to extract the main video thumbnail.
    int? thumbnailTime,
  }) async => await dio.post(
    _libraryMethod('/videos'),
    opt: _optionsWithPostBody,
    data: {
      'title': title,
      if (collectionId != null) 'collectionId': collectionId,
      if (thumbnailTime != null) 'thumbnailTime': thumbnailTime,
    },
  );

  /// Set the video thumbnail.
  ///
  /// https://docs.bunny.net/reference/video_setthumbnail
  Future<Response<Map<String, dynamic>>> setThumbnail(
    /// The video ID to set the thumbnail.
    String videoId, {

    /// Thumbnail source URL.
    String? thumbnailUrl,
  }) async => await dio.post(
    _videoMethod(videoId, '/thumbnail', {
      if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
    }),
    opt: _defaultOptions,
  );

  /// Fetch video from URL.
  ///
  /// https://docs.bunny.net/reference/video_fetchnewvideo
  Future<Response<Map<String, dynamic>>> fetchVideo(
    /// The video URL to fetch.
    String videoUrl, {

    /// Video title
    String? title,

    /// Header to pass to the video URL.
    Map<String, String>? headers,

    /// Collection ID to add the video to.
    String? collectionId,

    /// Thumbnail time in ms to extract the main video thumbnail.
    int? thumbnailTime,
  }) async => await dio.post(
    _libraryMethod('/videos/fetch', {
      if (collectionId != null) 'collectionId': collectionId,
      if (thumbnailTime != null) 'thumbnailTime': thumbnailTime,
    }),
    opt: _optionsWithPostBody,
    data: {
      'url': videoUrl,
      if (title != null) 'title': title,
      if (headers != null) 'headers': headers,
    },
  );

  /// Add caption to video.
  ///
  /// https://docs.bunny.net/reference/video_addcaption
  Future<Response<Map<String, dynamic>>> addCaption(
    /// The video ID to add caption.
    String videoId, {

    /// The unique srclang shortcode for the caption
    required String srclang,

    /// The text description label for the caption
    String? label,

    /// Base64 encoded captions file
    String? captionsFile,
  }) async => await dio.post(
    _videoMethod(videoId, '/captions/$srclang'),
    opt: _optionsWithPostBody,
    data: {
      'srclang': srclang,
      if (label != null) 'label': label,
      if (captionsFile != null) 'captionsFile': captionsFile,
    },
  );

  /// Delete caption from video.
  ///
  /// https://docs.bunny.net/reference/video_deletecaption
  Future<Response<Map<String, dynamic>>> deleteCaption(
    /// The video ID to delete caption.
    String videoId, {

    /// The unique srclang shortcode for the caption
    required String srclang,
  }) async => await dio.delete(
    _videoMethod(videoId, '/captions/$srclang'),
    opt: _defaultOptions,
  );

  /// Transcribe video.
  ///
  /// https://docs.bunny.net/reference/video_transcribevideo
  Future<Response<Map<String, dynamic>>> transcribeVideo(
    /// The video ID to delete caption.
    String videoId, {

    /// Video source language, use ISO 639-1 language code
    String? language,

    bool force = false,

    /// List of languages that will be used as target languages, use ISO 639-1 language codes
    List<String>? targetLanguages,

    /// Whether video title should be automatically generated
    bool generateTitle = false,

    /// Whether video description should be automatically generated
    bool generateDescription = false,

    /// Video source language, use ISO 639-1 language code. IMPORTANT: This value takes precedence over query param [language], if specified
    String? sourceLanguage,
  }) async => await dio.post(
    _videoMethod(videoId, '/transcribe', {
      if (language != null) 'language': language,
      'force': force,
    }),
    opt: _optionsWithPostBody,
    data: {
      if (targetLanguages != null && targetLanguages.isNotEmpty)
        'targetLanguages': targetLanguages,
      'generateTitle': generateTitle,
      'generateDescription': generateDescription,
      if (sourceLanguage != null) 'sourceLanguage': sourceLanguage,
    },
  );

  /// Get video resolution.
  ///
  /// https://docs.bunny.net/reference/video_getvideoresolutions
  Future<Response<Map<String, dynamic>>> videoResolutionsInfo(
    /// The video ID to get resolutions.
    String videoId,
  ) async => await dio.get(
    _videoMethod(videoId, '/resolutions'),
    opt: _defaultOptions,
  );

  /// Cleanup unconfigured resolutions.
  ///
  /// https://docs.bunny.net/reference/video_deleteresolutions
  Future<Response<Map<String, dynamic>>> deleteUnconfiguredResolutions(
    /// The video ID to delete resolutions.
    String videoId, {

    /// Resolution to delete
    String? resolutionsToDelete,

    /// Delete non configured resolutions
    bool deleteNonConfiguredResolutions = false,

    /// Delete original
    bool deleteOriginal = false,

    /// Delete MP4
    bool deleteMp4Files = false,

    /// If set to true, no actual file manipulation will happen, only informational data will be returned
    bool dryRun = false,
  }) async => await dio.post(
    _videoMethod(videoId, '/resolutions/cleanup'),
    opt: _defaultOptions,
  );
}
