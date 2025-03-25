// ignore_for_file: argument_type_not_assignable

import 'package:bunny_dart/src/common/common_object.dart';

/// Meta tags added to the video
class VideoMetaTag extends CommonObject {
  /// The key of the meta tag
  final String? _property;

  /// The value of the meta tag
  final String? _value;

  String? get property => _property;
  String? get value => _value;

  VideoMetaTag({String? property, String? value})
    : _property = property,
      _value = value;

  factory VideoMetaTag.fromMap(Map<String, dynamic> map) =>
      VideoMetaTag(property: map['property'], value: map['value']);

  @override
  Map<String, dynamic> get toMap => {'property': _property, 'value': _value};

  @override
  String toString() {
    return 'VideoMetaTag{property: $_property, value: $_value}';
  }
}
