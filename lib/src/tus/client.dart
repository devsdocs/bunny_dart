// ignore_for_file: parameter_assignments, avoid_dynamic_calls, no_leading_underscores_for_local_identifiers

import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'dart:math' show min;
import 'dart:typed_data' show BytesBuilder, Uint8List;

import 'package:bunny_dart/src/tus/exceptions.dart';
import 'package:bunny_dart/src/tus/retry_scale.dart';
import 'package:bunny_dart/src/tus/tus_client_base.dart';
import 'package:dio/dio.dart';
import 'package:speed_test_dart/speed_test_dart.dart';

/// This class is used for creating or resuming uploads.
class TusClient extends TusClientBase {
  TusClient(
    super.file, {
    super.store,
    super.maxChunkSize = 512 * 1024,
    super.retries = 0,
    super.retryScale = RetryScale.constant,
    super.retryInterval = 0,
    int parallelUploads = 1,
    super.connectionTimeout = const Duration(seconds: 30),
    super.receiveTimeout = const Duration(seconds: 30),
    super.enableCompression = true,
  }) {
    super.parallelUploads = parallelUploads;
    _fingerprint = generateFingerprint() ?? "";
    _initClient();
  }

  // Single reusable Dio client
  late final Dio _client;
  final CancelToken _cancelToken = CancelToken();

  // Initialize the shared client with proper settings
  void _initClient() {
    _client = Dio(
      BaseOptions(
        connectTimeout: connectionTimeout,
        receiveTimeout: receiveTimeout,
        sendTimeout: connectionTimeout,
        responseType: ResponseType.stream,
        // Use gzip compression when enabled
        contentType: Headers.jsonContentType,
        validateStatus: (status) => true, // We handle status codes ourselves
      ),
    );

    if (enableCompression) {
      _client.options.headers['Accept-Encoding'] = 'gzip, deflate, br';
    }
  }

  /// Override this method to use a custom Client
  Dio getClient() => _client;

  int _actualRetry = 0;
  final Map<int, int> _chunkOffsets = {};
  final List<bool> _chunkComplete = [];
  bool _uploadCancelled = false;

  /// Create a new [upload] throwing [ProtocolException] on server error
  @override
  Future<void> createUpload() async {
    try {
      _fileSize = await file.length();

      final createHeaders = Map<String, String>.from(headers ?? {})..addAll({
        "Tus-Resumable": tusVersion,
        "Upload-Metadata": _uploadMetadata ?? "",
        "Upload-Length": "$_fileSize",
      });

      final _url = url;

      if (_url == null) {
        throw ProtocolException('Error in request, URL is incorrect');
      }

      final response = await _client.postUri(
        _url,
        options: Options(headers: createHeaders),
        cancelToken: _cancelToken,
      );

      if (!(response.statusCode! >= 200 && response.statusCode! < 300) &&
          response.statusCode != 404) {
        throw ProtocolException(
          "Unexpected Error while creating upload",
          response.statusCode,
        );
      }

      final String urlStr = response.headers.value("location") ?? "";
      if (urlStr.isEmpty) {
        throw ProtocolException(
          "missing upload Uri in response for creating upload",
        );
      }

      _uploadUrl = _parseUrl(urlStr);
      await store?.set(_fingerprint, _uploadUrl!);
    } on FileSystemException {
      throw Exception('Cannot find file to upload');
    }
  }

  @override
  Future<bool> isResumable() async {
    try {
      _fileSize = await file.length();
      _pauseUpload = false;
      _uploadCancelled = false;

      if (!resumingEnabled) {
        return false;
      }

      _uploadUrl = await store?.get(_fingerprint);

      if (_uploadUrl == null) {
        return false;
      }
      return true;
    } on FileSystemException {
      throw Exception('Cannot find file to upload');
    } catch (e) {
      return false;
    }
  }

  @override
  Future<void> setUploadTestServers() async {
    final tester = SpeedTestDart();

    try {
      final settings = await tester.getSettings();
      final servers = settings.servers;

      bestServers = await tester.getBestServers(servers: servers);
    } catch (_) {
      bestServers = null;
    }
  }

  @override
  Future<void> uploadSpeedTest() async {
    final tester = SpeedTestDart();

    // If bestServers are null or they are empty, we will not measure upload speed
    // as it wouldn't be accurate at all
    if (bestServers == null || (bestServers?.isEmpty ?? true)) {
      uploadSpeed = null;
      return;
    }

    try {
      uploadSpeed = await tester.testUploadSpeed(servers: bestServers ?? []);
    } catch (_) {
      uploadSpeed = null;
    }
  }

