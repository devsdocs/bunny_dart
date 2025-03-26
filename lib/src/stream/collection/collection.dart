import 'package:bunny_dart/src/tool/dio_proxy.dart';
import 'package:dio/dio.dart';

part 'raw.dart';

/// Main class for BunnyStream Library Collections API
class BunnyStreamCollection {
  _BunnyStreamCollection get rawRequest => _BunnyStreamCollection(
    _streamKey,
    libraryId: _libraryId,
    collectionId: _collectionId,
  );

  /// Library ID
  final int _libraryId;

  /// Collection ID
  final String _collectionId;

  /// Stream key
  final String _streamKey;

  BunnyStreamCollection(
    String streamKey, {
    required int libraryId,
    required String collectionId,
  }) : _streamKey = streamKey,
       _collectionId = collectionId,
       _libraryId = libraryId;
}
