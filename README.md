(WIP) Dart Wrapper for [Bunny.net](https://docs.bunny.net/reference) APIs

[![pub package](https://img.shields.io/pub/v/bunny_dart)](https://pub.dev/packages/bunny_dart)

Supporting various endpoints, including TUS Resumable Upload for efficient video uploads, ensuring seamless integration and enhanced performance.

``` dart
import 'package:bunny_dart/bunny_dart.dart';

const streamKey = 'YOUR_BUNNY_STREAM_KEY';
const libraryId = 12345;

void main() async {
  final bunnyStreamLibrary = BunnyStream(streamKey).library(libraryId);

  final store = BunnyTusFileStore('tus/fingerprint/path');

  final upload = await bunnyStreamLibrary.createVideoWithTusUpload(
    title: 'Video Title',
    videoFile: XFile('path/to/video.mp4'),
    store: store,
    maxChunkSize: 512 * 1024,
  );

  await upload!.startUpload(
            onStart: (p0, p1) {},
            onProgress: (sended, total, speed, eta) {},
            onComplete: () {},
            measureUploadSpeed: true,
            forceNewUpload: attempt > 3, // Force new upload on retry
          );
}
```

Credit: https://github.com/tomassasovsky/tus_client