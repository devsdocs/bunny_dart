// ignore_for_file: argument_type_not_assignable

import 'package:bunny_dart/src/common/common_object.dart';

class CommonResponse extends CommonObject {
  final bool _success;
  final String? _message;
  final int _statusCode;

  bool get isSuccess => _success;

  bool get isError => !_success;

  String? get errorMessage => _message;

  int? get errorStatusCode => _statusCode;

  CommonResponse(bool success, String? message, int statusCode)
    : _success = success,
      _message = message,
      _statusCode = statusCode;

  factory CommonResponse.fromMap(Map<String, dynamic> map) =>
      CommonResponse(map['success'], map['message'], map['statusCode']);

  @override
  Map<String, dynamic> get toMap => {
    'success': _success,
    'message': _message,
    'statusCode': _statusCode,
  };

  @override
  String toString() {
    return 'CommonResponse{success: $_success, message: $_message, statusCode: $_statusCode}';
  }
}
