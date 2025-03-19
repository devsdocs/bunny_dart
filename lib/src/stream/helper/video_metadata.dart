// ignore_for_file: avoid_dynamic_calls

import 'dart:convert';
import 'dart:io';
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

/// Exception thrown when FFmpeg is not available
class FfmpegNotFoundException implements Exception {
  final String message;
  FfmpegNotFoundException([this.message = "FFmpeg not found"]);

  @override
  String toString() =>
      "FfmpegNotFoundException: $message. Download FFmpeg from https://ffmpeg.org/download.html and add it to your system PATH.";
}

// ignore: avoid_classes_with_only_static_members
/// Helper class to extract metadata from local video files
///
/// This class requires FFmpeg to be installed on the system and available in the system PATH.
///
/// FFmpeg can be downloaded from https://ffmpeg.org/download.html
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
    );
  }

  /// Scan a directory and get metadata for all video files that match criteria
  /// Returns a list of VideoMetadataResult objects
  static Future<List<VideoMetadataResult>> scanDirectory({
    required String directory,
    bool recursive = false,
    Duration? minDuration,
    Duration? maxDuration,
    int? minWidth,
    int? minHeight,
    Set<String>? allowedExtensions,
    bool skipErrors = true,
  }) async {
    // Verify FFmpeg is available
    if (!await isFFmpegAvailable()) {
      throw FfmpegNotFoundException();
    }

    // Get all video files in directory
    final dir = Directory(directory);
    if (!dir.existsSync()) {
      throw FileSystemException("Directory not found", directory);
    }

    final results = <VideoMetadataResult>[];
    final validExtensions =
        allowedExtensions ??
        {'.mp4', '.mov', '.avi', '.mkv', '.wmv', '.webm', '.flv'};

    final fileList = <File>[];

    // Collect files
    if (recursive) {
      await for (final entity in dir.list(recursive: true)) {
        if (entity is File) {
          final extension = path.extension(entity.path).toLowerCase();
          if (validExtensions.contains(extension)) {
            fileList.add(entity);
          }
        }
      }
    } else {
      for (final entity in dir.listSync()) {
        if (entity is File) {
          final extension = path.extension(entity.path).toLowerCase();
          if (validExtensions.contains(extension)) {
            fileList.add(entity);
          }
        }
      }
    }

    // Process each file
    for (final file in fileList) {
      try {
        final metadata = await getVideoMetadata(file.path);

        // Apply filters
        bool includeFile = true;

        // Duration filter
        if (minDuration != null &&
            (metadata.duration == null || metadata.duration! < minDuration)) {
          includeFile = false;
        }

        if (maxDuration != null &&
            (metadata.duration == null || metadata.duration! > maxDuration)) {
          includeFile = false;
        }

        // Resolution filter
        if (minWidth != null &&
            minHeight != null &&
            (metadata.width == null ||
                metadata.height == null ||
                metadata.width! < minWidth ||
                metadata.height! < minHeight)) {
          includeFile = false;
        }

        if (includeFile) {
          results.add(metadata);
        }
      } catch (e) {
        if (!skipErrors) {
          rethrow;
        }
        // Skip files with errors when skipErrors is true
      }
    }

    return results;
  }

  /// Find videos in a directory that meet specific criteria
  /// Returns a list of file paths
  static Future<List<String>> findVideosWithCriteria({
    required String directory,
    bool recursive = false,
    Duration? minDuration,
    Duration? maxDuration,
    int? minWidth,
    int? minHeight,
  }) async {
    final metadataResults = await scanDirectory(
      directory: directory,
      recursive: recursive,
      minDuration: minDuration,
      maxDuration: maxDuration,
      minWidth: minWidth,
      minHeight: minHeight,
    );

    return metadataResults.map((result) => result.path).toList();
  }

  /// Find videos in a directory with duration longer than specified
  /// Returns a list of file paths
  static Future<List<String>> findVideosLongerThan(
    String directory,
    Duration minDuration, {
    bool recursive = false,
  }) async {
    return await findVideosWithCriteria(
      directory: directory,
      recursive: recursive,
      minDuration: minDuration,
    );
  }

  /// Get a summary report of video files in a directory
  static Future<VideoDirectoryReport> generateDirectoryReport(
    String directory, {
    bool recursive = false,
    bool includeChapters = false,
  }) async {
    final allVideos = await scanDirectory(
      directory: directory,
      recursive: recursive,
    );

    // Basic summary stats
    final totalDuration = allVideos.fold<Duration>(
      Duration.zero,
      (sum, video) => sum + (video.duration ?? Duration.zero),
    );

    final totalFileSize = allVideos.fold<int>(
      0,
      (sum, video) => sum + video.fileSize,
    );

    // Group by format/codec
    final formatCounts = <String, int>{};
    final codecCounts = <String, int>{};

    for (final video in allVideos) {
      final format = video.format ?? 'unknown';
      formatCounts[format] = (formatCounts[format] ?? 0) + 1;

      final codec = video.codec ?? 'unknown';
      codecCounts[codec] = (codecCounts[codec] ?? 0) + 1;
    }

    return VideoDirectoryReport(
      directory: directory,
      recursive: recursive,
      videoCount: allVideos.length,
      totalDuration: totalDuration,
      totalFileSize: totalFileSize,
      formatCounts: formatCounts,
      codecCounts: codecCounts,
      videos: allVideos,
    );
  }

  /// Find potential duplicate videos in a directory
  /// Returns a DuplicateDetectionResult containing groups of potential duplicates
  static Future<DuplicateDetectionResult> findPotentialDuplicates({
    required String directory,
    bool recursive = false,
    double durationToleranceSeconds = 1.0,
    double fileSizeTolerancePercent = 10.0,
    bool compareResolution = true,
    bool compareCodec = false,
    double minSimilarityScore = 0.7,
  }) async {
    final allVideos = await scanDirectory(
      directory: directory,
      recursive: recursive,
    );

    // Sort videos by duration for more efficient comparisons
    allVideos.sort((a, b) {
      final aDuration = a.duration?.inMilliseconds ?? 0;
      final bDuration = b.duration?.inMilliseconds ?? 0;
      return aDuration.compareTo(bDuration);
    });

    final duplicateGroups = <VideoDuplicateGroup>[];
    final processedVideos = <String>{};

    for (var i = 0; i < allVideos.length; i++) {
      final video = allVideos[i];

      // Skip if this video is already in a duplicate group
      if (processedVideos.contains(video.path)) continue;

      final potentialDuplicates = <VideoMetadataResult>[];
      final durationTolerance = Duration(
        milliseconds: (durationToleranceSeconds * 1000).round(),
      );

      for (var j = i + 1; j < allVideos.length; j++) {
        final otherVideo = allVideos[j];

        // If other video duration is too far from current video, we can break
        // since we sorted by duration
        if (otherVideo.duration != null &&
            video.duration != null &&
            otherVideo.duration! > video.duration! + durationTolerance) {
          break;
        }

        final similarity = _calculateSimilarity(
          video,
          otherVideo,
          durationTolerance: durationTolerance,
          fileSizeTolerancePercent: fileSizeTolerancePercent,
          compareResolution: compareResolution,
          compareCodec: compareCodec,
        );

        if (similarity >= minSimilarityScore) {
          if (potentialDuplicates.isEmpty) {
            potentialDuplicates.add(video);
          }
          potentialDuplicates.add(otherVideo);
          processedVideos.add(otherVideo.path);
        }
      }

      if (potentialDuplicates.isNotEmpty) {
        duplicateGroups.add(
          VideoDuplicateGroup(
            videos: potentialDuplicates,
            baseVideo: video,
            directory: directory,
          ),
        );
        processedVideos.add(video.path);
      }
    }

    return DuplicateDetectionResult(
      directory: directory,
      recursive: recursive,
      totalVideosScanned: allVideos.length,
      duplicateGroups: duplicateGroups,
      uniqueVideos:
          allVideos.where((v) => !processedVideos.contains(v.path)).toList(),
    );
  }

  /// Calculate similarity score between two videos (0.0 to 1.0)
  static double _calculateSimilarity(
    VideoMetadataResult video1,
    VideoMetadataResult video2, {
    required Duration durationTolerance,
    required double fileSizeTolerancePercent,
    required bool compareResolution,
    required bool compareCodec,
  }) {
    double score = 0.0;
    num factors = 0;

    // Duration comparison (heaviest weight)
    if (video1.duration != null && video2.duration != null) {
      final durationDiff =
          (video1.duration!.inMilliseconds - video2.duration!.inMilliseconds)
              .abs();

      if (durationDiff <= durationTolerance.inMilliseconds) {
        final durationSimilarity =
            1 -
            (durationDiff /
                durationTolerance.inMilliseconds.clamp(1, double.infinity));
        score += durationSimilarity * 3; // Higher weight for duration
        factors += 3;
      } else {
        return 0.0; // Duration difference exceeds tolerance, not a duplicate
      }
    }

    // File size comparison
    final sizeRatio =
        video1.fileSize > video2.fileSize
            ? video2.fileSize / video1.fileSize
            : video1.fileSize / video2.fileSize;

    final minAcceptableRatio = (100 - fileSizeTolerancePercent) / 100;
    if (sizeRatio >= minAcceptableRatio) {
      score += sizeRatio * 2; // Higher weight for file size
      factors += 2;
    } else {
      score +=
          sizeRatio * 0.5; // Still consider file size but with lower weight
      factors += 0.5;
    }

    // Resolution comparison
    if (compareResolution &&
        video1.width != null &&
        video1.height != null &&
        video2.width != null &&
        video2.height != null) {
      if (video1.width == video2.width && video1.height == video2.height) {
        score += 2;
        factors += 2;
      } else {
        // Calculate resolution similarity
        final area1 = video1.width! * video1.height!;
        final area2 = video2.width! * video2.height!;
        final resRatio = area1 > area2 ? area2 / area1 : area1 / area2;
        score += resRatio;
        factors += 1;
      }
    }

    // Codec comparison
    if (compareCodec && video1.codec != null && video2.codec != null) {
      if (video1.codec == video2.codec) {
        score += 1;
        factors += 1;
      }
    }

    // Normalize score to 0.0-1.0
    return factors > 0 ? score / factors : 0.0;
  }
}

