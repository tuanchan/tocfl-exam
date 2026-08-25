import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class SavedPracticeTest {
  const SavedPracticeTest({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.questionIds,
  });

  final String id;
  final String name;
  final DateTime createdAt;
  final List<String> questionIds;

  SavedPracticeTest copyWith({String? name}) => SavedPracticeTest(
    id: id,
    name: name ?? this.name,
    createdAt: createdAt,
    questionIds: questionIds,
  );

  factory SavedPracticeTest.fromJson(Map<String, dynamic> json) {
    final savedName = json['name']?.toString().trim() ?? '';
    return SavedPracticeTest(
      id: json['id']?.toString() ?? '',
      name: savedName.isEmpty ? 'Đề đã tạo' : savedName,
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      questionIds: (json['questionIds'] as List<dynamic>? ?? const [])
          .map((value) => value.toString())
          .where((value) => value.isNotEmpty)
          .toList(growable: false),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'createdAt': createdAt.toIso8601String(),
    'questionIds': questionIds,
  };
}

class TestBuilderPreferences {
  const TestBuilderPreferences({
    required this.levels,
    required this.listening,
    required this.reading,
    required this.random,
    required this.questionCount,
  });

  static const defaults = TestBuilderPreferences(
    levels: ['01'],
    listening: true,
    reading: true,
    random: false,
    questionCount: 20,
  );

  final List<String> levels;
  final bool listening;
  final bool reading;
  final bool random;
  final int questionCount;

  factory TestBuilderPreferences.fromJson(Map<String, dynamic> json) {
    const allowedLevels = {'01', '02', '03', '04'};
    final savedLevels =
        (json['levels'] as List<dynamic>? ?? const [])
            .map((value) => value.toString())
            .where(allowedLevels.contains)
            .toSet()
            .toList()
          ..sort();
    final listening = json['listening'] is bool
        ? json['listening'] as bool
        : defaults.listening;
    final reading = json['reading'] is bool
        ? json['reading'] as bool
        : defaults.reading;
    final savedQuestionCount = int.tryParse(
      json['questionCount']?.toString() ?? '',
    );
    return TestBuilderPreferences(
      levels: savedLevels.isEmpty ? defaults.levels : savedLevels,
      listening: !listening && !reading ? defaults.listening : listening,
      reading: !listening && !reading ? defaults.reading : reading,
      random: json['random'] is bool ? json['random'] as bool : defaults.random,
      questionCount: (savedQuestionCount ?? defaults.questionCount).clamp(
        1,
        10000,
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'levels': levels,
    'listening': listening,
    'reading': reading,
    'random': random,
    'questionCount': questionCount,
  };
}

class CreatedTestStore {
  static const _storageKey = 'practiceTests.saved.v1';
  static const _builderPreferencesKey = 'practiceTests.builderPreferences.v1';

  final SharedPreferencesAsync _preferences = SharedPreferencesAsync();

  Future<List<SavedPracticeTest>> load() async {
    final source = await _preferences.getString(_storageKey);
    if (source == null || source.trim().isEmpty) return const [];
    try {
      final tests = (jsonDecode(source) as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(SavedPracticeTest.fromJson)
          .where((test) => test.id.isNotEmpty && test.questionIds.isNotEmpty)
          .toList();
      tests.sort((left, right) => right.createdAt.compareTo(left.createdAt));
      return tests;
    } catch (_) {
      return const [];
    }
  }

  Future<TestBuilderPreferences> loadBuilderPreferences() async {
    final source = await _preferences.getString(_builderPreferencesKey);
    if (source == null || source.trim().isEmpty) {
      return TestBuilderPreferences.defaults;
    }
    try {
      final json = jsonDecode(source);
      if (json is! Map<String, dynamic>) {
        return TestBuilderPreferences.defaults;
      }
      return TestBuilderPreferences.fromJson(json);
    } catch (_) {
      return TestBuilderPreferences.defaults;
    }
  }

  Future<void> saveBuilderPreferences(
    TestBuilderPreferences preferences,
  ) async {
    await _preferences.setString(
      _builderPreferencesKey,
      jsonEncode(preferences.toJson()),
    );
  }

  Future<List<SavedPracticeTest>> save(SavedPracticeTest test) async {
    final tests = (await load()).where((item) => item.id != test.id).toList()
      ..insert(0, test);
    await _write(tests);
    return tests;
  }

  Future<List<SavedPracticeTest>> delete(String id) async {
    final tests = (await load()).where((item) => item.id != id).toList();
    await _write(tests);
    return tests;
  }

  Future<List<SavedPracticeTest>> rename(String id, String name) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) {
      throw ArgumentError.value(name, 'name', 'Tên đề không được để trống.');
    }
    final tests = await load();
    final index = tests.indexWhere((test) => test.id == id);
    if (index < 0) return tests;
    tests[index] = tests[index].copyWith(name: cleanName);
    await _write(tests);
    return tests;
  }

  Future<void> _write(List<SavedPracticeTest> tests) async {
    await _preferences.setString(
      _storageKey,
      jsonEncode(tests.map((test) => test.toJson()).toList(growable: false)),
    );
  }
}
