// ignore_for_file: avoid_dynamic_calls, argument_type_not_assignable

import 'package:bunny_dart/src/common/common_object.dart';

class TranscodingMessages extends CommonObject {
  final DateTime _timeStamp;

  final TranscodingLevel _level;

  final TranscodingIssue _issueCode;

  final String? _message;

  final String? _value;

  DateTime get timeStamp => _timeStamp;

  TranscodingLevel get level => _level;

  TranscodingIssue get issueCode => _issueCode;

  String? get message => _message;

  String? get value => _value;

  TranscodingMessages({
    required DateTime timeStamp,
    required TranscodingLevel level,
    required TranscodingIssue issueCode,
    String? message,
    String? value,
  }) : _timeStamp = timeStamp,
       _level = level,
       _issueCode = issueCode,
       _message = message,
       _value = value;

  factory TranscodingMessages.fromMap(Map<String, dynamic> map) =>
      TranscodingMessages(
        timeStamp: DateTime.parse(map['timeStamp'] as String),
        level: TranscodingLevel.values[map['level'] as int],
        issueCode: TranscodingIssue.values[map['issueCode'] as int],
        message: map['message'] as String?,
        value: map['value'] as String?,
      );

  @override
  Map<String, dynamic> get toMap => {
    'timeStamp': _timeStamp.toIso8601String(),
    'level': _level.viewString,
    'issueCode': _issueCode.index,
    if (_message != null) 'message': _message,
    if (_value != null) 'value': _value,
  };
}

enum TranscodingLevel {
  undefined._('Undefined'),
  information._('Information'),
  warning._('Warning'),
  error._('Error');

  const TranscodingLevel._(this.viewString);

  final String viewString;
}

enum TranscodingIssue {
  undefined._('Undefined'),
  streamLengthsDifference._('Stream Lengths Difference'),
  transcodingWarnings._('Transcoding Warnings'),
  incompatibleResolution._('Incompatible Resolution'),
  invalidFramerate._('Invalid Framerate'),
  videoExceededMaxDuration._('Video Exceeded Max Duration'),
  audioExceededMaxDuration._('Audio Exceeded Max Duration'),
  originalCorrupted._('Original Corrupted'),
  transcriptionFailed._('Transcription Failed'),
  jitIncompatible._('JIT Incompatible'),
  jitFailed._('JIT Failed');

  const TranscodingIssue._(this.viewString);

  final String viewString;
}
