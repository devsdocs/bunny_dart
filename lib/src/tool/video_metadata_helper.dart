// ignore_for_file: avoid_dynamic_calls

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:cross_file/cross_file.dart';
import 'package:path/path.dart' as path;

/// Result of metadata extraction containing video properties
class VideoMetadataResult {
  final String path;
  final Duration? duration;
  final int? width;
  final int? height;
  final String? codec;
  final double? bitrate;
  final double? fps;
  final String? format;
  final int fileSize;
  final Map<String, dynamic> rawMetadata;
  final DateTime creationDate;
  final List<VideoChapterInfo>? chapters;

  VideoMetadataResult({
    required this.path,
    this.duration,
    this.width,
    this.height,
    this.codec,
    this.bitrate,
    this.fps,
    this.format,
    required this.fileSize,
    required this.rawMetadata,
    DateTime? creationDate,
    this.chapters,
  }) : creationDate = creationDate ?? DateTime.now();

  /// Returns a formatted string with the video resolution (e.g. "1920x1080")
  String? get resolution =>
      (width != null && height != null) ? "${width}x$height" : null;

  /// Returns a readable string with the video duration (e.g. "01:23:45")
  String? get durationFormatted {
    if (duration == null) return null;
    final hours = duration!.inHours.toString().padLeft(2, '0');
    final minutes = (duration!.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (duration!.inSeconds % 60).toString().padLeft(2, '0');
    return "$hours:$minutes:$seconds";
  }

  /// Returns a readable string with the file size (e.g. "123.45 MB")
  String get fileSizeFormatted {
    if (fileSize < 1024) return "$fileSize B";
    if (fileSize < 1024 * 1024) {
      return "${(fileSize / 1024).toStringAsFixed(2)} KB";
    }
    if (fileSize < 1024 * 1024 * 1024) {
      return "${(fileSize / (1024 * 1024)).toStringAsFixed(2)} MB";
    }
    return "${(fileSize / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB";
  }
}

/// Information about a chapter in a video
class VideoChapterInfo {
  final String title;
  final Duration startTime;
  final Duration? endTime;

  VideoChapterInfo({
    required this.title,
    required this.startTime,
    this.endTime,
  });

  /// Convert to Bunny.net compatible chapter format
  Map<String, dynamic> toBunnyChapter() {
    return {
      'title': title,
      'start': startTime.inMilliseconds,
      if (endTime != null) 'end': endTime!.inMilliseconds,
    };
  }
}

/// Exception thrown when FFmpeg is not available
class FfmpegNotFoundException implements Exception {
  final String message;
  FfmpegNotFoundException([this.message = "FFmpeg not found"]);

  @override
  String toString() => "FfmpegNotFoundException: $message";
}

// ignore: avoid_classes_with_only_static_members
/// Helper class to extract metadata from local video files
class VideoMetadataHelper {
  /// Check if FFmpeg is available on the system
  static Future<bool> isFFmpegAvailable() async {
    try {
      final result = await Process.run('ffmpeg', ['-version']);
      return result.exitCode == 0;
    } catch (e) {
      return false;
    }
  }

