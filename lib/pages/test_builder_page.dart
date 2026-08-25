import 'dart:math';

import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../core/app_toast.dart';
import '../models/tocfl_models.dart';
import '../services/created_test_store.dart';

class TestBuilderPage extends StatefulWidget {
  const TestBuilderPage({
    super.key,
    required this.catalog,
    required this.openExam,
  });

  final TocflCatalog catalog;
  final void Function(List<ExamDocument>, Set<String>?) openExam;

  @override
  State<TestBuilderPage> createState() => _TestBuilderPageState();
}

class _TestBuilderPageState extends State<TestBuilderPage> {
  final CreatedTestStore _testStore = CreatedTestStore();
  final TextEditingController _testNameController = TextEditingController();
  final Set<String> _levels = {'01'};
  bool _listening = true;
  bool _reading = true;
  bool _random = false;
  int _questionCount = 20;
  Set<String>? _manualQuestionIds;
  List<SavedPracticeTest> _savedTests = const [];
  bool _loadingSavedTests = true;

  @override
  void initState() {
    super.initState();
    _loadSavedTests();
  }

  @override
  void dispose() {
    _testNameController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedTests() async {
    try {
      final tests = await _testStore.load();
      final preferences = await _testStore.loadBuilderPreferences();
      if (!mounted) return;
      setState(() {
        _savedTests = tests;
        _levels
          ..clear()
          ..addAll(preferences.levels);
        _listening = preferences.listening;
        _reading = preferences.reading;
        _random = preferences.random;
        _questionCount = preferences.questionCount;
      });
    } finally {
      if (mounted) setState(() => _loadingSavedTests = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final available = _availableQuestions();
    final availableCount = available.length;
    final questionUsage = _questionUsage();
    final usedQuestionIds = questionUsage.keys.toSet();
    final unusedAvailableCount = available
        .where((question) => !usedQuestionIds.contains(question.id))
        .length;
    final usedAvailableCount = availableCount - unusedAvailableCount;
    final selectedManualCount = _manualQuestionIds == null
        ? 0
        : available
              .where((question) => _manualQuestionIds!.contains(question.id))
              .length;
    final selectedUsedCount = _manualQuestionIds == null
        ? 0
        : available
              .where(
                (question) =>
                    _manualQuestionIds!.contains(question.id) &&
                    usedQuestionIds.contains(question.id),
              )
              .length;
    final effectiveQuestionCount = unusedAvailableCount == 0
        ? 0
        : _questionCount.clamp(1, unusedAvailableCount).toInt();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Tạo đề luyện tập',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 16),
        AppSection(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Chọn cấp 01–04',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ['01', '02', '03', '04'].map((level) {
                  return AppTextButton(
                    label: 'Cấp $level',
                    selected: _levels.contains(level),
                    onPressed: () => setState(() {
                      _levels.contains(level)
                          ? _levels.remove(level)
                          : _levels.add(level);
                    }),
                  );
                }).toList(),
              ),
              const SizedBox(height: 18),
              const Text(
                'Kỹ năng',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  AppTextButton(
                    label: 'Nghe',
                    selected: _listening,
                    onPressed: () => setState(() => _listening = !_listening),
                  ),
                  AppTextButton(
                    label: 'Đọc',
                    selected: _reading,
                    danger: true,
                    onPressed: () => setState(() => _reading = !_reading),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              AppTextButton(
                label: _random ? 'Trộn câu ngẫu nhiên' : 'Theo thứ tự tài liệu',
                selected: _random,
                onPressed: () => setState(() => _random = !_random),
              ),
              const SizedBox(height: 18),
              Text(
                'Có $availableCount câu phù hợp với cấp và kỹ năng đã chọn.',
              ),
              if (_loadingSavedTests)
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text('Đang đối chiếu với các đề đã tạo...'),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    '$unusedAvailableCount câu chưa dùng • '
                    '$usedAvailableCount câu đã có trong đề trước.',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              const SizedBox(height: 10),
              if (_manualQuestionIds == null) ...[
                Text(
                  'Số câu chưa dùng trong đề mới: $effectiveQuestionCount',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                Slider(
                  value: effectiveQuestionCount.toDouble(),
                  min: unusedAvailableCount == 0 ? 0 : 1,
                  max: unusedAvailableCount == 0
                      ? 1
                      : unusedAvailableCount.toDouble(),
                  label: '$effectiveQuestionCount câu',
                  onChanged: unusedAvailableCount == 0 || _loadingSavedTests
                      ? null
                      : (value) => setState(() {
                          _questionCount = value.round();
                        }),
                ),
              ] else ...[
                Text(
                  'Đã chọn thủ công: $selectedManualCount câu'
                  '${selectedUsedCount == 0 ? '' : ' • $selectedUsedCount câu đã dùng'}',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 10),
              ],
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  AppTextButton(
                    label: _manualQuestionIds == null
                        ? 'Chọn từng câu'
                        : 'Sửa danh sách câu',
                    compact: true,
                    selected: _manualQuestionIds != null,
                    onPressed: availableCount == 0 || _loadingSavedTests
                        ? null
                        : () => _pickQuestions(available, questionUsage),
                  ),
                  if (_manualQuestionIds != null)
                    AppTextButton(
                      label: 'Dùng số lượng',
                      compact: true,
                      onPressed: () =>
                          setState(() => _manualQuestionIds = null),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _testNameController,
                maxLength: 80,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  labelText: 'Tên đề',
                  hintText:
                      'Để trống sẽ dùng tên: ${_testName(_manualQuestionIds == null ? effectiveQuestionCount : selectedManualCount)}',
                  prefixIcon: const Icon(
                    Icons.drive_file_rename_outline_rounded,
                  ),
                  counterText: '',
                ),
              ),
              const SizedBox(height: 12),
              AppTextButton(
                label: 'Tạo đề và bắt đầu',
                expand: true,
                onPressed: _loadingSavedTests ? null : _start,
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Danh sách đề đã tạo',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
            ),
            if (!_loadingSavedTests)
              Text(
                '${_savedTests.length} đề',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (_loadingSavedTests)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(18),
              child: CircularProgressIndicator(),
            ),
          )
        else if (_savedTests.isEmpty)
          const AppSection(
            child: Text(
              'Chưa có đề đã lưu. Mỗi lần bấm “Tạo đề và bắt đầu”, đề sẽ được thêm vào danh sách này.',
            ),
          )
        else
          for (final test in _savedTests) ...[
            AppSection(
              padding: EdgeInsets.zero,
              child: ListTile(
                contentPadding: const EdgeInsets.fromLTRB(14, 6, 4, 6),
                leading: const Icon(
                  Icons.assignment_outlined,
                  color: AppColors.blue,
                ),
                title: Text(
                  test.name,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  '${test.questionIds.length} câu • ${_formatDate(test.createdAt)}',
                ),
                onTap: () => _openSavedTest(test),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Đổi tên đề',
                      onPressed: () => _renameSavedTest(test),
                      icon: const Icon(
                        Icons.edit_outlined,
                        color: AppColors.blue,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Xóa đề',
                      onPressed: () => _deleteSavedTest(test),
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        color: AppColors.red,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
      ],
    );
  }

  List<_QuestionRef> _availableQuestions() {
    final result = <_QuestionRef>[];
    for (final document in widget.catalog.items) {
      if (!_levels.contains(document.levelCode) ||
          !((_listening && document.isListening) ||
              (_reading && !document.isListening))) {
        continue;
      }
      for (var index = 0; index < document.questionCount; index++) {
        result.add(_QuestionRef(document: document, childIndex: index));
      }
    }
    return result;
  }

  Map<String, List<SavedPracticeTest>> _questionUsage() {
    final usage = <String, List<SavedPracticeTest>>{};
    for (final test in _savedTests) {
      for (final questionId in test.questionIds.toSet()) {
        (usage[questionId] ??= []).add(test);
      }
    }
    return usage;
  }

  Future<void> _pickQuestions(
    List<_QuestionRef> available,
    Map<String, List<SavedPracticeTest>> questionUsage,
  ) async {
    final availableIds = available.map((question) => question.id).toSet();
    final selected = await showDialog<Set<String>>(
      context: context,
      builder: (_) => _QuestionPickerDialog(
        questions: available,
        usageByQuestion: questionUsage,
        initialSelection:
            _manualQuestionIds?.intersection(availableIds) ?? const {},
      ),
    );
    if (selected != null && mounted) {
      setState(() => _manualQuestionIds = selected);
    }
  }

  Future<void> _start() async {
    var questions = _availableQuestions();
    if (questions.isEmpty) {
      AppToast.show(
        context,
        'Hãy chọn ít nhất một cấp và một kỹ năng.',
        tone: AppToastTone.warning,
      );
      return;
    }
    if (_manualQuestionIds != null) {
      questions = questions
          .where((question) => _manualQuestionIds!.contains(question.id))
          .toList();
    } else {
      final usedQuestionIds = _questionUsage().keys;
      questions = questions
          .where((question) => !usedQuestionIds.contains(question.id))
          .toList();
      if (questions.isEmpty) {
        AppToast.show(
          context,
          'Tất cả câu phù hợp đã có trong đề trước. Hãy chọn từng câu nếu bạn muốn dùng lại.',
          tone: AppToastTone.warning,
        );
        return;
      }
      if (_random) questions.shuffle(Random.secure());
      questions = questions
          .take(_questionCount.clamp(1, questions.length).toInt())
          .toList();
    }
    if (questions.isEmpty) {
      AppToast.show(
        context,
        'Hãy chọn ít nhất một câu hỏi.',
        tone: AppToastTone.warning,
      );
      return;
    }
    if (_random && _manualQuestionIds != null) {
      questions.shuffle(Random.secure());
    }
    final documentsById = <String, ExamDocument>{};
    for (final question in questions) {
      documentsById.putIfAbsent(question.document.id, () => question.document);
    }
    final now = DateTime.now();
    final savedTest = SavedPracticeTest(
      id: now.microsecondsSinceEpoch.toString(),
      name: _testNameController.text.trim().isEmpty
          ? _testName(questions.length)
          : _testNameController.text.trim(),
      createdAt: now,
      questionIds: questions.map((question) => question.id).toList(),
    );
    final builderPreferences = TestBuilderPreferences(
      levels: (_levels.toList()..sort()),
      listening: _listening,
      reading: _reading,
      random: _random,
      questionCount: _questionCount,
    );
    try {
      await _testStore.saveBuilderPreferences(builderPreferences);
      final tests = await _testStore.save(savedTest);
      if (!mounted) return;
      _testNameController.clear();
      setState(() {
        _savedTests = tests;
        _manualQuestionIds = null;
      });
    } catch (error) {
      if (!mounted) return;
      AppToast.show(
        context,
        'Không lưu được đề hoặc cài đặt tạo đề: $error',
        tone: AppToastTone.error,
      );
      return;
    }
    widget.openExam(
      documentsById.values.toList(growable: false),
      questions.map((question) => question.id).toSet(),
    );
  }

  String _testName(int questionCount) {
    final levels = _levels.toList()..sort();
    final skill = _listening && _reading
        ? 'Nghe + Đọc'
        : _listening
        ? 'Nghe'
        : 'Đọc';
    return 'Cấp ${levels.join(', ')} • $skill • $questionCount câu';
  }

  void _openSavedTest(SavedPracticeTest test) {
    final documentsById = {
      for (final document in widget.catalog.items) document.id: document,
    };
    final selectedDocuments = <String, ExamDocument>{};
    final validQuestionIds = <String>[];
    for (final questionId in test.questionIds) {
      final separator = questionId.lastIndexOf('#');
      if (separator <= 0 || separator == questionId.length - 1) continue;
      final documentId = questionId.substring(0, separator);
      final childIndex = int.tryParse(questionId.substring(separator + 1));
      final document = documentsById[documentId];
      if (document == null ||
          childIndex == null ||
          childIndex < 0 ||
          childIndex >= document.questionCount) {
        continue;
      }
      selectedDocuments.putIfAbsent(document.id, () => document);
      validQuestionIds.add(questionId);
    }
    if (validQuestionIds.isEmpty) {
      AppToast.show(
        context,
        'Các câu trong đề này không còn trong dữ liệu hiện tại.',
        tone: AppToastTone.warning,
      );
      return;
    }
    widget.openExam(
      selectedDocuments.values.toList(),
      validQuestionIds.toSet(),
    );
  }

  Future<void> _renameSavedTest(SavedPracticeTest test) async {
    final controller = TextEditingController(text: test.name);
    controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: controller.text.length,
    );
    final formKey = GlobalKey<FormState>();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Đổi tên đề'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            maxLength: 80,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              labelText: 'Tên đề mới',
              prefixIcon: Icon(Icons.drive_file_rename_outline_rounded),
            ),
            validator: (value) => value?.trim().isEmpty == true
                ? 'Tên đề không được để trống.'
                : null,
            onFieldSubmitted: (value) {
              if (formKey.currentState?.validate() == true) {
                Navigator.of(dialogContext).pop(value.trim());
              }
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Hủy'),
          ),
          FilledButton.icon(
            onPressed: () {
              if (formKey.currentState?.validate() == true) {
                Navigator.of(dialogContext).pop(controller.text.trim());
              }
            },
            icon: const Icon(Icons.save_outlined),
            label: const Text('Lưu tên'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || !mounted || name == test.name) return;
    try {
      final tests = await _testStore.rename(test.id, name);
      if (mounted) setState(() => _savedTests = tests);
    } catch (error) {
      if (!mounted) return;
      AppToast.show(
        context,
        'Không đổi được tên đề: $error',
        tone: AppToastTone.error,
      );
    }
  }

  Future<void> _deleteSavedTest(SavedPracticeTest test) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xóa đề đã lưu?'),
        content: Text('Bạn muốn xóa “${test.name}”?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.red),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final tests = await _testStore.delete(test.id);
    if (mounted) setState(() => _savedTests = tests);
  }

  String _formatDate(DateTime value) {
    String two(int number) => number.toString().padLeft(2, '0');
    return '${two(value.day)}/${two(value.month)}/${value.year} '
        '${two(value.hour)}:${two(value.minute)}';
  }
}

class _QuestionRef {
  const _QuestionRef({required this.document, required this.childIndex});

  final ExamDocument document;
  final int childIndex;

  String get id => '${document.id}#$childIndex';
}

class _QuestionPickerDialog extends StatefulWidget {
  const _QuestionPickerDialog({
    required this.questions,
    required this.initialSelection,
    required this.usageByQuestion,
  });

  final List<_QuestionRef> questions;
  final Set<String> initialSelection;
  final Map<String, List<SavedPracticeTest>> usageByQuestion;

  @override
  State<_QuestionPickerDialog> createState() => _QuestionPickerDialogState();
}

class _QuestionPickerDialogState extends State<_QuestionPickerDialog> {
  late final Set<String> _selected;
  final TextEditingController _search = TextEditingController();
  String _query = '';
  bool _onlyUnused = true;

  @override
  void initState() {
    super.initState();
    _selected = Set<String>.from(widget.initialSelection);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<_QuestionRef> get _visible {
    final query = _query.trim().toLowerCase();
    return widget.questions
        .where((question) {
          if (_onlyUnused && _wasUsed(question.id)) return false;
          if (query.isEmpty) return true;
          final document = question.document;
          return document.fileName.toLowerCase().contains(query) ||
              document.sectionName.toLowerCase().contains(query) ||
              document.levelCode.contains(query) ||
              '${question.childIndex + 1}'.contains(query);
        })
        .toList(growable: false);
  }

  bool _wasUsed(String questionId) =>
      widget.usageByQuestion[questionId]?.isNotEmpty == true;

  String _usageLabel(List<SavedPracticeTest> tests) {
    const shownNameCount = 3;
    final names = tests
        .take(shownNameCount)
        .map((test) => test.name)
        .join(', ');
    final remaining = tests.length - shownNameCount;
    return 'Đã dùng trong: $names${remaining > 0 ? ' và $remaining đề khác' : ''}';
  }

  Future<void> _setQuestionSelected(
    _QuestionRef question,
    bool selected,
  ) async {
    if (!selected) {
      setState(() => _selected.remove(question.id));
      return;
    }
    final usedIn = widget.usageByQuestion[question.id] ?? const [];
    if (usedIn.isNotEmpty) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Câu này đã được dùng'),
          content: Text(
            '${_usageLabel(usedIn)}.\n\nBạn vẫn muốn chọn lại câu này?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Không chọn'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Vẫn chọn'),
            ),
          ],
        ),
      );
      if (!mounted || confirmed != true) return;
    }
    setState(() => _selected.add(question.id));
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
    final usedCount = widget.questions
        .where((question) => _wasUsed(question.id))
        .length;
    final unusedCount = widget.questions.length - usedCount;
    final visibleUnused = visible
        .where((question) => !_wasUsed(question.id))
        .toList(growable: false);
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 720),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Chọn từng câu (${_selected.length} đã chọn)',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Đóng',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _search,
                onChanged: (value) => setState(() => _query = value),
                decoration: const InputDecoration(
                  labelText: 'Tìm mã tài liệu, phần hoặc số câu',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '$unusedCount câu chưa dùng • $usedCount câu đã dùng',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    AppTextButton(
                      label: 'Chỉ hiện câu chưa dùng',
                      compact: true,
                      selected: _onlyUnused,
                      onPressed: () =>
                          setState(() => _onlyUnused = !_onlyUnused),
                    ),
                    AppTextButton(
                      label:
                          'Chọn ${visibleUnused.length} câu chưa dùng đang hiện',
                      compact: true,
                      onPressed: visibleUnused.isEmpty
                          ? null
                          : () => setState(
                              () => _selected.addAll(
                                visibleUnused.map((question) => question.id),
                              ),
                            ),
                    ),
                    AppTextButton(
                      label: 'Bỏ chọn tất cả',
                      compact: true,
                      danger: true,
                      onPressed: () => setState(_selected.clear),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: visible.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          _onlyUnused && unusedCount == 0
                              ? 'Không còn câu chưa dùng. Tắt bộ lọc để xem các câu đã có trong đề trước.'
                              : 'Không tìm thấy câu phù hợp.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: visible.length,
                      itemBuilder: (context, index) {
                        final question = visible[index];
                        final checked = _selected.contains(question.id);
                        final usedIn =
                            widget.usageByQuestion[question.id] ?? const [];
                        final wasUsed = usedIn.isNotEmpty;
                        return CheckboxListTile(
                          value: checked,
                          controlAffinity: ListTileControlAffinity.leading,
                          title: Text(
                            '${question.document.fileName} • Câu ${question.childIndex + 1}',
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Cấp ${question.document.levelCode} • '
                                '${question.document.isListening ? 'Nghe' : 'Đọc'} • '
                                '${question.document.sectionName}',
                              ),
                              const SizedBox(height: 3),
                              Text(
                                wasUsed
                                    ? _usageLabel(usedIn)
                                    : 'Chưa dùng trong đề nào',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: wasUsed
                                      ? AppColors.red
                                      : const Color(0xFF168445),
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                          secondary: Icon(
                            wasUsed
                                ? Icons.history_rounded
                                : Icons.fiber_new_rounded,
                            color: wasUsed
                                ? AppColors.red
                                : const Color(0xFF168445),
                          ),
                          tileColor: wasUsed
                              ? AppColors.red.withValues(alpha: 0.06)
                              : null,
                          onChanged: (value) =>
                              _setQuestionSelected(question, value == true),
                        );
                      },
                    ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Hủy'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: () => Navigator.of(context).pop(_selected),
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Dùng danh sách này'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
