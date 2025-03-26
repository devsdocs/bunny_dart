import 'package:bunny_dart/src/stream/library/library.dart';

/// The main class to interact with the BunnyStream API
class BunnyStream {
  /// The stream key
  final String _streamKey;

  /// Whether to print errors to the console
  final bool _errorPrint;

  BunnyStream(String streamKey, {bool errorPrint = false})
    : _streamKey = streamKey,
      _errorPrint = errorPrint;

  /// Get a library by its ID
  BunnyStreamLibrary library(int libraryId) => BunnyStreamLibrary(
    _streamKey,
    libraryId: libraryId,
    errorPrint: _errorPrint,
  );
}
