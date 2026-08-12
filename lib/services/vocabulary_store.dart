import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/tocfl_models.dart';

class VocabularyStore {
  static const defaultFilename = 'vocab.txt';
  static const geminiFilename = 'gemini_vocabulary.txt';
  static const _lastFilenameKey = 'vocabulary.lastFilename';

  final SharedPreferencesAsync _preferences = SharedPreferencesAsync();

  Future<Directory> directory() async {
    final documents = await getApplicationDocumentsDirectory();
    final result = Directory(
      p.join(documents.path, 'TOCFL Full Exam', 'vocabulary'),
    );
    await result.create(recursive: true);
    return result;
  }

  Future<String> filePath(String filename) async {
    final folder = await directory();
    return p.join(folder.path, normalizeFilename(filename));
  }

  Future<List<String>> listFiles() async {
    final folder = await directory();
    final names = <String>[];
    await for (final entity in folder.list()) {
      if (entity is File && p.extension(entity.path).toLowerCase() == '.txt') {
        names.add(p.basename(entity.path));
      }
    }
    if (!names.contains(defaultFilename)) {
      names.add(defaultFilename);
    }
    names.sort((left, right) {
      if (left == defaultFilename) return -1;
      if (right == defaultFilename) return 1;
      return left.toLowerCase().compareTo(right.toLowerCase());
    });
    return names;
  }

  Future<String> lastFilename() async {
    final saved = await _preferences.getString(_lastFilenameKey);
    return normalizeFilename(saved ?? defaultFilename);
  }

  Future<List<String>> readLines(String filename) async {
    final file = File(await filePath(filename));
    if (!await file.exists()) return const [];
    return const LineSplitter()
        .convert(await file.readAsString())
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
  }

  Future<bool> addEntry({
    required String filename,
    required String word,
    required String meaning,
    String pinyin = '',
  }) async {
    final entry = VocabularyEntry(
      word: word.trim(),
      pinyin: pinyin.trim(),
      meaning: meaning.trim(),
    );
    if (entry.word.isEmpty || entry.meaning.isEmpty) return false;
    final cleanFilename = normalizeFilename(filename);
    final lines = (await readLines(cleanFilename)).toList();
    final key = _wordKey(entry.word);
    if (lines.any((line) => _wordKey(line.split(':').first) == key)) {
      await _preferences.setString(_lastFilenameKey, cleanFilename);
      return false;
    }
    lines.add(entry.textLine);
    await _writeLines(cleanFilename, lines);
    await _preferences.setString(_lastFilenameKey, cleanFilename);
    return true;
  }

  Future<int> mergeEntries(
    Iterable<VocabularyEntry> entries, {
    String filename = geminiFilename,
  }) async {
    final cleanFilename = normalizeFilename(filename);
    final lines = (await readLines(cleanFilename)).toList();
    final known = lines
        .map((line) => _wordKey(line.split(':').first))
        .where((key) => key.isNotEmpty)
        .toSet();
    var added = 0;
    for (final entry in entries) {
      final key = _wordKey(entry.word);
      if (key.isEmpty || entry.meaning.trim().isEmpty || !known.add(key)) {
        continue;
      }
      lines.add(entry.textLine);
      added++;
    }
    if (added > 0) await _writeLines(cleanFilename, lines);
    return added;
  }

  String normalizeFilename(String value) {
    final basename = value.trim().split(RegExp(r'[/\\]')).last;
    final safe = basename.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_').trim();
    if (safe.isEmpty) return defaultFilename;
    return safe.toLowerCase().endsWith('.txt') ? safe : '$safe.txt';
  }

  Future<void> _writeLines(String filename, List<String> lines) async {
    final file = File(await filePath(filename));
    await file.writeAsString(
      lines.isEmpty ? '' : '${lines.join('\n')}\n',
      flush: true,
    );
  }

  String _wordKey(String value) => value.trim().toLowerCase();
}
