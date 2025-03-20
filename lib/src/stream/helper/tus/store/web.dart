import 'dart:convert';
import 'package:bunny_dart/src/stream/helper/tus/store/store.dart';
import 'package:web/web.dart' as html;

/// [BunnyTusFileStore] is used for storing upload progress locally in the browser.
/// It is used by [TusClient] to resume uploads at correct %.
class BunnyTusFileStore implements TusStore {
  /// It must receive a namespace for the localStorage keys
  BunnyTusFileStore(this.namespace);

  /// The namespace for localStorage keys
  final String namespace;

  /// The localStorage key prefix for URLs
  String get _urlPrefix =>
      'tus_url_${namespace}_'.replaceAll('/', '_').replaceAll(r'\', '_');

  /// The localStorage key prefix for metadata
  String get _metaPrefix =>
      'tus_meta_${namespace}_'.replaceAll('/', '_').replaceAll(r'\', '_');

  /// Store a new [fingerprint] and its upload [url].
  @override
  Future<void> set(String fingerprint, Uri url) async {
    html.window.localStorage.setItem(_urlPrefix + fingerprint, url.toString());
  }

  /// Retrieve an upload's Uri for a [fingerprint].
  /// If no matching entry is found this method will return `null`.
  @override
  Future<Uri?> get(String fingerprint) async {
    final urlStr = html.window.localStorage.getItem(_urlPrefix + fingerprint);
    if (urlStr == null) {
      return null;
    }
    return Uri.parse(urlStr);
  }

  /// Remove an entry from the store using an upload's [fingerprint].
  @override
  Future<void> remove(String fingerprint) async {
    html.window.localStorage.removeItem(_urlPrefix + fingerprint);
    html.window.localStorage.removeItem(_metaPrefix + fingerprint);
  }

  /// Store additional metadata for a fingerprint
  @override
  Future<void> setMetadata(
    String fingerprint,
    Map<String, dynamic> metadata,
  ) async {
    html.window.localStorage.setItem(
      _metaPrefix + fingerprint,
      jsonEncode(metadata),
    );
  }

  /// Get metadata for a fingerprint
  @override
  Future<Map<String, dynamic>?> getMetadata(String fingerprint) async {
    final data = html.window.localStorage.getItem(_metaPrefix + fingerprint);
    if (data == null) {
      return null;
    }
    return jsonDecode(data) as Map<String, dynamic>;
  }

  @override
  String get directoryOrNamespaceInternal => namespace;
}
