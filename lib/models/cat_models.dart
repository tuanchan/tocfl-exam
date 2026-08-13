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
      skill == CatSkill.reading && readingCompletionRatio < 1;

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

  CatQuestion nextQuestion() {
    if (_available.isEmpty) {
      throw StateError('Kho câu hỏi CAT đã hết.');
    }

    _available.sort(
      (left, right) => (left.difficulty - ability).abs().compareTo(
        (right.difficulty - ability).abs(),
      ),
    );
    final candidateCount = min(18, _available.length);
    final candidates = _available.take(candidateCount).toList(growable: false);
    final selected = candidates[_random.nextInt(candidates.length)];
    _available.remove(selected);
    return selected;
  }

  void recordAnswer(CatQuestion question, String? selectedAnswer) {
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
    if (presentedCount >= 40 || _available.isEmpty) return true;
    if (presentedCount < 25 || _recentAbilities.length < 6) return false;
    final spread = _recentAbilities.reduce(max) - _recentAbilities.reduce(min);
    return standardError <= 24 && spread <= 32;
  }

  CatSkillResult result() {
    final rawScore = ability.round().clamp(0, 700).toInt();
    final completionRatio = skill == CatSkill.reading && answeredCount < 25
        ? answeredCount / 25
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

    // Mỗi tài liệu chỉ góp một câu cho một lượt CAT. Nhờ vậy người thi không
    // gặp lại cùng PDF/audio nhiều lần, nhưng câu con được chọn ngẫu nhiên.
    final childIndex = generator.nextInt(document.answers.length);
    pool.add(
      CatQuestion(
        document: document,
        childIndex: childIndex,
        difficulty: _estimatedItemDifficulty(document, childIndex, skill),
      ),
    );
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