  /// Start or resume an upload in chunks of [maxChunkSize] throwing
  /// [ProtocolException] on server error
  @override
  Future<void> upload({
    Function(double, Duration)? onProgress,
    Function(TusClient, Duration?)? onStart,
    Function()? onComplete,
    required Uri uri,
    Map<String, String>? metadata = const {},
    Map<String, String>? headers = const {},
    bool measureUploadSpeed = false,
  }) async {
    setUploadData(uri, headers, metadata);

    final _isResumable = await isResumable();

    if (measureUploadSpeed) {
      await setUploadTestServers();
      await uploadSpeedTest();
    }

    if (!_isResumable) {
      await createUpload();
    }

    // get offset from server
    _offset = await _getOffset();

    // Save the file size as an int in a variable to avoid having to call
    final int totalBytes = _fileSize!;

    // We start a stopwatch to calculate the upload speed
    final uploadStopwatch = Stopwatch()..start();

    if (onStart != null) {
      Duration? estimate;
      if (uploadSpeed != null) {
        final _workedUploadSpeed = uploadSpeed! * 1000000;

        estimate = Duration(seconds: (totalBytes / _workedUploadSpeed).round());
      }
      // The time remaining to finish the upload
      onStart(this, estimate);
    }

    // Reset states
    _chunkOffsets.clear();
    _chunkComplete.clear();

    // For parallel uploads we need to split into chunks
    if (parallelUploads > 1) {
      await _performParallelUpload(
        onProgress: onProgress,
        onComplete: onComplete,
        uploadStopwatch: uploadStopwatch,
        totalBytes: totalBytes,
        headers: headers,
      );
    } else {
      // Original sequential upload
      while (!_pauseUpload && !_uploadCancelled && _offset < totalBytes) {
        await _performSingleChunkUpload(
          onComplete: onComplete,
          onProgress: onProgress,
          headers: headers,
          uploadStopwatch: uploadStopwatch,
          totalBytes: totalBytes,
        );
      }
    }
  }

