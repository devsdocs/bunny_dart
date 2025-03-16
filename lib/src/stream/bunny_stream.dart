import 'package:bunny_dart/src/stream/bunny_stream_library.dart';

class BunnyStream {
  final String _streamKey;

  BunnyStream(String streamKey) : _streamKey = streamKey;

  BunnyStreamLibrary library(int libraryId) =>
      BunnyStreamLibrary(_streamKey, libraryId: libraryId);
}
