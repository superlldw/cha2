import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

class LocalTemplateStore {
  LocalTemplateStore._();

  static const String _assetPath = 'assets/inspection_template_items.json';

  static List<Map<String, dynamic>>? _cachedItems;

  static Future<List<Map<String, dynamic>>> buildTaskTemplateTree({
    required String damType,
    required List<String> enabledChapters,
  }) async {
    final items = await _loadTemplateSeed();
    final filtered = items.where((item) {
      final chapterCode = item['chapter_code']?.toString() ?? '';
      final applicableDamTypes =
          (item['applicable_dam_type'] as List<dynamic>? ?? const [])
              .map((e) => e.toString())
              .toList();
      return enabledChapters.contains(chapterCode) &&
          _damTypeFilter(chapterCode, damType) &&
          applicableDamTypes.contains(damType);
    }).toList()
      ..sort((a, b) =>
          ((a['sort_order'] as num?) ?? 0).compareTo((b['sort_order'] as num?) ?? 0));

    return _buildTree(filtered);
  }

  static Future<List<Map<String, dynamic>>> _loadTemplateSeed() async {
    if (_cachedItems != null) {
      return _cachedItems!;
    }
    final raw = await rootBundle.loadString(_assetPath);
    final payload = jsonDecode(raw) as Map<String, dynamic>;
    final items = (payload['items'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();
    _cachedItems = items;
    return items;
  }

  static bool _damTypeFilter(String chapterCode, String damType) {
    if (damType == 'earthfill' || damType == 'rockfill') {
      return chapterCode != 'A3';
    }
    if (damType == 'concrete' || damType == 'masonry') {
      return chapterCode != 'A2';
    }
    return true;
  }

  static List<Map<String, dynamic>> _buildTree(
    List<Map<String, dynamic>> filteredItems,
  ) {
    final byCode = <String, Map<String, dynamic>>{
      for (final item in filteredItems) item['item_code'].toString(): item,
    };
    final chapters = filteredItems
        .where((item) => item['item_type'] == 'chapter')
        .toList()
      ..sort((a, b) =>
          ((a['sort_order'] as num?) ?? 0).compareTo((b['sort_order'] as num?) ?? 0));
    final sections = filteredItems
        .where((item) => item['item_type'] == 'section')
        .toList()
      ..sort((a, b) =>
          ((a['sort_order'] as num?) ?? 0).compareTo((b['sort_order'] as num?) ?? 0));
    final leaves = filteredItems
        .where((item) => item['item_type'] == 'inspection_item')
        .toList()
      ..sort((a, b) =>
          ((a['sort_order'] as num?) ?? 0).compareTo((b['sort_order'] as num?) ?? 0));

    final leavesByParent = <String, List<Map<String, dynamic>>>{};
    for (final leaf in leaves) {
      final parentCode = leaf['parent_code']?.toString() ?? '';
      leavesByParent.putIfAbsent(parentCode, () => []).add(leaf);
    }

    final sectionsByChapter = <String, List<Map<String, dynamic>>>{};
    for (final section in sections) {
      final chapterCode = section['chapter_code']?.toString() ?? '';
      sectionsByChapter.putIfAbsent(chapterCode, () => []).add(section);
    }

    final tree = <Map<String, dynamic>>[];
    for (final chapter in chapters) {
      final chapterCode = chapter['item_code']?.toString() ?? '';
      final chapterNode = <String, dynamic>{
        'chapter_code': chapterCode,
        'chapter_name': chapter['item_name']?.toString() ?? '',
        'children': <Map<String, dynamic>>[],
      };
      for (final section in sectionsByChapter[chapterCode] ?? const []) {
        final sectionCode = section['item_code']?.toString() ?? '';
        final sectionNode = <String, dynamic>{
          'item_code': sectionCode,
          'item_name': section['item_name']?.toString() ?? '',
          'item_type': section['item_type']?.toString() ?? 'section',
          'children': <Map<String, dynamic>>[],
        };
        for (final leaf in leavesByParent[sectionCode] ?? const []) {
          final parentCode = leaf['parent_code']?.toString() ?? '';
          if (!byCode.containsKey(parentCode)) {
            continue;
          }
          (sectionNode['children'] as List<Map<String, dynamic>>).add({
            'item_code': leaf['item_code']?.toString() ?? '',
            'item_name': leaf['item_name']?.toString() ?? '',
            'item_type': leaf['item_type']?.toString() ?? 'inspection_item',
            'supports_photo': leaf['supports_photo'] as bool? ?? false,
            'supports_audio': leaf['supports_audio'] as bool? ?? false,
            'supports_location': leaf['supports_location'] as bool? ?? false,
            'supports_attachment': leaf['supports_attachment'] as bool? ?? false,
          });
        }
        (chapterNode['children'] as List<Map<String, dynamic>>).add(sectionNode);
      }
      tree.add(chapterNode);
    }
    return tree;
  }
}
