import 'dart:math';

import 'tocfl_models.dart';

enum CatSkill {
  listening,
  reading;

  String get label => this == CatSkill.listening ? 'Nghe' : 'Đọc';
}

class CatQuestion {
  const CatQuestion({
    required this.document,
    required this.childIndex,
    required this.difficulty,
  });

  final ExamDocument document;
  final int childIndex;
  final double difficulty;

  String get id => '${document.id}#$childIndex';
  String get correctAnswer => document.answers[childIndex];

  /// Nhóm nội dung dùng để tránh phát liên tiếp quá nhiều câu cùng dạng.
  /// `sectionName` được ưu tiên vì cùng một dạng có thể mang mã phần khác nhau
  /// giữa các Band.
  String get contentCategory {
    final sectionName = document.sectionName.trim().toLowerCase();
    final section = sectionName.isEmpty
        ? 'section-${document.sectionCode}'
        : sectionName;
    return '${document.skill}:$section';
  }
}

class CatQuestionBlock {
  CatQuestionBlock(Iterable<CatQuestion> values)
    : questions = List.unmodifiable(values) {
    if (questions.isEmpty) {
      throw ArgumentError.value(values, 'values', 'Cụm câu hỏi CAT rỗng');
    }
    final documentId = questions.first.document.id;
    if (questions.any((question) => question.document.id != documentId)) {
      throw ArgumentError.value(
        values,
        'values',
        'Một cụm CAT chỉ được chứa câu hỏi của cùng một tài liệu',
      );
    }
  }

  final List<CatQuestion> questions;

  ExamDocument get document => questions.first.document;
  String get contentCategory => questions.first.contentCategory;
  int get questionCount => questions.length;
  double get difficulty =>
      questions.fold(0.0, (sum, question) => sum + question.difficulty) /
      questionCount;
}

class CatAnswerRecord {
  const CatAnswerRecord({
    required this.question,
    required this.selectedAnswer,
    required this.abilityAfterAnswer,
  });

  final CatQuestion question;
  final String? selectedAnswer;
  final double abilityAfterAnswer;

  bool get answered => selectedAnswer != null;
  bool get correct => selectedAnswer == question.correctAnswer;
}

class CatSkillResult {
  const CatSkillResult({
    required this.skill,
    required this.score,
    required this.unadjustedScore,
    required this.presentedCount,
    required this.answeredCount,
    required this.correctCount,
    required this.standardError,
    required this.readingCompletionRatio,
  });

  final CatSkill skill;
  final int score;
  final int unadjustedScore;
  final int presentedCount;
  final int answeredCount;
  final int correctCount;
  final double standardError;
  final double readingCompletionRatio;

  bool get readingPenaltyApplied =>
      skill == CatSkill.reading &&
      answeredCount > 0 &&
      readingCompletionRatio < 1;

  String get reportLevel => CatScoreRules.singleSkillLevel(skill, score);
}

class CatCertificateLevel {
  const CatCertificateLevel({
    required this.name,
    required this.shortName,
    required this.totalMinimum,
    this.listeningMinimum,
    this.readingMinimum,
  });

  final String name;
  final String shortName;
  final int totalMinimum;
  final int? listeningMinimum;
  final int? readingMinimum;

  bool qualifies({required int listening, required int reading}) {
    return listening + reading >= totalMinimum &&
        (listeningMinimum == null || listening >= listeningMinimum!) &&
        (readingMinimum == null || reading >= readingMinimum!);
  }
}

abstract final class CatScoreRules {
  static const certificateLevels = <CatCertificateLevel>[
    CatCertificateLevel(
      name: 'Level 6 / Band C (C2)',
      shortName: 'C2',
      totalMinimum: 1345,
      listeningMinimum: 620,
      readingMinimum: 655,
    ),
    CatCertificateLevel(
      name: 'Level 5 / Band C (C1)',
      shortName: 'C1',
      totalMinimum: 1210,
      listeningMinimum: 580,
      readingMinimum: 585,
    ),
    CatCertificateLevel(
      name: 'Level 4 / Band B (B2)',
      shortName: 'B2',
      totalMinimum: 1125,
      listeningMinimum: 515,
      readingMinimum: 530,
    ),
    CatCertificateLevel(
      name: 'Level 3 / Band B (B1)',
      shortName: 'B1',
      totalMinimum: 970,
      listeningMinimum: 460,
      readingMinimum: 470,
    ),
    CatCertificateLevel(
      name: 'Level 2 / Band A (A2)',
      shortName: 'A2',
      totalMinimum: 885,
      listeningMinimum: 395,
      readingMinimum: 415,
    ),
    CatCertificateLevel(
      name: 'Level 1 / Band A (A1)',
      shortName: 'A1',
      totalMinimum: 710,
      listeningMinimum: 335,
      readingMinimum: 340,
    ),
    CatCertificateLevel(
      name: 'Novice 2 / Band Novice',
      shortName: 'Novice 2',
      totalMinimum: 600,
    ),
    CatCertificateLevel(
      name: 'Novice 1 / Band Novice',
      shortName: 'Novice 1',
      totalMinimum: 385,
    ),
  ];

