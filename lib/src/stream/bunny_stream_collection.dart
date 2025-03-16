class BunnyStreamCollection {
  static const _base = 'video.bunnycdn.com';

  Uri _collectionMethod(String path) =>
      Uri.https(_base, '/library/$_libraryId/collections$path');

  final int _libraryId;
  final String _collectionId;
  final String _streamKey;

  BunnyStreamCollection(
    String streamKey, {
    required int libraryId,
    required String collectionId,
  }) : _streamKey = streamKey,
       _collectionId = collectionId,
       _libraryId = libraryId;
}
