import 'dart:async';
import 'dart:io';

import 'package:bunny_dart/src/stream/bunny_stream_library.dart';
import 'package:bunny_dart/src/tool/video_metadata_helper.dart';
import 'package:bunny_dart/src/tus/retry_scale.dart';
import 'package:bunny_dart/src/tus/store.dart';
import 'package:cross_file/cross_file.dart';
import 'package:path/path.dart' as path;

/// Marks a Future as purposefully not awaited.
void unawaited(Future<void> future) {}

/// Status of a video file during batch processing
enum VideoProcessingStatus {
  queued,
  analyzing,
  filtered,
  uploading,
  completed,
  failed,
  skipped,
}

/// Represents a single video file in the batch processing queue
class BatchVideoItem {
  /// The video file
  final XFile file;

  /// Current processing status
  VideoProcessingStatus status;

  /// Metadata if extracted
  VideoMetadataResult? metadata;

  /// Error message if any
  String? errorMessage;

  /// Upload progress (0-100)
  double uploadProgress;

  /// Estimated time remaining
  Duration? timeRemaining;

  /// The ID of the created video on Bunny.net
  String? videoId;

  BatchVideoItem({
    required this.file,
    this.status = VideoProcessingStatus.queued,
    this.metadata,
    this.errorMessage,
    this.uploadProgress = 0.0,
    this.timeRemaining,
    this.videoId,
  });

  /// Get the filename without path
  String get fileName => path.basename(file.path);

  /// Get the file extension
  String get extension => path.extension(file.path).toLowerCase();

  /// Is the file a video based on extension?
  bool get isVideoFile {
    const videoExtensions = [
      '.mp4',
      '.mov',
      '.avi',
      '.mkv',
      '.wmv',
      '.webm',
      '.flv',
    ];
    return videoExtensions.contains(extension);
  }
}

/// Filter definition function signature
typedef VideoFilter = Future<bool> Function(BatchVideoItem item);

/// Helper class to track upload tasks and completion status
class _UploadTask {
  final Future<void> future;
  final BatchVideoItem video;
  bool _isDone = false;

  _UploadTask(Future<void> uploadFuture, this.video) : future = uploadFuture {
    // Set isDone when future completes (success or error)
    future.then((_) => _isDone = true).catchError((_) => _isDone = true);
  }

  bool get isDone => _isDone;
}

/// Class for batch processing and uploading videos
class VideoBatchUploader {
  final BunnyStreamLibrary _bunnyClient;
  final List<BatchVideoItem> _videos = [];
  final List<VideoFilter> _filters = [];

  /// The current batch operation controller
  StreamController<List<BatchVideoItem>>? _progressController;

  /// Maximum concurrent uploads
  final int _maxConcurrentUploads;

  /// TUS store for resumable uploads
  final TusStore? _store;

  /// True if a batch operation is in progress
  bool _isProcessing = false;

  /// The directory filter if set
  String? _directoryFilter;

  // Upload settings
  final int _chunkSize;
  final int _retries;
  final RetryScale _retryScale;
  final int _retryInterval;
  final int _parallelChunks;

  /// Create a new batch uploader
  ///
  /// [bunnyClient] - The Bunny.net client
  /// [maxConcurrentUploads] - How many videos to upload in parallel
  /// [store] - Optional TUS store for resumable uploads
  VideoBatchUploader(
    BunnyStreamLibrary bunnyClient, {
    int maxConcurrentUploads = 2,
    TusStore? store,
    int chunkSize = 512 * 1024,
    int retries = 3,
    RetryScale retryScale = RetryScale.exponentialJitter,
    int retryInterval = 5,
    int parallelChunks = 3,
  }) : _bunnyClient = bunnyClient,
       _maxConcurrentUploads = maxConcurrentUploads,
       _store = store,
       _chunkSize = chunkSize,
       _retries = retries,
       _retryScale = retryScale,
       _retryInterval = retryInterval,
       _parallelChunks = parallelChunks,
       _directoryFilter = null;

  /// Get all videos to be processed
  List<BatchVideoItem> get videos => List.unmodifiable(_videos);

  /// True if currently processing videos
  bool get isProcessing => _isProcessing;

  /// Number of videos that passed all filters
  int get eligibleCount =>
      _videos
          .where(
            (v) =>
                v.status != VideoProcessingStatus.filtered &&
                v.status != VideoProcessingStatus.skipped,
          )
          .length;

  /// Number of videos that have been uploaded
  int get uploadedCount =>
      _videos.where((v) => v.status == VideoProcessingStatus.completed).length;

  /// Number of failed uploads
  int get failedCount =>
      _videos.where((v) => v.status == VideoProcessingStatus.failed).length;

  /// Add a directory of videos
  ///
  /// [directory] - The directory to scan
  /// [recursive] - Whether to scan subdirectories
  Future<void> addDirectory(String directory, {bool recursive = false}) async {
    final dir = Directory(directory);
    if (!dir.existsSync()) {
      throw DirectoryNotFoundException('Directory not found: $directory');
    }

    final entities = dir.listSync(recursive: recursive);

    for (final entity in entities) {
      if (entity is File) {
        final extension = path.extension(entity.path).toLowerCase();
        if ([
          '.mp4',
          '.mov',
          '.avi',
          '.mkv',
          '.wmv',
          '.webm',
          '.flv',
        ].contains(extension)) {
          _videos.add(BatchVideoItem(file: XFile(entity.path)));
        }
      }
    }
  }