  static CatCertificateLevel? certificateFor({
    required int listening,
    required int reading,
  }) {
    for (final level in certificateLevels) {
      if (level.qualifies(listening: listening, reading: reading)) {
        return level;
      }
    }
    return null;
  }

  static String singleSkillLevel(CatSkill skill, int score) {
    final thresholds = skill == CatSkill.listening
        ? const <(int, String)>[
            (655, 'Level 6 / C2'),
            (600, 'Level 5 / C1'),
            (555, 'Level 4 / B2'),
            (480, 'Level 3 / B1'),
            (435, 'Level 2 / A2'),
            (355, 'Level 1 / A1'),
            (295, 'Novice 2'),
            (190, 'Novice 1'),
          ]
        : const <(int, String)>[
            (690, 'Level 6 / C2'),
            (610, 'Level 5 / C1'),
            (570, 'Level 4 / B2'),
            (490, 'Level 3 / B1'),
            (450, 'Level 2 / A2'),
            (355, 'Level 1 / A1'),
            (305, 'Novice 2'),
            (195, 'Novice 1'),
          ];
    for (final threshold in thresholds) {
      if (score >= threshold.$1) return threshold.$2;
    }
    return 'Chưa đạt Novice 1';
  }
}

class CatEngine {
  static const int minimumQuestionCount = 25;
  static const int maximumQuestionCount = 40;

  // Chỉ cân bằng dạng câu trong vùng vẫn phù hợp với năng lực hiện tại. Nhờ
  // vậy content balancing không kéo thí sinh về một câu quá dễ hoặc quá khó.
  static const double _adaptiveWindow = 70;
  static const double _randomizationWindow = 14;

  CatEngine({
    required this.skill,
    required List<CatQuestion> questions,
    Random? random,
  }) : _available = List.of(questions),
       _random = random ?? Random.secure() {
    if (_available.isEmpty) {
      throw ArgumentError.value(questions, 'questions', 'Kho câu hỏi CAT rỗng');
    }
  }

  final CatSkill skill;
  final List<CatQuestion> _available;
  final Random _random;
  final List<CatAnswerRecord> answers = [];
  final List<double> _recentAbilities = [];

  double ability = 420;
  double standardError = 220;

  int get presentedCount => answers.length;
  int get answeredCount => answers.where((answer) => answer.answered).length;
  int get correctCount => answers.where((answer) => answer.correct).length;
  int get remainingQuestionCount => _available.length;

  bool hasRecordedAnswer(String questionId) {
    return answers.any((answer) => answer.question.id == questionId);
  }

