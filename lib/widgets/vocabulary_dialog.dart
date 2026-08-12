import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../core/app_theme.dart';
import '../services/gemini_service.dart';
import '../services/settings_store.dart';
import '../services/vocabulary_store.dart';

class VocabularySaveResult {
  const VocabularySaveResult({
    required this.filename,
    required this.word,
    required this.added,
  });

  final String filename;
  final String word;
  final bool added;
}

Future<VocabularySaveResult?> showVocabularyDialog(
  BuildContext context, {
  required SettingsStore settings,
  String initialWord = '',
  String initialMeaning = '',
  String initialPinyin = '',
  String? initialFilename,
}) {
  return showDialog<VocabularySaveResult>(
    context: context,
    builder: (_) => _VocabularyDialog(
      settings: settings,
      initialWord: initialWord,
      initialMeaning: initialMeaning,
      initialPinyin: initialPinyin,
      initialFilename: initialFilename,
    ),
  );
}

class _VocabularyDialog extends StatefulWidget {
  const _VocabularyDialog({
    required this.settings,
    required this.initialWord,
    required this.initialMeaning,
    required this.initialPinyin,
    required this.initialFilename,
  });

  final SettingsStore settings;
  final String initialWord;
  final String initialMeaning;
  final String initialPinyin;
  final String? initialFilename;

  @override
  State<_VocabularyDialog> createState() => _VocabularyDialogState();
}

class _VocabularyDialogState extends State<_VocabularyDialog> {
  final _formKey = GlobalKey<FormState>();
  final _store = VocabularyStore();
  late final TextEditingController _word;
  late final TextEditingController _meaning;
  late final TextEditingController _pinyin;
  late final TextEditingController _filename;
  bool _lookingUp = false;

  @override
  void initState() {
    super.initState();
    _word = TextEditingController(text: widget.initialWord.trim());
    _meaning = TextEditingController(text: widget.initialMeaning.trim());
    _pinyin = TextEditingController(text: widget.initialPinyin.trim());
    _filename = TextEditingController(
      text: widget.initialFilename ?? VocabularyStore.defaultFilename,
    );
    _loadLastFilename();
    if (_meaning.text.isEmpty &&
        _pinyin.text.isEmpty &&
        widget.settings.geminiApiKey.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _lookup();
      });
    }
  }

  Future<void> _loadLastFilename() async {
    if (widget.initialFilename != null) return;
    final value = await _store.lastFilename();
    if (mounted) _filename.text = value;
  }

  @override
  void dispose() {
    _word.dispose();
    _meaning.dispose();
    _pinyin.dispose();
    _filename.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.bookmark_add_outlined, color: AppColors.blue),
          SizedBox(width: 8),
          Expanded(child: Text('Thêm từ vựng')),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _word,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Từ / cụm từ'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Hãy nhập từ cần lưu.'
                      : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _meaning,
                  decoration: const InputDecoration(
                    labelText: 'Nghĩa tiếng Việt',
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Hãy nhập nghĩa của từ.'
                      : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _pinyin,
                  decoration: const InputDecoration(
                    labelText: 'Pinyin (không bắt buộc)',
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _filename,
                  decoration: const InputDecoration(
                    labelText: 'File TXT',
                    hintText: 'vocab.txt',
                  ),
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: _lookingUp ? null : _lookup,
                  icon: _lookingUp
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : SvgPicture.asset(
                          'assets/icon/gemini-color.svg',
                          width: 19,
                          height: 19,
                          semanticsLabel: 'Gemini',
                        ),
                  label: Text(
                    _lookingUp
                        ? 'Gemini đang phân tích nghĩa...'
                        : 'Gemini phân tích nghĩa và pinyin',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Hủy'),
        ),
        FilledButton.icon(
          onPressed: _save,
          icon: const Icon(Icons.save_outlined),
          label: const Text('Lưu vào TXT'),
        ),
      ],
    );
  }

  Future<void> _lookup() async {
    final word = _word.text.trim();
    if (word.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hãy nhập từ cần tra trước.')),
      );
      return;
    }
    setState(() => _lookingUp = true);
    try {
      final result = await GeminiService(
        widget.settings,
      ).lookupVocabulary(word);
      if (!mounted) return;
      if (result.word.trim().isNotEmpty) _word.text = result.word.trim();
      _meaning.text = result.meaning.trim();
      _pinyin.text = result.pinyin.trim();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Không tra được từ: $error')));
      }
    } finally {
      if (mounted) setState(() => _lookingUp = false);
    }
  }

  Future<void> _save() async {
    if (_formKey.currentState?.validate() != true) return;
    final filename = _store.normalizeFilename(_filename.text);
    final word = _word.text.trim();
    final added = await _store.addEntry(
      filename: filename,
      word: word,
      meaning: _meaning.text,
      pinyin: _pinyin.text,
    );
    if (!mounted) return;
    Navigator.of(
      context,
    ).pop(VocabularySaveResult(filename: filename, word: word, added: added));
  }
}