  /// Add a specific video file
  void addVideo(String filePath) {
    final file = File(filePath);
    if (!file.existsSync()) {
      throw FileSystemException('File not found', filePath);
    }

    _videos.add(BatchVideoItem(file: XFile(filePath)));
  }

  /// Add multiple video files
  void addVideos(List<String> filePaths) {
    for (final path in filePaths) {
      try {
        addVideo(path);
      } catch (e) {
        // Skip invalid files
      }
    }
  }

  /// Clear all videos from the queue
  void clear() {
    if (_isProcessing) {
      throw StateError('Cannot clear videos while processing is in progress');
    }
    _videos.clear();
  }

  /// Filter videos by minimum duration
  ///
  /// [minDuration] - The minimum duration required
  void filterByMinDuration(Duration minDuration) {
    _filters.add((item) async {
      if (item.metadata == null) {
        try {
          item.metadata = await VideoMetadataHelper.getVideoMetadata(
            item.file.path,
          );
        } catch (e) {
          item.errorMessage = 'Failed to extract metadata: $e';
          return false;
        }
      }

      return item.metadata!.duration != null &&
          item.metadata!.duration! >= minDuration;
    });
  }

  /// Filter videos by maximum duration
  ///
  /// [maxDuration] - The maximum duration allowed
  void filterByMaxDuration(Duration maxDuration) {
    _filters.add((item) async {
      if (item.metadata == null) {
        try {
          item.metadata = await VideoMetadataHelper.getVideoMetadata(
            item.file.path,
          );
        } catch (e) {
          item.errorMessage = 'Failed to extract metadata: $e';
          return false;
        }
      }

      return item.metadata!.duration != null &&
          item.metadata!.duration! <= maxDuration;
    });
  }

  /// Filter videos by minimum resolution
  ///
  /// [minWidth] - The minimum width required
  /// [minHeight] - The minimum height required
  void filterByMinResolution(int minWidth, int minHeight) {
    _filters.add((item) async {
      if (item.metadata == null) {
        try {
          item.metadata = await VideoMetadataHelper.getVideoMetadata(
            item.file.path,
          );
        } catch (e) {
          item.errorMessage = 'Failed to extract metadata: $e';
          return false;
        }
      }

      return item.metadata!.width != null &&
          item.metadata!.height != null &&
          item.metadata!.width! >= minWidth &&
          item.metadata!.height! >= minHeight;
    });
  }

  /// Filter videos by specific directory
  ///
  /// [directory] - Only process videos in this directory
  void filterByDirectory(String directory) {
    _directoryFilter = directory;

    _filters.add((item) async {
      final videoDir = path.dirname(item.file.path);
      return videoDir.startsWith(_directoryFilter!);
    });
  }

  /// Filter videos by custom criteria
  ///
  /// [filterFn] - Custom filter function
  void addCustomFilter(VideoFilter filterFn) {
    _filters.add(filterFn);
  }

  /// Apply filters to the videos
  /// Returns a stream of updates as filtering progresses
  Stream<List<BatchVideoItem>> applyFilters() async* {
    if (_isProcessing) {
      throw StateError('Already processing videos');
    }

    _isProcessing = true;
    _progressController = StreamController<List<BatchVideoItem>>();

    try {
      for (final video in _videos) {
        if (video.status == VideoProcessingStatus.filtered ||
            video.status == VideoProcessingStatus.skipped) {
          continue;
        }

        video.status = VideoProcessingStatus.analyzing;
        _progressController!.add(_videos);

        try {
          video.metadata ??= await VideoMetadataHelper.getVideoMetadata(
            video.file.path,
          );

          bool passedAllFilters = true;

          for (final filter in _filters) {
            if (!await filter(video)) {
              passedAllFilters = false;
              break;
            }
          }

          video.status =
              passedAllFilters
                  ? VideoProcessingStatus.queued
                  : VideoProcessingStatus.filtered;
        } catch (e) {
          video.errorMessage = e.toString();
          video.status = VideoProcessingStatus.failed;
        }

        _progressController!.add(_videos);
      }
    } finally {
      _isProcessing = false;
      await _progressController!.close();
    }

    yield* _progressController!.stream;
  }

