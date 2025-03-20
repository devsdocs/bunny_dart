(WIP) Dart Wrapper for [Bunny.net](https://docs.bunny.net/reference) API

``` dart
import 'dart:io';
import 'package:bunny_dart/bunny_dart.dart';

const streamKey = 'YOUR_BUNNY_STREAM_KEY';
const libraryId = 12345;

void main() async {
  final bunnyStreamLibrary = BunnyStream(streamKey).library(libraryId);

  final store = BunnyTusFileStore(Directory('tus/fingerprint'));

  final upload = await bunnyStreamLibrary.createVideoWithTusUpload(
    title: 'Video Title',
    videoFile: XFile(customVideoPath),
    store: store,
    maxChunkSize: 512 * 1024,
  );
}
```

Credit: https://github.com/tomassasovsky/tus_client