// ignore_for_file: avoid_dynamic_calls, argument_type_not_assignable

import 'package:bunny_dart/src/common/caption.dart';
import 'package:bunny_dart/src/common/common_object.dart';
import 'package:bunny_dart/src/common/transcoding_messages.dart';
import 'package:bunny_dart/src/common/video_chapter.dart';
import 'package:bunny_dart/src/common/video_meta_tag.dart';
import 'package:bunny_dart/src/common/video_moment.dart';

class Video extends CommonObject {
  /// The ID of the video library that the video belongs to
  final int _videoLibraryId;

  /// The unique ID of the video
  final String? _guid;

  /// The title of the video
  final String? _title;

  /// The date when the video was uploaded
  final DateTime _dateUploaded;

  /// The number of views the video received
  final int _views;

  /// Determines if the video is publically accessible
  final bool _isPublic;

  /// The duration of the video in seconds
  final int _length;

  /// The status of the video.
  final VideoStatus _status;

  /// The framerate of the video
  final double _framerate;

  /// The rotation of the video
  final int? _rotation;

  /// The width of the original video file
  final int _width;

  /// The height of the original video file
  final int _height;

  /// The available resolutions of the video
  final String? _availableResolutions;

  /// Encoded output codecs of the video
  final String? _outputCodecs;

  /// The number of thumbnails generated for this video
  final int _thumbnailCount;

  /// The current encode progress of the video
  final int _encodeProgress;

  /// The amount of storage used by this video
  final int _storageSize;

  /// The list of captions available for the video
  final List<Caption>? _captions;

  /// Determines if the video has MP4 fallback files generated
  final bool _hasMp4Fallback;

  /// The ID of the collection where the video belongs
  final String? _collectionId;

  /// The file name of the thumbnail inside of the storage
  final String? _thumbnailFileName;

  /// The average watch time of the video in seconds
  final int _averageWatchTime;

  /// The total video watch time in seconds
  final int _totalWatchTime;

  /// The automatically detected category of the video
  final String? _category;

  /// The list of chapters available for the video
  final List<VideoChapter>? _chapters;

  /// The list of moments available for the video
  final List<VideoMoment>? _moments;

  /// The list of meta tags that have been added to the video
  final List<VideoMetaTag>? _metaTags;

  /// The list of transcoding messages that describe potential issues while the video was transcoding
  final List<TranscodingMessages>? _transcodingMessages;

  Video({
    required int videoLibraryId,
    String? guid,
    String? title,
    required DateTime dateUploaded,
    required int views,
    required bool isPublic,
    required int length,
    required VideoStatus status,
    required double framerate,
    int? rotation,
    required int width,
    required int height,
    String? availableResolutions,
    String? outputCodecs,
    required int thumbnailCount,
    required int encodeProgress,
    required int storageSize,
    List<Caption>? captions,
    required bool hasMp4Fallback,
    String? collectionId,
    String? thumbnailFileName,
    required int averageWatchTime,
    required int totalWatchTime,
    String? category,
    List<VideoChapter>? chapters,
    List<VideoMoment>? moments,
    List<VideoMetaTag>? metaTags,
    List<TranscodingMessages>? transcodingMessages,
  }) : _videoLibraryId = videoLibraryId,
       _guid = guid,
       _title = title,
       _dateUploaded = dateUploaded,
       _views = views,
       _isPublic = isPublic,
       _length = length,
       _status = status,
       _framerate = framerate,
       _rotation = rotation,
       _width = width,
       _height = height,
       _availableResolutions = availableResolutions,
       _outputCodecs = outputCodecs,
       _thumbnailCount = thumbnailCount,
       _encodeProgress = encodeProgress,
       _storageSize = storageSize,
       _captions = captions,
       _hasMp4Fallback = hasMp4Fallback,
       _collectionId = collectionId,
       _thumbnailFileName = thumbnailFileName,
       _averageWatchTime = averageWatchTime,
       _totalWatchTime = totalWatchTime,
       _category = category,
       _chapters = chapters,
       _moments = moments,
       _metaTags = metaTags,
       _transcodingMessages = transcodingMessages;

