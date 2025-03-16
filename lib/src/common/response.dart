// ignore_for_file: argument_type_not_assignable

import 'package:bunny_dart/src/common/common_object.dart';

class CommonResponse extends CommonObject {
  final bool success;
  final String? message;
  final int statusCode;

  CommonResponse(this.success, this.message, this.statusCode);

  factory CommonResponse.fromMap(Map<String, dynamic> map) =>
      CommonResponse(map['success'], map['message'], map['statusCode']);

  @override
  Map<String, dynamic> get toMap => {
    'success': success,
    'message': message,
    'statusCode': statusCode,
  };
}
