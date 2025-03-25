// ignore_for_file: argument_type_not_assignable

import 'package:bunny_dart/src/common/common_object.dart';

class Caption extends CommonObject {
  /// The unique srclang shortcode for the caption
  final String? _srclang;

  /// The text description label for the caption
  final String? _label;

  String? get srclang => _srclang;

  String? get label => _label;

  Caption({String? srcLang, String? label})
    : _srclang = srcLang,
      _label = label;

  factory Caption.fromMap(Map<String, dynamic> map) =>
      Caption(srcLang: map['srclang'], label: map['label']);

  @override
  Map<String, dynamic> get toMap => {
    if (_srclang != null) 'srclang': _srclang,
    if (_label != null) 'label': _label,
  };

  @override
  String toString() {
    return 'Caption{srclang: $_srclang, label: $_label}';
  }
}