/// Report with statistics about videos in a directory
class VideoDirectoryReport {
  final String directory;
  final bool recursive;
  final int videoCount;
  final Duration totalDuration;
  final int totalFileSize;
  final Map<String, int> formatCounts;
  final Map<String, int> codecCounts;
  final List<VideoMetadataResult> videos;

  VideoDirectoryReport({
    required this.directory,
    required this.recursive,
    required this.videoCount,
    required this.totalDuration,
    required this.totalFileSize,
    required this.formatCounts,
    required this.codecCounts,
    required this.videos,
  });

  /// Get all videos with duration over a specified minimum
  List<VideoMetadataResult> getVideosLongerThan(Duration minDuration) {
    return videos
        .where((v) => v.duration != null && v.duration! >= minDuration)
        .toList();
  }

  /// Get all videos with specific resolution or higher
  List<VideoMetadataResult> getVideosWithMinResolution(
    int minWidth,
    int minHeight,
  ) {
    return videos
        .where(
          (v) =>
              v.width != null &&
              v.height != null &&
              v.width! >= minWidth &&
              v.height! >= minHeight,
        )
        .toList();
  }

  /// Get a formatted summary
  String getSummary() {
    final buffer = StringBuffer();
    buffer.writeln('Video Directory Report');
    buffer.writeln('---------------------');
    buffer.writeln('Directory: $directory ${recursive ? "(recursive)" : ""}');
    buffer.writeln('Total videos: $videoCount');

    final hours = totalDuration.inHours;
    final minutes = totalDuration.inMinutes % 60;
    final seconds = totalDuration.inSeconds % 60;
    buffer.writeln('Total duration: ${hours}h ${minutes}m ${seconds}s');

    final sizeInMB = totalFileSize / (1024 * 1024);
    buffer.writeln('Total size: ${sizeInMB.toStringAsFixed(2)} MB');

    buffer.writeln('\nFormats:');
    for (final entry in formatCounts.entries) {
      buffer.writeln('  ${entry.key}: ${entry.value}');
    }

    buffer.writeln('\nCodecs:');
    for (final entry in codecCounts.entries) {
      buffer.writeln('  ${entry.key}: ${entry.value}');
    }

    return buffer.toString();
  }
}

