import 'package:dio/dio.dart';

final dio = _DioProxy();

final _dio = Dio();

class _DioProxy {
  // Helper method to process data
  Object? _processData(Object? data) {
    if (data == null) return null;
    if (data is Map<String, dynamic>) {
      if (data.isEmpty) return null;
    }
    return data;
  }

  // Helper method to process options
  Options _processOptions(Options? opt) {
    return (opt ?? Options()).copyWith(
      headers: {
        ...?opt?.headers,
        Headers.acceptHeader: Headers.jsonContentType,
      },
    );
  }

  Future<Response<Map<String, dynamic>>> get(
    Uri uri, {
    Options? opt,
    Object? data,
  }) => _dio.getUri<Map<String, dynamic>>(
    uri,
    data: _processData(data),
    options: _processOptions(opt),
  );

  Future<Response<Map<String, dynamic>>> post(
    Uri uri, {
    Options? opt,
    Object? data,
  }) => _dio.postUri<Map<String, dynamic>>(
    uri,
    data: _processData(data),
    options: _processOptions(opt),
  );

  Future<Response<Map<String, dynamic>>> put(
    Uri uri, {
    Options? opt,
    Object? data,
  }) => _dio.putUri<Map<String, dynamic>>(
    uri,
    data: _processData(data),
    options: _processOptions(opt),
  );

  Future<Response<Map<String, dynamic>>> delete(
    Uri uri, {
    Options? opt,
    Object? data,
  }) => _dio.deleteUri<Map<String, dynamic>>(
    uri,
    data: _processData(data),
    options: _processOptions(opt),
  );
}
