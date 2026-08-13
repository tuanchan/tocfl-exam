import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_theme.dart';
import '../models/cat_models.dart';
import '../models/tocfl_models.dart';
import '../services/catalog_service.dart';
import '../services/settings_store.dart';

class CatHomePage extends StatelessWidget {
  const CatHomePage({super.key, required this.catalog, required this.settings});

  final TocflCatalog catalog;
  final SettingsStore settings;

  @override
  Widget build(BuildContext context) {
    final listeningCount = catalog.items
        .where((item) => item.isListening)
        .length;
    final readingCount = catalog.items
        .where((item) => !item.isListening)
        .length;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Thi CAT mô phỏng',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        const Text(
          'Làm trọn hai kỹ năng Nghe và Đọc. Câu sau được chọn quanh mức năng '
          'lực đang ước lượng và cân bằng giữa các dạng câu trong kho đề.',
        ),
        const SizedBox(height: 16),
        AppSection(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Thể lệ áp dụng',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              const _RuleLine(
                text:
                    'Mỗi kỹ năng khoảng 25–40 câu; hệ thống có thể kết thúc khi đã ước lượng đủ ổn định.',
              ),
              const _RuleLine(
                text:
                    'Nghe khoảng 50 phút; Đọc 60 phút. Sau khi âm thanh kết thúc có 10 giây để xác nhận đáp án.',
              ),
              const _RuleLine(
                text:
                    'Phần Nghe không thể quay lại sau khi xác nhận. Phần Đọc ở chế độ luyện tập cho phép quay lại, đổi đáp án và đánh dấu xem lại.',
              ),
              const _RuleLine(
                text:
                    'Đọc trả lời dưới 25 câu sẽ bị điều chỉnh điểm theo tỷ lệ số câu đã trả lời/25.',
              ),
              Text(
                'Kho hiện có: $listeningCount tài liệu Nghe và $readingCount tài liệu Đọc.',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        AppSection(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Ngưỡng cấp chứng chỉ CAT',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              for (final level in CatScoreRules.certificateLevels)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    level.listeningMinimum == null
                        ? '${level.shortName}: tổng ≥ ${level.totalMinimum}'
                        : '${level.shortName}: tổng ≥ ${level.totalMinimum} • '
                              'Nghe ≥ ${level.listeningMinimum} • '
                              'Đọc ≥ ${level.readingMinimum}',
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        AppSection(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Giới hạn của bài mô phỏng',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              const Text(
                'TOCFL không công bố tham số Rasch/IRT của từng câu trong bộ '
                'tài liệu này. App dùng mức Band của tài liệu làm độ khó neo và '
                'ước lượng Rasch kết hợp cân bằng dạng câu để luyện tập. Điểm '
                '0–700 là điểm mô phỏng, không phải điểm thi hoặc chứng chỉ '
                'chính thức.',
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  AppTextButton(
                    label: 'Thể lệ CAT chính thức',
                    compact: true,
                    onPressed: () => _openOfficialSource(
                      context,
                      'https://tocfl.edu.tw/tocfl/index.php/test/cat/list/5',
                    ),
                  ),
                  AppTextButton(
                    label: 'Bảng điểm chứng chỉ',
                    compact: true,
                    onPressed: () => _openOfficialSource(
                      context,
                      'https://tocfl.edu.tw/tocfl/index.php/sign_up/rule/list/1',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AppTextButton(
          label: 'Bắt đầu thi CAT',
          filled: true,
          expand: true,
          onPressed: catalog.items.isEmpty
              ? null
              : () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        CatExamPage(catalog: catalog, settings: settings),
                  ),
                ),
        ),
      ],
    );
  }

  Future<void> _openOfficialSource(BuildContext context, String value) async {
    final opened = await launchUrl(
      Uri.parse(value),
      mode: LaunchMode.externalApplication,
    );
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không mở được trang thể lệ chính thức.')),
      );
    }
  }
}

class _RuleLine extends StatelessWidget {
  const _RuleLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text('• $text'),
  );
}

