(WIP) Dart Wrapper for [Bunny.net](https://docs.bunny.net/reference) API

``` dart
import 'dart:io';
import 'package:bunny_dart/bunny_dart.dart';

void main() async {
  // Initialize your Bunny.net client
  final bunnyClient = BunnyStreamLibrary('YOUR_API_KEY', libraryId: 12345);
  
  // Create a TUS store for resumable uploads
  final store = TusFileStore(Directory('path/to/store/uploads'));
  
  // Create a batch uploader
  final uploader = bunnyClient.createBatchUploader(store: store);
  
  // Add a directory of videos
  await uploader.addDirectory('/path/to/videos', recursive: true);
  
  // Add filters - only videos longer than 1 minute and only from a specific directory
  uploader.filterByMinDuration(const Duration(minutes: 1));
  uploader.filterByDirectory('/path/to/specific/videos');
  
  // Apply filters to see which videos will be uploaded
  await for (final update in uploader.applyFilters()) {
    // Print status updates
    print('Eligible videos: ${uploader.eligibleCount}');
  }
  
  // Start uploading
  await for (final update in uploader.uploadVideos()) {
    // Show progress
    final completed = update.where((v) => v.status == VideoProcessingStatus.completed).length;
    final total = update.length;
    print('Uploaded $completed of $total videos');
  }
  
  // Or use the convenience method for everything in one call
  await for (final update in bunnyClient.uploadVideosFromDirectory(
    directory: '/path/to/videos',
    minDuration: const Duration(minutes: 1),
    collectionId: 'your-collection-id',
    detectChapters: true,
  )) {
    // Process updates
    print('Processing videos: ${update.length}');
  }
}
```

Credit: https://github.com/tomassasovsky/tus_client