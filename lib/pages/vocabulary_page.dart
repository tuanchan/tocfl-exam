import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../core/app_toast.dart';
import '../models/tocfl_models.dart';
import '../services/settings_store.dart';
import '../services/vocabulary_store.dart';
import '../widgets/highlightable_text.dart';
import '../widgets/vocabulary_dialog.dart';

enum _VocabularyFileAction { open, delete }

class VocabularyPage extends StatefulWidget {
  const VocabularyPage({super.key, required this.settings});

  final SettingsStore settings;

  @override
  State<VocabularyPage> createState() => _VocabularyPageState();
}

class _VocabularyPageState extends State<VocabularyPage> {
  static const _filesPerPage = 5;
  static const _wordsPerPage = 5;

  final VocabularyStore _store = VocabularyStore();
  final GlobalKey _wordPageStartKey = GlobalKey();
  List<VocabularyFileInfo> _files = const [];
  List<String> _lines = const [];
  String? _selectedFile;
  String? _error;
  bool _loading = true;
  int _filePage = 0;
  int _wordPage = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({
    String? preferredFile,
    bool showLastWordPage = false,
  }) async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final files = await _store.listFileInfos();
      final recent =
          preferredFile ?? _selectedFile ?? await _store.lastFilename();
      final normalized = _store.normalizeFilename(recent);
      final selected = files.firstWhere(
        (file) => file.filename.toLowerCase() == normalized.toLowerCase(),
        orElse: () => files.first,
      );
      final lines = await _store.readLines(selected.filename);
      await _store.selectFile(selected.filename);
      final selectedIndex = files.indexOf(selected);
      final selectedFileChanged = selected.filename != _selectedFile;
      final lastWordPage = lines.isEmpty
          ? 0
          : (lines.length - 1) ~/ _wordsPerPage;
      final nextWordPage = showLastWordPage
          ? lastWordPage
          : selectedFileChanged
          ? 0
          : _wordPage.clamp(0, lastWordPage);
      if (!mounted) return;
      setState(() {
        _files = files;
        _selectedFile = selected.filename;
        _lines = lines;
        _filePage = selectedIndex ~/ _filesPerPage;
        _wordPage = nextWordPage;
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
                        Expanded(child: ListView(children: _contentWidgets())),
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
          Expanded(child: SingleChildScrollView(child: _fileTable())),
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
            _fileTable(),
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
        Text('${_files.length} file • chọn một dòng để mở'),
      ],
    );
  }

  Widget _fileTable() {
    final pageCount = (_files.length / _filesPerPage).ceil().clamp(1, 999999);
    final currentPage = _filePage.clamp(0, pageCount - 1);
    final start = currentPage * _filesPerPage;
    final end = (start + _filesPerPage).clamp(0, _files.length);
    final visibleFiles = _files.sublist(start, end);
    final mutedColor = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.62);

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.blue.withValues(alpha: 0.38)),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Column(
        children: [
          Container(
            color: AppColors.blue.withValues(alpha: 0.09),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            child: const Row(
              children: [
                Expanded(
                  child: Text(
                    'TÊN FILE / CẬP NHẬT',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
                  ),
                ),
                SizedBox(
                  width: 45,
                  child: Text(
                    'TỪ',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
                  ),
                ),
                SizedBox(
                  width: 62,
                  child: Text(
                    'CỠ FILE',
                    textAlign: TextAlign.right,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
                  ),
                ),
                SizedBox(width: 34),
              ],
            ),
          ),
          for (var index = 0; index < visibleFiles.length; index++) ...[
            _fileTableRow(visibleFiles[index], mutedColor),
            if (index < visibleFiles.length - 1)
              Divider(height: 1, color: AppColors.blue.withValues(alpha: 0.18)),
          ],
          Divider(height: 1, color: AppColors.blue.withValues(alpha: 0.28)),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 4, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${start + 1}–$end/${_files.length} • 5 dòng/trang',
                    style: TextStyle(fontSize: 12, color: mutedColor),
                  ),
                ),
                IconButton(
                  tooltip: 'Trang trước',
                  visualDensity: VisualDensity.compact,
                  onPressed: currentPage == 0
                      ? null
                      : () => setState(() => _filePage = currentPage - 1),
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                Text(
                  '${currentPage + 1}/$pageCount',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                IconButton(
                  tooltip: 'Trang sau',
                  visualDensity: VisualDensity.compact,
                  onPressed: currentPage >= pageCount - 1
                      ? null
                      : () => setState(() => _filePage = currentPage + 1),
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _fileTableRow(VocabularyFileInfo file, Color mutedColor) {
    final selected = file.filename == _selectedFile;
    return Semantics(
      button: true,
      selected: selected,
      label: 'Mở file ${file.filename}',
      child: Material(
        color: selected
            ? AppColors.blue.withValues(alpha: 0.13)
            : Colors.transparent,
        child: InkWell(
          onTap: () => _load(preferredFile: file.filename),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.description_outlined,
                            size: 17,
                            color: selected ? AppColors.blue : mutedColor,
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              file.filename,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: selected ? AppColors.blue : null,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        file.exists
                            ? _formatFileDate(file.modifiedAt!)
                            : 'Chưa tạo trên thiết bị',
                        style: TextStyle(fontSize: 11, color: mutedColor),
                      ),
                      if (selected)
                        const Padding(
                          padding: EdgeInsets.only(top: 3),
                          child: Text(
                            'ĐANG MỞ',
                            style: TextStyle(
                              color: AppColors.blue,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 45,
                  child: Text(
                    '${file.wordCount}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                SizedBox(
                  width: 62,
                  child: Text(
                    _formatFileSize(file.sizeInBytes),
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                SizedBox(
                  width: 34,
                  height: 34,
                  child: PopupMenuButton<_VocabularyFileAction>(
                    tooltip: 'Thao tác với ${file.filename}',
                    padding: EdgeInsets.zero,
                    iconSize: 20,
                    onSelected: (action) {
                      if (action == _VocabularyFileAction.open) {
                        _load(preferredFile: file.filename);
                      } else {
                        _deleteFile(file);
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: _VocabularyFileAction.open,
                        child: ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.folder_open_outlined),
                          title: Text('Mở file'),
                        ),
                      ),
                      PopupMenuItem(
                        value: _VocabularyFileAction.delete,
                        enabled: file.exists,
                        child: const ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            Icons.delete_outline_rounded,
                            color: AppColors.red,
                          ),
                          title: Text(
                            'Xóa file',
                            style: TextStyle(color: AppColors.red),
                          ),
                        ),
                      ),
                    ],
                    icon: Icon(
                      Icons.more_vert_rounded,
                      color: selected ? AppColors.blue : mutedColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    final kilobytes = bytes / 1024;
    if (kilobytes < 1024) {
      return '${kilobytes.toStringAsFixed(kilobytes < 10 ? 1 : 0)} KB';
    }
    return '${(kilobytes / 1024).toStringAsFixed(1)} MB';
  }

  String _formatFileDate(DateTime value) {
    String two(int number) => number.toString().padLeft(2, '0');
    return '${two(value.day)}/${two(value.month)}/${value.year} '
        '${two(value.hour)}:${two(value.minute)}';
  }

  List<Widget> _contentWidgets() {
    final pageCount = _lines.isEmpty
        ? 1
        : ((_lines.length - 1) ~/ _wordsPerPage) + 1;
    final currentPage = _wordPage.clamp(0, pageCount - 1);
    final start = currentPage * _wordsPerPage;
    final end = (start + _wordsPerPage).clamp(0, _lines.length);
    return [
      if (_lines.isEmpty)
        const AppSection(
          child: Text(
            'File chưa có từ vựng. Hãy thêm thủ công hoặc chọn từ trong đề thi.',
            textAlign: TextAlign.center,
          ),
        )
      else ...[
        _wordPaginationBar(
          currentPage: currentPage,
          pageCount: pageCount,
          start: start,
          end: end,
          top: true,
        ),
        const SizedBox(height: 10),
        for (var index = start; index < end; index++) ...[
          _entryCard(index, _store.parseLine(_lines[index])),
          if (index < end - 1) const SizedBox(height: 10),
        ],
        const SizedBox(height: 10),
        _wordPaginationBar(
          currentPage: currentPage,
          pageCount: pageCount,
          start: start,
          end: end,
          top: false,
        ),
      ],
      const SizedBox(height: 16),
    ];
  }

  Widget _wordPaginationBar({
    required int currentPage,
    required int pageCount,
    required int start,
    required int end,
    required bool top,
  }) {
    return AppSection(
      key: top ? _wordPageStartKey : null,
      padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${start + 1}–$end/${_lines.length} từ • 5 từ/trang',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
          IconButton(
            tooltip: 'Trang từ vựng trước',
            visualDensity: VisualDensity.compact,
            onPressed: currentPage == 0
                ? null
                : () => _changeWordPage(currentPage - 1),
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          Text(
            '${currentPage + 1}/$pageCount',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          IconButton(
            tooltip: 'Trang từ vựng sau',
            visualDensity: VisualDensity.compact,
            onPressed: currentPage >= pageCount - 1
                ? null
                : () => _changeWordPage(currentPage + 1),
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
    );
  }

  void _changeWordPage(int page) {
    setState(() => _wordPage = page);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final targetContext = _wordPageStartKey.currentContext;
      if (targetContext == null) return;
      Scrollable.ensureVisible(
        targetContext,
        alignment: 0.02,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    });
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
    await _load(
      preferredFile: result.filename,
      showLastWordPage: result.action == VocabularySaveAction.added,
    );
    if (!mounted) return;
    _showSaveResult(result);
  }

  Future<void> _editVocabulary(int index, VocabularyEntry entry) async {
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

  Future<void> _deleteVocabulary(int index, VocabularyEntry entry) async {
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

  Future<void> _deleteFile(VocabularyFileInfo file) async {
    final filename = file.filename;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xóa file TXT?'),
        content: Text(
          'Xóa toàn bộ file $filename và ${file.wordCount} từ bên trong? Hành động này không thể hoàn tác.',
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
      if (filename == _selectedFile) _selectedFile = null;
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
