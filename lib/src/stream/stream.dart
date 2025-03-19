import 'package:bunny_dart/src/stream/library/library.dart';

class BunnyStream {
  final String _streamKey;
  final bool _errorPrint;

  BunnyStream(String streamKey, {bool errorPrint = false})
    : _streamKey = streamKey,
      _errorPrint = errorPrint;

  BunnyStreamLibrary library(int libraryId) => BunnyStreamLibrary(
    _streamKey,
    libraryId: libraryId,
    errorPrint: _errorPrint,
  );
}
