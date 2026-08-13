import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../core/app_toast.dart';
import '../models/tocfl_models.dart';
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
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final files = await _store.listFiles();
      final recent =
          preferredFile ?? _selectedFile ?? await _store.lastFilename();
      final normalized = _store.normalizeFilename(recent);
      final selected = files.firstWhere(
        (filename) => filename.toLowerCase() == normalized.toLowerCase(),
        orElse: () => files.first,
      );
      final lines = await _store.readLines(selected);
      final filePath = await _store.filePath(selected);
      await _store.selectFile(selected);
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
        title: const Text('Danh sách từ vựng'),
        actions: [
          TextButton(onPressed: _addVocabulary, child: const Text('Thêm từ')),
          TextButton(
            onPressed: _loading ? null : _load,
            child: const Text('Tải lại'),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 14),
                    AppTextButton(label: 'Thử lại', onPressed: _load),
                  ],
                ),
              ),
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth >= 860) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 280,
                          height: constraints.maxHeight - 32,
                          child: _wideFileList(),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: ListView(children: _contentWidgets()),
                        ),
                      ],
                    ),
                  );
                }
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [_compactFileList(), ..._contentWidgets()],
                );
              },
            ),
    );
  }

  Widget _wideFileList() {
    return AppSection(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _fileListTitle(),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.separated(
              itemCount: _files.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (_, index) => _fileButton(_files[index]),
            ),
          ),
          const SizedBox(height: 12),
          AppTextButton(
            label: 'Tạo file TXT mới',
            expand: true,
            compact: true,
            onPressed: _createEmptyFile,
          ),
        ],
      ),
    );
  }

  Widget _compactFileList() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppSection(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _fileListTitle(),
            const SizedBox(height: 12),
            for (var index = 0; index < _files.length; index++) ...[
              _fileButton(_files[index]),
              if (index < _files.length - 1) const SizedBox(height: 8),
            ],
            const SizedBox(height: 12),
            AppTextButton(
              label: 'Tạo file TXT mới',
              expand: true,
              compact: true,
              onPressed: _createEmptyFile,
            ),
          ],
        ),
      ),
    );
  }

  Widget _fileListTitle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Các file TXT',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 4),
        Text('${_files.length} file • bấm tên file để mở'),
      ],
    );
  }

  Widget _fileButton(String filename) {
    return AppTextButton(
      label: filename,
      selected: filename == _selectedFile,
      expand: true,
      compact: true,
      onPressed: () => _load(preferredFile: filename),
    );
  }

  List<Widget> _contentWidgets() {
    return [
      AppSection(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _selectedFile ?? 'Chưa chọn file',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text('${_lines.length} từ • ${_filePath ?? ''}'),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                AppTextButton(
                  label: 'Thêm từ vào file này',
                  filled: true,
                  compact: true,
                  onPressed: _addVocabulary,
                ),
                AppTextButton(
                  label: 'Xóa file TXT',
                  danger: true,
                  compact: true,
                  onPressed: _selectedFile == null ? null : _deleteCurrentFile,
                ),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      if (_lines.isEmpty)
        const AppSection(
          child: Text(
            'File chưa có từ vựng. Hãy thêm thủ công hoặc chọn từ trong đề thi.',
            textAlign: TextAlign.center,
          ),
        )
      else
        for (var index = 0; index < _lines.length; index++) ...[
          _entryCard(index, _store.parseLine(_lines[index])),
          if (index < _lines.length - 1) const SizedBox(height: 10),
        ],
      const SizedBox(height: 16),
    ];
  }

  Widget _entryCard(int index, VocabularyEntry entry) {
    final rawLine = _lines[index];
    return AppSection(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.blue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    color: AppColors.blue,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    HighlightableText(
                      text: entry.word.isEmpty ? rawLine : entry.word,
                      highlightKey:
                          'vocabulary/${_selectedFile ?? ''}/$rawLine/word',
                      onAddVocabulary: _addSelectedText,
                    ),
                    if (entry.pinyin.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        entry.pinyin,
                        style: TextStyle(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.65),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                    if (entry.meaning.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      HighlightableText(
                        text: entry.meaning,
                        highlightKey:
                            'vocabulary/${_selectedFile ?? ''}/$rawLine/meaning',
                        onAddVocabulary: _addSelectedText,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              AppTextButton(
                label: 'Sửa',
                compact: true,
                onPressed: () => _editVocabulary(index, entry),
              ),
              AppTextButton(
                label: 'Xóa',
                danger: true,
                compact: true,
                onPressed: () => _deleteVocabulary(index, entry),
              ),
            ],
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
    _showSaveResult(result);
  }

  Future<void> _editVocabulary(
    int index,
    VocabularyEntry entry,
  ) async {
    final filename = _selectedFile;
    if (filename == null) return;
    final result = await showVocabularyDialog(
      context,
      settings: widget.settings,
      initialWord: entry.word,
      initialMeaning: entry.meaning,
      initialPinyin: entry.pinyin,
      initialFilename: filename,
      editingLineIndex: index,
    );
    if (!mounted || result == null) return;
    await _load(preferredFile: filename);
    if (!mounted) return;
    _showSaveResult(result);
  }

  void _showSaveResult(VocabularySaveResult result) {
    final message = switch (result.action) {
      VocabularySaveAction.added =>
        'Đã thêm "${result.word}" vào ${result.filename}.',
      VocabularySaveAction.updated =>
        'Đã cập nhật "${result.word}" trong ${result.filename}.',
      VocabularySaveAction.duplicate =>
        '"${result.word}" đã tồn tại trong ${result.filename}.',
    };
    AppToast.show(
      context,
      message,
      tone: result.action == VocabularySaveAction.duplicate
          ? AppToastTone.warning
          : AppToastTone.success,
    );
  }

  Future<void> _deleteVocabulary(
    int index,
    VocabularyEntry entry,
  ) async {
    final filename = _selectedFile;
    if (filename == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xóa từ vựng?'),
        content: Text(
          'Xóa "${entry.word.isEmpty ? _lines[index] : entry.word}" khỏi $filename?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await _store.deleteEntryAt(filename: filename, index: index);
      await _load(preferredFile: filename);
      if (!mounted) return;
      AppToast.show(
        context,
        'Đã xóa từ khỏi $filename.',
        tone: AppToastTone.success,
      );
    } catch (error) {
      if (mounted) {
        AppToast.show(
          context,
          'Không xóa được từ vựng: $error',
          tone: AppToastTone.error,
        );
      }
    }
  }

  Future<void> _createEmptyFile() async {
    final controller = TextEditingController();
    final rawName = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Tạo file TXT mới'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Tên file',
            hintText: 'chu_de_moi.txt',
          ),
          onSubmitted: (value) => Navigator.of(dialogContext).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: const Text('Tạo file'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (!mounted || rawName == null || rawName.trim().isEmpty) return;
    try {
      final filename = await _store.createFile(rawName);
      await _load(preferredFile: filename);
      if (!mounted) return;
      AppToast.show(
        context,
        'Đã tạo và mở file $filename.',
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
    }
  }

  Future<void> _deleteCurrentFile() async {
    final filename = _selectedFile;
    if (filename == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xóa file TXT?'),
        content: Text(
          'Xóa toàn bộ file $filename và ${_lines.length} từ bên trong? Hành động này không thể hoàn tác.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Xóa file'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      final deleted = await _store.deleteFile(filename);
      _selectedFile = null;
      await _load();
      if (!mounted) return;
      AppToast.show(
        context,
        deleted
            ? 'Đã xóa file $filename.'
            : 'File $filename chưa tồn tại trên thiết bị.',
        tone: deleted ? AppToastTone.success : AppToastTone.warning,
      );
    } catch (error) {
      if (mounted) {
        AppToast.show(
          context,
          'Không xóa được file TXT: $error',
          tone: AppToastTone.error,
        );
      }
    }
  }
}
