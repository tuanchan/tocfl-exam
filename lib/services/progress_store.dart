import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ReviewState {
  const ReviewState({
    required this.questionId,
    required this.level,
    required this.easeFactor,
    required this.intervalDays,
    required this.repetitionCount,
    required this.correctCount,
    required this.wrongCount,
    required this.lastReviewedAt,
    required this.nextReviewAt,
  });

  final String questionId;
  final int level;
  final double easeFactor;
  final int intervalDays;
  final int repetitionCount;
  final int correctCount;
  final int wrongCount;
  final DateTime? lastReviewedAt;
  final DateTime? nextReviewAt;

  factory ReviewState.fromJson(Map<String, dynamic> json) => ReviewState(
    questionId: json['questionId'].toString(),
    level: (json['level'] as num?)?.toInt() ?? 0,
    easeFactor: (json['easeFactor'] as num?)?.toDouble() ?? 2.5,
    intervalDays: (json['intervalDays'] as num?)?.toInt() ?? 0,
    repetitionCount: (json['repetitionCount'] as num?)?.toInt() ?? 0,
    correctCount: (json['correctCount'] as num?)?.toInt() ?? 0,
    wrongCount: (json['wrongCount'] as num?)?.toInt() ?? 0,
    lastReviewedAt: DateTime.tryParse(json['lastReviewedAt']?.toString() ?? ''),
    nextReviewAt: DateTime.tryParse(json['nextReviewAt']?.toString() ?? ''),
  );

  Map<String, dynamic> toJson() => {
    'questionId': questionId,
    'level': level,
    'easeFactor': easeFactor,
    'intervalDays': intervalDays,
    'repetitionCount': repetitionCount,
    'correctCount': correctCount,
    'wrongCount': wrongCount,
    'lastReviewedAt': lastReviewedAt?.toIso8601String(),
    'nextReviewAt': nextReviewAt?.toIso8601String(),
  };
}

class StudyResult {
  const StudyResult({
    required this.questionId,
    required this.levelCode,
    required this.correct,
    required this.reviewedAt,
  });

  final String questionId;
  final String levelCode;
  final bool correct;
  final DateTime reviewedAt;

  factory StudyResult.fromJson(Map<String, dynamic> json) => StudyResult(
    questionId: json['questionId'].toString(),
    levelCode: json['levelCode'].toString(),
    correct: json['correct'] == true,
    reviewedAt: DateTime.parse(json['reviewedAt'].toString()),
  );

  Map<String, dynamic> toJson() => {
    'questionId': questionId,
    'levelCode': levelCode,
    'correct': correct,
    'reviewedAt': reviewedAt.toIso8601String(),
  };
}

abstract final class ReviewScheduler {
  static const masteredLevel = 5;
  static const intervalsByLevel = <int>[1, 2, 4, 7, 15, 30, 60, 120];

  static int intervalDaysForLevel(int level) {
    if (level <= 0) return 0;
    if (level <= intervalsByLevel.length) return intervalsByLevel[level - 1];
    final extraLevel = level - intervalsByLevel.length;
    return (intervalsByLevel.last * math.pow(1.55, extraLevel)).round();
  }

  static ReviewState nextState({
    required String questionId,
    required ReviewState? previous,
    required bool isCorrect,
    required DateTime now,
  }) {
    if (previous != null && isCorrect && previous.nextReviewAt != null) {
      final tomorrow = DateTime(
        now.year,
        now.month,
        now.day,
      ).add(const Duration(days: 1));
      if (!previous.nextReviewAt!.isBefore(tomorrow)) {
        return ReviewState(
          questionId: questionId,
          level: previous.level,
          easeFactor: previous.easeFactor,
          intervalDays: previous.intervalDays,
          repetitionCount: previous.repetitionCount + 1,
          correctCount: previous.correctCount + 1,
          wrongCount: previous.wrongCount,
          lastReviewedAt: now,
          nextReviewAt: previous.nextReviewAt,
        );
      }
    }
    final oldLevel = previous?.level ?? 0;
    final oldEase = previous?.easeFactor ?? 2.5;
    final nextLevel = isCorrect
        ? math.min(oldLevel + 1, intervalsByLevel.length)
        : oldLevel;
    final nextEase = isCorrect
        ? math.min(oldEase + 0.08, 3.0)
        : math.max(oldEase - 0.2, 1.3);
    final interval = intervalDaysForLevel(nextLevel);
    final today = DateTime(now.year, now.month, now.day);
    return ReviewState(
      questionId: questionId,
      level: nextLevel,
      easeFactor: nextEase,
      intervalDays: interval,
      repetitionCount: (previous?.repetitionCount ?? 0) + 1,
      correctCount: (previous?.correctCount ?? 0) + (isCorrect ? 1 : 0),
      wrongCount: (previous?.wrongCount ?? 0) + (isCorrect ? 0 : 1),
      lastReviewedAt: now,
      nextReviewAt: nextLevel > 0 ? today.add(Duration(days: interval)) : now,
    );
  }
}

