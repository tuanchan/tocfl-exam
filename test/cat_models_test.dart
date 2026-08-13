import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluttertocflexam/models/cat_models.dart';
import 'package:fluttertocflexam/models/tocfl_models.dart';

void main() {
  group('CAT certificate rules', () {
    test('500 listening + 500 reading reaches B1, not B2', () {
      final result = CatScoreRules.certificateFor(listening: 500, reading: 500);

      expect(result?.shortName, 'B1');
    });

    test('both skill floors are required in addition to total score', () {
      final result = CatScoreRules.certificateFor(listening: 600, reading: 370);

      expect(result?.shortName, 'A1');
    });

    test('all six CEFR certificate thresholds match the official table', () {
      const cases = <(int, int, String)>[
        (370, 340, 'A1'),
        (470, 415, 'A2'),
        (500, 470, 'B1'),
        (595, 530, 'B2'),
        (625, 585, 'C1'),
        (690, 655, 'C2'),
      ];

      for (final value in cases) {
        expect(
          CatScoreRules.certificateFor(
            listening: value.$1,
            reading: value.$2,
          )?.shortName,
          value.$3,
        );
      }
    });
  });

  test('reading under 25 answered questions is adjusted proportionally', () {
    final document = ExamDocument(
      id: 'reading-test',
      levelCode: '02',
      levelName: 'Nhập môn và Cơ bản',
      skill: 'reading',
      sectionCode: '01',
      sectionName: 'Đọc hiểu',
      fileName: 'test.pdf',
      pdfPath: 'test.pdf',
      answers: List.filled(30, 'A'),
    );
    final questions = List.generate(
      30,
      (index) =>
          CatQuestion(document: document, childIndex: index, difficulty: 400),
    );
    final engine = CatEngine(
      skill: CatSkill.reading,
      questions: questions,
      random: Random(1),
    );

    for (var index = 0; index < 20; index++) {
      final question = engine.nextQuestion();
      engine.recordAnswer(question, 'A');
    }
    final result = engine.result();

    expect(result.readingPenaltyApplied, isTrue);
    expect(result.readingCompletionRatio, 0.8);
    expect(result.score, (result.unadjustedScore * 0.8).round());
  });
}