  /// Extract metadata from a video file
  ///
  /// Returns a [VideoMetadataResult] object containing video properties
  /// Throws [FfmpegNotFoundException] if FFmpeg is not available
  static Future<VideoMetadataResult> getVideoMetadata(
    String filePath, {
    bool extractChapters = true,
  }) async {
    final file = File(filePath);
    if (!file.existsSync()) {
      throw FileSystemException("File not found", filePath);
    }

    // Check if FFmpeg is available
    if (!await isFFmpegAvailable()) {
      throw FfmpegNotFoundException();
    }

    // Run FFprobe to get metadata
    final result = await Process.run('ffprobe', [
      '-v',
      'quiet',
      '-print_format',
      'json',
      '-show_format',
      '-show_streams',
      if (extractChapters) '-show_chapters',
      filePath,
    ]);

    if (result.exitCode != 0) {
      throw Exception("Failed to extract metadata: ${result.stderr}");
    }

    // Parse JSON output
    final metadata =
        jsonDecode(result.stdout as String) as Map<String, dynamic>;

    // Extract common metadata
    final format = metadata['format'] as Map<String, dynamic>?;
    final streams = metadata['streams'] as List<dynamic>?;
    final videoStream =
        streams?.firstWhere(
              (s) => s['codec_type'] == 'video',
              orElse: () => <String, dynamic>{},
            )
            as Map<String, dynamic>?;

    // Extract chapters if available
    List<VideoChapterInfo>? chapters;
    if (extractChapters && metadata.containsKey('chapters')) {
      final chaptersList = metadata['chapters'] as List<dynamic>;
      chapters =
          chaptersList.map((c) {
            final Map<String, dynamic> chapter = c as Map<String, dynamic>;
            final startTime = Duration(
              microseconds:
                  (double.parse(chapter['start_time'] as String) * 1000000)
                      .round(),
            );
            final endTime = Duration(
              microseconds:
                  (double.parse(chapter['end_time'] as String) * 1000000)
                      .round(),
            );
            final title =
                chapter['tags']?['title'] as String? ??
                'Chapter ${chaptersList.indexOf(c) + 1}';
            return VideoChapterInfo(
              title: title,
              startTime: startTime,
              endTime: endTime,
            );
          }).toList();
    }

    // Extract basic metadata
    final duration =
        format != null && format.containsKey('duration')
            ? Duration(
              microseconds:
                  (double.parse(format['duration'] as String) * 1000000)
                      .round(),
            )
            : null;

    final width = videoStream != null ? videoStream['width'] as int? : null;
    final height = videoStream != null ? videoStream['height'] as int? : null;
    final codec =
        videoStream != null ? videoStream['codec_name'] as String? : null;

    double? bitrate;
    if (format != null && format.containsKey('bit_rate')) {
      final bitrateValue = format['bit_rate'] as String;
      bitrate = double.tryParse(bitrateValue);
      if (bitrate != null) {
        bitrate = bitrate / 1000; // Convert to Kbps
      }
    }

    double? fps;
    if (videoStream != null && videoStream.containsKey('r_frame_rate')) {
      final fpsValue = videoStream['r_frame_rate'] as String;
      final parts = fpsValue.split('/');
      if (parts.length == 2) {
        final num = double.tryParse(parts[0]) ?? 0;
        final den = double.tryParse(parts[1]) ?? 1;
        if (den != 0) {
          fps = num / den;
        }
      }
    }

    // Get creation time
    DateTime? creationTime;
    if (videoStream != null &&
        videoStream['tags'] != null &&
        (videoStream['tags'] as Map).containsKey('creation_time')) {
      try {
        creationTime = DateTime.parse(
          videoStream['tags']['creation_time'] as String,
        );
      } catch (e) {
        // Ignore parsing errors
      }
    }

    return VideoMetadataResult(
      path: filePath,
      duration: duration,
      width: width,
      height: height,
      codec: codec,
      bitrate: bitrate,
      fps: fps,
      format: format != null ? format['format_name'] as String? : null,
      fileSize: file.lengthSync(),
      rawMetadata: metadata,
      creationDate: creationTime,
      chapters: chapters,
    );
  }