/// Represents a group of potentially duplicate videos
class VideoDuplicateGroup {
  /// The base video that others are compared against
  final VideoMetadataResult baseVideo;

  /// List of videos that are potential duplicates (includes the base video)
  final List<VideoMetadataResult> videos;

  /// Directory from which these videos were found
  final String directory;

  VideoDuplicateGroup({
    required this.baseVideo,
    required this.videos,
    required this.directory,
  });

  /// Get total space that could be saved by removing duplicates
  int get potentialSpaceSaving {
    if (videos.length <= 1) return 0;
    return videos
        .skip(1) // Skip the base video
        .fold(0, (sum, video) => sum + video.fileSize);
  }

  /// Get a formatted string showing the potential space saving
  String get potentialSpaceSavingFormatted {
    final bytes = potentialSpaceSaving;
    if (bytes < 1024) return "$bytes B";
    if (bytes < 1024 * 1024) {
      return "${(bytes / 1024).toStringAsFixed(2)} KB";
    }
    if (bytes < 1024 * 1024 * 1024) {
      return "${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB";
    }
    return "${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB";
  }

  /// Returns a summary of the duplicate group
  String getSummary() {
    final buffer = StringBuffer();
    buffer.writeln('Potential duplicate group:');
    buffer.writeln('Base: ${baseVideo.path}');
    buffer.writeln('  - Size: ${baseVideo.fileSizeFormatted}');
    buffer.writeln('  - Duration: ${baseVideo.durationFormatted}');
    buffer.writeln('  - Resolution: ${baseVideo.resolution}');
    buffer.writeln('Potential duplicates:');

    for (final video in videos.skip(1)) {
      buffer.writeln('- ${video.path}');
      buffer.writeln('  - Size: ${video.fileSizeFormatted}');
      buffer.writeln('  - Duration: ${video.durationFormatted}');
      buffer.writeln('  - Resolution: ${video.resolution}');
    }

    buffer.writeln('Potential space saving: $potentialSpaceSavingFormatted');
    return buffer.toString();
  }
}

