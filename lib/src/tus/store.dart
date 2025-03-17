import 'dart:io';
import 'dart:convert';

/// Implementations of this interface are used to lookup a
/// [fingerprint] with the corresponding [file].
///
/// This functionality is used to allow resuming uploads.
///
/// See [TusMemoryStore] or [TusFileStore]
abstract class TusStore {
  /// Store a new [fingerprint] and its upload [url].
  Future<void> set(String fingerprint, Uri url);

  /// Retrieve an upload's Uri for a [fingerprint].
  /// If no matching entry is found this method will return `null`.
  Future<Uri?> get(String fingerprint);

  /// Remove an entry from the store using an upload's [fingerprint].
  Future<void> remove(String fingerprint);
}

/// This class is used to lookup a [fingerprint] with the
/// corresponding [file] entries in a [Map].
///
/// This functionality is used to allow resuming uploads.
///
/// This store **will not** keep the values after your application crashes or
/// restarts.
class TusMemoryStore implements TusStore {
  Map<String, Uri> store = {};

  @override
  Future<void> set(String fingerprint, Uri url) async {
    store[fingerprint] = url;
  }

  @override
  Future<Uri?> get(String fingerprint) async {
    return store[fingerprint];
  }

  @override
  Future<void> remove(String fingerprint) async {
    store.remove(fingerprint);
  }
}

/// [TusFileStore] is used for storing upload progress locally on the device.
/// It is used by [TusClient] to resume uploads at correct %.
class TusFileStore implements TusStore {
  /// It must receive the directory to store the upload.
  TusFileStore(this.directory) {
    // Ensure the directory exists
    if (!directory.existsSync()) {
      directory.createSync(recursive: true);
    }
  }

  /// The directory where the upload  is stored.
  final Directory directory;

  /// Store a new [fingerprint] and its upload [url]. The [fingerprint] is
  /// generated by [TusClient] and is used to identify the upload. Basically
  /// it's a made of the file location + file name.
  @override
  Future<void> set(String fingerprint, Uri url) async {
    final file = await _getFile(fingerprint);
    await file.writeAsString(url.toString());
  }

  /// Retrieve an upload's Uri for a [fingerprint].
  /// If no matching entry is found this method will return `null`.
  @override
  Future<Uri?> get(String fingerprint) async {
    final file = await _getFile(fingerprint);
    if (file.existsSync()) {
      return Uri.parse(await file.readAsString());
    }
    return null;
  }

  /// Remove an entry from the store using an upload's [fingerprint].
  @override
  Future<void> remove(String fingerprint) async {
    final file = await _getFile(fingerprint);

    if (file.existsSync()) {
      file.deleteSync();
    }
  }

  Future<File> _getFile(String fingerprint) async {
    final filePath = '${directory.absolute.path}/$fingerprint';
    return File(filePath);
  }
}

/// Enhanced [TusFileStore] that also stores metadata about each upload
/// This is particularly useful for Bunny.net uploads where additional
/// information about each upload needs to be preserved
class BunnyTusFileStore extends TusFileStore {
  BunnyTusFileStore(super.directory);

  /// Store additional metadata for a fingerprint
  Future<void> setMetadata(
    String fingerprint,
    Map<String, dynamic> metadata,
  ) async {
    final file = await _getMetadataFile(fingerprint);
    await file.writeAsString(jsonEncode(metadata));
  }

  /// Get metadata for a fingerprint
  Future<Map<String, dynamic>?> getMetadata(String fingerprint) async {
    final file = await _getMetadataFile(fingerprint);
    if (file.existsSync()) {
      final data = await file.readAsString();
      return jsonDecode(data) as Map<String, dynamic>;
    }
    return null;
  }

  /// Remove metadata for a fingerprint
  @override
  Future<void> remove(String fingerprint) async {
    await super.remove(fingerprint);

    // Also remove metadata
    final metaFile = await _getMetadataFile(fingerprint);
    if (metaFile.existsSync()) {
      metaFile.deleteSync();
    }
  }

  Future<File> _getMetadataFile(String fingerprint) async {
    final filePath = '${directory.absolute.path}/$fingerprint.meta';
    return File(filePath);
  }
}
