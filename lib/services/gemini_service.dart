import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/tocfl_models.dart';
import 'settings_store.dart';
import 'vocabulary_store.dart';

class GeminiModelOption {
  const GeminiModelOption({
    required this.id,
    required this.displayName,
    required this.description,
  });

  final String id;
  final String displayName;
  final String description;

  String get label => displayName.trim().isEmpty ? id : displayName;
}

class GeminiService {
  GeminiService(this.settings);

  final SettingsStore settings;

  Future<List<GeminiModelOption>> listGenerateContentModels({
    String? apiKey,
  }) async {
    final key = (apiKey ?? settings.geminiApiKey).trim();
    if (key.isEmpty) {
      throw StateError(
        'Hãy nhập API key Gemini trước khi tải danh sách model.',
      );
    }
    final client = HttpClient();
    final models = <String, GeminiModelOption>{};
    String? pageToken;
    try {
      do {
        final query = <String, String>{'key': key, 'pageSize': '1000'};
        if (pageToken?.isNotEmpty == true) query['pageToken'] = pageToken!;
        final uri = Uri.https(
          'generativelanguage.googleapis.com',
          '/v1beta/models',
          query,
        );
        final request = await client.getUrl(uri);
        final response = await request.close();
        final body = await response.transform(utf8.decoder).join();
        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw HttpException(_apiError(body));
        }
        final decoded = jsonDecode(body) as Map<String, dynamic>;
        for (final value in decoded['models'] as List<dynamic>? ?? const []) {
          final model = value as Map<String, dynamic>;
          final methods =
              (model['supportedGenerationMethods'] as List<dynamic>? ??
                      const [])
                  .map((method) => method.toString())
                  .toSet();
          if (!methods.contains('generateContent')) continue;
          final rawName = model['name']?.toString() ?? '';
          final id = rawName.replaceFirst(RegExp(r'^models/'), '').trim();
          if (id.isEmpty || !id.toLowerCase().contains('gemini')) continue;
          models[id] = GeminiModelOption(
            id: id,
            displayName: model['displayName']?.toString() ?? id,
            description: model['description']?.toString() ?? '',
          );
        }
        pageToken = decoded['nextPageToken']?.toString();
      } while (pageToken?.isNotEmpty == true);
    } finally {
      client.close(force: true);
    }
    final result = models.values.toList();
    result.sort((left, right) {
      int rank(GeminiModelOption model) {
        final id = model.id.toLowerCase();
        var value = 0;
        if (id.contains('preview') || id.contains('exp')) value += 20;
        if (id.contains('latest')) value -= 5;
        if (id.contains('flash')) value -= 3;
        return value;
      }

      final byRank = rank(left).compareTo(rank(right));
      return byRank != 0 ? byRank : left.id.compareTo(right.id);
    });
    if (result.isEmpty) {
      throw StateError('API key này không có model hỗ trợ generateContent.');
    }
    return result;
  }

  Future<GeminiAnalysis> analyze({
    required ExamDocument document,
    required String pdfFile,
    String? transcriptFile,
  }) async {
    if (settings.geminiApiKey.isEmpty) {
      throw StateError('Chưa nhập API key Gemini trong Cài đặt.');
    }
    final parts = <Map<String, dynamic>>[
      {
        'inlineData': {
          'mimeType': 'application/pdf',
          'data': base64Encode(await _readSource(pdfFile)),
        },
      },
    ];
    if (transcriptFile != null) {
      parts.add({
        'inlineData': {
          'mimeType': 'application/pdf',
          'data': base64Encode(await _readSource(transcriptFile)),
        },
      });
    }
    parts.add({'text': _prompt(document, transcriptFile != null)});

    final uri = Uri.https(
      'generativelanguage.googleapis.com',
      '/v1beta/models/${settings.geminiModel}:generateContent',
      {'key': settings.geminiApiKey},
    );
    final client = HttpClient();
    try {
      final request = await client.postUrl(uri);
      request.headers.contentType = ContentType.json;
      request.write(
        jsonEncode({
          'contents': [
            {'role': 'user', 'parts': parts},
          ],
          'generationConfig': {
            'temperature': 0.2,
            'topP': 0.85,
            'maxOutputTokens': 8192,
            'responseMimeType': 'application/json',
          },
        }),
      );
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(_apiError(body));
      }
      final envelope = jsonDecode(body) as Map<String, dynamic>;
      final candidates = envelope['candidates'] as List<dynamic>?;
      final firstContent = candidates?.isNotEmpty == true
          ? (candidates!.first as Map<String, dynamic>)['content']
                as Map<String, dynamic>?
          : null;
      final responseParts = firstContent == null
          ? null
          : firstContent['parts'] as List<dynamic>?;
      final text =
          responseParts
              ?.map((value) => value['text']?.toString() ?? '')
              .join('\n')
              .trim() ??
          '';
      if (text.isEmpty) throw StateError('Gemini không trả về nội dung.');
      final analysis = GeminiAnalysis.fromJson(
        jsonDecode(_stripFence(text)) as Map<String, dynamic>,
      );
      await save(document.id, analysis);
      return analysis;
    } finally {
      client.close(force: true);
    }
  }

  Future<Uint8List> _readSource(String source) async {
    final uri = Uri.tryParse(source);
    if (uri == null || (uri.scheme != 'https' && uri.scheme != 'http')) {
      return File(source).readAsBytes();
    }

    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 20);
    try {
      final request = await client.getUrl(uri);
      final response = await request.close();
      if (response.statusCode < HttpStatus.ok ||
          response.statusCode >= HttpStatus.multipleChoices) {
        throw HttpException(
          'Không tải được tài liệu: HTTP ${response.statusCode}',
          uri: uri,
        );
      }
      final bytes = BytesBuilder(copy: false);
      await response
          .forEach(bytes.add)
          .timeout(const Duration(seconds: 90));
      return bytes.takeBytes();
    } finally {
      client.close(force: true);
    }
  }

  String _prompt(ExamDocument document, bool hasTranscript) =>
      '''
Bạn là giáo viên TOCFL. Phân tích đầy đủ tài liệu đính kèm sang tiếng Việt.
Tài liệu chính là đề ${document.isListening ? 'nghe' : 'đọc'}.
${hasTranscript ? 'Tài liệu thứ hai là script nghe. Hãy dịch nguyên văn TOÀN BỘ script sang tiếng Việt, giữ đúng thứ tự, ngữ cảnh và từng lượt người nói trên một dòng riêng.' : 'Không có script nghe, tuyệt đối không tự bịa transcript.'}
PDF này có ${document.questionCount} câu nhỏ, đáp án lần lượt: ${document.answers.join(', ')}.
Không đưa lời khuyên, mẹo làm bài hoặc gợi ý học tập thay cho bản dịch script.

Trả về duy nhất JSON hợp lệ theo cấu trúc:
{
  "summary": "tóm tắt rất ngắn nội dung chính bằng tiếng Việt, không có lời khuyên hoặc gợi ý",
  "transcript": "bản dịch nguyên văn toàn bộ script sang tiếng Việt, giữ nguyên cấu trúc từng dòng và người nói; để rỗng nếu không có nguồn",
  "questions": [
    {
      "question": "nguyên văn đầy đủ của câu hỏi trong đề",
      "questionMeaning": "dịch sát nghĩa toàn bộ câu hỏi sang tiếng Việt",
      "answers": [
        ${document.answerOptions.map((label) => '{"label": "$label", "text": "nguyên văn đáp án $label", "meaning": "dịch sát nghĩa đáp án $label sang tiếng Việt"}').join(',\n        ')}
      ],
      "explanation": "giải thích bằng tiếng Việt vì sao đáp án đúng và các đáp án còn lại sai"
    }
  ],
  "vocabulary": [
    {"word": "từ phồn thể", "pinyin": "pinyin", "meaning": "nghĩa tiếng Việt"}
  ]
}

Số phần tử questions phải đúng ${document.questionCount}. Với mỗi câu, phải đọc
đủ nguyên văn câu hỏi và TẤT CẢ lựa chọn hiện có rồi dịch nghĩa riêng từng phần;
nếu phần nào thực sự chỉ có hình ảnh thì để text và meaning của phần đó là chuỗi rỗng,
không tự bịa nội dung.

Danh sách vocabulary phải bao phủ TOÀN BỘ script, câu hỏi và các lựa chọn trả lời:
- Lấy tất cả từ và cụm từ tiếng Hoa có giá trị học tập, kể cả từ cơ bản.
- Chỉ lấy từ thực sự xuất hiện trong tài liệu, giữ chữ phồn thể và pinyin chính xác.
- Không chỉ chọn vài từ nổi bật và không dừng ở 5 mục. Nếu nguồn có đủ từ, trả ít
  nhất 15 mục; với nguồn dài phải tiếp tục lấy hết các mục không trùng.
- Mỗi mục phải có nghĩa tiếng Việt cụ thể, không để trống và không gộp thành đoạn văn.

Không thêm Markdown và không thêm nội dung ngoài JSON.
''';

  Future<VocabularyEntry> lookupVocabulary(String word) async {
    final cleanWord = word.trim();
    if (cleanWord.isEmpty) throw StateError('Chưa nhập từ cần tra.');
    if (settings.geminiApiKey.isEmpty) {
      throw StateError('Chưa nhập API key Gemini trong Cài đặt.');
    }
    final uri = Uri.https(
      'generativelanguage.googleapis.com',
      '/v1beta/models/${settings.geminiModel}:generateContent',
      {'key': settings.geminiApiKey},
    );
    final client = HttpClient();
    try {
      final request = await client.postUrl(uri);
      request.headers.contentType = ContentType.json;
      request.write(
        jsonEncode({
          'contents': [
            {
              'role': 'user',
              'parts': [
                {
                  'text':
                      'Tra từ "$cleanWord" trong ngữ cảnh học TOCFL. '
                      'Trả về đúng một JSON gồm word (chữ phồn thể), pinyin '
                      'và meaning (nghĩa tiếng Việt ngắn gọn).',
                },
              ],
            },
          ],
          'generationConfig': {
            'temperature': 0.1,
            'maxOutputTokens': 256,
            'responseMimeType': 'application/json',
          },
        }),
      );
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(_apiError(body));
      }
      final envelope = jsonDecode(body) as Map<String, dynamic>;
      final candidates = envelope['candidates'] as List<dynamic>?;
      final content = candidates?.isNotEmpty == true
          ? (candidates!.first as Map<String, dynamic>)['content']
                as Map<String, dynamic>?
          : null;
      final parts = content?['parts'] as List<dynamic>?;
      final text =
          parts
              ?.map((value) => value['text']?.toString() ?? '')
              .join('\n')
              .trim() ??
          '';
      if (text.isEmpty) throw StateError('Gemini không trả về nội dung.');
      return VocabularyEntry.fromJson(
        jsonDecode(_stripFence(text)) as Map<String, dynamic>,
      );
    } finally {
      client.close(force: true);
    }
  }

  String _apiError(String body) {
    try {
      return (jsonDecode(body) as Map<String, dynamic>)['error']?['message']
              ?.toString() ??
          body;
    } catch (_) {
      return body;
    }
  }

  String _stripFence(String text) => text
      .replaceFirst(RegExp(r'^```(?:json)?\s*'), '')
      .replaceFirst(RegExp(r'\s*```$'), '')
      .trim();

  Future<Directory> _analysisDirectory(String documentId) async {
    final base = Platform.isWindows
        ? Directory(settings.localDataRoot)
        : await getApplicationSupportDirectory();
    final safeId = documentId.replaceAll(RegExp(r'[^A-Za-z0-9_.-]'), '_');
    return Directory(p.join(base.path, '.tocfl_analysis', safeId));
  }

  Future<void> save(String documentId, GeminiAnalysis analysis) async {
    final directory = await _analysisDirectory(documentId);
    await directory.create(recursive: true);
    await File(p.join(directory.path, 'analysis.json')).writeAsString(
      const JsonEncoder.withIndent('  ').convert(analysis.toJson()),
      flush: true,
    );
    final vocabulary = <String, VocabularyEntry>{};
    for (final entry in analysis.vocabulary) {
      final key = entry.word.trim().toLowerCase();
      if (key.isNotEmpty) vocabulary.putIfAbsent(key, () => entry);
    }
    await File(p.join(directory.path, 'vocabulary.txt')).writeAsString(
      vocabulary.values.map((value) => value.textLine).join('\n'),
      flush: true,
    );
    await VocabularyStore().mergeEntries(vocabulary.values);
  }

  Future<GeminiAnalysis?> load(String documentId) async {
    final directory = await _analysisDirectory(documentId);
    final file = File(p.join(directory.path, 'analysis.json'));
    if (!await file.exists()) return null;
    final analysis = GeminiAnalysis.fromJson(
      jsonDecode(await file.readAsString()) as Map<String, dynamic>,
    );
    await VocabularyStore().mergeEntries(analysis.vocabulary);
    return analysis;
  }
}
