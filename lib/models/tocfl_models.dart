class TocflCatalog {
  const TocflCatalog({required this.generatedAt, required this.items});

  final String generatedAt;
  final List<ExamDocument> items;

  factory TocflCatalog.fromJson(Map<String, dynamic> json) => TocflCatalog(
    generatedAt: json['generatedAt']?.toString() ?? '',
    items: (json['items'] as List<dynamic>? ?? const [])
        .map((value) => ExamDocument.fromJson(value as Map<String, dynamic>))
        .toList(growable: false),
  );
}

const _levelNames = <String, String>{
  '01': 'Chuẩn bị cấp',
  '02': 'Nhập môn và Cơ bản',
  '03': 'Tiến cấp và Cao cấp',
  '04': 'Lưu loát và Tinh thông',
};

class ExamDocument {
  const ExamDocument({
    required this.id,
    required this.levelCode,
    required this.levelName,
    required this.skill,
    required this.sectionCode,
    required this.sectionName,
    required this.fileName,
    required this.pdfPath,
    required this.answers,
    this.audioPath,
    this.transcriptPath,
  });

  final String id;
  final String levelCode;
  final String levelName;
  final String skill;
  final String sectionCode;
  final String sectionName;
  final String fileName;
  final String pdfPath;
  final String? audioPath;
  final String? transcriptPath;
  final List<String> answers;

  bool get isListening => skill == 'listening';
  bool get hasTranscript => transcriptPath?.isNotEmpty == true;
  int get questionCount => answers.isEmpty ? 1 : answers.length;

  List<String> get answerOptions {
    // Catalog TOCFL hiện tại dùng ba lựa chọn cho toàn bộ cấp 01 và ba phần
    // đầu của cấp 02. Các phần còn lại dùng bốn lựa chọn. Không lấy số lượng
    // từ Gemini vì mô hình có thể tự sinh thêm đáp án D không tồn tại trên đề.
    final hasThreeOptions =
        levelCode == '01' ||
        (levelCode == '02' && const {'01', '02', '03'}.contains(sectionCode));
    return hasThreeOptions ? const ['A', 'B', 'C'] : const ['A', 'B', 'C', 'D'];
  }

  factory ExamDocument.fromJson(Map<String, dynamic> json) {
    final levelCode = json['levelCode'].toString();
    return ExamDocument(
      id: json['id'].toString(),
      levelCode: levelCode,
      // Một số catalog cũ được tạo bởi Windows PowerShell 5 nên chuỗi tiếng
      // Việt bị đọc nhầm UTF-8. Tên cấp là dữ liệu cố định, lấy theo mã cấp để
      // giao diện luôn hiển thị đúng dù catalog cũ chưa được tạo lại.
      levelName: _levelNames[levelCode] ?? json['levelName'].toString(),
      skill: json['skill'].toString(),
      sectionCode: json['sectionCode'].toString(),
      sectionName: json['sectionName'].toString(),
      fileName: json['fileName'].toString(),
      pdfPath: json['pdfPath'].toString(),
      audioPath: json['audioPath']?.toString(),
      transcriptPath: json['transcriptPath']?.toString(),
      answers: (json['answers'] as List<dynamic>? ?? const [])
          .map((value) => value.toString().trim().toUpperCase())
          .where((value) => value.isNotEmpty)
          .toList(growable: false),
    );
  }
}

class GeminiAnalysis {
  const GeminiAnalysis({
    required this.summary,
    required this.transcript,
    required this.questions,
    required this.vocabulary,
  });

  final String summary;
  final String transcript;
  final List<AnalyzedQuestion> questions;
  final List<VocabularyEntry> vocabulary;

  factory GeminiAnalysis.fromJson(Map<String, dynamic> json) => GeminiAnalysis(
    summary: json['summary']?.toString() ?? '',
    transcript: json['transcript']?.toString() ?? '',
    questions: (json['questions'] as List<dynamic>? ?? const [])
        .map(
          (value) => AnalyzedQuestion.fromJson(value as Map<String, dynamic>),
        )
        .toList(growable: false),
    vocabulary: (json['vocabulary'] as List<dynamic>? ?? const [])
        .map((value) => VocabularyEntry.fromJson(value as Map<String, dynamic>))
        .toList(growable: false),
  );

  Map<String, dynamic> toJson() => {
    'summary': summary,
    'transcript': transcript,
    'questions': questions.map((value) => value.toJson()).toList(),
    'vocabulary': vocabulary.map((value) => value.toJson()).toList(),
  };
}

class AnalyzedQuestion {
  const AnalyzedQuestion({
    required this.question,
    required this.questionMeaning,
    required this.answers,
    required this.explanation,
  });

  final String question;
  final String questionMeaning;
  final List<AnalyzedAnswer> answers;
  final String explanation;

  factory AnalyzedQuestion.fromJson(Map<String, dynamic> json) {
    final answers = <AnalyzedAnswer>[];
    final source = json['answers'] ?? json['options'];
    if (source is List<dynamic>) {
      for (final value in source) {
        if (value is Map<String, dynamic>) {
          answers.add(AnalyzedAnswer.fromJson(value));
        }
      }
    } else if (source is Map<String, dynamic>) {
      for (final entry in source.entries) {
        final value = entry.value;
        if (value is Map<String, dynamic>) {
          answers.add(AnalyzedAnswer.fromJson({...value, 'label': entry.key}));
        } else {
          answers.add(
            AnalyzedAnswer(
              label: entry.key,
              text: value?.toString() ?? '',
              meaning: '',
            ),
          );
        }
      }
    }
    return AnalyzedQuestion(
      question: json['question']?.toString() ?? '',
      questionMeaning:
          json['questionMeaning']?.toString() ??
          json['questionTranslation']?.toString() ??
          '',
      answers: answers,
      explanation: json['explanation']?.toString() ?? '',
    );
  }

  AnalyzedAnswer? answerFor(String label) {
    final normalized = label.trim().toUpperCase();
    for (final answer in answers) {
      if (answer.label.trim().toUpperCase() == normalized) return answer;
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
    'question': question,
    'questionMeaning': questionMeaning,
    'answers': answers.map((value) => value.toJson()).toList(),
    'explanation': explanation,
  };
}

class AnalyzedAnswer {
  const AnalyzedAnswer({
    required this.label,
    required this.text,
    required this.meaning,
  });

  final String label;
  final String text;
  final String meaning;

  factory AnalyzedAnswer.fromJson(Map<String, dynamic> json) => AnalyzedAnswer(
    label: json['label']?.toString().trim().toUpperCase() ?? '',
    text:
        json['text']?.toString() ??
        json['answer']?.toString() ??
        json['option']?.toString() ??
        '',
    meaning:
        json['meaning']?.toString() ?? json['translation']?.toString() ?? '',
  );

  Map<String, dynamic> toJson() => {
    'label': label,
    'text': text,
    'meaning': meaning,
  };
}

class VocabularyEntry {
  const VocabularyEntry({
    required this.word,
    required this.pinyin,
    required this.meaning,
  });

  final String word;
  final String pinyin;
  final String meaning;

  factory VocabularyEntry.fromJson(Map<String, dynamic> json) =>
      VocabularyEntry(
        word: json['word']?.toString() ?? '',
        pinyin: json['pinyin']?.toString() ?? '',
        meaning: json['meaning']?.toString() ?? '',
      );

  Map<String, dynamic> toJson() => {
    'word': word,
    'pinyin': pinyin,
    'meaning': meaning,
  };

  String get textLine => '$word:$meaning ($pinyin)';
}