class CatExamPage extends StatefulWidget {
  const CatExamPage({super.key, required this.catalog, required this.settings});

  final TocflCatalog catalog;
  final SettingsStore settings;

  @override
  State<CatExamPage> createState() => _CatExamPageState();
}

class _CatExamPageState extends State<CatExamPage> {
  static const int _maximumQuestionCount = CatEngine.maximumQuestionCount;

  final Random _random = Random.secure();
  late CatEngine _engine;
  CatQuestion? _question;
  CatQuestionBlock? _questionBlock;
  CatSkill _skill = CatSkill.listening;
  CatSkillResult? _listeningResult;
  CatSkillResult? _readingResult;
  Timer? _timer;
  int _secondsLeft = 50 * 60;
  int? _listeningAnswerSeconds;
  String? _pdfFile;
  String? _audioFile;
  String? _assetError;
  bool _loadingAssets = true;
  bool _betweenSkills = false;
  bool _finished = false;
  bool _finishingSkill = false;
  bool _submittingAnswer = false;
  int _assetRequest = 0;
  final Map<String, String> _selectedAnswers = {};
  final List<CatQuestionBlock> _readingBlocks = [];
  final Set<String> _markedReadingQuestions = {};
  int _readingBlockIndex = 0;

  List<CatQuestion> get _readingQuestions => [
    for (final block in _readingBlocks) ...block.questions,
  ];

  int get _currentBlockStartIndex {
    if (_skill != CatSkill.reading) return _engine.presentedCount;
    var result = 0;
    for (var index = 0; index < _readingBlockIndex; index++) {
      result += _readingBlocks[index].questionCount;
    }
    return result;
  }

  int get _currentQuestionNumber => _currentBlockStartIndex + 1;

  int get _currentQuestionEndNumber =>
      _currentBlockStartIndex + (_questionBlock?.questionCount ?? 1);

  int get _visibleQuestionCount => _skill == CatSkill.reading
      ? _readingQuestions.length
      : _engine.presentedCount + (_questionBlock?.questionCount ?? 0);

