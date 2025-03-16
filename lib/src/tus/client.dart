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
  }) {
    _fingerprint = generateFingerprint() ?? "";
  }

  /// Override this method to use a custom Client
  Dio getClient() => Dio();

  int _actualRetry = 0;

  /// Create a new [upload] throwing [ProtocolException] on server error
  @override
  Future<void> createUpload() async {
    try {
      _fileSize = await file.length();

      final client = getClient();
      final createHeaders = Map<String, String>.from(headers ?? {})..addAll({
        "Tus-Resumable": tusVersion,
        "Upload-Metadata": _uploadMetadata ?? "",
        "Upload-Length": "$_fileSize",
      });

      final _url = url;

      if (_url == null) {
        throw ProtocolException('Error in request, URL is incorrect');
      }

      final response = await client.postUri(
        _url,
        options: Options(headers: createHeaders),
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
      store?.set(_fingerprint, _uploadUrl!);
    } on FileSystemException {
      throw Exception('Cannot find file to upload');
    }
  }

  @override
  Future<bool> isResumable() async {
    try {
      _fileSize = await file.length();
      _pauseUpload = false;

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

    // start upload
    final client = getClient();

    if (onStart != null) {
      Duration? estimate;
      if (uploadSpeed != null) {
        final _workedUploadSpeed = uploadSpeed! * 1000000;

        estimate = Duration(seconds: (totalBytes / _workedUploadSpeed).round());
      }
      // The time remaining to finish the upload
      onStart(this, estimate);
    }

    while (!_pauseUpload && _offset < totalBytes) {
      if (!File(file.path).existsSync()) {
        throw Exception("Cannot find file ${file.path.split('/').last}");
      }
      final uploadHeaders = Map<String, String>.from(headers ?? {})..addAll({
        "Tus-Resumable": tusVersion,
        "Upload-Offset": "$_offset",
        "Content-Type": "application/offset+octet-stream",
      });

      await _performUpload(
        onComplete: onComplete,
        onProgress: onProgress,
        uploadHeaders: uploadHeaders,
        client: client,
        uploadStopwatch: uploadStopwatch,
        totalBytes: totalBytes,
      );
    }
  }

  Future<void> _performUpload({
    Function(double, Duration)? onProgress,
    Function()? onComplete,
    required Map<String, String> uploadHeaders,
    required Dio client,
    required Stopwatch uploadStopwatch,
    required int totalBytes,
  }) async {
    try {
      _response = await client.patchUri<ResponseBody>(
        _uploadUrl!,
        data: await _getData(),
        options: Options(
          headers: uploadHeaders,
          responseType: ResponseType.stream,
        ),
      );

      if (_response != null) {
        (_response!.data as ResponseBody).stream.listen(
          (newBytes) {
            if (_actualRetry != 0) _actualRetry = 0;
          },
          onDone: () {
            if (onProgress != null && !_pauseUpload) {
              // Total byte sent
              final totalSent = _offset + maxChunkSize;
              double _workedUploadSpeed = 1.0;

              // If upload speed != null, it means it has been measured
              if (uploadSpeed != null) {
                // Multiplied by 10^6 to convert from Mb/s to b/s
                _workedUploadSpeed = uploadSpeed! * 1000000;
              } else {
                _workedUploadSpeed =
                    totalSent / uploadStopwatch.elapsedMilliseconds;
              }

              // The data that hasn't been sent yet
              final remainData = totalBytes - totalSent;

              // The time remaining to finish the upload
              final estimate = Duration(
                seconds: (remainData / _workedUploadSpeed).round(),
              );

              final progress = totalSent / totalBytes * 100;
              onProgress(progress.clamp(0, 100), estimate);
              _actualRetry = 0;
            }
          },
        );

        // check if correctly uploaded
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

        if (_offset == totalBytes && !_pauseUpload) {
          onCompleteUpload();
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
      log('Failed to upload,try: $_actualRetry, interval: $waitInterval');
      await Future.delayed(waitInterval);
      return await _performUpload(
        onComplete: onComplete,
        onProgress: onProgress,
        uploadHeaders: uploadHeaders,
        client: client,
        uploadStopwatch: uploadStopwatch,
        totalBytes: totalBytes,
      );
    }
  }

  /// Pause the current upload
  @override
  Future<bool> pauseUpload() async {
    try {
      _pauseUpload = true;
      (_response?.data as ResponseBody).stream.timeout(Duration.zero);
      return true;
    } catch (e) {
      throw Exception("Error pausing upload");
    }
  }

  @override
  Future<bool> cancelUpload() async {
    try {
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
    final client = getClient();

    final offsetHeaders = Map<String, String>.from(headers ?? {})
      ..addAll({"Tus-Resumable": tusVersion});
    final response = await client.headUri(
      _uploadUrl!,
      options: Options(headers: offsetHeaders),
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
}
