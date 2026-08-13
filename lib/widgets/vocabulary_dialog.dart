import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../core/app_theme.dart';
import '../core/app_toast.dart';
import '../services/gemini_service.dart';
import '../services/settings_store.dart';
import '../services/vocabulary_store.dart';

enum VocabularySaveAction { added, updated, duplicate }

class VocabularySaveResult {
  const VocabularySaveResult({
    required this.filename,
    required this.word,
    required this.action,
  });

  final String filename;
  final String word;
  final VocabularySaveAction action;

  bool get added => action == VocabularySaveAction.added;
  bool get updated => action == VocabularySaveAction.updated;
}

Future<VocabularySaveResult?> showVocabularyDialog(
  BuildContext context, {
  required SettingsStore settings,
  String initialWord = '',
  String initialMeaning = '',
  String initialPinyin = '',
  String? initialFilename,
  int? editingLineIndex,
}) {
  return showDialog<VocabularySaveResult>(
    context: context,
    builder: (_) => _VocabularyDialog(
      settings: settings,
      initialWord: initialWord,
      initialMeaning: initialMeaning,
      initialPinyin: initialPinyin,
      initialFilename: initialFilename,
      editingLineIndex: editingLineIndex,
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
    required this.editingLineIndex,
  });

  final SettingsStore settings;
  final String initialWord;
  final String initialMeaning;
  final String initialPinyin;
  final String? initialFilename;
  final int? editingLineIndex;

  @override
  State<_VocabularyDialog> createState() => _VocabularyDialogState();
}

class _VocabularyDialogState extends State<_VocabularyDialog> {
  final _formKey = GlobalKey<FormState>();
  final _store = VocabularyStore();
  late final TextEditingController _word;
  late final TextEditingController _meaning;
  late final TextEditingController _pinyin;
  late final TextEditingController _newFilename;
  List<String> _files = const [];
  String? _selectedFilename;
  String? _newFilenameError;
  bool _loadingFiles = true;
  bool _creatingFile = false;
  bool _savingFile = false;
  bool _lookingUp = false;

  bool get _editing => widget.editingLineIndex != null;

