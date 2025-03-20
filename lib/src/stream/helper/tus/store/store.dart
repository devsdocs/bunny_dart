/// Implementations of this interface are used to lookup a
/// [fingerprint]
///
/// This functionality is used to allow resuming uploads.
abstract class TusStore {
  TusStore(String directoryOrNamespace)
    : directoryOrNamespaceInternal = directoryOrNamespace;

  final String directoryOrNamespaceInternal;

  /// Store a new [fingerprint] and its upload [url].
  Future<void> set(String fingerprint, Uri url);

  /// Retrieve an upload's Uri for a [fingerprint].
  /// If no matching entry is found this method will return `null`.
  Future<Uri?> get(String fingerprint);

  /// Remove an entry from the store using an upload's [fingerprint].
  Future<void> remove(String fingerprint);

  Future<void> setMetadata(String fingerprint, Map<String, dynamic> metadata);

  Future<Map<String, dynamic>?> getMetadata(String fingerprint);
}
