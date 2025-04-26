part of 'bunny_tus_client.dart';

/// This class is used for creating or resuming uploads.
class TusClient extends TusClientBase {
  bool allowParallelFallback = true;

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
    this.allowParallelFallback = true,
  }) {
    super.parallelUploads = parallelUploads;
    _fingerprint = generateFingerprint() ?? "";
    _initClient();
  }

  // Single reusable Dio client
  late final Dio _client;
  final CancelToken cancelToken = CancelToken();

  List<Uri>? partialUploadUrls;

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
  bool uploadCancelled = false;

  /// Create a new [upload] throwing [ProtocolException] on server error
  @override
  Future<void> createUpload() async {
    try {
      fileSize = await file.length();

      final createHeaders = Map<String, String>.from(headers ?? {})..addAll({
        "Tus-Resumable": tusVersion,
        "Upload-Metadata": _uploadMetadata ?? "",
        "Upload-Length": "$fileSize",
        // Add Cache-Control header as per TUS spec
        "Cache-Control": "no-store",
      });

      final url_ = url;

      if (url_ == null) {
        throw ProtocolException('Error in request, URL is incorrect');
      }

      final response = await _client.postUri(
        url_,
        options: Options(headers: createHeaders),
        cancelToken: cancelToken,
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

      uploadUrl_ = _parseUrl(urlStr);
      await store?.set(_fingerprint, uploadUrl_!);
    } catch (e) {
      throw Exception(e);
    }
  }

  @override
  Future<bool> isResumable() async {
    try {
      fileSize = await file.length();
      pauseUpload_ = false;
      uploadCancelled = false;

      if (!resumingEnabled) {
        return false;
      }

      uploadUrl_ = await store?.get(_fingerprint);

      if (uploadUrl_ == null) {
        return false;
      }

      // Basic URL validation
      final urlStr = uploadUrl_.toString();
      if (urlStr.isEmpty || !urlStr.startsWith('http')) {
        await store?.remove(_fingerprint);
        return false;
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<void> uploadSpeedTest() async {
    final tester = SpeedTestDart();

    try {
      // Add a timeout to prevent hanging
      final settings = await tester.getSettings().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Speed test settings request timed out');
        },
      );
      final servers = settings.servers;

      if (servers.isEmpty) {
        // No servers available
        bestServers = null;
        return;
      }

      // Limit the number of servers to test for efficiency
      bestServers = await tester
          .getBestServers(servers: servers)
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              // If timeout occurs, use any servers we have rather than none
              return servers.take(3).toList();
            },
          );

      if (bestServers == null || bestServers!.isEmpty) {
        uploadSpeed = null;
        return;
      }

      // Add timeout to prevent hanging
      uploadSpeed = await tester
          .testUploadSpeed(servers: bestServers!)
          .timeout(
            const Duration(seconds: 20),
            onTimeout: () {
              throw TimeoutException('Upload speed test timed out');
            },
          );

      // Validate the result
      if (uploadSpeed == null || uploadSpeed! <= 0) {
        // Invalid result, reset to null
        uploadSpeed = null;
      }
    } catch (e) {
      bestServers = null;
      uploadSpeed = null;
    }
  }

  /// Start or resume an upload in chunks of [maxChunkSize] throwing
  /// [ProtocolException] on server error
  @override
  Future<void> upload({
    Function(
      int totalBytesSend,
      int totalBytes,
      double progressPercentage,
      Duration estimatedDuration,
    )?
    onProgress,
    Function(TusClient client, Duration? duration)? onStart,
    Function()? onComplete,
    required Uri uri,
    Map<String, String>? metadata = const {},
    Map<String, String>? headers = const {},
    bool measureUploadSpeed = false,
  }) async {
    setUploadData(uri, headers, metadata);

    final isResumable_ = await isResumable();

    if (measureUploadSpeed) {
      await uploadSpeedTest();
    }

    // Create a new upload if not resumable
    if (!isResumable_) {
      await createUpload();
    } else {}

    // Attempt to get offset from server with error handling
    try {
      _offset = await _getOffset();
    } catch (e) {
      if (e is ProtocolException &&
          (e.code == 404 || e.code == 410 || e.code == 403 || e.code == 400)) {
        // Clean up the old upload
        await store?.remove(_fingerprint);
        // Create a new upload and try again
        await createUpload();
        _offset = 0; // Reset offset
      } else {
        // For other errors, just rethrow
        rethrow;
      }
    }

    // Save the file size as an int in a variable to avoid having to call
    final int totalBytes = fileSize!;

    // We start a stopwatch to calculate the upload speed
    final uploadStopwatch = Stopwatch()..start();

    if (onStart != null) {
      Duration? estimate;
      if (uploadSpeed != null) {
        final workedUploadSpeed_ = uploadSpeed! * 1000000;

        estimate = Duration(seconds: (totalBytes / workedUploadSpeed_).round());
      }
      // The time remaining to finish the upload
      onStart(this, estimate);
    }

    // Reset states
    _chunkOffsets.clear();
    _chunkComplete.clear();

    // Original sequential upload
    while (!pauseUpload_ && !uploadCancelled && _offset < totalBytes) {
      await _performUpload(
        onComplete: onComplete,
        onProgress: onProgress,
        headers: headers,
        uploadStopwatch: uploadStopwatch,
        totalBytes: totalBytes,
      );
    }
  }

  Future<void> _performUpload({
    Function(
      int totalBytesSend,
      int totalBytes,
      double progressPercentage,
      Duration estimatedDuration,
    )?
    onProgress,
    Function()? onComplete,
    Map<String, String>? headers,
    required Stopwatch uploadStopwatch,
    required int totalBytes,
  }) async {
    // Use consistent headers generation
    final uploadHeaders = _generateRequestHeaders({
      "Upload-Offset": "$_offset",
      "Content-Type": "application/offset+octet-stream",
    });

    try {
      _response = await _client.patchUri<ResponseBody>(
        uploadUrl_!,
        data: await getData(),
        options: Options(
          headers: uploadHeaders,
          responseType: ResponseType.stream,
        ),
        cancelToken: cancelToken,
      );

      if (_response != null) {
        (_response!.data as ResponseBody).stream.listen(
          (newBytes) {
            if (_actualRetry != 0) _actualRetry = 0;
          },
          onDone: () {
            if (onProgress != null && !pauseUpload_ && !uploadCancelled) {
              final totalSent = min(_offset, totalBytes);
              double bytesPerMs = 1.0;

              if (uploadSpeed != null) {
                // Convert from Mbps to bytes per millisecond
                // Mbps = 1,000,000 bits per second = 125,000 bytes per second
                // = 125 bytes per millisecond
                bytesPerMs = uploadSpeed! * 125;
              } else {
                // Calculate a safe upload speed with guard against division by zero
                final elapsedMs = uploadStopwatch.elapsedMilliseconds;
                if (elapsedMs > 0) {
                  bytesPerMs = totalSent / elapsedMs;
                }
              }

              // Ensure we have a positive value
              bytesPerMs =
                  bytesPerMs.isFinite && bytesPerMs > 0 ? bytesPerMs : 1.0;

              final remainData = totalBytes - totalSent;

              // Calculate a safe estimate with guards against invalid values
              Duration estimate;
              try {
                final milliseconds = (remainData / bytesPerMs).round();
                // Ensure we have a valid, non-negative duration
                estimate = Duration(
                  milliseconds:
                      milliseconds.isFinite && milliseconds >= 0
                          ? milliseconds
                          : 0,
                );
              } catch (e) {
                // Fallback if any calculation error occurs
                estimate = Duration.zero;
              }

              final progress =
                  (totalSent / totalBytes * 100).toPrecision(2).toDouble();
              onProgress(
                totalSent,
                totalBytes,
                progress.clamp(0, 100),
                estimate,
              );
              _actualRetry = 0;
            }
          },
        );

        if (_response!.statusCode == 409) {
          final offset = await _getOffset();
          _offset = offset;
          throw ProtocolException(
            'Server returned 409, re-sync offset, will retry',
            409,
          );
        } else if (_response!.statusCode == 400) {
          final offset = await _getOffset();
          _offset = offset;
          throw ProtocolException(
            'Server returned 400, re-sync offset, will retry',
            400,
          );
        } else if (!(_response!.statusCode! >= 200 &&
            _response!.statusCode! < 300)) {
          throw ProtocolException(
            'Error while uploading file',
            _response!.statusCode,
          );
        }

        final int? serverOffset = parseOffset(
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

        if (_offset == totalBytes && !pauseUpload_ && !uploadCancelled) {
          await onCompleteUpload();
          if (onComplete != null) {
            onComplete();
          }
        }
      } else {
        throw ProtocolException("Error getting Response from server");
      }
    } catch (e) {
      // Better error logging and differentiation
      if (e.toString().contains('400')) {}

      if (_actualRetry >= retries) rethrow;
      final waitInterval = retryScale.getInterval(_actualRetry, retryInterval);
      _actualRetry += 1;
      await Future.delayed(waitInterval);
    }
  }

  /// Pause the current upload
  @override
  Future<bool> pauseUpload() async {
    try {
      pauseUpload_ = true;
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
      uploadCancelled = true;
      cancelToken.cancel("Upload cancelled by user");
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

  @override
  Map<String, String> customHeaders() {
    // If this is BunnyTusClient, add Bunny.net authorization headers
    if (this is BunnyTusClient) {
      return (this as BunnyTusClient).customHeaders();
    }
    return {};
  }

  /// Get offset from server throwing [ProtocolException] on error
  Future<int> _getOffset() async {
    try {
      final offsetHeaders = Map<String, String>.from(headers ?? {});

      offsetHeaders.addAll({
        ...customHeaders(),
        "Tus-Resumable": tusVersion,
        "Cache-Control": "no-store",
      });

      // Add debugging for headers

      final response = await _client.headUri(
        uploadUrl_!,
        options: Options(
          headers: offsetHeaders,
          validateStatus: (status) => true, // Handle status codes manually
          receiveTimeout: receiveTimeout,
          sendTimeout: connectionTimeout,
        ),
        cancelToken: cancelToken,
      );

      // Handle status codes as per TUS spec
      if (response.statusCode == 404 ||
          response.statusCode == 410 ||
          response.statusCode == 403) {
        // Resource no longer exists
        await store?.remove(_fingerprint);
        throw ProtocolException(
          "Upload resource no longer available",
          response.statusCode,
        );
      } else if (response.statusCode == 400) {
        // Bad request - could be expired auth or other issues
        throw ProtocolException(
          "Bad request when retrieving offset - auth may be expired",
          response.statusCode,
        );
      } else if (!(response.statusCode! >= 200 && response.statusCode! < 300)) {
        throw ProtocolException(
          "Unexpected error while resuming upload",
          response.statusCode,
        );
      }

      final int? serverOffset = parseOffset(
        response.headers.value("upload-offset"),
      );
      if (serverOffset == null) {
        throw ProtocolException(
          "missing upload offset in response for resuming upload",
        );
      }
      return serverOffset;
    } on DioException catch (e) {
      throw ProtocolException(
        "Network error getting offset: ${e.message}",
        e.response?.statusCode ?? 0,
      );
    } catch (e) {
      // If it's already a ProtocolException, just rethrow
      if (e is ProtocolException) rethrow;

      // Otherwise wrap the error
      // Instead of always returning 400, use 0 for unknown
      throw ProtocolException("Failed to retrieve upload offset: $e", 0);
    }
  }

  /// Get data from file to upload - made public for subclasses to override
  Future<Uint8List> getData() async {
    final int start = _offset;
    int end = _offset + maxChunkSize;
    end = end > (fileSize ?? 0) ? fileSize ?? 0 : end;

    final result = BytesBuilder();
    await for (final chunk in file.openRead(start, end)) {
      result.add(chunk);
    }

    final bytesRead = min(maxChunkSize, result.length);
    _offset = _offset + bytesRead;

    return result.takeBytes();
  }

  /// Implement the termination extension for the TUS protocol
  Future<bool> terminateUpload() async {
    if (uploadUrl_ == null) {
      return false;
    }

    try {
      final terminateHeaders = Map<String, String>.from(headers ?? {})
        ..addAll({"Tus-Resumable": tusVersion});

      final response = await _client.deleteUri(
        uploadUrl_!,
        options: Options(
          headers: terminateHeaders,
          validateStatus: (status) => true,
        ),
        cancelToken: cancelToken,
      );

      if (response.statusCode == 204) {
        await store?.remove(_fingerprint);
        return true;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  int? parseOffset(String? offset) {
    String? offset_ = offset;
    if (offset_ == null || offset_.isEmpty) {
      return null;
    }
    if (offset_.contains(",")) {
      offset_ = offset_.substring(0, offset_.indexOf(","));
    }
    return int.tryParse(offset_);
  }

  Uri _parseUrl(String urlStr) {
    String urlStr_ = urlStr;
    if (urlStr_.contains(",")) {
      urlStr_ = urlStr_.substring(0, urlStr_.indexOf(","));
    }
    Uri uploadUrl = Uri.parse(urlStr_);
    if (uploadUrl.host.isEmpty) {
      uploadUrl = uploadUrl.replace(host: url?.host, port: url?.port);
    }
    if (uploadUrl.scheme.isEmpty) {
      uploadUrl = uploadUrl.replace(scheme: url?.scheme);
    }
    return uploadUrl;
  }

  Response? _response;

  int? fileSize;

  String _fingerprint = "";

  String? _uploadMetadata;

  Uri? uploadUrl_;

  int _offset = 0;

  bool pauseUpload_ = false;

  /// The URI on the server for the file
  Uri? get uploadUrl => uploadUrl_;

  /// The fingerprint of the file being uploaded
  String get fingerprint => _fingerprint;

  /// The 'Upload-Metadata' header sent to server
  String get uploadMetadata => _uploadMetadata ?? "";

  /// Cleanup resources when done
  void dispose() {
    if (!cancelToken.isCancelled) {
      cancelToken.cancel('Disposed');
    }
  }

  /// Generate consistent headers for all TUS requests
  Map<String, String> _generateRequestHeaders([
    Map<String, String>? additionalHeaders,
  ]) {
    final requestHeaders = {
      'Tus-Resumable': tusVersion,
      'Cache-Control': 'no-store',
    };

    // Add any custom headers
    if (headers != null) {
      requestHeaders.addAll(headers!);
    }

    // Add additional headers if provided
    if (additionalHeaders != null) {
      requestHeaders.addAll(additionalHeaders);
    }

    return requestHeaders;
  }
}