  /// Generate a thumbnail from a video at a specific timestamp
  ///
  /// [timestamp] is the position in the video (in milliseconds)
  /// [outputPath] is the path where the thumbnail will be saved. If null,
  /// the thumbnail will be returned as a [Uint8List] and not saved to disk.
  /// [width] and [height] are the dimensions of the thumbnail. If not specified,
  /// the original video dimensions will be used.
  static Future<Uint8List?> generateThumbnail(
    String videoPath, {
    required int timestamp,
    String? outputPath,
    int? width,
    int? height,
    int quality = 90,
  }) async {
    if (!await isFFmpegAvailable()) {
      throw FfmpegNotFoundException();
    }

    final file = File(videoPath);
    if (!file.existsSync()) {
      throw FileSystemException("Video file not found", videoPath);
    }

    // Format timestamp as HH:MM:SS.mmm
    final position = Duration(milliseconds: timestamp);
    final formattedTime =
        '${[position.inHours.toString().padLeft(2, '0'), (position.inMinutes % 60).toString().padLeft(2, '0'), (position.inSeconds % 60).toString().padLeft(2, '0')].join(':')}.${(position.inMilliseconds % 1000).toString().padLeft(3, '0')}';

    final tempFile =
        outputPath ??
        '${Directory.systemTemp.path}/${path.basenameWithoutExtension(videoPath)}_${timestamp}_thumbnail.jpg';

    final args = [
      '-y', // Overwrite output file if it exists
      '-ss', formattedTime, // Seek to position
      '-i', videoPath, // Input file
      '-vframes', '1', // Extract one frame
      if (width != null && height != null) ...[
        '-s', '${width}x$height', // Resize
      ],
      '-q:v', quality.toString(), // JPEG quality (2-31, lower is better)
      tempFile, // Output file
    ];

    final result = await Process.run('ffmpeg', args);
    if (result.exitCode != 0) {
      throw Exception("Failed to generate thumbnail: ${result.stderr}");
    }

    // If output path is provided, return null (file is saved at outputPath)
    // Otherwise, read the temporary file and return its contents
    if (outputPath != null) {
      return null;
    } else {
      final bytes = await File(tempFile).readAsBytes();
      await File(tempFile).delete();
      return bytes;
    }
  }

  /// Detect scenes (shots) in a video
  ///
  /// This method detects scene changes in a video and returns a list of timestamps
  /// [threshold] is the sensitivity for scene detection (0.0-1.0, default is 0.3)
  /// A higher threshold will detect fewer scenes
  static Future<List<VideoChapterInfo>> detectScenes(
    String videoPath, {
    double threshold = 0.3,
    String? customSceneTitle,
  }) async {
    if (!await isFFmpegAvailable()) {
      throw FfmpegNotFoundException();
    }

    final file = File(videoPath);
    if (!file.existsSync()) {
      throw FileSystemException("Video file not found", videoPath);
    }

    // FFmpeg scene detection command
    final tempFile =
        '${Directory.systemTemp.path}/scenes_${DateTime.now().millisecondsSinceEpoch}.txt';

    final args = [
      '-i',
      videoPath,
      '-filter:v',
      "select='gt(scene,$threshold)',showinfo",
      '-f',
      'null',
      '-',
    ];

    final result = await Process.run('ffmpeg', args);

    // Parse output to find scene changes
    final scenePositions = <Duration>[];
    final output = result.stderr as String;
    final regex = RegExp(r'pts_time:(\d+\.\d+)');

    for (final match in regex.allMatches(output)) {
      final timeStr = match.group(1)!;
      final seconds = double.parse(timeStr);
      scenePositions.add(Duration(milliseconds: (seconds * 1000).round()));
    }

    // Create chapters from scene positions
    final chapters = <VideoChapterInfo>[];
    for (int i = 0; i < scenePositions.length; i++) {
      final startTime = scenePositions[i];
      final endTime =
          i < scenePositions.length - 1 ? scenePositions[i + 1] : null;

      chapters.add(
        VideoChapterInfo(
          title:
              customSceneTitle != null
                  ? '$customSceneTitle ${i + 1}'
                  : 'Scene ${i + 1}',
          startTime: startTime,
          endTime: endTime,
        ),
      );
    }

    return chapters;
  }