  /// Handles uploading multiple chunks in parallel
  Future<void> _performParallelUpload({
    Function(double, Duration)? onProgress,
    Function()? onComplete,
    required Stopwatch uploadStopwatch,
    required int totalBytes,
    Map<String, String>? headers,
  }) async {
    // Create a shared progress and error handler
    int totalProgress = _offset;
    final completer = Completer<void>();
    var activeUploads = 0;
    bool fallbackToSequential = false;

    // Prep chunks
    final int effectiveChunks = min(
      parallelUploads,
      ((totalBytes - _offset) / maxChunkSize).ceil(),
    );

    // Initialize chunk states
    for (int i = 0; i < effectiveChunks; i++) {
      _chunkOffsets[i] = _offset + (i * maxChunkSize);
      _chunkComplete.add(false);
    }

    // Report progress periodically
    Timer? progressTimer;
    if (onProgress != null) {
      progressTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
        final currentProgress = totalProgress / totalBytes * 100;

        double _workedUploadSpeed = 1.0;
        if (uploadSpeed != null) {
          _workedUploadSpeed = uploadSpeed! * 1000000;
        } else {
          // Calculate a safe upload speed with guard against division by zero
          final elapsedMs = uploadStopwatch.elapsedMilliseconds;
          if (elapsedMs > 0) {
            _workedUploadSpeed = totalProgress / elapsedMs;
          }
          // Ensure we have a positive value
          _workedUploadSpeed =
              _workedUploadSpeed.isFinite && _workedUploadSpeed > 0
                  ? _workedUploadSpeed
                  : 1.0;
        }

        final remainData = totalBytes - totalProgress;

        // Calculate a safe estimate with guards against invalid values
        Duration estimate;
        try {
          final seconds = (remainData / _workedUploadSpeed).round();
          // Ensure we have a valid, non-negative duration
          estimate = Duration(
            seconds: seconds.isFinite && seconds >= 0 ? seconds : 0,
          );
        } catch (e) {
          // Fallback if any calculation error occurs
          estimate = Duration.zero;
        }

        onProgress(currentProgress.clamp(0, 100), estimate);
      });
    }

    try {
      // Start uploads for each chunk
      for (int i = 0; i < effectiveChunks; i++) {
        if (_pauseUpload || _uploadCancelled) break;

        activeUploads++;
        await _uploadChunk(i, totalBytes, headers)
            .then((_) async {
              // Update progress
              totalProgress += maxChunkSize;
              _chunkComplete[i] = true;

              // Check if we need to upload more chunks
              if (_allChunksComplete() || _pauseUpload || _uploadCancelled) {
                activeUploads--;
                if (activeUploads == 0 && !completer.isCompleted) {
                  progressTimer?.cancel();

                  if (totalProgress >= totalBytes &&
                      !_pauseUpload &&
                      !_uploadCancelled) {
                    await onCompleteUpload();
                    if (onComplete != null) onComplete();
                  }
                  completer.complete();
                }
              } else {
                // Find next chunk to upload
                final nextChunkIndex = _findNextChunkIndex(effectiveChunks);
                if (nextChunkIndex != -1) {
                  await _uploadChunk(
                    nextChunkIndex,
                    totalBytes,
                    headers,
                  ).then((_) => activeUploads--);
                } else {
                  activeUploads--;
                }
              }
            })
            .catchError((e) {
              activeUploads--;
              if (e is ProtocolException && e.code == 409) {
                // 409 conflict - try sequential upload instead
                fallbackToSequential = true;
              }
              if (!completer.isCompleted) {
                if (fallbackToSequential) {
                  // Don't propagate the error, let it fall through to fallback
                  completer.complete();
                } else {
                  completer.completeError(e as Object);
                }
              }
            });
      }

      await completer.future;

      // Fallback to sequential if we had conflicts with parallel upload
      if (fallbackToSequential && !_pauseUpload && !_uploadCancelled) {
        log('Falling back to sequential upload due to conflicts');
        progressTimer?.cancel();

        // Reset offset to last server-confirmed offset
        _offset = await _getOffset();

        // Continue with sequential upload
        while (!_pauseUpload && !_uploadCancelled && _offset < totalBytes) {
          await _performSingleChunkUpload(
            onComplete: onComplete,
            onProgress: onProgress,
            headers: headers,
            uploadStopwatch: uploadStopwatch,
            totalBytes: totalBytes,
          );
        }
      }
    } finally {
      progressTimer?.cancel();
    }
  }

  bool _allChunksComplete() => _chunkComplete.every((complete) => complete);

  int _findNextChunkIndex(int totalChunks) {
    final baseOffset = _offset + (totalChunks * maxChunkSize);

    if (baseOffset >= _fileSize!) return -1;

    // Add a new chunk
    final newIndex = _chunkOffsets.length;
    _chunkOffsets[newIndex] = baseOffset;
    _chunkComplete.add(false);
    return newIndex;
  }

  Future<void> _uploadChunk(
    int chunkIndex,
    int totalBytes,
    Map<String, String>? headers,
  ) async {
    final uploadHeaders = Map<String, String>.from(headers ?? {})..addAll({
      "Tus-Resumable": tusVersion,
      "Upload-Offset": "${_chunkOffsets[chunkIndex]}",
      "Content-Type": "application/offset+octet-stream",
    });

    try {
      final chunkData = await _getChunkData(chunkIndex);
      final response = await _client.patchUri<ResponseBody>(
        _uploadUrl!,
        data: chunkData,
        options: Options(
          headers: uploadHeaders,
          responseType: ResponseType.stream,
        ),
        cancelToken: _cancelToken,
      );

      if (response.statusCode == 409) {
        // 409 Conflict - Need to resynchronize with server
        log('Conflict detected for chunk $chunkIndex, re-syncing with server');
        // Get current server offset
        final serverOffset = await _getOffset();
        _chunkOffsets[chunkIndex] = serverOffset;
        throw ProtocolException(
          "Conflict while uploading chunk $chunkIndex - resynchronizing",
          response.statusCode,
        );
      } else if (!(response.statusCode! >= 200 && response.statusCode! < 300)) {
        throw ProtocolException(
          "Error while uploading chunk $chunkIndex",
          response.statusCode,
        );
      }

      final int? serverOffset = _parseOffset(
        response.headers.value("upload-offset"),
      );

      if (serverOffset == null) {
        throw ProtocolException(
          "Response to PATCH request contains no or invalid Upload-Offset header",
        );
      }

      // Update client offset with server offset to maintain sync
      _chunkOffsets[chunkIndex] = serverOffset;
    } catch (e) {
      if (_actualRetry >= retries) {
        // If we've exhausted retries with parallel upload, throw to allow fallback
        if (e is ProtocolException && e.code == 409) {
          rethrow;
        }
        rethrow;
      }

      final waitInterval = retryScale.getInterval(_actualRetry, retryInterval);
      _actualRetry += 1;

      log(
        'Failed to upload chunk $chunkIndex, retry: $_actualRetry, interval: $waitInterval',
      );
      await Future.delayed(waitInterval);
      return _uploadChunk(chunkIndex, totalBytes, headers);
    }
  }

  Future<void> _performSingleChunkUpload({
    Function(double, Duration)? onProgress,
    Function()? onComplete,
    Map<String, String>? headers,
    required Stopwatch uploadStopwatch,
    required int totalBytes,
  }) async {
    if (!File(file.path).existsSync()) {
      throw Exception("Cannot find file ${file.path.split('/').last}");
    }

    final uploadHeaders = Map<String, String>.from(headers ?? {})..addAll({
      "Tus-Resumable": tusVersion,
      "Upload-Offset": "$_offset",
      "Content-Type": "application/offset+octet-stream",
    });

    try {
      _response = await _client.patchUri<ResponseBody>(
        _uploadUrl!,
        data: await _getData(),
        options: Options(
          headers: uploadHeaders,
          responseType: ResponseType.stream,
        ),
        cancelToken: _cancelToken,
      );

      if (_response != null) {
        (_response!.data as ResponseBody).stream.listen(
          (newBytes) {
            if (_actualRetry != 0) _actualRetry = 0;
          },
          onDone: () {
            if (onProgress != null && !_pauseUpload && !_uploadCancelled) {
              final totalSent = min(_offset, totalBytes);
              double _workedUploadSpeed = 1.0;

              if (uploadSpeed != null) {
                _workedUploadSpeed = uploadSpeed! * 1000000;
              } else {
                // Calculate a safe upload speed with guard against division by zero
                final elapsedMs = uploadStopwatch.elapsedMilliseconds;
                if (elapsedMs > 0) {
                  _workedUploadSpeed = totalSent / elapsedMs;
                }
                // Ensure we have a positive value
                _workedUploadSpeed =
                    _workedUploadSpeed.isFinite && _workedUploadSpeed > 0
                        ? _workedUploadSpeed
                        : 1.0;
              }

              final remainData = totalBytes - totalSent;

              // Calculate a safe estimate with guards against invalid values
              Duration estimate;
              try {
                final seconds = (remainData / _workedUploadSpeed).round();
                // Ensure we have a valid, non-negative duration
                estimate = Duration(
                  seconds: seconds.isFinite && seconds >= 0 ? seconds : 0,
                );
              } catch (e) {
                // Fallback if any calculation error occurs
                estimate = Duration.zero;
              }

              final progress = totalSent / totalBytes * 100;
              onProgress(progress.clamp(0, 100), estimate);
              _actualRetry = 0;
            }
          },
        );

        if (!(_response!.statusCode! >= 200 && _response!.statusCode! < 300)) {
          throw ProtocolException(
            "Error while uploading file",
            _response!.statusCode,
          );
        }

        final int? serverOffset = _parseOffset(
          _response!.headers.value("upload-offset"),
        );
        if (serverOffset == null) {
          throw ProtocolException(
            "Response to PATCH request contains no or invalid Upload-Offset header",
          );
        }
        if (_offset != serverOffset) {
          throw ProtocolException(
            "Response contains different Upload-Offset value ($serverOffset) than expected ($_offset)",
          );
        }

        if (_offset == totalBytes && !_pauseUpload && !_uploadCancelled) {
          await onCompleteUpload();
          if (onComplete != null) {
            onComplete();
          }
        }
      } else {
        throw ProtocolException("Error getting Response from server");
      }
    } catch (e) {
      if (_actualRetry >= retries) rethrow;
      final waitInterval = retryScale.getInterval(_actualRetry, retryInterval);
      _actualRetry += 1;
      log('Failed to upload, retry: $_actualRetry, interval: $waitInterval');
      await Future.delayed(waitInterval);
    }
  }

  /// Pause the current upload
  @override
  Future<bool> pauseUpload() async {
    try {
      _pauseUpload = true;
      if (_response != null && _response!.data is ResponseBody) {
        (_response!.data as ResponseBody).stream.timeout(Duration.zero);
      }
      return true;
    } catch (e) {
      throw Exception("Error pausing upload");
    }
  }

  @override
  Future<bool> cancelUpload() async {
    try {
      _uploadCancelled = true;
      _cancelToken.cancel("Upload cancelled by user");
      await pauseUpload();
      await store?.remove(_fingerprint);
      return true;
    } catch (_) {
      throw Exception("Error cancelling upload");
    }
  }

  /// Actions to be performed after a successful upload
  @override
  Future<void> onCompleteUpload() async {
    await store?.remove(_fingerprint);
  }

  void setUploadData(
    Uri url,
    Map<String, String>? headers,
    Map<String, String>? metadata,
  ) {
    this.url = url;
    this.headers = headers;
    this.metadata = metadata;
    _uploadMetadata = generateMetadata();
  }

  /// Get offset from server throwing [ProtocolException] on error
  Future<int> _getOffset() async {
    final offsetHeaders = Map<String, String>.from(headers ?? {})
      ..addAll({"Tus-Resumable": tusVersion});
    final response = await _client.headUri(
      _uploadUrl!,
      options: Options(headers: offsetHeaders),
      cancelToken: _cancelToken,
    );

    if (!(response.statusCode! >= 200 && response.statusCode! < 300)) {
      throw ProtocolException(
        "Unexpected error while resuming upload",
        response.statusCode,
      );
    }

    final int? serverOffset = _parseOffset(
      response.headers.value("upload-offset"),
    );
    if (serverOffset == null) {
      throw ProtocolException(
        "missing upload offset in response for resuming upload",
      );
    }
    return serverOffset;
  }

  /// Get data from file to upload
  Future<Uint8List> _getData() async {
    final int start = _offset;
    int end = _offset + maxChunkSize;
    end = end > (_fileSize ?? 0) ? _fileSize ?? 0 : end;

    final result = BytesBuilder();
    await for (final chunk in file.openRead(start, end)) {
      result.add(chunk);
    }

    final bytesRead = min(maxChunkSize, result.length);
    _offset = _offset + bytesRead;

    return result.takeBytes();
  }

  /// Gets data for a specific chunk in parallel upload mode
  Future<Uint8List> _getChunkData(int chunkIndex) async {
    final int start = _chunkOffsets[chunkIndex]!;
    int end = start + maxChunkSize;
    end = end > (_fileSize ?? 0) ? _fileSize ?? 0 : end;

    final result = BytesBuilder();
    await for (final chunk in file.openRead(start, end)) {
      if (_pauseUpload || _uploadCancelled) break;
      result.add(chunk);
    }

    final bytesRead = result.length;
    _chunkOffsets[chunkIndex] = _chunkOffsets[chunkIndex]! + bytesRead;

    return result.takeBytes();
  }

  int? _parseOffset(String? offset) {
    if (offset == null || offset.isEmpty) {
      return null;
    }
    if (offset.contains(",")) {
      offset = offset.substring(0, offset.indexOf(","));
    }
    return int.tryParse(offset);
  }

  Uri _parseUrl(String urlStr) {
    if (urlStr.contains(",")) {
      urlStr = urlStr.substring(0, urlStr.indexOf(","));
    }
    Uri uploadUrl = Uri.parse(urlStr);
    if (uploadUrl.host.isEmpty) {
      uploadUrl = uploadUrl.replace(host: url?.host, port: url?.port);
    }
    if (uploadUrl.scheme.isEmpty) {
      uploadUrl = uploadUrl.replace(scheme: url?.scheme);
    }
    return uploadUrl;
  }

  Response? _response;

  int? _fileSize;

  String _fingerprint = "";

  String? _uploadMetadata;

  Uri? _uploadUrl;

  int _offset = 0;

  bool _pauseUpload = false;

  /// The URI on the server for the file
  Uri? get uploadUrl => _uploadUrl;

  /// The fingerprint of the file being uploaded
  String get fingerprint => _fingerprint;

  /// The 'Upload-Metadata' header sent to server
  String get uploadMetadata => _uploadMetadata ?? "";

  /// Cleanup resources when done
  void dispose() {
    if (!_cancelToken.isCancelled) {
      _cancelToken.cancel('Disposed');
    }
  }
}
