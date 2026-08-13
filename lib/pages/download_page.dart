import 'dart:io';

import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../core/app_toast.dart';
import '../models/tocfl_models.dart';
import '../services/download_service.dart';
import '../services/settings_store.dart';

class DownloadPage extends StatefulWidget {
  const DownloadPage({
    super.key,
    required this.settings,
    required this.catalog,
    required this.reloadCatalog,
  });

  final SettingsStore settings;
  final TocflCatalog catalog;
  final Future<void> Function() reloadCatalog;

  @override
  State<DownloadPage> createState() => _DownloadPageState();
}

class _DownloadPageState extends State<DownloadPage> {
  late final DownloadService _downloadService;
  LevelDownloadProgress? _progress;
  String? _downloadingLevel;
  String? _error;

  @override
  void initState() {
    super.initState();
    _downloadService = DownloadService(widget.settings);
  }

  @override
  Widget build(BuildContext context) {
    final grouped = <String, List<ExamDocument>>{};
    for (final document in widget.catalog.items) {
      grouped.putIfAbsent(document.levelCode, () => []).add(document);
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Tải đề về ứng dụng',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
        ),
        if (Platform.isWindows) ...[
          const SizedBox(height: 8),
          Text(
            'Nguồn debug: ${widget.settings.remoteDataRoot}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        const SizedBox(height: 16),
        for (final level in const ['01', '02', '03', '04']) ...[
          _levelCard(level, grouped[level] ?? const []),
          const SizedBox(height: 12),
        ],
        if (_downloadingLevel != null && _progress != null)
          AppSection(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _downloadingLevel == 'all'
                      ? 'Đang tải toàn bộ đề'
                      : 'Đang tải cấp $_downloadingLevel',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 10),
                LinearProgressIndicator(value: _progress!.ratio),
                const SizedBox(height: 8),
                Text(
                  '${_progress!.completed}/${_progress!.total}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                if (_progress!.currentFile.isNotEmpty)
                  Text(
                    _progress!.currentFile,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(
            _error!,
            style: const TextStyle(
              color: AppColors.red,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
        const SizedBox(height: 4),
        AppTextButton(
          label: _downloadingLevel == 'all'
              ? 'Đang tải toàn bộ...'
              : 'Tải toàn bộ 4 cấp',
          expand: true,
          filled: true,
          danger: true,
          onPressed: _downloadingLevel == null ? _downloadAll : null,
        ),
      ],
    );
  }

  Widget _levelCard(String level, List<ExamDocument> documents) {
    final questions = documents.fold<int>(
      0,
      (sum, document) => sum + document.questionCount,
    );
    final title = documents.isEmpty
        ? 'Cấp $level'
        : '$level — ${documents.first.levelName}';
    return AppSection(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.blue,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text('${documents.length} tài liệu • $questions câu hỏi'),
              ],
            ),
          ),
          const SizedBox(width: 10),
          AppTextButton(
            label: _downloadingLevel == level
                ? 'Đang tải...'
                : 'Tải cấp $level',
            compact: true,
            filled: true,
            onPressed: _downloadingLevel == null && documents.isNotEmpty
                ? () => _downloadLevel(level)
                : null,
          ),
        ],
      ),
    );
  }

  Future<void> _downloadAll() async {
    setState(() {
      _downloadingLevel = 'all';
      _progress = null;
      _error = null;
    });
    try {
      for (final level in const ['01', '02', '03', '04']) {
        await _download(level);
      }
      await widget.reloadCatalog();
      if (mounted) _showCompleted('Đã tải xong toàn bộ 4 cấp.');
    } catch (error) {
      if (mounted) setState(() => _error = 'Không tải được đề: $error');
    } finally {
      if (mounted) setState(() => _downloadingLevel = null);
    }
  }

  Future<void> _downloadLevel(String level) async {
    setState(() {
      _downloadingLevel = level;
      _progress = null;
      _error = null;
    });
    try {
      await _download(level);
      await widget.reloadCatalog();
      if (mounted) _showCompleted('Đã tải xong cấp $level.');
    } catch (error) {
      if (mounted) setState(() => _error = 'Không tải được cấp $level: $error');
    } finally {
      if (mounted) setState(() => _downloadingLevel = null);
    }
  }

  Future<void> _download(String level) {
    return _downloadService.downloadLevel(
      levelCode: level,
      documents: widget.catalog.items,
      onProgress: (value) {
        if (mounted) setState(() => _progress = value);
      },
    );
  }

  void _showCompleted(String message) {
    AppToast.show(context, message, tone: AppToastTone.success);
  }
}
