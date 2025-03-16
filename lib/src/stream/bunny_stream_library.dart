import 'package:bunny_dart/src/common/video.dart';
import 'package:bunny_dart/src/common/video_chapter.dart';
import 'package:bunny_dart/src/common/video_meta_tag.dart';
import 'package:bunny_dart/src/common/video_moment.dart';
import 'package:bunny_dart/src/stream/bunny_stream_collection.dart';
import 'package:bunny_dart/src/tool/dio_proxy.dart';
import 'package:dio/dio.dart';

class BunnyStreamLibrary {
  static const _base = 'video.bunnycdn.com';

  BunnyStreamCollection collection(String collectionId) =>
      BunnyStreamCollection(
        _streamKey,
        libraryId: _libraryId,
        collectionId: collectionId,
      );

  Uri _libraryMethod([String? path, Map<String, dynamic>? queryParameters]) =>
      Uri.https(_base, '/library/$_libraryId${path ?? ''}', queryParameters);

  Uri _videoMethod(
    String videoId, [
    String? path,
    Map<String, dynamic>? queryParameters,
  ]) => Uri.https(
    _base,
    '/library/$_libraryId/videos/$videoId${path ?? ''}',
    queryParameters,
  );

  Options get _defaultOptions => Options(headers: {'AccessKey': _streamKey});

  Options get _optionsWithPostBody => Options(
    headers: {'AccessKey': _streamKey},
    contentType: Headers.jsonContentType,
  );

  final int _libraryId;
  final String _streamKey;

  BunnyStreamLibrary(String streamKey, {required int libraryId})
    : _streamKey = streamKey,
      _libraryId = libraryId;

  /// Get a video from the library.
  ///
  /// https://docs.bunny.net/reference/video_getvideo
  Future<Response<Map<String, dynamic>>> _getVideoResponse(
    /// The video ID to retrieve.
    String videoId,
  ) async => await dio.get(_videoMethod(videoId), _defaultOptions);

  Future<Video?> getVideo(String videoId) async {
    try {
      final response = await _getVideoResponse(videoId);
      return Video.fromMap(response.data!);
    } catch (e) {
      return null;
    }
  }

  /// Update a video in the library.
  ///
  /// https://docs.bunny.net/reference/video_updatevideo
  Future<Response<Map<String, dynamic>>> _updateVideoResponse(
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
    _optionsWithPostBody,
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
  Future<Response<Map<String, dynamic>>> _deleteVideoResponse(
    /// The video ID to delete.
    String videoId,
  ) async => await dio.delete(_videoMethod(videoId), _defaultOptions);

  /// Upload a video to the library.
  ///
  /// https://docs.bunny.net/reference/video_uploadvideo
  Future<Response<Map<String, dynamic>>> _uploadVideoResponse(
    /// The video ID to be uploaded.
    String videoId, {

    /// Marks whether JIT encoding should be enabled for this video (works only when Premium Encoding is enabled), overrides library settings
    bool jitEnabled = false,

    /// Comma separated list of resolutions enabled for encoding, available options: 240p, 360p, 480p, 720p, 1080p, 1440p, 2160p
    String? resolutions,

    /// List of codecs that will be used to encode the file (overrides library settings). Available values: x264, vp9
    String? codecs,
  }) async => await dio.post(_videoMethod(videoId), _defaultOptions);

  /// List all videos in the library.
  ///
  /// https://docs.bunny.net/reference/video_list
  Future<Response<Map<String, dynamic>>> _listVideosResponse({
    /// The page number to retrieve. Default is 1.
    int? page,

    /// The number of items to retrieve per page. Default is 100.
    int? itemsPerPage,

    /// The search query to filter the videos by.
    String? search,

    /// The collection ID to filter the videos by.
    String? collectionId,

    /// The category ID to filter the videos by. Default is date.
    String? orderBy,
  }) async => await dio.get(
    _libraryMethod('/videos', {
      'page': page,
      'itemsPerPage': itemsPerPage,
      'search': search,
      'collection': collectionId,
      'orderBy': orderBy,
    }),
    _defaultOptions,
  );
}