  /// Extract multiple thumbnails at regular intervals
  static Future<List<Uint8List>> extractThumbnailGrid(
    String videoPath, {
    int count = 9,
    int? width,
    int? height,
  }) async {
    final metadata = await getVideoMetadata(videoPath);
    if (metadata.duration == null) {
      throw Exception("Could not determine video duration");
    }

    final interval = metadata.duration!.inMilliseconds ~/ (count + 1);
    final thumbnails = <Uint8List>[];

    for (int i = 1; i <= count; i++) {
      final timestamp = i * interval;
      final thumbnail = await generateThumbnail(
        videoPath,
        timestamp: timestamp,
        width: width,
        height: height,
      );

      if (thumbnail != null) {
        thumbnails.add(thumbnail);
      }
    }

    return thumbnails;
  }

  /// Get an optimal thumbnail position by analyzing the video content
  /// This attempts to find a frame that is not too dark, not too bright,
  /// and has some visual interest
  static Future<int> findOptimalThumbnailPosition(String videoPath) async {
    if (!await isFFmpegAvailable()) {
      throw FfmpegNotFoundException();
    }

    final metadata = await getVideoMetadata(videoPath);
    if (metadata.duration == null) {
      throw Exception("Could not determine video duration");
    }

    // Skip the first and last 10% of the video
    final skipStart = metadata.duration!.inMilliseconds ~/ 10;
    final skipEnd = metadata.duration!.inMilliseconds - skipStart;
    final usableDuration = skipEnd - skipStart;

    // Sample frames at regular intervals
    const sampleCount = 10;
    final sampleInterval = usableDuration ~/ sampleCount;

    // Analyze frames to find one with good visual properties
    double bestScore = -1;
    int bestTimestamp = skipStart + (usableDuration ~/ 2); // Default to middle

    for (int i = 0; i < sampleCount; i++) {
      final timestamp = skipStart + (i * sampleInterval);

      // Generate a low-res thumbnail for analysis
      final thumbnail = await generateThumbnail(
        videoPath,
        timestamp: timestamp,
        width: 320,
        height: 180,
      );

      if (thumbnail != null) {
        // Basic image analysis - this is just an example
        // In a real implementation, you might want to check:
        // - Average brightness (not too dark, not too bright)
        // - Standard deviation of pixel values (contrast)
        // - Edge detection to measure "interestingness"
        // - Face detection if appropriate

        // Here we're just scoring based on file size as a simple proxy
        // for image complexity (more complex = better thumbnail usually)
        final score = thumbnail.length.toDouble();

        if (score > bestScore) {
          bestScore = score;
          bestTimestamp = timestamp;
        }
      }
    }

    return bestTimestamp;
  }

  /// Create thumbnails and generate metadata for a video file
  /// Returns a ready-to-use map for uploading to Bunny.net
  static Future<Map<String, dynamic>> prepareBunnyUploadMetadata(
    XFile videoFile, {
    String? title,
    String? collectionId,
    int? thumbnailTime,
    bool detectChapters = false,
    double chapterThreshold = 0.3,
  }) async {
    final filePath = videoFile.path;
    final metadata = await getVideoMetadata(filePath);

    // Use file name as title if not provided
    final videoTitle = title ?? path.basenameWithoutExtension(filePath);

    // Find optimal thumbnail position if not specified
    final thumbPosition =
        thumbnailTime ?? await findOptimalThumbnailPosition(filePath);

    // Extract chapters if requested
    List<Map<String, dynamic>>? chapters;
    if (detectChapters) {
      final detectedChapters = await detectScenes(
        filePath,
        threshold: chapterThreshold,
      );

      chapters = detectedChapters.map((c) => c.toBunnyChapter()).toList();
    } else if (metadata.chapters != null) {
      // Use embedded chapters if available
      chapters = metadata.chapters!.map((c) => c.toBunnyChapter()).toList();
    }

    // Build metadata object for Bunny.net upload
    final bunnyMetadata = {
      'title': videoTitle,
      if (collectionId != null) 'collection': collectionId,
      'thumbnailTime': thumbPosition,
      if (chapters != null && chapters.isNotEmpty) 'chapters': chapters,
    };

    return bunnyMetadata;
  }
}
