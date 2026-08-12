import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../services/settings_store.dart';
import '../services/vocabulary_store.dart';
import '../widgets/highlightable_text.dart';
import '../widgets/vocabulary_dialog.dart';

class VocabularyPage extends StatefulWidget {
  const VocabularyPage({super.key, required this.settings});

  final SettingsStore settings;

  @override
  State<VocabularyPage> createState() => _VocabularyPageState();
}

class _VocabularyPageState extends State<VocabularyPage> {
  final VocabularyStore _store = VocabularyStore();
  List<String> _files = const [];
  List<String> _lines = const [];
  String? _selectedFile;
  String? _filePath;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({String? preferredFile}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final files = await _store.listFiles();
      final last =
          preferredFile ?? _selectedFile ?? await _store.lastFilename();
      final selected = files.contains(last) ? last : files.first;
      final lines = await _store.readLines(selected);
      final filePath = await _store.filePath(selected);
      if (!mounted) return;
      setState(() {
        _files = files;
        _selectedFile = selected;
        _lines = lines;
        _filePath = filePath;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Từ vựng TXT'),
        actions: [
          IconButton(
            tooltip: 'Thêm từ vựng',
            onPressed: _addVocabulary,
            icon: const Icon(Icons.add_rounded),
          ),
          IconButton(
            tooltip: 'Tải lại file',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!, textAlign: TextAlign.center))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                AppSection(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: _selectedFile,
                        decoration: const InputDecoration(
                          labelText: 'File từ vựng',
                        ),
                        items: _files
                            .map(
                              (filename) => DropdownMenuItem(
                                value: filename,
                                child: Text(filename),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: (value) {
                          if (value != null) _load(preferredFile: value);
                        },
                      ),
                      const SizedBox(height: 10),
                      Text('${_lines.length} từ • ${_filePath ?? ''}'),
                      const SizedBox(height: 10),
                      AppTextButton(
                        label: 'Thêm từ vào file đang xem',
                        compact: true,
                        onPressed: _addVocabulary,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (_lines.isEmpty)
                  const AppSection(
                    child: Text(
                      'File chưa có từ vựng. Hãy thêm thủ công hoặc dùng Gemini trong đề thi.',
                      textAlign: TextAlign.center,
                    ),
                  )
                else
                  AppSection(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Nội dung file',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 12),
                        for (var index = 0; index < _lines.length; index++) ...[
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.bookmark_rounded,
                                color: AppColors.red,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: HighlightableText(
                                  text: _lines[index],
                                  highlightKey:
                                      'vocabulary/${_selectedFile ?? ''}/${_lines[index]}',
                                  onAddVocabulary: _addSelectedText,
                                ),
                              ),
                            ],
                          ),
                          if (index != _lines.length - 1)
                            const Divider(height: 18),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
    );
  }

  Future<void> _addSelectedText(String text) async {
    await _showAddDialog(initialWord: text);
  }

  Future<void> _addVocabulary() async {
    await _showAddDialog();
  }

  Future<void> _showAddDialog({String initialWord = ''}) async {
    final result = await showVocabularyDialog(
      context,
      settings: widget.settings,
      initialWord: initialWord,
      initialFilename: _selectedFile,
    );
    if (!mounted || result == null) return;
    await _load(preferredFile: result.filename);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.added
              ? 'Đã lưu "${result.word}" vào ${result.filename}.'
              : '"${result.word}" đã có trong ${result.filename}.',
        ),
      ),
    );
  }
}
