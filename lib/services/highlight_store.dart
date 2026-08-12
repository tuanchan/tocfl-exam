import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TextHighlightMark {
  const TextHighlightMark({
    required this.start,
    required this.end,
    required this.color,
    this.bold = false,
    this.italic = false,
    this.underline = false,
  });

  final int start;
  final int end;
  final Color color;
  final bool bold;
  final bool italic;
  final bool underline;

  bool overlaps(int otherStart, int otherEnd) =>
      start < otherEnd && otherStart < end;

  Map<String, dynamic> toJson() => {
    'start': start,
    'end': end,
    'color': color.toARGB32(),
    'bold': bold,
    'italic': italic,
    'underline': underline,
  };

  factory TextHighlightMark.fromJson(Map<String, dynamic> json) =>
      TextHighlightMark(
        start: (json['start'] as num?)?.toInt() ?? 0,
        end: (json['end'] as num?)?.toInt() ?? 0,
        color: Color((json['color'] as num?)?.toInt() ?? 0xFFFFF59D),
        bold: json['bold'] as bool? ?? false,
        italic: json['italic'] as bool? ?? false,
        underline: json['underline'] as bool? ?? false,
      );
}

class HighlightStore {
  HighlightStore._();

  static final HighlightStore instance = HighlightStore._();
  static const _storageKey = 'highlights.content.v1';

  final SharedPreferencesAsync _preferences = SharedPreferencesAsync();
  final Map<String, List<TextHighlightMark>> _marks = {};

  Future<void> load() async {
    _marks.clear();
    final source = await _preferences.getString(_storageKey);
    if (source == null || source.trim().isEmpty) return;
    try {
      final values = jsonDecode(source) as Map<String, dynamic>;
      for (final entry in values.entries) {
        _marks[entry.key] = (entry.value as List<dynamic>)
            .map(
              (value) =>
                  TextHighlightMark.fromJson(value as Map<String, dynamic>),
            )
            .toList();
      }
    } catch (_) {
      _marks.clear();
    }
  }

  List<TextHighlightMark> get(String key) =>
      List<TextHighlightMark>.unmodifiable(_marks[key] ?? const []);

  Future<void> set(String key, List<TextHighlightMark> marks) async {
    if (marks.isEmpty) {
      _marks.remove(key);
    } else {
      _marks[key] = List<TextHighlightMark>.from(marks);
    }
    await _preferences.setString(
      _storageKey,
      jsonEncode(
        _marks.map(
          (key, value) => MapEntry(
            key,
            value.map((mark) => mark.toJson()).toList(growable: false),
          ),
        ),
      ),
    );
  }
}
