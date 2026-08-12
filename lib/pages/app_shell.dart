import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../models/tocfl_models.dart';
import '../services/catalog_service.dart';
import '../services/progress_store.dart';
import '../services/settings_store.dart';
import 'download_page.dart';
import 'exam_page.dart';
import 'settings_page.dart';
import 'statistics_page.dart';
import 'test_builder_page.dart';
import 'vocabulary_page.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.settings});

  final SettingsStore settings;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final ProgressStore _progress = ProgressStore();
  TocflCatalog? _catalog;
  String? _error;
  int _tab = 0;
  bool _navExpanded = false;

  static const _tabNames = <String>[
    'Bài học',
    'Tạo đề',
    'Ôn SRS',
    'Thống kê',
    'Tải đề',
    'Cài đặt',
    'Từ vựng TXT',
  ];

  @override
  void initState() {
    super.initState();
    _progress.addListener(_refreshProgress);
    _load();
  }

  @override
  void dispose() {
    _progress.removeListener(_refreshProgress);
    super.dispose();
  }

  void _refreshProgress() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      await _progress.load();
      final catalog = await CatalogService(widget.settings).load();
      if (mounted) setState(() => _catalog = catalog);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  void _openExam(List<ExamDocument> documents, [Set<String>? questionIds]) {
    if (documents.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ExamPage(
          documents: documents,
          settings: widget.settings,
          progress: _progress,
          questionIds: questionIds,
        ),
      ),
    );
  }

  void _selectTab(int index) {
    setState(() {
      _tab = index;
      _navExpanded = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final catalog = _catalog;
    final compact = MediaQuery.sizeOf(context).width < 720;
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset(
              'assets/icon/icon.PNG',
              width: 32,
              height: 32,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: 10),
            const Flexible(
              child: Text(
                'TOCFL Exam',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: compact
            ? [
                IconButton(
                  tooltip: _navExpanded
                      ? 'Đóng thanh chức năng'
                      : 'Mở thanh chức năng',
                  onPressed: () => setState(() => _navExpanded = !_navExpanded),
                  icon: AnimatedRotation(
                    turns: _navExpanded ? 0.25 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: Icon(
                      _navExpanded ? Icons.close_rounded : Icons.menu_rounded,
                    ),
                  ),
                ),
              ]
            : null,
      ),
      body: SafeArea(
        child: Column(
          children: [
            AnimatedSize(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              child: !compact || _navExpanded
                  ? _navigationBar()
                  : const SizedBox.shrink(),
            ),
            Expanded(
              child: _error != null && _tab != 5 && _tab != 6
                  ? _ErrorView(message: _error!, retry: _load)
                  : catalog == null && _tab != 5 && _tab != 6
                  ? const Center(child: CircularProgressIndicator())
                  : _page(
                      catalog ?? const TocflCatalog(generatedAt: '', items: []),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _navigationBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          for (var index = 0; index < _tabNames.length; index++)
            TextButton(
              onPressed: () => _selectTab(index),
              style: TextButton.styleFrom(
                foregroundColor: _tab == index
                    ? Theme.of(context).brightness == Brightness.dark
                          ? AppColors.attemptedYellow
                          : AppColors.darkBlue
                    : index == 5
                    ? AppColors.red
                    : AppColors.blue,
                padding: const EdgeInsets.symmetric(
                  horizontal: 7,
                  vertical: 5,
                ),
                minimumSize: const Size(0, 30),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: TextStyle(
                  fontWeight: _tab == index
                      ? FontWeight.w900
                      : FontWeight.w700,
                ),
              ),
              child: Text(_tabNames[index]),
            ),
        ],
      ),
    );
  }

  Widget _page(TocflCatalog catalog) {
    switch (_tab) {
      case 0:
        return _LibraryPage(catalog: catalog, openExam: _openExam);
      case 1:
        return TestBuilderPage(catalog: catalog, openExam: _openExam);
      case 2:
        final due = _progress.dueQuestionIds(DateTime.now()).toSet();
        final documents = catalog.items
            .where((document) {
              return List.generate(
                document.questionCount,
                (index) => '${document.id}#$index',
              ).any(due.contains);
            })
            .toList(growable: false);
        final availableDue = <String>{};
        for (final document in documents) {
          for (var index = 0; index < document.questionCount; index++) {
            final id = '${document.id}#$index';
            if (due.contains(id)) availableDue.add(id);
          }
        }
        return _SrsPage(
          documents: documents,
          questionIds: availableDue,
          openExam: _openExam,
        );
      case 3:
        return StatisticsPage(progress: _progress, catalog: catalog);
      case 4:
        return DownloadPage(
          settings: widget.settings,
          catalog: catalog,
          reloadCatalog: _load,
        );
      case 5:
        return SettingsPage(settings: widget.settings, reloadCatalog: _load);
      default:
        return VocabularyPage(settings: widget.settings);
    }
  }
}

class _LibraryPage extends StatelessWidget {
  const _LibraryPage({required this.catalog, required this.openExam});

  final TocflCatalog catalog;
  final void Function(List<ExamDocument>, Set<String>?) openExam;

  @override
  Widget build(BuildContext context) {
    final grouped = <String, List<ExamDocument>>{};
    for (final item in catalog.items) {
      grouped.putIfAbsent(item.levelCode, () => []).add(item);
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final entry in grouped.entries) ...[
          AppSection(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${entry.key} — ${entry.value.first.levelName}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.blue,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${entry.value.length} tài liệu • '
                  '${entry.value.fold<int>(0, (sum, item) => sum + item.questionCount)} câu hỏi',
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    AppTextButton(
                      label: 'Luyện nghe',
                      filled: true,
                      onPressed: () => openExam(
                        entry.value
                            .where((item) => item.isListening)
                            .toList(growable: false),
                        null,
                      ),
                    ),
                    AppTextButton(
                      label: 'Luyện đọc',
                      danger: true,
                      filled: true,
                      onPressed: () => openExam(
                        entry.value
                            .where((item) => !item.isListening)
                            .toList(growable: false),
                        null,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _SrsPage extends StatelessWidget {
  const _SrsPage({
    required this.documents,
    required this.questionIds,
    required this.openExam,
  });

  final List<ExamDocument> documents;
  final Set<String> questionIds;
  final void Function(List<ExamDocument>, Set<String>?) openExam;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Ôn tập theo lịch SRS',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        const Text('Lịch ôn: 1, 2, 4, 7, 15, 30, 60 và 120 ngày.'),
        const SizedBox(height: 16),
        AppSection(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${questionIds.length} câu đang đến hạn trong '
                '${documents.length} tài liệu',
              ),
              const SizedBox(height: 12),
              AppTextButton(
                label: documents.isEmpty ? 'Chưa có bài đến hạn' : 'Bắt đầu ôn',
                expand: true,
                onPressed: documents.isEmpty
                    ? null
                    : () => openExam(documents, questionIds),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.retry});

  final String message;
  final VoidCallback retry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          AppTextButton(label: 'Thử lại', onPressed: retry),
        ],
      ),
    ),
  );
}