class ProgressStore extends ChangeNotifier {
  static const _reviewStatesKey = 'progress.reviewStates.v1';
  static const _studyResultsKey = 'progress.studyResults.v1';
  static const _attemptedKey = 'progress.attempted.v1';

  final SharedPreferencesAsync _preferences = SharedPreferencesAsync();
  final Map<String, ReviewState> reviewStates = {};
  final List<StudyResult> studyResults = [];
  final Set<String> attemptedQuestionIds = {};

  Future<void> load() async {
    reviewStates.clear();
    studyResults.clear();
    attemptedQuestionIds.clear();
    final statesSource = await _preferences.getString(_reviewStatesKey);
    final resultsSource = await _preferences.getString(_studyResultsKey);
    attemptedQuestionIds.addAll(
      await _preferences.getStringList(_attemptedKey) ?? const [],
    );
    if (statesSource != null) {
      final values = jsonDecode(statesSource) as List<dynamic>;
      for (final value in values) {
        final state = ReviewState.fromJson(value as Map<String, dynamic>);
        reviewStates[state.questionId] = state;
      }
    }
    if (resultsSource != null) {
      studyResults.addAll(
        (jsonDecode(resultsSource) as List<dynamic>).map(
          (value) => StudyResult.fromJson(value as Map<String, dynamic>),
        ),
      );
    }
    notifyListeners();
  }

  Future<void> markAttempted(String questionId) async {
    if (!attemptedQuestionIds.add(questionId)) return;
    await _preferences.setStringList(
      _attemptedKey,
      attemptedQuestionIds.toList(growable: false),
    );
    notifyListeners();
  }

  Future<void> recordAnswer({
    required String questionId,
    required String levelCode,
    required bool correct,
  }) async {
    final now = DateTime.now();
    reviewStates[questionId] = ReviewScheduler.nextState(
      questionId: questionId,
      previous: reviewStates[questionId],
      isCorrect: correct,
      now: now,
    );
    studyResults.add(
      StudyResult(
        questionId: questionId,
        levelCode: levelCode,
        correct: correct,
        reviewedAt: now,
      ),
    );
    attemptedQuestionIds.add(questionId);
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    await _preferences.setString(
      _reviewStatesKey,
      jsonEncode(reviewStates.values.map((value) => value.toJson()).toList()),
    );
    await _preferences.setString(
      _studyResultsKey,
      jsonEncode(studyResults.map((value) => value.toJson()).toList()),
    );
    await _preferences.setStringList(
      _attemptedKey,
      attemptedQuestionIds.toList(growable: false),
    );
  }

  List<String> dueQuestionIds(DateTime now) {
    final tomorrow = DateTime(
      now.year,
      now.month,
      now.day,
    ).add(const Duration(days: 1));
    return reviewStates.values
        .where(
          (value) =>
              value.nextReviewAt != null &&
              value.nextReviewAt!.isBefore(tomorrow),
        )
        .map((value) => value.questionId)
        .toList(growable: false);
  }

  List<String> questionIdsDueWithin(DateTime now, {int days = 7}) {
    return questionIdsDueByDay(
      now,
      days: days,
    ).values.expand((questionIds) => questionIds).toList(growable: false);
  }

  Map<DateTime, List<String>> questionIdsDueByDay(
    DateTime now, {
    int days = 7,
  }) {
    if (days <= 0) return const {};
    final startOfToday = DateTime(now.year, now.month, now.day);
    final exclusiveEnd = startOfToday.add(Duration(days: days));
    final schedule = <DateTime, List<String>>{
      for (var offset = 0; offset < days; offset++)
        startOfToday.add(Duration(days: offset)): <String>[],
    };

    for (final state in reviewStates.values) {
      final dueAt = state.nextReviewAt;
      if (dueAt == null || !dueAt.isBefore(exclusiveEnd)) continue;
      final localDueAt = dueAt.toLocal();
      final dueDay = DateTime(
        localDueAt.year,
        localDueAt.month,
        localDueAt.day,
      );
      // Giống dashboard app flashcard: các câu đã quá hạn được cộng vào hôm
      // nay, còn sáu ô sau là từng ngày kế tiếp.
      final bucket = dueDay.isBefore(startOfToday) ? startOfToday : dueDay;
      schedule[bucket]?.add(state.questionId);
    }
    return schedule;
  }

  int get totalCorrect => studyResults.where((value) => value.correct).length;
  int get totalWrong => studyResults.where((value) => !value.correct).length;
  int get accuracy {
    if (studyResults.isEmpty) return 0;
    return (totalCorrect * 100 / studyResults.length).round();
  }

  int get mastered => reviewStates.values
      .where((value) => value.level >= ReviewScheduler.masteredLevel)
      .length;

  int get currentStreak {
    final days = studyResults
        .map(
          (value) => DateTime(
            value.reviewedAt.year,
            value.reviewedAt.month,
            value.reviewedAt.day,
          ),
        )
        .toSet();
    var cursor = DateTime.now();
    cursor = DateTime(cursor.year, cursor.month, cursor.day);
    if (!days.contains(cursor)) {
      cursor = cursor.subtract(const Duration(days: 1));
    }
    var count = 0;
    while (days.contains(cursor)) {
      count++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return count;
  }
}
