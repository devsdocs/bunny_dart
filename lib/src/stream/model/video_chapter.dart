// ignore_for_file: argument_type_not_assignable

import 'package:bunny_dart/src/common/common_object.dart';

/// Chapters available for the video
class VideoChapter extends CommonObject {
  /// The title of the chapter
  final String _title;

  /// The start time of the chapter in seconds
  final int? _start;

  /// The end time of the chapter in seconds
  final int? _end;

  String get title => _title;

  int? get start => _start;

  int? get end => _end;

  VideoChapter(String title, {int? start, int? end})
    : assert(title.isNotEmpty),
      _title = title,
      _start = start,
      _end = end;

  factory VideoChapter.fromMap(Map<String, dynamic> map) =>
      VideoChapter(map['title'], start: map['start'], end: map['end']);

  @override
  Map<String, dynamic> get toMap => {
    'title': _title,
    'start': _start,
    'end': _end,
  };

  @override
  String toString() {
    return 'VideoChapter{title: $_title, start: $_start, end: $_end}';
  }
}