/// Results of a duplicate detection scan
class DuplicateDetectionResult {
  /// Directory that was scanned
  final String directory;

  /// Whether the scan was recursive
  final bool recursive;

  /// Total number of videos scanned
  final int totalVideosScanned;

  /// Groups of potential duplicates found
  final List<VideoDuplicateGroup> duplicateGroups;

  /// Videos that aren't part of any duplicate group
  final List<VideoMetadataResult> uniqueVideos;

  DuplicateDetectionResult({
    required this.directory,
    required this.recursive,
    required this.totalVideosScanned,
    required this.duplicateGroups,
    required this.uniqueVideos,
  });

  /// Number of videos that are potential duplicates
  int get totalPotentialDuplicates =>
      duplicateGroups.fold(0, (sum, group) => sum + group.videos.length - 1);

  /// Total space that could be saved by removing duplicates
  int get totalPotentialSpaceSaving =>
      duplicateGroups.fold(0, (sum, group) => sum + group.potentialSpaceSaving);

  /// Get a formatted string showing the total potential space saving
  String get totalPotentialSpaceSavingFormatted {
    final bytes = totalPotentialSpaceSaving;
    if (bytes < 1024) return "$bytes B";
    if (bytes < 1024 * 1024) {
      return "${(bytes / 1024).toStringAsFixed(2)} KB";
    }
    if (bytes < 1024 * 1024 * 1024) {
      return "${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB";
    }
    return "${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB";
  }

  /// Returns a summary of the duplicate detection results
  String getSummary() {
    final buffer = StringBuffer();
    buffer.writeln('Duplicate Detection Report');
    buffer.writeln('--------------------------');
    buffer.writeln('Directory: $directory ${recursive ? "(recursive)" : ""}');
    buffer.writeln('Total videos scanned: $totalVideosScanned');
    buffer.writeln('Unique videos: ${uniqueVideos.length}');
    buffer.writeln('Potential duplicate groups: ${duplicateGroups.length}');
    buffer.writeln('Total potential duplicates: $totalPotentialDuplicates');
    buffer.writeln(
      'Potential space saving: $totalPotentialSpaceSavingFormatted',
    );

    if (duplicateGroups.isNotEmpty) {
      buffer.writeln('\nDuplicate groups overview:');
      for (var i = 0; i < duplicateGroups.length; i++) {
        final group = duplicateGroups[i];
        buffer.writeln(
          'Group ${i + 1}: ${group.videos.length} videos, '
          'potential saving: ${group.potentialSpaceSavingFormatted}',
        );
      }
    }

    return buffer.toString();
  }

  /// Returns detailed information about all duplicate groups
  String getDetailedReport() {
    final buffer = StringBuffer();
    buffer.write(getSummary());

    if (duplicateGroups.isNotEmpty) {
      buffer.writeln('\nDetailed Groups:');
      for (var i = 0; i < duplicateGroups.length; i++) {
        buffer.writeln('\nGroup ${i + 1}:');
        buffer.writeln(duplicateGroups[i].getSummary());
      }
    }

    return buffer.toString();
  }
}
