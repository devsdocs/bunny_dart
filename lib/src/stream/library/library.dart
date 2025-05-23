import 'package:bunny_dart/src/common/response.dart';
import 'package:bunny_dart/src/stream/collection/collection.dart';
import 'package:bunny_dart/src/stream/helper/tus/bunny_tus_client.dart';
import 'package:bunny_dart/src/stream/helper/tus/store/store.dart';
import 'package:bunny_dart/src/stream/model/list_videos.dart';
import 'package:bunny_dart/src/stream/model/video.dart';
import 'package:bunny_dart/src/stream/model/video_chapter.dart';
import 'package:bunny_dart/src/stream/model/video_meta_tag.dart';
import 'package:bunny_dart/src/stream/model/video_moment.dart';
import 'package:bunny_dart/src/stream/model/video_play_data.dart';
import 'package:bunny_dart/src/tool/dio_proxy.dart';
import 'package:bunny_dart/src/tool/verbose.dart';
import 'package:cross_file/cross_file.dart';
import 'package:dio/dio.dart';

part 'extension.dart';
part 'raw.dart';

/// The main class to interact with the BunnyStream Library API
class BunnyStreamLibrary {
  /// Get a collection by its ID
  BunnyStreamCollection collection(String collectionId) =>
      BunnyStreamCollection(
        _streamKey,
        libraryId: _libraryId,
        collectionId: collectionId,
      );

  /// Raw request methods
  _BunnyStreamLibrary get rawRequest =>
      _BunnyStreamLibrary(_streamKey, libraryId: _libraryId);

  void _sendError(String message) {
    errorPrint(message, isPrint: _errorPrint);
  }

  /// Library ID
  final int _libraryId;

  /// Stream key
  final String _streamKey;

  /// Whether to print errors to the console
  final bool _errorPrint;

  BunnyStreamLibrary(
    String streamKey, {
    required int libraryId,
    bool errorPrint = false,
  }) : _streamKey = streamKey,
       _errorPrint = errorPrint,
       _libraryId = libraryId;

  Future<Video?> getVideo(String videoId) async {
    try {
      final response = await rawRequest.getVideo(videoId);
      return Video.fromMap(response.data!);
    } catch (e, s) {
      _sendError('Error: $e\nStack: $s');
      return null;
    }
  }

  Future<CommonResponse?> updateVideo(
    String videoId, {
    String? title,
    String? collectionId,
    List<VideoChapter>? chapters,
    List<VideoMoment>? moments,
    List<VideoMetaTag>? metaTags,
  }) async {
    try {
      final response = await rawRequest.updateVideo(
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

  Future<CommonResponse?> deleteVideo(String videoId) async {
    try {
      final response = await rawRequest.deleteVideo(videoId);
      return CommonResponse.fromMap(response.data!);
    } catch (e, s) {
      _sendError('Error: $e\nStack: $s');
      return null;
    }
  }

  Future<CommonResponse?> uploadVideo(
    String videoId, {
    bool jitEnabled = false,
    String? resolutions,
    String? codecs,
  }) async {
    try {
      final response = await rawRequest.uploadVideo(
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

  // Future<VideoHeatmap?> getVideoHeatmap(String videoId) async {
  //   try {
  //     final response = await getVideoHeatmapResponse(videoId);
  //     return VideoHeatmap.fromMap(response.data!);
  //   } catch (e,s) {
  //     return null;
  //   }
  // }

  Future<VideoPlayData?> getVideoPlayData(String videoId) async {
    try {
      final response = await rawRequest.getVideoPlayData(videoId);
      return VideoPlayData.fromMap(response.data!);
    } catch (e, s) {
      _sendError('Error: $e\nStack: $s');
      return null;
    }
  }

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

  Future<Video?> reencodeVideo(String videoId) async {
    try {
      final response = await rawRequest.reencodeVideo(videoId);
      return Video.fromMap(response.data!);
    } catch (e, s) {
      _sendError('Error: $e\nStack: $s');
      return null;
    }
  }

  Future<Video?> addOutputCodec(
    String videoId, {
    required int outputCodec,
  }) async {
    try {
      final response = await rawRequest.addOutputCodec(
        videoId,
        outputCodec: outputCodec,
      );
      return Video.fromMap(response.data!);
    } catch (e, s) {
      _sendError('Error: $e\nStack: $s');
      return null;
    }
  }

  Future<Video?> repackageVideo(
    String videoId, {
    bool keepOriginalFiles = true,
  }) async {
    try {
      final response = await rawRequest.repackageVideo(
        videoId,
        keepOriginalFiles: keepOriginalFiles,
      );
      return Video.fromMap(response.data!);
    } catch (e, s) {
      _sendError('Error: $e\nStack: $s');
      return null;
    }
  }

  Future<ListVideos?> listVideos({
    int page = 1,
    int itemsPerPage = 100,
    String? search,
    String? collectionId,
    String orderBy = 'date',
  }) async {
    try {
      final response = await rawRequest.listVideos(
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