  @override
  void initState() {
    super.initState();
    _word = TextEditingController(text: widget.initialWord.trim());
    _meaning = TextEditingController(text: widget.initialMeaning.trim());
    _pinyin = TextEditingController(text: widget.initialPinyin.trim());
    _newFilename = TextEditingController();
    _loadFiles();
    if (_meaning.text.isEmpty &&
        _pinyin.text.isEmpty &&
        widget.settings.geminiApiKey.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _lookup();
      });
    }
  }

  Future<void> _loadFiles() async {
    try {
      final files = await _store.listFiles();
      final initial = widget.initialFilename == null
          ? null
          : _store.normalizeFilename(widget.initialFilename!);
      final recent = initial ?? await _store.lastFilename();
      final selected = files.firstWhere(
        (filename) => filename.toLowerCase() == recent.toLowerCase(),
        orElse: () => files.first,
      );
      if (!mounted) return;
      setState(() {
        _files = files;
        _selectedFilename = selected;
        _loadingFiles = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loadingFiles = false);
      AppToast.show(
        context,
        'Không đọc được danh sách TXT: $error',
        tone: AppToastTone.error,
      );
    }
  }

  @override
  void dispose() {
    _word.dispose();
    _meaning.dispose();
    _pinyin.dispose();
    _newFilename.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_editing ? 'Sửa từ vựng' : 'Thêm từ vựng'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
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
                const SizedBox(height: 12),
                if (_editing)
                  InputDecorator(
                    decoration: const InputDecoration(labelText: 'File TXT'),
                    child: Text(
                      widget.initialFilename ?? VocabularyStore.defaultFilename,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  )
                else
                  _fileSelector(),
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
        FilledButton(
          onPressed: _loadingFiles || _savingFile ? null : _save,
          child: Text(_editing ? 'Lưu thay đổi' : 'Lưu vào TXT'),
        ),
      ],
    );
  }

  Widget _fileSelector() {
    if (_loadingFiles) {
      return const InputDecorator(
        decoration: InputDecoration(labelText: 'Lưu vào file TXT'),
        child: Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 10),
            Text('Đang đọc danh sách file...'),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          key: ValueKey(_selectedFilename),
          initialValue: _selectedFilename,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Lưu vào file TXT'),
          items: _files
              .map(
                (filename) => DropdownMenuItem(
                  value: filename,
                  child: Text(filename, overflow: TextOverflow.ellipsis),
                ),
              )
              .toList(growable: false),
          onChanged: (value) => setState(() => _selectedFilename = value),
        ),
        const SizedBox(height: 8),
        AppTextButton(
          label: _creatingFile ? 'Hủy tạo TXT mới' : 'Tạo TXT mới ngay',
          compact: true,
          onPressed: () => setState(() {
            _creatingFile = !_creatingFile;
            _newFilenameError = null;
          }),
        ),
        if (_creatingFile) ...[
          const SizedBox(height: 10),
          TextField(
            controller: _newFilename,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Tên file TXT mới',
              hintText: 'chu_de_moi.txt',
              errorText: _newFilenameError,
            ),
            onSubmitted: (_) => _createAndSelectFile(),
          ),
          const SizedBox(height: 8),
          AppTextButton(
            label: _savingFile ? 'Đang tạo file...' : 'Tạo và chọn file này',
            filled: true,
            compact: true,
            onPressed: _savingFile ? null : _createAndSelectFile,
          ),
        ],
      ],
    );
  }

  Future<void> _createAndSelectFile() async {
    final rawName = _newFilename.text.trim();
    if (rawName.isEmpty) {
      setState(() => _newFilenameError = 'Hãy nhập tên file TXT.');
      return;
    }

    setState(() {
      _savingFile = true;
      _newFilenameError = null;
    });
    try {
      final normalized = _store.normalizeFilename(rawName);
      final existed = _files.any(
        (filename) => filename.toLowerCase() == normalized.toLowerCase(),
      );
      final filename = await _store.createFile(normalized);
      final files = await _store.listFiles();
      if (!mounted) return;
      setState(() {
        _files = files;
        _selectedFilename = filename;
        _creatingFile = false;
        _newFilename.clear();
      });
      AppToast.show(
        context,
        existed ? 'Đã chọn file $filename.' : 'Đã tạo file $filename.',
        tone: AppToastTone.success,
      );
    } catch (error) {
      if (mounted) {
        AppToast.show(
          context,
          'Không tạo được file TXT: $error',
          tone: AppToastTone.error,
        );
      }
    } finally {
      if (mounted) setState(() => _savingFile = false);
    }
  }

  Future<void> _lookup() async {
    final word = _word.text.trim();
    if (word.isEmpty) {
      AppToast.show(
        context,
        'Hãy nhập từ cần tra trước.',
        tone: AppToastTone.warning,
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
        AppToast.show(
          context,
          'Không tra được từ: $error',
          tone: AppToastTone.error,
        );
      }
    } finally {
      if (mounted) setState(() => _lookingUp = false);
    }
  }

  Future<void> _save() async {
    if (_formKey.currentState?.validate() != true) return;
    final filename = _editing
        ? _store.normalizeFilename(
            widget.initialFilename ?? VocabularyStore.defaultFilename,
          )
        : _selectedFilename;
    if (filename == null) {
      AppToast.show(
        context,
        'Hãy chọn file TXT muốn lưu.',
        tone: AppToastTone.warning,
      );
      return;
    }

    setState(() => _savingFile = true);
    try {
      final word = _word.text.trim();
      final saved = _editing
          ? await _store.updateEntryAt(
              filename: filename,
              index: widget.editingLineIndex!,
              word: word,
              meaning: _meaning.text,
              pinyin: _pinyin.text,
            )
          : await _store.addEntry(
              filename: filename,
              word: word,
              meaning: _meaning.text,
              pinyin: _pinyin.text,
            );
      if (!mounted) return;
      setState(() => _savingFile = false);
      Navigator.of(context).pop(
        VocabularySaveResult(
          filename: filename,
          word: word,
          action: saved
              ? _editing
                    ? VocabularySaveAction.updated
                    : VocabularySaveAction.added
              : VocabularySaveAction.duplicate,
        ),
      );
    } catch (error) {
      if (mounted) {
        setState(() => _savingFile = false);
        AppToast.show(
          context,
          'Không lưu được từ vựng: $error',
          tone: AppToastTone.error,
        );
      }
    }
  }
}
