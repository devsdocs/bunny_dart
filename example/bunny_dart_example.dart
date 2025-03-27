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
  );

  await upload!.startUpload(
    onStart: (p0, p1) {},
    onProgress: (sended, total, speed, eta) {},
    onComplete: () {},
    measureUploadSpeed: true,
  );
}
