// ignore_for_file: avoid_dynamic_calls, argument_type_not_assignable

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
  /// https://support.bunny.net/hc/en-us/articles/360016055099-How-to-sign-URLs-for-BunnyCDN-Token-Authentication
  Map<String, String> getDirectMp4Link(
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

    String path(String q) => '/$guid/play_$q.mp4';

    final links = <String, String>{};

    for (final q in availableResolutions!.split(',')) {
      final token = base64Encode(
            sha256.convert(utf8.encode(cdnToken + path(q) + expiry)).bytes,
          )
          .replaceAll('\n', '')
          .replaceAll('+', '-')
          .replaceAll('/', '_')
          .replaceAll('=', '');

      if (pathBased) {
        final url = Uri.https(baseUrl, '', {
          'bcdn_token': token,
          'expires': expiry,
          'token_path': path(q),
        });

        links[q] = Uri.decodeFull(url.toString()).replaceAll('?', '/');
      } else {
        final url = Uri.https(baseUrl, path(q), {
          'token': token,
          'expires': expiry,
        });

        links[q] = Uri.decodeFull(url.toString());
      }
    }

    return links;
  }
}
