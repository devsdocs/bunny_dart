part of 'collection.dart';

class _BunnyStreamCollection {
  static const _base = 'video.bunnycdn.com';

  /// Library ID
  final int _libraryId;

  /// Collection ID
  final String _collectionId;

  /// Stream key
  final String _streamKey;

  Options get _defaultOptions => Options(headers: {'AccessKey': _streamKey});

  Options get _optionsWithPostBody => Options(
    headers: {'AccessKey': _streamKey},
    contentType: Headers.jsonContentType,
  );

  _BunnyStreamCollection(
    String streamKey, {
    required int libraryId,
    required String collectionId,
  }) : _streamKey = streamKey,
       _collectionId = collectionId,
       _libraryId = libraryId;

  Uri collectionMethod({
    bool includeCollectionId = true,
    Map<String, dynamic>? query,
  }) => Uri.https(
    _base,
    '/library/$_libraryId/collections${includeCollectionId ? '/$_collectionId' : ''}',
    query,
  );

  /// Get a collection by its ID
  ///
  /// https://docs.bunny.net/reference/collection_getcollection
  Future<Response<Map<String, dynamic>>?> getCollection({
    /// Include thumbnails
    bool includeThumbnails = false,
  }) async {
    return await dio.get(
      collectionMethod(query: {'includeThumbnails': includeThumbnails}),
      opt: _defaultOptions,
    );
  }

  /// Update a collection
  ///
  /// https://docs.bunny.net/reference/collection_updatecollection
  Future<Response<Map<String, dynamic>>?> updateCollection({
    /// Name of the collection
    String? name,
  }) async {
    return await dio.post(
      collectionMethod(),
      data: {if (name != null) 'name': name},
      opt: _optionsWithPostBody,
    );
  }

  /// Delete a collection
  ///
  /// https://docs.bunny.net/reference/collection_deletecollection
  Future<Response<Map<String, dynamic>>?> deleteCollection() async {
    return await dio.delete(collectionMethod(), opt: _defaultOptions);
  }

  /// Get collection list
  ///
  /// https://docs.bunny.net/reference/collection_list
  Future<Response<Map<String, dynamic>>?> listCollections({
    /// Page number
    int page = 1,

    /// Number of items per page
    int itemsPerPage = 100,

    /// Search
    String? search,

    /// Order by
    String orderBy = 'date',

    /// Include thumbnails
    bool includeThumbnails = false,
  }) async {
    return await dio.get(
      collectionMethod(
        includeCollectionId: false,
        query: {'includeThumbnails': includeThumbnails},
      ),
      opt: _defaultOptions,
    );
  }

  /// Create a collection
  ///
  /// https://docs.bunny.net/reference/collection_createcollection
  Future<Response<Map<String, dynamic>>?> createCollection({
    /// Name of the collection
    String? name,
  }) async {
    return await dio.post(
      collectionMethod(),
      data: {if (name != null) 'name': name},
      opt: _optionsWithPostBody,
    );
  }
}
