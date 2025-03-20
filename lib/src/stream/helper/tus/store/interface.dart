import 'package:bunny_dart/src/stream/helper/tus/store/store.dart';

class BunnyTusFileStore extends TusStore {
  BunnyTusFileStore(super.directoryOrNamespace);

  @override
  Future<Uri?> get(String fingerprint) {
    throw UnimplementedError();
  }

  @override
  Future<Map<String, dynamic>?> getMetadata(String fingerprint) {
    throw UnimplementedError();
  }

  @override
  Future<void> remove(String fingerprint) {
    throw UnimplementedError();
  }

  @override
  Future<void> set(String fingerprint, Uri url) {
    throw UnimplementedError();
  }

  @override
  Future<void> setMetadata(String fingerprint, Map<String, dynamic> metadata) {
    throw UnimplementedError();
  }
}