  @override
  void initState() {
    super.initState();
    _initializeSkill(CatSkill.listening, notify: false);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _initializeSkill(CatSkill skill, {bool notify = true}) {
    _timer?.cancel();
    final engine = CatEngine(
      skill: skill,
      questions: buildCatQuestionPool(widget.catalog, skill, random: _random),
      random: _random,
    );
    final block = engine.nextQuestionBlock();
    final question = block.questions.first;

    void assign() {
      _skill = skill;
      _engine = engine;
      _question = question;
      _questionBlock = block;
      _pdfFile = null;
      _audioFile = null;
      _assetError = null;
      _loadingAssets = true;
      _betweenSkills = false;
      _finishingSkill = false;
      _submittingAnswer = false;
      _listeningAnswerSeconds = null;
      _secondsLeft = skill == CatSkill.listening ? 50 * 60 : 60 * 60;
      _selectedAnswers.clear();
      _readingBlocks.clear();
      _markedReadingQuestions.clear();
      _readingBlockIndex = 0;
      if (skill == CatSkill.reading) {
        _readingBlocks.add(block);
      }
    }

    if (notify) {
      setState(assign);
    } else {
      assign();
    }
    unawaited(_loadQuestionAssets(question));
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    if (!mounted || _betweenSkills || _finished || _finishingSkill) return;
    if (_secondsLeft <= 1) {
      setState(() => _secondsLeft = 0);
      unawaited(_finishSkill(reason: 'Đã hết thời gian.'));
      return;
    }

    var autoSubmit = false;
    setState(() {
      _secondsLeft--;
      if (_listeningAnswerSeconds != null) {
        _listeningAnswerSeconds = _listeningAnswerSeconds! - 1;
        if (_listeningAnswerSeconds! <= 0) autoSubmit = true;
      }
    });
    if (autoSubmit) unawaited(_submitAnswer());
  }

  Future<void> _loadQuestionAssets(CatQuestion question) async {
    final request = ++_assetRequest;
    try {
      final location = AssetLocationService(widget.settings);
      final values = await Future.wait([
        location.resolve(question.document.pdfPath),
        location.resolve(question.document.audioPath),
      ]);
      if (!mounted ||
          request != _assetRequest ||
          _question?.id != question.id) {
        return;
      }
      setState(() {
        _pdfFile = values[0];
        _audioFile = values[1];
        _loadingAssets = false;
        if (_pdfFile == null) {
          _assetError = 'Không tìm thấy PDF của câu hỏi.';
        }
      });
    } catch (error) {
      if (!mounted || request != _assetRequest) return;
      setState(() {
        _assetError = error.toString();
        _loadingAssets = false;
      });
    }
  }

  void _audioCompleted() {
    if (!mounted || _skill != CatSkill.listening || _finishingSkill) return;
    setState(() => _listeningAnswerSeconds = 10);
  }

  void _selectAnswer(CatQuestion question, String answer) {
    if (_skill == CatSkill.reading) {
      if (_engine.hasRecordedAnswer(question.id)) {
        _engine.reviseAnswer(question, answer);
      }
    }
    setState(() => _selectedAnswers[question.id] = answer);
  }

  void _toggleReadingMark(CatQuestion question) {
    if (_skill != CatSkill.reading) return;
    setState(() {
      if (!_markedReadingQuestions.add(question.id)) {
        _markedReadingQuestions.remove(question.id);
      }
    });
  }

  Future<void> _showReadingBlock(int index) async {
    if (_skill != CatSkill.reading ||
        index < 0 ||
        index >= _readingBlocks.length ||
        index == _readingBlockIndex) {
      return;
    }

    final block = _readingBlocks[index];
    final question = block.questions.first;
    setState(() {
      _readingBlockIndex = index;
      _question = question;
      _questionBlock = block;
      _pdfFile = null;
      _audioFile = null;
      _assetError = null;
      _loadingAssets = true;
    });
    await _loadQuestionAssets(question);
  }

  int _readingBlockIndexForQuestion(int questionIndex) {
    var offset = 0;
    for (var blockIndex = 0; blockIndex < _readingBlocks.length; blockIndex++) {
      offset += _readingBlocks[blockIndex].questionCount;
      if (questionIndex < offset) return blockIndex;
    }
    return _readingBlocks.length - 1;
  }

  void _commitCurrentBlock() {
    final block = _questionBlock;
    if (block == null) return;
    for (final question in block.questions) {
      if (!_engine.hasRecordedAnswer(question.id)) {
        _engine.recordAnswer(question, _selectedAnswers[question.id]);
      }
    }
  }

  Future<void> _submitAnswer() async {
    final question = _question;
    final block = _questionBlock;
    if (question == null ||
        block == null ||
        _submittingAnswer ||
        _finishingSkill ||
        _finished ||
        _betweenSkills) {
      return;
    }

    if (_skill == CatSkill.reading &&
        _readingBlockIndex < _readingBlocks.length - 1) {
      await _showReadingBlock(_readingBlockIndex + 1);
      return;
    }

    _submittingAnswer = true;
    _commitCurrentBlock();
    if (_engine.shouldStop) {
      await _finishSkill(reason: 'Hệ thống đã ước lượng đủ ổn định.');
      _submittingAnswer = false;
      return;
    }

    final nextBlock = _engine.nextQuestionBlock();
    final next = nextBlock.questions.first;
    setState(() {
      if (_skill == CatSkill.reading) {
        _readingBlocks.add(nextBlock);
        _readingBlockIndex = _readingBlocks.length - 1;
      }
      _question = next;
      _questionBlock = nextBlock;
      _pdfFile = null;
      _audioFile = null;
      _assetError = null;
      _loadingAssets = true;
      _listeningAnswerSeconds = null;
    });
    _submittingAnswer = false;
    unawaited(_loadQuestionAssets(next));
  }

  Future<void> _finishSkill({required String reason}) async {
    if (_finishingSkill || _finished) return;
    _finishingSkill = true;
    _timer?.cancel();
    _assetRequest++;
    _commitCurrentBlock();
    final result = _engine.result();
    if (!mounted) return;

    if (_skill == CatSkill.listening) {
      setState(() {
        _listeningResult = result;
        _betweenSkills = true;
        _finishingSkill = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$reason Phần Nghe đã kết thúc.')));
    } else {
      setState(() {
        _readingResult = result;
        _finished = true;
        _finishingSkill = false;
      });
    }
  }

  Future<void> _confirmFinishEarly() async {
    final answered = _selectedAnswers.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Nộp phần ${_skill.label} sớm?'),
        content: Text(
          _skill == CatSkill.reading && answered < 25
              ? 'Bạn mới trả lời $answered câu. Điểm Đọc sẽ bị nhân tỷ lệ '
                    '$answered/25 theo quy tắc CAT.'
              : 'Các câu chưa làm không được tính. Bạn không thể quay lại sau khi nộp.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Tiếp tục làm'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Nộp sớm'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _finishSkill(reason: 'Bạn đã nộp sớm.');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_finished) return _resultPage();
    if (_betweenSkills) return _betweenSkillsPage();

    final question = _question!;
    final block = _questionBlock!;
    return Scaffold(
      appBar: AppBar(
        title: Text('CAT • ${_skill.label}'),
        actions: [
          TextButton(
            onPressed: _confirmFinishEarly,
            child: const Text('Nộp sớm'),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Column(
        children: [
          _statusBar(),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 900;
                if (wide) {
                  return Row(
                    children: [
                      Expanded(flex: 3, child: _documentPanel(question)),
                      Expanded(
                        flex: 2,
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(12, 12, 16, 24),
                          child: _answerPanel(block),
                        ),
                      ),
                    ],
                  );
                }
                return ListView(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                  children: [
                    SizedBox(height: 440, child: _documentPanel(question)),
                    const SizedBox(height: 12),
                    _answerPanel(block),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusBar() {
    final start = _currentQuestionNumber;
    final end = _currentQuestionEndNumber;
    final range = start == end ? '$start' : '$start–$end';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.blue.withValues(alpha: 0.3)),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Câu $range • khoảng 25–40 câu',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              Text(
                _formatTime(_secondsLeft),
                style: const TextStyle(
                  color: AppColors.red,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          LinearProgressIndicator(
            value: (_visibleQuestionCount / _maximumQuestionCount)
                .clamp(0, 1)
                .toDouble(),
            minHeight: 5,
            color: AppColors.blue,
            backgroundColor: AppColors.blue.withValues(alpha: 0.12),
          ),
        ],
      ),
    );
  }

  Widget _documentPanel(CatQuestion question) {
    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.blue),
        borderRadius: BorderRadius.circular(6),
      ),
      clipBehavior: Clip.antiAlias,
      child: _loadingAssets
          ? const Center(child: CircularProgressIndicator())
          : _assetError != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Text(_assetError!, textAlign: TextAlign.center),
              ),
            )
          : _pdfFile == null
          ? const Center(child: Text('Không có PDF.'))
          : _isRemoteLocation(_pdfFile!)
          ? _CatRemotePdfViewer(
              uri: Uri.parse(_pdfFile!),
              key: ValueKey(_pdfFile),
            )
          : PdfViewer.file(_pdfFile!, key: ValueKey(_pdfFile)),
    );
  }

  Widget _answerPanel(CatQuestionBlock block) {
    final document = block.document;
    final reading = _skill == CatSkill.reading;
    final hasKnownNext =
        reading && _readingBlockIndex < _readingBlocks.length - 1;
    final answeredInBlock = block.questions
        .where((question) => _selectedAnswers.containsKey(question.id))
        .length;
    final unansweredInBlock = block.questionCount - answeredInBlock;

    Widget questionOptions(CatQuestion question, int index) {
      final marked = _markedReadingQuestions.contains(question.id);
      final selectedAnswer = _selectedAnswers[question.id];
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _CatQuestionNumberBadge(
                  number: _currentQuestionNumber + index,
                  marked: marked,
                  onTap: reading ? () => _toggleReadingMark(question) : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final option in document.answerOptions) ...[
                        _CatOptionTile(
                          label: option,
                          selected: selectedAnswer == option,
                          onTap: () => _selectAnswer(question, option),
                        ),
                        const SizedBox(height: 7),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (index < block.questionCount - 1) ...[
              const SizedBox(height: 4),
              Divider(height: 1, color: AppColors.blue.withValues(alpha: 0.18)),
            ],
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_skill == CatSkill.listening && _audioFile != null) ...[
          _CatAudioPlayer(
            key: ValueKey('${document.id}/$_audioFile'),
            source: _audioFile!,
            onCompleted: _audioCompleted,
          ),
        ],
        if (_listeningAnswerSeconds != null) ...[
          const SizedBox(height: 10),
          Text(
            'Còn $_listeningAnswerSeconds giây để xác nhận',
            style: const TextStyle(
              color: AppColors.red,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
        const SizedBox(height: 16),
        Text(
          block.questionCount == 1
              ? 'Chọn một đáp án'
              : 'Chọn đáp án cho ${block.questionCount} câu trong ngữ liệu',
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 12),
        for (var index = 0; index < block.questions.length; index++)
          questionOptions(block.questions[index], index),
        const SizedBox(height: 8),
        if (reading) ...[
          Row(
            children: [
              Expanded(
                child: AppTextButton(
                  label: 'Câu trước',
                  onPressed: _readingBlockIndex == 0
                      ? null
                      : () => _showReadingBlock(_readingBlockIndex - 1),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AppTextButton(
                  label: hasKnownNext
                      ? 'Câu tiếp'
                      : unansweredInBlock > 0
                      ? 'Bỏ qua $unansweredInBlock câu và tiếp'
                      : 'Xác nhận và tiếp',
                  danger: !hasKnownNext && unansweredInBlock > 0,
                  filled: true,
                  onPressed: _submittingAnswer ? null : _submitAnswer,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _readingQuestionIndexBar(),
        ] else ...[
          AppTextButton(
            label: unansweredInBlock == 0
                ? 'Xác nhận và sang câu tiếp'
                : 'Xác nhận $answeredInBlock/${block.questionCount} câu và tiếp',
            filled: true,
            expand: true,
            onPressed: answeredInBlock == 0 ? null : _submitAnswer,
          ),
          const SizedBox(height: 8),
          AppTextButton(
            label: 'Bỏ qua cụm này (tính sai)',
            danger: true,
            expand: true,
            onPressed: _submitAnswer,
          ),
          const SizedBox(height: 10),
          const Text(
            'Các câu chưa chọn được tính sai. Sau khi sang cụm tiếp theo, bạn không thể quay lại.',
            style: TextStyle(fontSize: 12),
          ),
        ],
      ],
    );
  }

  Widget _readingQuestionIndexBar() {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border.all(color: AppColors.blue.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Danh sách câu hỏi',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          const Text(
            'Chú ý: chạm vào số tròn của câu hỏi để đánh dấu xem lại.',
            style: TextStyle(
              color: Color(0xFFFF9D22),
              fontSize: 13,
              height: 1.35,
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Đã làm ${_selectedAnswers.length}/$_maximumQuestionCount câu tối đa',
            style: TextStyle(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.68),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Đọc',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 7,
            runSpacing: 8,
            children: [
              for (var index = 0; index < _maximumQuestionCount; index++)
                _CatQuestionIndexButton(
                  number: index + 1,
                  current:
                      index >= _currentBlockStartIndex &&
                      index < _currentQuestionEndNumber,
                  answered: index < _readingQuestions.length
                      ? _selectedAnswers.containsKey(
                          _readingQuestions[index].id,
                        )
                      : false,
                  marked: index < _readingQuestions.length
                      ? _markedReadingQuestions.contains(
                          _readingQuestions[index].id,
                        )
                      : false,
                  onTap: index < _readingQuestions.length
                      ? () => _showReadingBlock(
                          _readingBlockIndexForQuestion(index),
                        )
                      : null,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _betweenSkillsPage() {
    return Scaffold(
      appBar: AppBar(title: const Text('CAT • Chuyển kỹ năng')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: AppSection(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Đã hoàn thành phần Nghe',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${_listeningResult!.presentedCount} câu đã hiển thị • '
                    '${_listeningResult!.answeredCount} câu đã trả lời',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Điểm sẽ được mở sau khi hoàn thành cả phần Đọc.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 18),
                  AppTextButton(
                    label: 'Bắt đầu phần Đọc',
                    filled: true,
                    expand: true,
                    onPressed: () => _initializeSkill(CatSkill.reading),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _resultPage() {
    final listening = _listeningResult!;
    final reading = _readingResult!;
    final total = listening.score + reading.score;
    final certificate = CatScoreRules.certificateFor(
      listening: listening.score,
      reading: reading.score,
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Kết quả CAT mô phỏng')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AppSection(
            child: Column(
              children: [
                Text(
                  certificate?.name ?? 'Chưa đạt ngưỡng chứng chỉ',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: certificate == null ? AppColors.red : AppColors.blue,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tổng điểm: $total / 1400',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _skillResultCard(listening),
          const SizedBox(height: 12),
          _skillResultCard(reading),
          if (reading.readingPenaltyApplied) ...[
            const SizedBox(height: 12),
            AppSection(
              child: Text(
                'Điểm Đọc gốc ${reading.unadjustedScore} đã được nhân '
                '${reading.answeredCount}/25 vì trả lời dưới 25 câu, còn ${reading.score} điểm.',
                style: const TextStyle(
                  color: AppColors.red,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          const AppSection(
            child: Text(
              'Kết quả này dùng Rasch/IRT mô phỏng trên mức Band của tài liệu. '
              'Nó giúp luyện chiến thuật CAT nhưng không thay thế kết quả do TOCFL cấp.',
            ),
          ),
          const SizedBox(height: 16),
          AppTextButton(
            label: 'Thi lại đề CAT ngẫu nhiên',
            filled: true,
            expand: true,
            onPressed: () {
              setState(() {
                _listeningResult = null;
                _readingResult = null;
                _finished = false;
              });
              _initializeSkill(CatSkill.listening);
            },
          ),
          const SizedBox(height: 8),
          AppTextButton(
            label: 'Về màn hình CAT',
            expand: true,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _skillResultCard(CatSkillResult result) {
    return AppSection(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  result.skill.label,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                '${result.score} / 700',
                style: const TextStyle(
                  color: AppColors.blue,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            result.reportLevel,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            '${result.correctCount}/${result.presentedCount} câu đúng • '
            '${result.answeredCount} câu có trả lời',
          ),
        ],
      ),
    );
  }

  String _formatTime(int totalSeconds) {
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

class _CatQuestionNumberBadge extends StatelessWidget {
  const _CatQuestionNumberBadge({
    required this.number,
    required this.marked,
    required this.onTap,
  });

  final int number;
  final bool marked;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = marked
        ? const Color(0xFFFF9D22)
        : AppColors.blue.withValues(alpha: 0.12);
    final badge = Container(
      width: 38,
      height: 38,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Text(
        '$number',
        style: TextStyle(
          color: marked ? AppColors.white : AppColors.blue,
          fontSize: 15,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
    if (onTap == null) return badge;
    return Tooltip(
      message: marked ? 'Bỏ đánh dấu xem lại' : 'Đánh dấu xem lại',
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: badge,
      ),
    );
  }
}

class _CatQuestionIndexButton extends StatelessWidget {
  const _CatQuestionIndexButton({
    required this.number,
    required this.current,
    required this.answered,
    required this.marked,
    required this.onTap,
  });

  final int number;
  final bool current;
  final bool answered;
  final bool marked;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final markedColor = const Color(0xFFFF9D22);
    final enabled = onTap != null;
    final background = current
        ? AppColors.blue
        : marked
        ? markedColor
        : answered
        ? AppColors.blue
        : AppColors.blue.withValues(alpha: enabled ? 0.06 : 0.025);
    final foreground = current || marked || answered
        ? AppColors.white
        : Theme.of(
            context,
          ).colorScheme.onSurface.withValues(alpha: enabled ? 0.82 : 0.36);
    final border = marked
        ? markedColor
        : current || answered
        ? AppColors.blue
        : AppColors.blue.withValues(alpha: enabled ? 0.35 : 0.12);

    return Semantics(
      button: true,
      enabled: enabled,
      selected: current,
      label: 'Câu $number${marked ? ', đã đánh dấu' : ''}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          width: 38,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: background,
            border: Border.all(color: border, width: current ? 2 : 1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            '$number',
            style: TextStyle(
              color: foreground,
              fontSize: 13,
              fontWeight: current || marked || answered
                  ? FontWeight.w900
                  : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _CatOptionTile extends StatelessWidget {
  const _CatOptionTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.blue.withValues(alpha: 0.13)
                : Colors.transparent,
            border: Border.all(
              color: selected
                  ? AppColors.blue
                  : AppColors.blue.withValues(alpha: 0.4),
              width: selected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? AppColors.blue : null,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

class _CatAudioPlayer extends StatefulWidget {
  const _CatAudioPlayer({
    super.key,
    required this.source,
    required this.onCompleted,
  });

  final String source;
  final VoidCallback onCompleted;

  @override
  State<_CatAudioPlayer> createState() => _CatAudioPlayerState();
}

class _CatAudioPlayerState extends State<_CatAudioPlayer> {
  final AudioPlayer _player = AudioPlayer();
  StreamSubscription<PlayerState>? _stateSubscription;
  bool _loaded = false;
  bool _completed = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _stateSubscription = _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed && !_completed) {
        _completed = true;
        widget.onCompleted();
        if (mounted) setState(() {});
      }
    });
    unawaited(_loadAndPlay());
  }

  Future<void> _loadAndPlay() async {
    try {
      if (_isRemoteLocation(widget.source)) {
        await _player.setUrl(widget.source);
      } else {
        await _player.setFilePath(widget.source);
      }
      if (!mounted) return;
      setState(() => _loaded = true);
      await _player.play();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  @override
  void dispose() {
    _stateSubscription?.cancel();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Text('Không phát được âm thanh: $_error');
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.blue.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            !_loaded
                ? 'Đang tải âm thanh…'
                : _completed
                ? 'Âm thanh đã phát xong'
                : 'Âm thanh đang tự động phát',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 7),
          StreamBuilder<Duration>(
            stream: _player.positionStream,
            initialData: Duration.zero,
            builder: (context, snapshot) {
              final position = snapshot.data ?? Duration.zero;
              final duration = _player.duration ?? Duration.zero;
              final progress = duration.inMilliseconds <= 0
                  ? 0.0
                  : position.inMilliseconds / duration.inMilliseconds;
              return LinearProgressIndicator(
                value: progress.clamp(0, 1).toDouble(),
                minHeight: 5,
                color: AppColors.red,
                backgroundColor: AppColors.blue.withValues(alpha: 0.15),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CatRemotePdfViewer extends StatefulWidget {
  const _CatRemotePdfViewer({super.key, required this.uri});

  final Uri uri;

  @override
  State<_CatRemotePdfViewer> createState() => _CatRemotePdfViewerState();
}

class _CatRemotePdfViewerState extends State<_CatRemotePdfViewer> {
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
      await response.forEach(builder.add).timeout(const Duration(seconds: 90));
      final bytes = builder.takeBytes();
      if (bytes.isEmpty) throw HttpException('PDF không có dữ liệu');
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

bool _isRemoteLocation(String value) {
  final uri = Uri.tryParse(value);
  return uri != null && (uri.scheme == 'https' || uri.scheme == 'http');
}
