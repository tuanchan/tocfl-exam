import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../models/tocfl_models.dart';
import '../services/progress_store.dart';

class StatisticsPage extends StatelessWidget {
  const StatisticsPage({
    super.key,
    required this.progress,
    required this.catalog,
  });

  final ProgressStore progress;
  final TocflCatalog catalog;

  @override
  Widget build(BuildContext context) {
    final due = progress.dueQuestionIds(DateTime.now()).length;
    final dueSchedule = progress.questionIdsDueByDay(DateTime.now(), days: 7);
    final totalQuestions = catalog.items.fold<int>(
      0,
      (sum, item) => sum + item.questionCount,
    );
    final levelStats = <String, List<StudyResult>>{};
    for (final result in progress.studyResults) {
      levelStats.putIfAbsent(result.levelCode, () => []).add(result);
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Thống kê học tập',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: MediaQuery.sizeOf(context).width > 700 ? 4 : 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.7,
          children: [
            _StatBox(label: 'Tổng câu', value: '$totalQuestions'),
            _StatBox(
              label: 'Đã trả lời',
              value: '${progress.studyResults.length}',
            ),
            _StatBox(label: 'Độ chính xác', value: '${progress.accuracy}%'),
            _StatBox(label: 'Chuỗi ngày', value: '${progress.currentStreak}'),
            _StatBox(label: 'Đã thành thạo', value: '${progress.mastered}'),
            _StatBox(label: 'Đến hạn SRS', value: '$due'),
            _StatBox(label: 'Đúng', value: '${progress.totalCorrect}'),
            _StatBox(
              label: 'Sai',
              value: '${progress.totalWrong}',
              danger: true,
            ),
          ],
        ),
        const SizedBox(height: 16),
        _SevenDayReviewDashboard(dueSchedule: dueSchedule, catalog: catalog),
        const SizedBox(height: 16),
        AppSection(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Kết quả theo cấp',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 12),
              for (final level in ['01', '02', '03', '04']) ...[
                _levelRow(level, levelStats[level] ?? const []),
                if (level != '04') const Divider(height: 20),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        AppSection(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Phân bố SRS',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 12),
              for (var level = 0; level <= 8; level++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      SizedBox(width: 58, child: Text('Cấp $level')),
                      Expanded(
                        child: LinearProgressIndicator(
                          value: _srsRatio(level),
                          minHeight: 10,
                          color: level >= ReviewScheduler.masteredLevel
                              ? AppColors.red
                              : AppColors.blue,
                          backgroundColor: AppColors.blue.withValues(
                            alpha: 0.12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 36,
                        child: Text(
                          '${_srsCount(level)}',
                          textAlign: TextAlign.end,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _levelRow(String level, List<StudyResult> values) {
    final correct = values.where((value) => value.correct).length;
    final accuracy = values.isEmpty
        ? 0
        : (correct * 100 / values.length).round();
    return Row(
      children: [
        Expanded(
          child: Text(
            'Cấp $level',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        Text('${values.length} lượt • $accuracy% đúng'),
      ],
    );
  }

  int _srsCount(int level) => progress.reviewStates.values
      .where((value) => value.level == level)
      .length;

  double _srsRatio(int level) {
    if (progress.reviewStates.isEmpty) return 0;
    return _srsCount(level) / progress.reviewStates.length;
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({
    required this.label,
    required this.value,
    this.danger = false,
  });

  final String label;
  final String value;
  final bool danger;

  @override
  Widget build(BuildContext context) => AppSection(
    padding: const EdgeInsets.all(12),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: danger ? AppColors.red : AppColors.blue,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(label, textAlign: TextAlign.center),
      ],
    ),
  );
}

class _SevenDayReviewDashboard extends StatelessWidget {
  const _SevenDayReviewDashboard({
    required this.dueSchedule,
    required this.catalog,
  });

  final Map<DateTime, List<String>> dueSchedule;
  final TocflCatalog catalog;

  @override
  Widget build(BuildContext context) {
    final items = dueSchedule.entries
        .map(
          (entry) => _DueScheduleItem(
            date: entry.key,
            label: _shortDayLabel(entry.key),
            questionIds: entry.value,
          ),
        )
        .toList(growable: false);
    final colors = Theme.of(context).colorScheme;

    return AppSection(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'LỊCH CÂU HỎI CẦN ÔN (7 NGÀY TỚI)',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: AppColors.blue.withValues(alpha: 0.18)),
          const SizedBox(height: 12),
          SizedBox(
            height: 160,
            child: CustomPaint(
              painter: _DueSchedulePainter(
                items: items,
                lineColor: AppColors.blue,
                textColor: colors.onSurfaceVariant,
                valueColor: colors.onSurface,
                pointBackgroundColor: colors.surface,
                gridColor: AppColors.blue.withValues(alpha: 0.14),
              ),
              child: const SizedBox.expand(),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => _SevenDayDetailsDialog(
                  dueSchedule: dueSchedule,
                  catalog: catalog,
                ),
              ),
              icon: const Icon(Icons.calendar_view_week_rounded),
              label: const Text('Chi tiết lịch ôn 7 ngày'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.blue,
                foregroundColor: AppColors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SevenDayDetailsDialog extends StatefulWidget {
  const _SevenDayDetailsDialog({
    required this.dueSchedule,
    required this.catalog,
  });

  final Map<DateTime, List<String>> dueSchedule;
  final TocflCatalog catalog;

  @override
  State<_SevenDayDetailsDialog> createState() => _SevenDayDetailsDialogState();
}

class _SevenDayDetailsDialogState extends State<_SevenDayDetailsDialog> {
  DateTime? _selectedDate;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.sizeOf(context);
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 22),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: math.min(media.width - 28, 560.0),
        height: math.min(media.height - 44, 650.0),
        child: Column(
          children: [
            _header(context),
            const Divider(height: 1),
            Expanded(
              child: _selectedDate == null
                  ? _dayList()
                  : _questionList(_selectedDate!),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    final selectedDate = _selectedDate;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 6, 8),
      child: Row(
        children: [
          IconButton(
            tooltip: selectedDate == null ? 'Đóng' : 'Danh sách ngày',
            onPressed: selectedDate == null
                ? () => Navigator.of(context).pop()
                : () => setState(() => _selectedDate = null),
            icon: Icon(
              selectedDate == null
                  ? Icons.close_rounded
                  : Icons.arrow_back_rounded,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  selectedDate == null
                      ? 'Chi tiết lịch ôn 7 ngày'
                      : _longDayLabel(selectedDate),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  selectedDate == null
                      ? 'Chọn một ngày để xem tên câu hỏi'
                      : '${widget.dueSchedule[selectedDate]?.length ?? 0} câu cần ôn',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dayList() {
    final entries = widget.dueSchedule.entries.toList(growable: false);
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: entries.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final entry = entries[index];
        final isToday = index == 0;
        return Material(
          color: AppColors.blue.withValues(alpha: isToday ? 0.10 : 0.05),
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => setState(() => _selectedDate = entry.key),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isToday ? AppColors.blue : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.blue),
                    ),
                    child: Text(
                      '${entry.key.day}',
                      style: TextStyle(
                        color: isToday ? AppColors.white : AppColors.blue,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _longDayLabel(entry.key),
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        if (isToday)
                          Text(
                            'Bao gồm cả câu đã quá hạn',
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    constraints: const BoxConstraints(minWidth: 36),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 6,
                    ),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: entry.value.isEmpty
                          ? AppColors.blue.withValues(alpha: 0.10)
                          : AppColors.red,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      '${entry.value.length}',
                      style: TextStyle(
                        color: entry.value.isEmpty
                            ? AppColors.blue
                            : AppColors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _questionList(DateTime date) {
    final questionIds = widget.dueSchedule[date] ?? const <String>[];
    final questions =
        questionIds
            .map((id) => _resolveQuestion(id, widget.catalog))
            .toList(growable: false)
          ..sort((a, b) => a.title.compareTo(b.title));
    if (questions.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Ngày này không có câu hỏi cần ôn.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: questions.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final question = questions[index];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 6,
            vertical: 5,
          ),
          leading: CircleAvatar(
            backgroundColor: AppColors.blue.withValues(alpha: 0.12),
            foregroundColor: AppColors.blue,
            child: Text(
              '${question.questionNumber}',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          title: Text(
            question.title,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: Text(question.subtitle),
        );
      },
    );
  }
}

class _DueScheduleItem {
  const _DueScheduleItem({
    required this.date,
    required this.label,
    required this.questionIds,
  });

  final DateTime date;
  final String label;
  final List<String> questionIds;
  int get count => questionIds.length;
}

class _ReviewQuestionInfo {
  const _ReviewQuestionInfo({
    required this.questionNumber,
    required this.title,
    required this.subtitle,
  });

  final int questionNumber;
  final String title;
  final String subtitle;
}

_ReviewQuestionInfo _resolveQuestion(String questionId, TocflCatalog catalog) {
  final separator = questionId.lastIndexOf('#');
  final documentId = separator < 0
      ? questionId
      : questionId.substring(0, separator);
  final questionIndex = separator < 0
      ? 0
      : int.tryParse(questionId.substring(separator + 1)) ?? 0;
  ExamDocument? document;
  for (final item in catalog.items) {
    if (item.id == documentId) {
      document = item;
      break;
    }
  }
  if (document == null) {
    return _ReviewQuestionInfo(
      questionNumber: questionIndex + 1,
      title: 'Câu ${questionIndex + 1}',
      subtitle: questionId,
    );
  }
  final skill = document.isListening ? 'Nghe' : 'Đọc';
  return _ReviewQuestionInfo(
    questionNumber: questionIndex + 1,
    title: 'Câu ${questionIndex + 1} • ${document.fileName}',
    subtitle: 'Cấp ${document.levelCode} • $skill • ${document.sectionName}',
  );
}

String _shortDayLabel(DateTime date) {
  final today = DateTime.now();
  final start = DateTime(today.year, today.month, today.day);
  final offset = date.difference(start).inDays;
  if (offset == 0) return 'Hôm nay';
  if (offset == 1) return 'Ngày mai';
  return '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}';
}

String _longDayLabel(DateTime date) {
  const weekdays = <String>[
    'Thứ Hai',
    'Thứ Ba',
    'Thứ Tư',
    'Thứ Năm',
    'Thứ Sáu',
    'Thứ Bảy',
    'Chủ Nhật',
  ];
  return '${weekdays[date.weekday - 1]}, '
      '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year}';
}

class _DueSchedulePainter extends CustomPainter {
  const _DueSchedulePainter({
    required this.items,
    required this.lineColor,
    required this.textColor,
    required this.valueColor,
    required this.pointBackgroundColor,
    required this.gridColor,
  });

  final List<_DueScheduleItem> items;
  final Color lineColor;
  final Color textColor;
  final Color valueColor;
  final Color pointBackgroundColor;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    final chart = Rect.fromLTWH(24, 8, size.width - 34, size.height - 36);
    var maxValue = 1;
    for (final item in items) {
      maxValue = math.max(maxValue, item.count);
    }
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var index = 0; index <= 4; index++) {
      final y = chart.top + chart.height * index / 4;
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), gridPaint);
    }
    if (items.isEmpty) return;

    final points = <Offset>[];
    for (var index = 0; index < items.length; index++) {
      final x = items.length == 1
          ? chart.center.dx
          : chart.left + chart.width * index / (items.length - 1);
      final y = chart.bottom - chart.height * (items[index].count / maxValue);
      points.add(Offset(x, y));
    }

    final fillPath = Path()
      ..moveTo(points.first.dx, chart.bottom)
      ..lineTo(points.first.dx, points.first.dy);
    final linePath = Path()..moveTo(points.first.dx, points.first.dy);
    for (var index = 1; index < points.length; index++) {
      final previous = points[index - 1];
      final current = points[index];
      final controlX = (previous.dx + current.dx) / 2;
      linePath.cubicTo(
        controlX,
        previous.dy,
        controlX,
        current.dy,
        current.dx,
        current.dy,
      );
      fillPath.cubicTo(
        controlX,
        previous.dy,
        controlX,
        current.dy,
        current.dx,
        current.dy,
      );
    }
    fillPath
      ..lineTo(points.last.dx, chart.bottom)
      ..close();

    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            lineColor.withValues(alpha: 0.22),
            lineColor.withValues(alpha: 0.02),
          ],
        ).createShader(chart),
    );
    canvas.drawPath(
      linePath,
      Paint()
        ..color = lineColor
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    for (var index = 0; index < points.length; index++) {
      final point = points[index];
      canvas.drawCircle(point, 4.5, Paint()..color = pointBackgroundColor);
      canvas.drawCircle(point, 3, Paint()..color = lineColor);
      _drawText(
        canvas,
        '${items[index].count}',
        Offset(point.dx, math.max(0, point.dy - 17)),
        valueColor,
        10,
        FontWeight.w900,
      );
      _drawText(
        canvas,
        items[index].label,
        Offset(point.dx, chart.bottom + 15),
        textColor,
        9,
        FontWeight.w800,
      );
    }
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset center,
    Color color,
    double fontSize,
    FontWeight weight,
  ) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: color, fontSize: fontSize, fontWeight: weight),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: 58);
    painter.paint(
      canvas,
      Offset(center.dx - painter.width / 2, center.dy - painter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _DueSchedulePainter oldDelegate) {
    if (oldDelegate.items.length != items.length ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.textColor != textColor ||
        oldDelegate.valueColor != valueColor ||
        oldDelegate.pointBackgroundColor != pointBackgroundColor ||
        oldDelegate.gridColor != gridColor) {
      return true;
    }
    for (var index = 0; index < items.length; index++) {
      if (oldDelegate.items[index].date != items[index].date ||
          oldDelegate.items[index].count != items[index].count) {
        return true;
      }
    }
    return false;
  }
}
