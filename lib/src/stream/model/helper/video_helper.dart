// ignore_for_file: avoid_dynamic_calls, argument_type_not_assignable, constant_identifier_names

import 'dart:convert';

import 'package:bunny_dart/src/stream/model/video.dart';
import 'package:crypto/crypto.dart';

extension VideoHelper on Video {
  /// Get direct MP4 links for the video.
  ///
  /// [baseUrl] is the CDN domain.
  ///
  /// [cdnToken] is the token from BunnyCDN.
  ///
  /// [expiredAt] is the expiry date for the token.
  ///
  /// [pathBased] is whether the token is path-based or not.
  ///
  /// Returns a map of resolution and direct MP4 link.
  ///
  /// https://docs.bunny.net/docs/stream-video-storage-structure
  ///
  /// https://support.bunny.net/hc/en-us/articles/360016055099-How-to-sign-URLs-for-BunnyCDN-Token-Authentication
  Map<String, String> getDirectMp4Links(
    String baseUrl, {
    required String cdnToken,
    required DateTime expiredAt,
    bool pathBased = true,
  }) {
    if (!hasMP4Fallback) {
      return {};
    }
    if (availableResolutions == null) {
      return {};
    }
    if (availableResolutions!.isEmpty) {
      return {};
    }
    final expiry = (expiredAt.millisecondsSinceEpoch ~/ 1000).toString();

    final links = <String, String>{};

    for (final q in availableResolutions!.split(',')) {
      final path = '/$guid/play_$q.mp4';

      final token = base64Encode(
            sha256.convert(utf8.encode(cdnToken + path + expiry)).bytes,
          )
          .replaceAll('\n', '')
          .replaceAll('+', '-')
          .replaceAll('/', '_')
          .replaceAll('=', '');

      if (pathBased) {
        final url = Uri.https(baseUrl, '', {
          'bcdn_token': token,
          'expires': expiry,
          'token_path': path,
        });

        links[q] = Uri.decodeFull(url.toString()).replaceAll('?', '/');
      } else {
        final url = Uri.https(baseUrl, path, {
          'token': token,
          'expires': expiry,
        });

        links[q] = Uri.decodeFull(url.toString());
      }
    }

    return links;
  }

  /// Human readable duration of the video.
  String get humanReadableDuration {
    final duration = length;
    final hours = duration ~/ 3600;
    final minutes = (duration % 3600) ~/ 60;
    final seconds = duration % 60;

    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    if (minutes > 0) {
      return '$minutes:${seconds.toString().padLeft(2, '0')}';
    }
    return '0:$seconds';
  }

  /// Human readable size of the video.
  String get humanReadableSize {
    final sizeInByte = storageSize;
    final sizeInKb = sizeInByte / 1024;
    final sizeInMb = sizeInKb / 1024;
    final sizeInGb = sizeInMb / 1024;

    if (sizeInGb >= 1) {
      return '${sizeInGb.toStringAsFixed(2)} GB';
    }
    if (sizeInMb >= 1) {
      return '${sizeInMb.toStringAsFixed(2)} MB';
    }
    if (sizeInKb >= 1) {
      return '${sizeInKb.toStringAsFixed(2)} KB';
    }
    return '$sizeInByte B';
  }

  /// Get available resolutions for the video.
  List<Resolution> get availableResolutionsList {
    if (availableResolutions == null) {
      return [];
    }
    if (availableResolutions!.isEmpty) {
      return [];
    }
    return availableResolutions!.split(',').map((e) {
      switch (e) {
        case '240p':
          return Resolution._240p;
        case '360p':
          return Resolution._360p;
        case '480p':
          return Resolution._480p;
        case '720p':
          return Resolution._720p;
        case '1080p':
          return Resolution._1080p;
        case '1440p':
          return Resolution._1440p;
        case '2160p':
          return Resolution._2160p;
        default:
          return Resolution.unknown;
      }
    }).toList();
  }

  /// Get embed link for the video with customizable parameters.
  ///
  /// https://docs.bunny.net/docs/stream-embedding-videos
  ///
  /// [autoplay] Controls whether the video should start playing automatically
  ///
  /// [captions] Controls the default captions file that will be shown
  ///
  /// [preload] Controls whether the video files are preloaded
  ///
  /// [t] Sets the video start time (accepts: "Xs", "1h20m45s", "hh:mm:ss", or seconds)
  ///
  /// [chromecast] Enables or disables Chromecast support
  ///
  /// [disableAirplay] Disables AirPlay support when true
  ///
  /// [disableIosPlayer] Disables the native iOS player when true
  ///
  /// [showHeatmap] Displays a heatmap on the progress bar when true
  ///
  /// [muted] If true, the player starts in mute mode
  ///
  /// [loop] Replays the video automatically after it ends when true
  ///
  /// [playsinline] Allows video to play inline on mobile devices
  ///
  /// [showSpeed] Shows speed control within the player when true
  String getDefaultEmbedLink(
    String baseUrl, {
    bool? autoplay,
    String? captions,
    bool? preload,
    String? t,
    bool? chromecast,
    bool? disableAirplay,
    bool? disableIosPlayer,
    bool? showHeatmap,
    bool? muted,
    bool? loop,
    bool? playsinline,
    bool? showSpeed,
  }) {
    if (guid == null) {
      return '';
    }

    final queryParams = <String, String>{};

    if (autoplay != null) queryParams['autoplay'] = autoplay.toString();
    if (captions != null) queryParams['captions'] = captions;
    if (preload != null) queryParams['preload'] = preload.toString();
    if (t != null) queryParams['t'] = t;
    if (chromecast != null) queryParams['chromecast'] = chromecast.toString();
    if (disableAirplay != null) {
      queryParams['disableAirplay'] = disableAirplay.toString();
    }
    if (disableIosPlayer != null) {
      queryParams['disableIosPlayer'] = disableIosPlayer.toString();
    }
    if (showHeatmap != null) {
      queryParams['showHeatmap'] = showHeatmap.toString();
    }
    if (muted != null) queryParams['muted'] = muted.toString();
    if (loop != null) queryParams['loop'] = loop.toString();
    if (playsinline != null) {
      queryParams['playsinline'] = playsinline.toString();
    }
    if (showSpeed != null) queryParams['showSpeed'] = showSpeed.toString();

    return Uri.decodeFull(
      Uri.https(
        'iframe.mediadelivery.net',
        '/embed/$videoLibraryId/$guid',
        queryParams,
      ).toString(),
    );
  }
}

enum Resolution {
  /// Handling unknown resolution.
  unknown,
  _240p,
  _360p,
  _480p,
  _720p,
  _1080p,
  _1440p,
  _2160p;

  const Resolution();

  String get valueString {
    switch (this) {
      case _240p:
        return '240p';
      case _360p:
        return '360p';
      case _480p:
        return '480p';
      case _720p:
        return '720p';
      case _1080p:
        return '1080p';
      case _1440p:
        return '1440p';
      case _2160p:
        return '2160p';

      case Resolution.unknown:
        return 'Unknown';
    }
  }
}
