// ignore_for_file: avoid_dynamic_calls, argument_type_not_assignable
import 'package:bunny_dart/src/common/common_object.dart';
import 'package:bunny_dart/src/common/video.dart';

class VideoPlayData extends CommonObject {
  final Video _video;
  final String? _captionsPath;
  final String? _seekPath;
  final String? _thumbnailUrl;
  final String? _fallbackUrl;
  final String? _videoPlaylistUrl;
  final String? _originalUrl;
  final String? _previewUrl;
  final String? _controls;
  final bool? _enableDRM;
  final int? _drmVersion;
  final String? _playerKeyColor;
  final String? _vastTagUrl;
  final int? _captionsFontSize;
  final String? _captionsFontColor;
  final String? _captionsBackground;
  final String? _uiLanguage;
  final bool? _allowEarlyPlay;
  final bool? _tokenAuthEnabled;
  final bool? _enableMP4Fallback;
  final bool? _showHeatmap;
  final String? _fontFamily;
  final String? _playbackSpeeds;

  VideoPlayData(
    Video video, {
    String? captionsPath,
    String? seekPath,
    String? thumbnailUrl,
    String? fallbackUrl,
    String? videoPlaylistUrl,
    String? originalUrl,
    String? previewUrl,
    String? controls,
    bool? enableDRM,
    int? drmVersion,
    String? playerKeyColor,
    String? vastTagUrl,
    int? captionsFontSize,
    String? captionsFontColor,
    String? captionsBackground,
    String? uiLanguage,
    bool? allowEarlyPlay,
    bool? tokenAuthEnabled,
    bool? enableMP4Fallback,
    bool? showHeatmap,
    String? fontFamily,
    String? playbackSpeeds,
  }) : _video = video,
       _captionsPath = captionsPath,
       _seekPath = seekPath,
       _thumbnailUrl = thumbnailUrl,
       _fallbackUrl = fallbackUrl,
       _videoPlaylistUrl = videoPlaylistUrl,
       _originalUrl = originalUrl,
       _previewUrl = previewUrl,
       _controls = controls,
       _enableDRM = enableDRM,
       _drmVersion = drmVersion,
       _playerKeyColor = playerKeyColor,
       _vastTagUrl = vastTagUrl,
       _captionsFontSize = captionsFontSize,
       _captionsFontColor = captionsFontColor,
       _captionsBackground = captionsBackground,
       _uiLanguage = uiLanguage,
       _allowEarlyPlay = allowEarlyPlay,
       _tokenAuthEnabled = tokenAuthEnabled,
       _enableMP4Fallback = enableMP4Fallback,
       _showHeatmap = showHeatmap,
       _fontFamily = fontFamily,
       _playbackSpeeds = playbackSpeeds;

  factory VideoPlayData.fromMap(Map<String, dynamic> map) => VideoPlayData(
    Video.fromMap(map['video']),
    captionsPath: map['captionsPath'],
    seekPath: map['seekPath'],
    thumbnailUrl: map['thumbnailUrl'],
    fallbackUrl: map['fallbackUrl'],
    videoPlaylistUrl: map['videoPlaylistUrl'],
    originalUrl: map['originalUrl'],
    previewUrl: map['previewUrl'],
    controls: map['controls'],
    enableDRM: map['enableDRM'],
    drmVersion: map['drmVersion'],
    playerKeyColor: map['playerKeyColor'],
    vastTagUrl: map['vastTagUrl'],
    captionsFontSize: map['captionsFontSize'],
    captionsFontColor: map['captionsFontColor'],
    captionsBackground: map['captionsBackground'],
    uiLanguage: map['uiLanguage'],
    allowEarlyPlay: map['allowEarlyPlay'],
    tokenAuthEnabled: map['tokenAuthEnabled'],
    enableMP4Fallback: map['enableMP4Fallback'],
    showHeatmap: map['showHeatmap'],
    fontFamily: map['fontFamily'],
    playbackSpeeds: map['playbackSpeeds'],
  );

  @override
  Map<String, dynamic> get toMap => {
    'video': _video.toMap,
    if (_captionsPath != null) 'captionsPath': _captionsPath,
    if (_seekPath != null) 'seekPath': _seekPath,
    if (_thumbnailUrl != null) 'thumbnailUrl': _thumbnailUrl,
    if (_fallbackUrl != null) 'fallbackUrl': _fallbackUrl,
    if (_videoPlaylistUrl != null) 'videoPlaylistUrl': _videoPlaylistUrl,
    if (_originalUrl != null) 'originalUrl': _originalUrl,
    if (_previewUrl != null) 'previewUrl': _previewUrl,
    if (_controls != null) 'controls': _controls,
    if (_enableDRM != null) 'enableDRM': _enableDRM,
    if (_drmVersion != null) 'drmVersion': _drmVersion,
    if (_playerKeyColor != null) 'playerKeyColor': _playerKeyColor,
    if (_vastTagUrl != null) 'vastTagUrl': _vastTagUrl,
    if (_captionsFontSize != null) 'captionsFontSize': _captionsFontSize,
    if (_captionsFontColor != null) 'captionsFontColor': _captionsFontColor,
    if (_captionsBackground != null) 'captionsBackground': _captionsBackground,
    if (_uiLanguage != null) 'uiLanguage': _uiLanguage,
    if (_allowEarlyPlay != null) 'allowEarlyPlay': _allowEarlyPlay,
    if (_tokenAuthEnabled != null) 'tokenAuthEnabled': _tokenAuthEnabled,
    if (_enableMP4Fallback != null) 'enableMP4Fallback': _enableMP4Fallback,
    if (_showHeatmap != null) 'showHeatmap': _showHeatmap,
    if (_fontFamily != null) 'fontFamily': _fontFamily,
    if (_playbackSpeeds != null) 'playbackSpeeds': _playbackSpeeds,
  };
}
