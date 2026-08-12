import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:just_audio/just_audio.dart';
import 'package:pdfrx/pdfrx.dart';

import '../core/app_theme.dart';
import '../models/tocfl_models.dart';
import '../services/catalog_service.dart';
import '../services/gemini_service.dart';
import '../services/progress_store.dart';
import '../services/settings_store.dart';
import '../widgets/highlightable_text.dart';
import '../widgets/vocabulary_dialog.dart';

class ExamPage extends StatefulWidget {
  const ExamPage({
    super.key,
    required this.documents,
    required this.settings,
    required this.progress,
    this.questionIds,
  });

  final List<ExamDocument> documents;
  final SettingsStore settings;
  final ProgressStore progress;
  final Set<String>? questionIds;

  @override
  State<ExamPage> createState() => _ExamPageState();
}

class _ExamPageState extends State<ExamPage> {
  final Map<String, String> _selectedAnswers = {};
  final Set<String> _recorded = {};
  final Set<String> _revealedAnswers = {};
  int _documentIndex = 0;
  bool _showTranscript = false;
  bool _analyzing = false;
  bool _gradingCurrentDocument = false;
  String? _pdfFile;
  String? _audioFile;
  String? _transcriptFile;
  GeminiAnalysis? _analysis;
  String? _assetError;

  ExamDocument get _document => widget.documents[_documentIndex];

  List<int> _questionIndexes(ExamDocument document) =>
      List.generate(document.questionCount, (index) => index)
          .where((index) {
            final selectedIds = widget.questionIds;
            return selectedIds == null ||
                selectedIds.contains('${document.id}#$index');
          })
          .toList(growable: false);

  @override
  void initState() {
    super.initState();
    _loadDocumentAssets();
  }

  Future<void> _loadDocumentAssets() async {
    final document = _document;
    setState(() {
      _pdfFile = null;
      _audioFile = null;
      _transcriptFile = null;
      _analysis = null;
      _assetError = null;
      _showTranscript = false;
    });
    try {
      final location = AssetLocationService(widget.settings);
      final values = await Future.wait([
        location.resolve(document.pdfPath),
        location.resolve(document.audioPath),
        location.resolve(document.transcriptPath),
        GeminiService(widget.settings).load(document.id),
      ]);
      if (!mounted || document.id != _document.id) return;
      setState(() {
        _pdfFile = values[0] as String?;
        _audioFile = values[1] as String?;
        _transcriptFile = values[2] as String?;
        _analysis = values[3] as GeminiAnalysis?;
        if (_pdfFile == null) {
          _assetError =
              'Chưa có file đề trên thiết bị. Hãy tải cấp ${document.levelCode} trong Cài đặt.';
        }
      });
    } catch (error) {
      if (mounted) setState(() => _assetError = error.toString());
    }
  }