  /// Upload all eligible videos (those that passed filters)
  /// Returns a stream of updates as uploads progress
  Stream<List<BatchVideoItem>> uploadVideos({
    String? collectionId,
    bool detectChapters = false,
    double chapterThreshold = 0.3,
  }) async* {
    if (_isProcessing) {
      throw StateError('Already processing videos');
    }

    _isProcessing = true;
    _progressController = StreamController<List<BatchVideoItem>>();

    // Get eligible videos
    final eligibleVideos =
        _videos.where((v) => v.status == VideoProcessingStatus.queued).toList();

    // List to track active upload tasks
    final List<_UploadTask> activeTasks = [];

    try {
      for (final video in eligibleVideos) {
        // Wait if max concurrent uploads reached
        while (activeTasks.length >= _maxConcurrentUploads) {
          if (activeTasks.isEmpty) break;

          // Create a completer that will be completed when any upload completes
          final completer = Completer<void>();

          // Set up listeners for all active tasks
          for (final task in List<_UploadTask>.from(activeTasks)) {
            unawaited(
              task.future
                  .then((_) {
                    if (!completer.isCompleted) completer.complete();
                  })
                  .catchError((_) {
                    if (!completer.isCompleted) completer.complete();
                  }),
            );
          }

          // Wait for either a task to complete or a timeout
          await Future.any([
            completer.future,
            Future.delayed(const Duration(seconds: 30)),
          ]);

          // Remove completed tasks
          activeTasks.removeWhere((task) => task.isDone);
        }

        // Start new upload
        final uploadFuture = _uploadVideo(
          video,
          collectionId: collectionId,
          detectChapters: detectChapters,
          chapterThreshold: chapterThreshold,
        );

        // Create a task to track the upload
        final task = _UploadTask(uploadFuture, video);
        activeTasks.add(task);

        _progressController!.add(_videos);
      }

      // Wait for all remaining uploads to complete
      while (activeTasks.isNotEmpty) {
        // Wait for any task to complete
        final completer = Completer<void>();

        for (final task in List<_UploadTask>.from(activeTasks)) {
          unawaited(
            task.future
                .then((_) {
                  if (!completer.isCompleted) completer.complete();
                })
                .catchError((_) {
                  if (!completer.isCompleted) completer.complete();
                }),
          );
        }

        // Wait for a task to complete or timeout
        await Future.any([
          completer.future,
          Future.delayed(const Duration(seconds: 30)),
        ]);

        // Remove completed tasks
        activeTasks.removeWhere((task) => task.isDone);
      }
    } finally {
      _isProcessing = false;
      await _progressController!.close();
    }

    yield* _progressController!.stream;
  }

  /// Upload a single video
  Future<void> _uploadVideo(
    BatchVideoItem item, {
    String? collectionId,
    bool detectChapters = false,
    double chapterThreshold = 0.3,
  }) async {
    item.status = VideoProcessingStatus.uploading;
    _progressController?.add(_videos);

    try {
      // Get metadata if not already extracted
      item.metadata ??= await VideoMetadataHelper.getVideoMetadata(
        item.file.path,
      );

      // Create video with extracted metadata
      final result = await _bunnyClient.createVideoWithMetadata(
        videoFile: item.file,
        title: path.basenameWithoutExtension(item.file.path),
        collectionId: collectionId,
        detectChapters: detectChapters,
        chapterThreshold: chapterThreshold,
        store: _store,
        maxChunkSize: _chunkSize,
        retries: _retries,
        retryScale: _retryScale,
        retryInterval: _retryInterval,
        parallelUploads: _parallelChunks,
      );

      if (!result.success) {
        throw Exception(result.error ?? 'Unknown error creating video');
      }

      // Start the upload
      item.videoId = result.videoId;
      await result.tusClient!.startUpload(
        onProgress: (progress, estimate) {
          item.uploadProgress = progress;
          item.timeRemaining = estimate;
          _progressController?.add(_videos);
        },
        onComplete: () {
          item.status = VideoProcessingStatus.completed;
          item.uploadProgress = 100;
          item.timeRemaining = Duration.zero;
          _progressController?.add(_videos);
        },
      );
    } catch (e) {
      item.status = VideoProcessingStatus.failed;
      item.errorMessage = e.toString();
      _progressController?.add(_videos);
    }
  }

  /// Upload videos that match specific criteria
  ///
  /// A convenient method that combines filtering and uploading
  Stream<List<BatchVideoItem>> uploadMatchingVideos({
    // Directory filters
    String? directory,
    bool recursive = false,

    // Duration filters
    Duration? minDuration,
    Duration? maxDuration,

    // Resolution filters
    int? minWidth,
    int? minHeight,

    // Upload settings
    String? collectionId,
    bool detectChapters = false,
  }) async* {
    // Add directory filter
    if (directory != null) {
      filterByDirectory(directory);
    }

    // Add duration filters
    if (minDuration != null) {
      filterByMinDuration(minDuration);
    }

    if (maxDuration != null) {
      filterByMaxDuration(maxDuration);
    }

    // Add resolution filters
    if (minWidth != null && minHeight != null) {
      filterByMinResolution(minWidth, minHeight);
    }

    // Apply filters
    await for (final update in applyFilters()) {
      yield update;
    }

    // Upload eligible videos
    await for (final update in uploadVideos(
      collectionId: collectionId,
      detectChapters: detectChapters,
    )) {
      yield update;
    }
  }
}

/// Exception thrown when a directory is not found
class DirectoryNotFoundException implements Exception {
  final String message;

  DirectoryNotFoundException(this.message);

  @override
  String toString() => message;
}
