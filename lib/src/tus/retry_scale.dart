part of 'bunny_tus_client.dart';

enum RetryScale {
  /// Same time interval between every retry.
  constant,

  /// If interval is n, on every retry the the interval is increased by n.
  /// For example if [retryInterval] is set to 2 seconds, and the [retries] is set to 4,
  /// the interval for every retry is going to be [2, 4, 6, 8]
  lineal,

  /// If interval is n, on every retry the last interval is going to be duplicated.
  /// For example if [retryInterval] is set to 2 seconds, and the [retries] is set to 4,
  /// the interval for every retry is going to be [2, 4, 8, 16]
  exponential,

  /// Like exponential but with added jitter to prevent thundering herd problem
  /// For example: [2.1, 4.3, 7.9, 15.2]
  exponentialJitter;

  Duration getInterval(int retry, int retryInterval) {
    if (retryInterval == 0) return Duration.zero;
    if (retry == 0) return Duration(seconds: retryInterval);

    switch (this) {
      case RetryScale.constant:
        return Duration(seconds: retryInterval);
      case RetryScale.lineal:
        return Duration(seconds: (retry + 1) * retryInterval);
      case RetryScale.exponential:
        return Duration(seconds: retryInterval * pow(2, retry).toInt());
      case RetryScale.exponentialJitter:
        final baseInterval = retryInterval * pow(2, retry).toInt();
        // Add up to 20% random jitter
        final jitter = Random().nextInt((baseInterval * 0.2).toInt() + 1);
        return Duration(seconds: baseInterval + jitter);
    }
  }
}
