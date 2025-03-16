abstract class CommonObject {
  Map<String, dynamic> get toMap;
}

/// Chapters available for the video
class VideoChapter implements CommonObject {
  final String _title;
  final int? _start;
  final int? _end;

  VideoChapter(
    /// The title of the chapter
    String title, {

    /// The start time of the chapter in seconds
    int? start,

    /// The end time of the chapter in seconds
    int? end,
  }) : assert(title.isNotEmpty),
       _title = title,
       _start = start,
       _end = end;

  @override
  Map<String, dynamic> get toMap => {
    'title': _title,
    'start': _start,
    'end': _end,
  };
}

/// Moment available for the video
class VideoMoment implements CommonObject {
  final String _label;
  final int? _time;

  VideoMoment(
    /// The text description label for the chapter
    String label, {

    /// The timestamp of the moment in seconds
    int? time,
  }) : assert(label.isNotEmpty),
       _label = label,
       _time = time;

  @override
  Map<String, dynamic> get toMap => {'label': _label, 'timestamp': _time};
}

/// Meta tags added to the video
class VideoMetaTag implements CommonObject {
  final String? _property;
  final String? _value;

  VideoMetaTag({
    /// The key of the meta tag
    String? key,

    /// The value of the meta tag
    String? value,
  }) : _property = key,
       _value = value;

  @override
  Map<String, dynamic> get toMap => {'property': _property, 'value': _value};
}
