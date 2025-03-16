// ignore_for_file: argument_type_not_assignable

import 'package:bunny_dart/src/common/common_object.dart';

/// Moment available for the video
class VideoMoment extends CommonObject {
  /// The text description label for the chapter
  final String _label;

  /// The timestamp of the moment in seconds
  final int? _time;

  String get label => _label;

  int? get time => _time;

  VideoMoment(String label, {int? time})
    : assert(label.isNotEmpty),
      _label = label,
      _time = time;

  factory VideoMoment.fromMap(Map<String, dynamic> map) =>
      VideoMoment(map['label'], time: map['timestamp']);

  @override
  Map<String, dynamic> get toMap => {'label': _label, 'timestamp': _time};
}
