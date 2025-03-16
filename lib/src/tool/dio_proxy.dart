import 'dart:io';
import 'package:dio/dio.dart';

final dio = _DioProxy();

final _dio = Dio();

class _DioProxy {
  Future<Response<Map<String, dynamic>>> get(
    Uri uri,
    Options opt, {
    Object? data,
  }) => _dio.getUri<Map<String, dynamic>>(
    uri,
    data: data,
    options: opt.copyWith(
      headers: {HttpHeaders.acceptHeader: 'application/json'},
      responseType: ResponseType.json,
    ),
  );

  Future<Response<Map<String, dynamic>>> post(
    Uri uri,
    Options opt, {
    Object? data,
  }) => _dio.postUri<Map<String, dynamic>>(
    uri,
    data: data,
    options: opt.copyWith(
      headers: {HttpHeaders.acceptHeader: 'application/json'},
      responseType: ResponseType.json,
    ),
  );

  Future<Response<Map<String, dynamic>>> put(
    Uri uri,
    Options opt, {
    Object? data,
  }) => _dio.putUri<Map<String, dynamic>>(
    uri,
    data: data,
    options: opt.copyWith(
      headers: {HttpHeaders.acceptHeader: 'application/json'},
      responseType: ResponseType.json,
    ),
  );

  Future<Response<Map<String, dynamic>>> delete(
    Uri uri,
    Options opt, {
    Object? data,
  }) => _dio.deleteUri<Map<String, dynamic>>(
    uri,
    data: data,
    options: opt.copyWith(
      headers: {HttpHeaders.acceptHeader: 'application/json'},
      responseType: ResponseType.json,
    ),
  );
}