  CatQuestionBlock nextQuestionBlock() {
    if (_available.isEmpty) {
      throw StateError('Kho câu hỏi CAT đã hết.');
    }

    final questionsByDocument = <String, List<CatQuestion>>{};
    for (final question in _available) {
      questionsByDocument
          .putIfAbsent(question.document.id, () => <CatQuestion>[])
          .add(question);
    }
    final remainingCapacity = maximumQuestionCount - presentedCount;
    final blocks = questionsByDocument.values
        .where((questions) => questions.length <= remainingCapacity)
        .map((questions) {
          questions.sort(
            (left, right) => left.childIndex.compareTo(right.childIndex),
          );
          return CatQuestionBlock(questions);
        })
        .toList(growable: false);
    if (blocks.isEmpty) {
      throw StateError(
        'Không còn cụm câu hỏi nào vừa giới hạn $maximumQuestionCount câu.',
      );
    }

    double distance(CatQuestionBlock block) =>
        (block.difficulty - ability).abs();

    blocks.sort((left, right) => distance(left).compareTo(distance(right)));

    // Bước 1: tạo vùng câu hỏi thích ứng quanh năng lực Rasch hiện tại.
    final nearestDistance = distance(blocks.first);
    final adaptiveCandidates = blocks
        .where((block) => distance(block) <= nearestDistance + _adaptiveWindow)
        .toList(growable: false);

    // Bước 2: trong vùng trên, ưu tiên dạng câu đã xuất hiện ít nhất. Cả Nghe
    // và Đọc đều dùng cùng nguyên tắc này nhưng có các nhóm section riêng.
    final exposureByCategory = <String, int>{};
    for (final answer in answers) {
      exposureByCategory.update(
        answer.question.contentCategory,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
    }
    final minimumExposure = adaptiveCandidates
        .map((block) => exposureByCategory[block.contentCategory] ?? 0)
        .reduce(min);
    final balancedCandidates =
        adaptiveCandidates
            .where(
              (block) =>
                  (exposureByCategory[block.contentCategory] ?? 0) ==
                  minimumExposure,
            )
            .toList(growable: false)
          ..sort((left, right) => distance(left).compareTo(distance(right)));

    // Bước 3: ngẫu nhiên nhẹ giữa các câu gần tương đương để mỗi lượt thi khác
    // nhau nhưng vẫn không phá vỡ độ khó mà IRT vừa ước lượng.
    final bestBalancedDistance = distance(balancedCandidates.first);
    final finalists = balancedCandidates
        .where(
          (block) =>
              distance(block) <= bestBalancedDistance + _randomizationWindow,
        )
        .toList(growable: false);
    final selected = finalists[_random.nextInt(finalists.length)];

    // Một PDF/audio là một cụm ngữ liệu. Phát toàn bộ câu con đúng như Excel
    // nguồn rồi loại cụm đó khỏi ngân hàng của lượt thi hiện tại.
    _available.removeWhere(
      (question) => question.document.id == selected.document.id,
    );
    return selected;
  }

  CatQuestion nextQuestion() => nextQuestionBlock().questions.first;

  void recordAnswer(CatQuestion question, String? selectedAnswer) {
    if (hasRecordedAnswer(question.id)) {
      throw StateError('Câu hỏi ${question.id} đã được ghi nhận.');
    }
    _appendAnswer(question, selectedAnswer);
  }

  void reviseAnswer(CatQuestion question, String? selectedAnswer) {
    final answerIndex = answers.indexWhere(
      (answer) => answer.question.id == question.id,
    );
    if (answerIndex == -1) {
      throw StateError('Câu hỏi ${question.id} chưa được ghi nhận.');
    }

    final revisedAnswers = <(CatQuestion, String?)>[
      for (var index = 0; index < answers.length; index++)
        (
          answers[index].question,
          index == answerIndex ? selectedAnswer : answers[index].selectedAnswer,
        ),
    ];

    answers.clear();
    _recentAbilities.clear();
    ability = 420;
    standardError = 220;
    for (final answer in revisedAnswers) {
      _appendAnswer(answer.$1, answer.$2);
    }
  }

  void _appendAnswer(CatQuestion question, String? selectedAnswer) {
    final provisional = CatAnswerRecord(
      question: question,
      selectedAnswer: selectedAnswer,
      abilityAfterAnswer: ability,
    );
    final allAnswers = [...answers, provisional];
    final estimate = _estimate(allAnswers);
    ability = estimate.$1;
    standardError = estimate.$2;
    answers.add(
      CatAnswerRecord(
        question: question,
        selectedAnswer: selectedAnswer,
        abilityAfterAnswer: ability,
      ),
    );
    _recentAbilities.add(ability);
    if (_recentAbilities.length > 6) _recentAbilities.removeAt(0);
  }

  bool get shouldStop {
    if (presentedCount >= maximumQuestionCount || _available.isEmpty) {
      return true;
    }
    final remainingCapacity = maximumQuestionCount - presentedCount;
    final remainingDocumentSizes = <String, int>{};
    for (final question in _available) {
      remainingDocumentSizes.update(
        question.document.id,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
    }
    if (!remainingDocumentSizes.values.any(
      (questionCount) => questionCount <= remainingCapacity,
    )) {
      return true;
    }
    if (presentedCount < minimumQuestionCount || _recentAbilities.length < 6) {
      return false;
    }
    final spread = _recentAbilities.reduce(max) - _recentAbilities.reduce(min);
    return standardError <= 24 && spread <= 32;
  }

  CatSkillResult result() {
    // IRT always has an initial ability estimate, but that estimate is not an
    // earned score. A skill with no selected answer must therefore score zero.
    final rawScore = answeredCount == 0
        ? 0
        : ability.round().clamp(0, 700).toInt();
    final completionRatio =
        skill == CatSkill.reading && answeredCount < minimumQuestionCount
        ? answeredCount / minimumQuestionCount
        : 1.0;
    final adjustedScore = (rawScore * completionRatio)
        .round()
        .clamp(0, 700)
        .toInt();
    return CatSkillResult(
      skill: skill,
      score: adjustedScore,
      unadjustedScore: rawScore,
      presentedCount: presentedCount,
      answeredCount: answeredCount,
      correctCount: correctCount,
      standardError: standardError,
      readingCompletionRatio: completionRatio,
    );
  }

  (double, double) _estimate(List<CatAnswerRecord> values) {
    const step = 2;
    final logWeights = <double>[];
    var maximum = double.negativeInfinity;

    for (var score = 0; score <= 700; score += step) {
      final priorZ = (score - 420) / 220;
      var logWeight = -0.5 * priorZ * priorZ;
      for (final answer in values) {
        final probability = _probability(
          score.toDouble(),
          answer.question.difficulty,
        );
        logWeight += answer.correct ? log(probability) : log(1 - probability);
      }
      logWeights.add(logWeight);
      maximum = max(maximum, logWeight);
    }

    var totalWeight = 0.0;
    var weightedScore = 0.0;
    for (var index = 0; index < logWeights.length; index++) {
      final weight = exp(logWeights[index] - maximum);
      final score = index * step.toDouble();
      totalWeight += weight;
      weightedScore += weight * score;
    }
    final mean = weightedScore / totalWeight;

    var weightedVariance = 0.0;
    for (var index = 0; index < logWeights.length; index++) {
      final weight = exp(logWeights[index] - maximum);
      final score = index * step.toDouble();
      weightedVariance += weight * pow(score - mean, 2);
    }
    return (mean, sqrt(weightedVariance / totalWeight));
  }

  double _probability(double score, double difficulty) {
    final exponent = ((score - difficulty) / 65).clamp(-12.0, 12.0);
    return 1 / (1 + exp(-exponent));
  }
}

List<CatQuestion> buildCatQuestionPool(
  TocflCatalog catalog,
  CatSkill skill, {
  Random? random,
}) {
  final generator = random ?? Random.secure();
  final pool = <CatQuestion>[];
  for (final document in catalog.items) {
    final matchesSkill = skill == CatSkill.listening
        ? document.isListening
        : !document.isListening;
    if (!matchesSkill || document.answers.isEmpty) continue;

    // Đưa toàn bộ câu con vào ngân hàng. CatEngine sẽ chọn câu phù hợp nhất rồi
    // loại các câu còn lại của cùng PDF/audio khỏi lượt thi hiện tại.
    for (
      var childIndex = 0;
      childIndex < document.answers.length;
      childIndex++
    ) {
      pool.add(
        CatQuestion(
          document: document,
          childIndex: childIndex,
          difficulty: _estimatedItemDifficulty(document, childIndex, skill),
        ),
      );
    }
  }
  pool.shuffle(generator);
  return pool;
}

double _estimatedItemDifficulty(
  ExamDocument document,
  int childIndex,
  CatSkill skill,
) {
  // Catalog công khai không kèm tham số Rasch chính thức của từng câu. Các mốc
  // dưới đây đặt câu vào vùng điểm của Band tương ứng; nhiễu xác định chỉ giúp
  // tránh coi mọi câu trong cùng Band là khó như nhau.
  final centers = skill == CatSkill.listening
      ? const {'01': 242.0, '02': 395.0, '03': 518.0, '04': 625.0}
      : const {'01': 250.0, '02': 402.0, '03': 530.0, '04': 645.0};
  final section = int.tryParse(document.sectionCode) ?? 1;
  var hash = 17;
  for (final value in '${document.id}#$childIndex'.codeUnits) {
    hash = (hash * 31 + value) & 0x7fffffff;
  }
  final jitter = (hash % 57) - 28;
  final sectionOffset = (section - 1) * 4;
  return ((centers[document.levelCode] ?? 420) + jitter + sectionOffset)
      .clamp(80, 700)
      .toDouble();
}
