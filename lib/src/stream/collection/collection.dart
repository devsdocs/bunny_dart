class BunnyStreamCollection {
  static const _base = 'video.bunnycdn.com';

  Uri collectionMethod(String path) =>
      Uri.https(_base, '/library/$libraryId/collections$path');

  final int libraryId;
  final String collectionId;
  final String streamKey;

  BunnyStreamCollection(
    String streamKey, {
    required int libraryId,
    required String collectionId,
  }) : streamKey = streamKey,
       collectionId = collectionId,
       libraryId = libraryId;
}
