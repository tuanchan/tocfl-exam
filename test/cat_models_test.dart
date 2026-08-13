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
    final questions = List.generate(
      30,
      (index) => CatQuestion(
        document: _document(
          id: 'reading-test-$index',
          skill: CatSkill.reading,
          sectionName: 'Đọc hiểu',
        ),
        childIndex: 0,
        difficulty: 400,
      ),
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

  group('CAT adaptive item selection', () {
    for (final skill in CatSkill.values) {
      test('${skill.name} moves difficulty up after correct answer', () {
        final questions = [
          for (final difficulty in const [220.0, 420.0, 600.0])
            CatQuestion(
              document: _document(
                id: '${skill.name}-${difficulty.toInt()}',
                skill: skill,
                sectionName: 'Cùng dạng',
              ),
              childIndex: 0,
              difficulty: difficulty,
            ),
        ];
        final engine = CatEngine(
          skill: skill,
          questions: questions,
          random: Random(1),
        );

        final first = engine.nextQuestion();
        engine.recordAnswer(first, first.correctAnswer);
        final second = engine.nextQuestion();

        expect(first.difficulty, 420);
        expect(engine.ability, greaterThan(420));
        expect(second.difficulty, greaterThan(first.difficulty));
      });

      test('${skill.name} moves difficulty down after wrong answer', () {
        final questions = [
          for (final difficulty in const [220.0, 420.0, 600.0])
            CatQuestion(
              document: _document(
                id: '${skill.name}-wrong-${difficulty.toInt()}',
                skill: skill,
                sectionName: 'Cùng dạng',
              ),
              childIndex: 0,
              difficulty: difficulty,
            ),
        ];
        final engine = CatEngine(
          skill: skill,
          questions: questions,
          random: Random(1),
        );

        final first = engine.nextQuestion();
        engine.recordAnswer(first, 'B');
        final second = engine.nextQuestion();

        expect(first.difficulty, 420);
        expect(engine.ability, lessThan(420));
        expect(second.difficulty, lessThan(first.difficulty));
      });

      test('${skill.name} balances content categories near ability', () {
        final questions = <CatQuestion>[
          for (var category = 1; category <= 4; category++)
            for (var item = 1; item <= 2; item++)
              CatQuestion(
                document: _document(
                  id: '${skill.name}-category-$category-item-$item',
                  skill: skill,
                  sectionName: 'Dạng $category',
                ),
                childIndex: 0,
                difficulty: 420,
              ),
        ];
        final engine = CatEngine(
          skill: skill,
          questions: questions,
          random: Random(1),
        );
        final firstFourCategories = <String>{};

        for (var index = 0; index < 4; index++) {
          final question = engine.nextQuestion();
          firstFourCategories.add(question.contentCategory);
          engine.recordAnswer(
            question,
            index.isEven ? question.correctAnswer : 'B',
          );
        }

        expect(firstFourCategories, hasLength(4));
      });
    }

    test('question pool includes every child but uses each document once', () {
      final firstDocument = _document(
        id: 'multi-question-document',
        skill: CatSkill.reading,
        sectionName: 'Đọc hiểu',
        answers: const ['A', 'B', 'C'],
      );
      final secondDocument = _document(
        id: 'single-question-document',
        skill: CatSkill.reading,
        sectionName: 'Hoàn thành đoạn văn',
      );
      final pool = buildCatQuestionPool(
        TocflCatalog(
          generatedAt: 'test',
          items: [firstDocument, secondDocument],
        ),
        CatSkill.reading,
        random: Random(1),
      );
      final engine = CatEngine(
        skill: CatSkill.reading,
        questions: pool,
        random: Random(1),
      );
      final selectedDocumentIds = <String>{};

      expect(pool, hasLength(4));
      while (engine.remainingQuestionCount > 0) {
        final block = engine.nextQuestionBlock();
        selectedDocumentIds.add(block.document.id);
        for (final question in block.questions) {
          engine.recordAnswer(question, question.correctAnswer);
        }
      }

      expect(selectedDocumentIds, hasLength(2));
      expect(engine.presentedCount, 4);
    });

    test('a selected document keeps all child questions in one block', () {
      final document = _document(
        id: 'five-question-reading-block',
        skill: CatSkill.reading,
        sectionName: 'Chọn từ điền chỗ trống',
        answers: const ['C', 'B', 'A', 'A', 'B'],
      );
      final pool = buildCatQuestionPool(
        TocflCatalog(generatedAt: 'test', items: [document]),
        CatSkill.reading,
        random: Random(1),
      );
      final engine = CatEngine(
        skill: CatSkill.reading,
        questions: pool,
        random: Random(1),
      );

      final block = engine.nextQuestionBlock();

      expect(block.document.id, document.id);
      expect(block.questionCount, 5);
      expect(
        block.questions.map((question) => question.childIndex),
        orderedEquals(const [0, 1, 2, 3, 4]),
      );
      for (final question in block.questions) {
        engine.recordAnswer(question, question.correctAnswer);
      }
      expect(engine.presentedCount, 5);
      expect(engine.answeredCount, 5);
      expect(engine.correctCount, 5);
    });
  });

  test('answer option count follows the original TOCFL section', () {
    final threeOptions = _document(
      id: 'three-options',
      skill: CatSkill.reading,
      sectionCode: '03',
      sectionName: 'Chọn từ điền chỗ trống',
    );
    final fourOptions = _document(
      id: 'four-options',
      skill: CatSkill.reading,
      sectionCode: '04',
      sectionName: 'Hoàn thành đoạn văn',
    );

    expect(threeOptions.answerOptions, const ['A', 'B', 'C']);
    expect(fourOptions.answerOptions, const ['A', 'B', 'C', 'D']);
  });

  for (final skill in CatSkill.values) {
    test('${skill.name} scores zero when no question is answered', () {
      final document = ExamDocument(
        id: 'empty-${skill.name}',
        levelCode: '02',
        levelName: 'Band A',
        skill: skill.name,
        sectionCode: '01',
        sectionName: skill.name,
        fileName: 'empty.pdf',
        pdfPath: 'empty.pdf',
        answers: const ['A'],
      );
      final engine = CatEngine(
        skill: skill,
        questions: [
          CatQuestion(document: document, childIndex: 0, difficulty: 400),
        ],
        random: Random(1),
      );

      engine.recordAnswer(engine.nextQuestion(), null);
      final result = engine.result();

      expect(result.presentedCount, 1);
      expect(result.answeredCount, 0);
      expect(result.correctCount, 0);
      expect(result.unadjustedScore, 0);
      expect(result.score, 0);
      expect(result.readingPenaltyApplied, isFalse);
    });
  }

  test('a recorded reading answer can be revised without duplication', () {
    final document = ExamDocument(
      id: 'reading-revision',
      levelCode: '02',
      levelName: 'Nhập môn và Cơ bản',
      skill: 'reading',
      sectionCode: '01',
      sectionName: 'Đọc hiểu',
      fileName: 'revision.pdf',
      pdfPath: 'revision.pdf',
      answers: const ['A', 'B'],
    );
    final questions = List.generate(
      2,
      (index) => CatQuestion(
        document: document,
        childIndex: index,
        difficulty: 400 + index * 20,
      ),
    );
    final engine = CatEngine(
      skill: CatSkill.reading,
      questions: questions,
      random: Random(1),
    );

    final first = engine.nextQuestion();
    engine.recordAnswer(first, first.correctAnswer);
    final abilityWithCorrectAnswer = engine.ability;

    engine.reviseAnswer(first, first.correctAnswer == 'A' ? 'B' : 'A');

    expect(engine.presentedCount, 1);
    expect(engine.answeredCount, 1);
    expect(engine.correctCount, 0);
    expect(engine.ability, lessThan(abilityWithCorrectAnswer));
  });
}

ExamDocument _document({
  required String id,
  required CatSkill skill,
  required String sectionName,
  String sectionCode = '01',
  List<String> answers = const ['A'],
}) {
  return ExamDocument(
    id: id,
    levelCode: '02',
    levelName: 'Nhập môn và Cơ bản',
    skill: skill.name,
    sectionCode: sectionCode,
    sectionName: sectionName,
    fileName: '$id.pdf',
    pdfPath: '$id.pdf',
    answers: answers,
  );
}