  String _questionId(int childIndex) => '${_document.id}#$childIndex';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(
          tooltip: 'Quay lại',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: Text('${_document.levelCode} • ${_document.sectionName}'),
        actions: [
          IconButton(
            tooltip: 'Danh sách câu hỏi',
            onPressed: _showDocumentList,
            icon: SvgPicture.asset(
              'assets/list-solid-full.svg',
              width: 22,
              height: 22,
              colorFilter: ColorFilter.mode(
                Theme.of(context).colorScheme.onSurface,
                BlendMode.srcIn,
              ),
              semanticsLabel: 'Danh sách câu hỏi',
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _assetError != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(_assetError!, textAlign: TextAlign.center),
                    ),
                  )
                : _pdfFile == null
                ? const Center(child: CircularProgressIndicator())
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final wide = constraints.maxWidth >= 900;
                      return wide
                          ? Row(
                              children: [
                                Expanded(flex: 3, child: _pdfPanel()),
                                Expanded(
                                  flex: 2,
                                  child: ListView(
                                    padding: const EdgeInsets.fromLTRB(
                                      12,
                                      8,
                                      16,
                                      28,
                                    ),
                                    children: [
                                      _practiceContent(includePdf: false),
                                    ],
                                  ),
                                ),
                              ],
                            )
                          : ListView(
                              padding: const EdgeInsets.fromLTRB(12, 8, 12, 28),
                              children: [_practiceContent(includePdf: true)],
                            );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _showDocumentList() async {
    final attemptedIndexes = <int>{};
    for (var index = 0; index < widget.documents.length; index++) {
      final document = widget.documents[index];
      final attempted = _questionIndexes(document)
          .map((child) => '${document.id}#$child')
          .any(
            (id) =>
                _selectedAnswers.containsKey(id) ||
                widget.progress.attemptedQuestionIds.contains(id),
          );
      if (attempted) attemptedIndexes.add(index);
    }
    final selectedIndex = await showDialog<int>(
      context: context,
      builder: (_) => _DocumentListDialog(
        documents: widget.documents,
        selectedIndex: _documentIndex,
        attemptedIndexes: attemptedIndexes,
      ),
    );
    if (!mounted || selectedIndex == null || selectedIndex == _documentIndex) {
      return;
    }
    setState(() => _documentIndex = selectedIndex);
    await _loadDocumentAssets();
  }

  Widget _pdfPanel({EdgeInsets? margin}) {
    // Đề đọc không có file transcript riêng. Khi bật nội dung Gemini, vẫn giữ
    // PDF đề và chỉ mở các khối phân tích ở phía dưới.
    final path = _showTranscript && _transcriptFile != null
        ? _transcriptFile
        : _pdfFile;
    return Container(
      margin: margin ?? const EdgeInsets.fromLTRB(12, 4, 6, 12),
      decoration: BoxDecoration(border: Border.all(color: AppColors.blue)),
      child: path == null
          ? const Center(child: Text('Không tìm thấy tài liệu.'))
          : _isRemoteLocation(path)
          ? _RemotePdfViewer(uri: Uri.parse(path), key: ValueKey(path))
          : PdfViewer.file(path, key: ValueKey(path)),
    );
  }

  Widget _practiceContent({required bool includePdf}) {
    final document = _document;
    final questionIndexes = _questionIndexes(document);
    final hasPendingAnswer = questionIndexes.any((index) {
      final id = _questionId(index);
      return _selectedAnswers[id] != null && !_revealedAnswers.contains(id);
    });
    final hasRevealedAnswer = questionIndexes.any(
      (index) => _revealedAnswers.contains(_questionId(index)),
    );
    final canRetry = hasRevealedAnswer && !hasPendingAnswer;
    final pdf = includePdf
        ? SizedBox(
            height: 460,
            child: _pdfPanel(margin: const EdgeInsets.only(bottom: 16)),
          )
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_audioFile != null) ...[
          AudioControl(key: ValueKey(_audioFile), source: _audioFile!),
          const SizedBox(height: 10),
        ],
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 4,
          runSpacing: 4,
          children: [
            if (_transcriptFile != null || _analysis != null)
              IconButton(
                tooltip: _showTranscript
                    ? 'Ẩn nội dung Gemini'
                    : _transcriptFile != null
                    ? 'Hiện script và nội dung Gemini'
                    : 'Hiện nội dung Gemini',
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints.tightFor(
                  width: 36,
                  height: 36,
                ),
                onPressed: () =>
                    setState(() => _showTranscript = !_showTranscript),
                icon: Icon(
                  _showTranscript
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  color: AppColors.blue,
                ),
              ),
            _ExamToolAction(
              label: _analyzing
                  ? 'Gemini đang phân tích'
                  : _analysis == null
                  ? 'Dịch và phân tích'
                  : 'Phân tích lại',
              foregroundColor: Theme.of(context).colorScheme.onSurface,
              icon: _analyzing
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
              onPressed: _analyzing ? null : _runGemini,
            ),
            _ExamToolAction(
              label: _gradingCurrentDocument
                  ? 'Đang chấm'
                  : canRetry
                  ? 'Làm lại'
                  : 'Chấm đáp án',
              foregroundColor: Theme.of(context).colorScheme.onSurface,
              icon: _gradingCurrentDocument
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      canRetry
                          ? Icons.refresh_rounded
                          : Icons.check_circle_outline_rounded,
                      size: 20,
                    ),
              onPressed: _gradingCurrentDocument
                  ? null
                  : canRetry
                  ? _retryCurrentDocument
                  : _gradeCurrentDocument,
            ),
          ],
        ),
        const SizedBox(height: 10),
        ?pdf,
        if (_showTranscript && _analysis?.transcript.isNotEmpty == true) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.blue.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Bản dịch tiếng Việt của script',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                HighlightableText(
                  text: _analysis!.transcript,
                  highlightKey: '${document.id}/transcript',
                  onAddVocabulary: _addSelectedVocabulary,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (_showTranscript && _analysis?.questions.isNotEmpty == true) ...[
          _scriptQuestionsPanel(),
          const SizedBox(height: 12),
        ],
        if (_showTranscript && _analysis?.vocabulary.isNotEmpty == true) ...[
          Container(
            decoration: BoxDecoration(
              color: AppColors.blue.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(6),
            ),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 8),
              title: Text(
                'Từ vựng Gemini (${_analysis!.vocabulary.length})',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              children: [
                for (
                  var index = 0;
                  index < _analysis!.vocabulary.length;
                  index++
                )
                  ListTile(
                    dense: true,
                    title: HighlightableText(
                      text: _analysis!.vocabulary[index].textLine,
                      highlightKey: '${document.id}/vocabulary/$index',
                      onAddVocabulary: _addSelectedVocabulary,
                    ),
                    trailing: IconButton(
                      tooltip: 'Thêm vào TXT',
                      onPressed: () =>
                          _addAnalysisVocabulary(_analysis!.vocabulary[index]),
                      icon: const Icon(Icons.add_rounded),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        for (final index in questionIndexes) ...[_question(index)],
        Row(
          children: [
            Expanded(
              child: AppTextButton(
                label: 'Câu trước',
                filled: true,
                onPressed: _documentIndex == 0 ? null : _previous,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: AppTextButton(
                label: _documentIndex == widget.documents.length - 1
                    ? 'Nộp bài'
                    : 'Câu tiếp',
                filled: true,
                danger: true,
                onPressed: _documentIndex == widget.documents.length - 1
                    ? _submit
                    : _next,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _scriptQuestionsPanel() {
    final questions = _analysis?.questions ?? const <AnalyzedQuestion>[];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.blue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Nguyên văn và nghĩa câu hỏi – đáp án',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          for (
            var questionIndex = 0;
            questionIndex < questions.length;
            questionIndex++
          ) ...[
            _scriptQuestionDetails(questionIndex, questions[questionIndex]),
            if (questionIndex < questions.length - 1)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Divider(
                  height: 1,
                  color: AppColors.blue.withValues(alpha: 0.20),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _scriptQuestionDetails(int questionIndex, AnalyzedQuestion question) {
    final questionText = question.question.trim();
    final questionMeaning = question.questionMeaning.trim();
    final allowedLabels = _document.answerOptions.toSet();
    final visibleAnswers = question.answers
        .where((answer) => allowedLabels.contains(answer.label))
        .toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Câu ${questionIndex + 1}',
          style: const TextStyle(
            color: AppColors.red,
            fontWeight: FontWeight.w900,
          ),
        ),
        if (questionText.isNotEmpty) ...[
          const SizedBox(height: 5),
          HighlightableText(
            text: questionText,
            highlightKey: '${_document.id}/script-question/$questionIndex/text',
            onAddVocabulary: _addSelectedVocabulary,
            style: const TextStyle(fontWeight: FontWeight.w700, height: 1.35),
          ),
        ],
        if (questionMeaning.isNotEmpty) ...[
          const SizedBox(height: 4),
          HighlightableText(
            text: 'Nghĩa câu hỏi: $questionMeaning',
            highlightKey:
                '${_document.id}/script-question/$questionIndex/meaning',
            onAddVocabulary: _addSelectedVocabulary,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
              height: 1.35,
            ),
          ),
        ],
        if (visibleAnswers.isNotEmpty) ...[
          const SizedBox(height: 8),
          for (final answer in visibleAnswers)
            if (answer.text.trim().isNotEmpty ||
                answer.meaning.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 7, left: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    HighlightableText(
                      text: answer.text.trim().isEmpty
                          ? answer.label
                          : '${answer.label}. ${answer.text.trim()}',
                      highlightKey:
                          '${_document.id}/script-question/$questionIndex/'
                          '${answer.label}/text',
                      onAddVocabulary: _addSelectedVocabulary,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        height: 1.35,
                      ),
                    ),
                    if (answer.meaning.trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      HighlightableText(
                        text: 'Nghĩa: ${answer.meaning.trim()}',
                        highlightKey:
                            '${_document.id}/script-question/$questionIndex/'
                            '${answer.label}/meaning',
                        onAddVocabulary: _addSelectedVocabulary,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
        ],
        if (question.explanation.trim().isNotEmpty) ...[
          const SizedBox(height: 3),
          HighlightableText(
            text: 'Giải thích: ${question.explanation.trim()}',
            highlightKey:
                '${_document.id}/script-question/$questionIndex/explanation',
            onAddVocabulary: _addSelectedVocabulary,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
              height: 1.35,
            ),
          ),
        ],
        if (questionText.isEmpty &&
            questionMeaning.isEmpty &&
            visibleAnswers.isEmpty &&
            question.explanation.trim().isEmpty)
          const Text('Gemini chưa đọc được nội dung câu hỏi này.'),
      ],
    );
  }

  Widget _question(int index) {
    final id = _questionId(index);
    final selected = _selectedAnswers[id];
    final submitted = _revealedAnswers.contains(id);
    final expected = index < _document.answers.length
        ? _document.answers[index]
        : '';

    Widget optionTile(String option) {
      return _Study4OptionTile(
        label: option,
        selected: selected == option,
        isCorrect: submitted && expected == option,
        isWrong: submitted && selected == option && expected != option,
        onTap: submitted
            ? null
            : () {
                setState(() => _selectedAnswers[id] = option);
                unawaited(widget.progress.markAttempted(id));
              },
      );
    }

    Widget options() => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final option in _document.answerOptions) optionTile(option),
      ],
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Study4QuestionBadge(
                number: index + 1,
                answered: selected != null,
                submitted: submitted,
                correct: submitted && selected == expected,
              ),
              const SizedBox(width: 12),
              Expanded(child: options()),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: AppColors.blue.withValues(alpha: 0.18), height: 1),
        ],
      ),
    );
  }

  Future<void> _runGemini() async {
    if (_pdfFile == null) return;
    setState(() => _analyzing = true);
    try {
      final analysis = await GeminiService(widget.settings).analyze(
        document: _document,
        pdfFile: _pdfFile!,
        transcriptFile: _transcriptFile,
      );
      if (mounted) {
        setState(() {
          _analysis = analysis;
          _showTranscript = true;
        });
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gemini lỗi: $error')));
      }
    } finally {
      if (mounted) setState(() => _analyzing = false);
    }
  }

  Future<void> _gradeCurrentDocument() async {
    final indexes = _questionIndexes(_document);
    final selectedIndexes = indexes
        .where((index) {
          final id = _questionId(index);
          return _selectedAnswers[id] != null && !_revealedAnswers.contains(id);
        })
        .toList(growable: false);
    if (selectedIndexes.isEmpty) {
      final alreadyGraded = indexes.any(
        (index) => _revealedAnswers.contains(_questionId(index)),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            alreadyGraded
                ? 'Các câu đã chọn trên tài liệu này đã được chấm.'
                : 'Hãy chọn đáp án trước khi chấm.',
          ),
        ),
      );
      return;
    }

    setState(() => _gradingCurrentDocument = true);
    var correct = 0;
    var wrong = 0;
    try {
      for (final index in selectedIndexes) {
        final id = _questionId(index);
        final selected = _selectedAnswers[id]!;
        final expected = index < _document.answers.length
            ? _document.answers[index]
            : '';
        final isCorrect = expected.isNotEmpty && selected == expected;
        if (!_recorded.contains(id)) {
          await widget.progress.recordAnswer(
            questionId: id,
            levelCode: _document.levelCode,
            correct: isCorrect,
          );
          _recorded.add(id);
        }
        _revealedAnswers.add(id);
        isCorrect ? correct++ : wrong++;
      }
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Đúng: $correct • Sai: $wrong')));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không chấm được đáp án: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _gradingCurrentDocument = false);
    }
  }

  void _retryCurrentDocument() {
    setState(() {
      for (final index in _questionIndexes(_document)) {
        final id = _questionId(index);
        _selectedAnswers.remove(id);
        _revealedAnswers.remove(id);
      }
    });
  }

  Future<void> _addSelectedVocabulary(String selectedText) async {
    await _showVocabularyDialog(initialWord: selectedText);
  }

  Future<void> _addAnalysisVocabulary(VocabularyEntry entry) async {
    await _showVocabularyDialog(
      initialWord: entry.word,
      initialMeaning: entry.meaning,
      initialPinyin: entry.pinyin,
    );
  }

  Future<void> _showVocabularyDialog({
    required String initialWord,
    String initialMeaning = '',
    String initialPinyin = '',
  }) async {
    final result = await showVocabularyDialog(
      context,
      settings: widget.settings,
      initialWord: initialWord,
      initialMeaning: initialMeaning,
      initialPinyin: initialPinyin,
    );
    if (!mounted || result == null) return;
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

  void _previous() {
    setState(() => _documentIndex--);
    _loadDocumentAssets();
  }

  void _next() {
    setState(() => _documentIndex++);
    _loadDocumentAssets();
  }

  Future<void> _submit() async {
    var correct = 0;
    var wrong = 0;
    for (final document in widget.documents) {
      for (final index in _questionIndexes(document)) {
        final id = '${document.id}#$index';
        final selected = _selectedAnswers[id];
        if (selected == null) continue;
        final expected = index < document.answers.length
            ? document.answers[index]
            : '';
        final isCorrect = expected.isNotEmpty && selected == expected;
        if (!_recorded.contains(id)) {
          await widget.progress.recordAnswer(
            questionId: id,
            levelCode: document.levelCode,
            correct: isCorrect,
          );
          _recorded.add(id);
        }
        _revealedAnswers.add(id);
        isCorrect ? correct++ : wrong++;
      }
    }
    if (!mounted) return;
    setState(() {});
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kết quả'),
        content: Text(
          'Đúng: $correct\nSai: $wrong\nChưa trả lời: ${_unansweredCount()}',
        ),
        actions: [
          AppTextButton(
            label: 'Đóng',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  int _unansweredCount() {
    final total = widget.documents.fold<int>(
      0,
      (sum, item) => sum + _questionIndexes(item).length,
    );
    return total - _selectedAnswers.length;
  }
}

class _DocumentListDialog extends StatelessWidget {
  const _DocumentListDialog({
    required this.documents,
    required this.selectedIndex,
    required this.attemptedIndexes,
  });

  final List<ExamDocument> documents;
  final int selectedIndex;
  final Set<int> attemptedIndexes;

  @override
  Widget build(BuildContext context) {
    final grouped = <String, List<int>>{};
    for (var index = 0; index < documents.length; index++) {
      grouped.putIfAbsent(documents[index].sectionName, () => []).add(index);
    }
    final height = MediaQuery.sizeOf(context).height * 0.76;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 28),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 350, maxHeight: height),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Danh sách câu hỏi',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.red,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${documents.length}',
                      style: const TextStyle(
                        color: AppColors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Đóng',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView(
                padding: const EdgeInsets.all(14),
                children: [
                  for (final group in grouped.entries) ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        group.key,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: group.value.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            mainAxisSpacing: 7,
                            crossAxisSpacing: 7,
                            childAspectRatio: 2.15,
                          ),
                      itemBuilder: (context, itemIndex) {
                        final index = group.value[itemIndex];
                        final active = index == selectedIndex;
                        final attempted = attemptedIndexes.contains(index);
                        final background = active
                            ? AppColors.attemptedYellow
                            : attempted
                            ? AppColors.blue
                            : AppColors.blue.withValues(alpha: 0.10);
                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => Navigator.of(context).pop(index),
                          child: Container(
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: background,
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(
                                color: active
                                    ? AppColors.red
                                    : AppColors.blue.withValues(alpha: 0.35),
                              ),
                            ),
                            child: Text(
                              _shortCode(documents[index], index),
                              style: TextStyle(
                                color: active
                                    ? AppColors.darkBlue
                                    : attempted
                                    ? AppColors.white
                                    : AppColors.blue,
                                fontSize: 12,
                                fontWeight: active || attempted
                                    ? FontWeight.w900
                                    : FontWeight.w600,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 14),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _shortCode(ExamDocument document, int index) {
    final digits = document.fileName.replaceAll(RegExp(r'\D'), '');
    if (digits.length >= 4) return digits.substring(digits.length - 4);
    return digits.isEmpty ? '${index + 1}' : digits;
  }
}

class _ExamToolAction extends StatelessWidget {
  const _ExamToolAction({
    required this.label,
    required this.onPressed,
    this.foregroundColor,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color? foregroundColor;
  final Widget? icon;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final color = (foregroundColor ?? AppColors.blue).withValues(
      alpha: enabled ? 1 : 0.38,
    );
    return Semantics(
      button: true,
      enabled: enabled,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 32),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  IconTheme(
                    data: IconThemeData(color: color),
                    child: icon!,
                  ),
                  const SizedBox(width: 8),
                ],
                Text(
                  label,
                  style: TextStyle(color: color, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Study4QuestionBadge extends StatelessWidget {
  const _Study4QuestionBadge({
    required this.number,
    required this.answered,
    required this.submitted,
    required this.correct,
  });

  final int number;
  final bool answered;
  final bool submitted;
  final bool correct;

  @override
  Widget build(BuildContext context) {
    final resultColor = correct ? const Color(0xFF168445) : AppColors.red;
    final background = submitted
        ? resultColor.withValues(alpha: 0.13)
        : answered
        ? AppColors.blue
        : AppColors.blue.withValues(alpha: 0.14);
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        shape: BoxShape.circle,
        border: submitted ? Border.all(color: resultColor, width: 1.4) : null,
      ),
      child: Text(
        '$number',
        style: TextStyle(
          color: submitted
              ? resultColor
              : answered
              ? AppColors.white
              : AppColors.blue,
          fontSize: 15,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _Study4OptionTile extends StatelessWidget {
  const _Study4OptionTile({
    required this.label,
    required this.selected,
    required this.isCorrect,
    required this.isWrong,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool isCorrect;
  final bool isWrong;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final correctColor = const Color(0xFF168445);
    final background = isCorrect
        ? const Color(0xFFE3F5E9)
        : isWrong
        ? const Color(0xFFFFE5E7)
        : selected
        ? AppColors.blue.withValues(alpha: 0.10)
        : Colors.transparent;
    final iconColor = isCorrect
        ? correctColor
        : isWrong
        ? AppColors.red
        : selected
        ? AppColors.blue
        : const Color(0xFF6B7280);
    final textColor = isCorrect
        ? correctColor
        : isWrong
        ? AppColors.red
        : Theme.of(context).colorScheme.onSurface;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(4),
          border: isCorrect || isWrong
              ? Border.all(color: iconColor.withValues(alpha: 0.65))
              : null,
        ),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: iconColor,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: textColor,
                  fontSize: 14,
                  height: 1.35,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AudioControl extends StatefulWidget {
  const AudioControl({super.key, required this.source});

  final String source;

  @override
  State<AudioControl> createState() => _AudioControlState();
}

class _RemotePdfViewer extends StatefulWidget {
  const _RemotePdfViewer({super.key, required this.uri});

  final Uri uri;

  @override
  State<_RemotePdfViewer> createState() => _RemotePdfViewerState();
}

class _RemotePdfViewerState extends State<_RemotePdfViewer> {
  late final Future<Uint8List> _bytes = _download();

  Future<Uint8List> _download() async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 20);
    try {
      final request = await client.getUrl(widget.uri);
      request.headers.set(HttpHeaders.acceptHeader, 'application/pdf');
      final response = await request.close();
      if (response.statusCode < HttpStatus.ok ||
          response.statusCode >= HttpStatus.multipleChoices) {
        throw HttpException(
          'Không tải được PDF: HTTP ${response.statusCode}',
          uri: widget.uri,
        );
      }
      final builder = BytesBuilder(copy: false);
      await response
          .forEach(builder.add)
          .timeout(const Duration(seconds: 90));
      final bytes = builder.takeBytes();
      if (bytes.isEmpty) {
        throw HttpException('PDF không có dữ liệu', uri: widget.uri);
      }
      return bytes;
    } finally {
      client.close(force: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: _bytes,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Không mở được PDF: ${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        final bytes = snapshot.data;
        if (bytes == null) {
          return const Center(child: CircularProgressIndicator());
        }
        return PdfViewer.data(
          bytes,
          sourceName: widget.uri.pathSegments.last,
          key: ValueKey(widget.uri),
        );
      },
    );
  }
}

class _AudioControlState extends State<AudioControl> {
  final AudioPlayer _player = AudioPlayer();
  double _speed = 1;
  bool _muted = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      if (_isRemoteLocation(widget.source)) {
        await _player.setUrl(widget.source);
      } else {
        await _player.setFilePath(widget.source);
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) return Text('Không mở được âm thanh: $_error');
    return Container(
      height: 48,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: AppColors.blue.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          StreamBuilder<bool>(
            stream: _player.playingStream,
            initialData: false,
            builder: (context, snapshot) => IconButton(
              tooltip: snapshot.data == true ? 'Tạm dừng' : 'Phát',
              onPressed: snapshot.data == true ? _player.pause : _player.play,
              icon: Icon(
                snapshot.data == true
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                color: AppColors.blue,
                size: 28,
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<Duration>(
              stream: _player.positionStream,
              initialData: Duration.zero,
              builder: (context, snapshot) {
                final position = snapshot.data ?? Duration.zero;
                final duration = _player.duration ?? Duration.zero;
                final max = duration.inMilliseconds <= 0
                    ? 1.0
                    : duration.inMilliseconds.toDouble();
                final value = position.inMilliseconds
                    .clamp(0, max.toInt())
                    .toDouble();
                return Row(
                  children: [
                    Expanded(
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 4,
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 6,
                          ),
                          overlayShape: SliderComponentShape.noOverlay,
                        ),
                        child: Slider(
                          value: value,
                          max: max,
                          onChanged: duration == Duration.zero
                              ? null
                              : (next) => _player.seek(
                                  Duration(milliseconds: next.round()),
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${_time(position)} / ${_time(duration)}',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ],
                );
              },
            ),
          ),
          IconButton(
            tooltip: _muted ? 'Bật tiếng' : 'Tắt tiếng',
            onPressed: _toggleMute,
            icon: Icon(
              _muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
              color: const Color(0xFF4B5D78),
              size: 21,
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Tinh chỉnh âm thanh',
            icon: const Icon(
              Icons.settings_rounded,
              color: Color(0xFF4B5D78),
              size: 21,
            ),
            onSelected: _handleAudioAction,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'stop',
                child: Text('Dừng và quay về đầu'),
              ),
              const PopupMenuDivider(),
              for (final speed in const [0.75, 1.0, 1.25, 1.5])
                PopupMenuItem(
                  value: 'speed:$speed',
                  child: Row(
                    children: [
                      Icon(
                        _speed == speed
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        size: 16,
                        color: AppColors.blue,
                      ),
                      const SizedBox(width: 8),
                      Text('${speed}x'),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _toggleMute() async {
    final next = !_muted;
    await _player.setVolume(next ? 0 : 1);
    if (mounted) setState(() => _muted = next);
  }

  Future<void> _handleAudioAction(String action) async {
    if (action == 'stop') {
      await _player.pause();
      await _player.seek(Duration.zero);
      return;
    }
    final value = double.tryParse(action.replaceFirst('speed:', ''));
    if (value == null) return;
    await _player.setSpeed(value);
    if (mounted) setState(() => _speed = value);
  }

  String _time(Duration value) {
    final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

bool _isRemoteLocation(String value) {
  final uri = Uri.tryParse(value);
  return uri != null && (uri.scheme == 'https' || uri.scheme == 'http');
}
