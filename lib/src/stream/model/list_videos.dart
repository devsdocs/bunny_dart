// ignore_for_file: avoid_dynamic_calls, argument_type_not_assignable

import 'package:bunny_dart/src/common/common_object.dart';
import 'package:bunny_dart/src/stream/model/video.dart';

class ListVideos extends CommonObject {
  final int _totalItems;
  final int _currentPage;
  final int _itemsPerPage;
  final List<Video>? _items;

  int get totalItems => _totalItems;
  int get currentPage => _currentPage;
  int get itemsPerPage => _itemsPerPage;
  List<Video>? get items => _items;

  ListVideos({
    required int totalItems,
    required int currentPage,
    required int itemsPerPage,
    List<Video>? items,
  }) : _totalItems = totalItems,
       _currentPage = currentPage,
       _itemsPerPage = itemsPerPage,
       _items = items;

  factory ListVideos.fromMap(Map<String, dynamic> map) => ListVideos(
    totalItems: map['totalItems'],
    currentPage: map['currentPage'],
    itemsPerPage: map['itemsPerPage'],
    items:
        map['items'] == null
            ? null
            : List<Video>.from(map['items'].map((x) => Video.fromMap(x))),
  );

  @override
  Map<String, dynamic> get toMap => {
    'totalItems': _totalItems,
    'currentPage': _currentPage,
    'itemsPerPage': _itemsPerPage,
    if (_items != null) 'items': List<dynamic>.from(_items.map((x) => x.toMap)),
  };

  @override
  String toString() {
    return 'ListVideos{totalItems: $_totalItems, currentPage: $_currentPage, itemsPerPage: $_itemsPerPage, items: $_items}';
  }
}