  factory Video.fromMap(Map<String, dynamic> map) => Video(
    videoLibraryId: map['videoLibraryId']?.toInt() ?? 0,
    guid: map['guid'] as String?,
    title: map['title'] as String?,
    dateUploaded: DateTime.parse(map['dateUploaded'] as String),
    views: map['views']?.toInt() ?? 0,
    isPublic: map['isPublic'] ?? false,
    length: map['length']?.toInt() ?? 0,
    status: VideoStatus.values[map['status']?.toInt() ?? 0],
    framerate: map['framerate']?.toDouble() ?? 0.0,
    rotation: map['rotation']?.toInt(),
    width: map['width']?.toInt() ?? 0,
    height: map['height']?.toInt() ?? 0,
    availableResolutions: map['availableResolutions'] as String?,
    outputCodecs: map['outputCodecs'] as String?,
    thumbnailCount: map['thumbnailCount']?.toInt() ?? 0,
    encodeProgress: map['encodeProgress']?.toInt() ?? 0,
    storageSize: map['storageSize']?.toInt() ?? 0,
    captions:
        map['captions'] != null
            ? List<Caption>.from(
              (map['captions'] as List<dynamic>).map<Caption>(
                (x) => Caption.fromMap(x as Map<String, dynamic>),
              ),
            )
            : null,
    hasMp4Fallback: map['hasMp4Fallback'] ?? false,
    collectionId: map['collectionId'] as String?,
    thumbnailFileName: map['thumbnailFileName'] as String?,
    averageWatchTime: map['averageWatchTime']?.toInt() ?? 0,
    totalWatchTime: map['totalWatchTime']?.toInt() ?? 0,
    category: map['category'] as String?,
    chapters:
        map['chapters'] != null
            ? List<VideoChapter>.from(
              (map['chapters'] as List<dynamic>).map<VideoChapter>(
                (x) => VideoChapter.fromMap(x as Map<String, dynamic>),
              ),
            )
            : null,
    moments:
        map['moments'] != null
            ? List<VideoMoment>.from(
              (map['moments'] as List<dynamic>).map<VideoMoment>(
                (x) => VideoMoment.fromMap(x as Map<String, dynamic>),
              ),
            )
            : null,
    metaTags:
        map['metaTags'] != null
            ? List<VideoMetaTag>.from(
              (map['metaTags'] as List<dynamic>).map<VideoMetaTag>(
                (x) => VideoMetaTag.fromMap(x as Map<String, dynamic>),
              ),
            )
            : null,
    transcodingMessages:
        map['transcodingMessages'] != null
            ? List<TranscodingMessages>.from(
              (map['transcodingMessages'] as List<dynamic>).map<
                TranscodingMessages
              >((x) => TranscodingMessages.fromMap(x as Map<String, dynamic>)),
            )
            : null,
  );

  @override
  Map<String, dynamic> get toMap => {
    'videoLibraryId': _videoLibraryId,
    if (_guid != null) 'guid': _guid,
    if (_title != null) 'title': _title,
    'dateUploaded': _dateUploaded.toIso8601String(),
    'views': _views,
    'isPublic': _isPublic,
    'length': _length,
    'status': _status.index,
    'framerate': _framerate,
    if (_rotation != null) 'rotation': _rotation,
    'width': _width,
    'height': _height,
    if (_availableResolutions != null)
      'availableResolutions': _availableResolutions,
    if (_outputCodecs != null) 'outputCodecs': _outputCodecs,
    'thumbnailCount': _thumbnailCount,
    'encodeProgress': _encodeProgress,
    'storageSize': _storageSize,
    if (_captions != null && _captions.isNotEmpty)
      'captions': _captions.map((e) => e.toMap).toList(),
    'hasMp4Fallback': _hasMp4Fallback,
    if (_collectionId != null) 'collectionId': _collectionId,
    if (_thumbnailFileName != null) 'thumbnailFileName': _thumbnailFileName,
    'averageWatchTime': _averageWatchTime,
    'totalWatchTime': _totalWatchTime,
    if (_category != null) 'category': _category,
    if (_chapters != null && _chapters.isNotEmpty)
      'chapters': _chapters.map((e) => e.toMap).toList(),
    if (_moments != null && _moments.isNotEmpty)
      'moments': _moments.map((e) => e.toMap).toList(),
    if (_metaTags != null && _metaTags.isNotEmpty)
      'metaTags': _metaTags.map((e) => e.toMap).toList(),
    if (_transcodingMessages != null && _transcodingMessages.isNotEmpty)
      'transcodingMessages': _transcodingMessages.map((e) => e.toMap).toList(),
  };
}

enum VideoStatus {
  created._('Created'),
  uploaded._('Uploaded'),
  processing._('Processing'),
  transcoding._('Transcoding'),
  finished._('Finished'),
  error._('Error'),
  uploadFailed._('Upload Failed'),
  jitSegmenting._('JIT Segmenting'),
  jitPlaylistsCreated._('JIT Playlists Created');

  const VideoStatus._(this.viewString);

  final String viewString;
}
