part of 'bunny_tus_client.dart';

abstract class TusClientBase {
  /// Version of the tus protocol used by the client. The remote server needs to
  /// support this version, too.
  final tusVersion = "1.0.0";

  int parallelUploads = 1;

  /// The tus server Uri
  Uri? url;

  Map<String, String>? metadata;

  /// Any additional headers
  Map<String, String>? headers;

  /// Upload speed in Mb/s
  double? uploadSpeed;

  /// List of [Server] that are good for testing speed
  List<Server>? bestServers;

  TusClientBase(
    this.file, {
    this.store,
    this.maxChunkSize = 512 * 1024,
    this.retries = 0,
    this.retryScale = RetryScale.constant,
    this.retryInterval = 0,
    this.parallelUploads = 1,
    this.connectionTimeout = const Duration(seconds: 30),
    this.receiveTimeout = const Duration(seconds: 30),
    this.enableCompression = true,
  });

  /// Custom headers to be sent with the request
  Map<String, String> customHeaders();

  /// Create a new upload URL
  Future<void> createUpload();

  /// Checks if upload can be resumed.
  Future<bool> isResumable();

  /// Starts an upload
  Future<void> upload({
    Function(int, int, double, Duration)? onProgress,
    Function(TusClient, Duration?)? onStart,
    Function()? onComplete,
    required Uri uri,
    Map<String, String>? metadata = const {},
    Map<String, String>? headers = const {},
    bool measureUploadSpeed = false,
  });

  /// Pauses the upload
  Future<bool> pauseUpload();

  /// Cancels the upload
  Future<bool> cancelUpload();

  /// Function to be called after completing upload
  Future<void> onCompleteUpload();

  /// Override this method to customize creating file fingerprint
  String? generateFingerprint() {
    return '${file.path.replaceAll(RegExp(r"\W+"), '.')}.fingerprint';
  }

  /// Measures the upload speed of the device
  Future<void> uploadSpeedTest();

  /// Override this to customize creating 'Upload-Metadata'
  String generateMetadata() {
    final meta = Map<String, String>.from(metadata ?? {});

    if (!meta.containsKey("filename")) {
      // Add the filename to the metadata from the whole directory path.
      //I.e: /home/user/file.txt -> file.txt
      meta["filename"] = file.path.split('/').last;
    }

    return meta.entries
        .map(
          (entry) => "${entry.key} ${base64.encode(utf8.encode(entry.value))}",
        )
        .join(",");
  }

  /// Storage used to save and retrieve upload URLs by its fingerprint.
  final TusStore? store;

  /// File to upload, must be in[XFile] type
  final XFile file;

  /// The maximum payload size in bytes when uploading the file in chunks (512KB)
  final int maxChunkSize;

  /// The number of times that should retry to resume the upload if a failure occurs after rethrow the error.
  final int retries;

  /// The interval between the first error and the first retry in [seconds].
  final int retryInterval;

  /// The scale type used to increase the interval of time between every retry.
  final RetryScale retryScale;

  /// The number of parallel chunk uploads (defaults to 1 for sequential uploads)
  // final int parallelUploads;

  /// Connection timeout for network requests
  final Duration connectionTimeout;

  /// Receive timeout for network requests
  final Duration receiveTimeout;

  /// Whether to use compression for uploads when supported
  final bool enableCompression;

  /// Whether the client supports resuming
  bool get resumingEnabled => store != null;
}
