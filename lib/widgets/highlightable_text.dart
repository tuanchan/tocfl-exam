import 'dart:async';

import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../services/highlight_store.dart';

class HighlightableText extends StatefulWidget {
  const HighlightableText({
    super.key,
    required this.text,
    required this.highlightKey,
    this.style,
    this.onAddVocabulary,
  });

  final String text;
  final String highlightKey;
  final TextStyle? style;
  final Future<void> Function(String selectedText)? onAddVocabulary;

  @override
  State<HighlightableText> createState() => _HighlightableTextState();
}

class _HighlightableTextState extends State<HighlightableText> {
  static _HighlightableTextState? _activeToolbarOwner;
  static const _colors = <Color>[
    Color(0xFF9CECF4),
    Color(0xFFF7B7C6),
    Color(0xFFCFF4C8),
    Color(0xFFFFF59D),
  ];

  TextSelection? _selection;
  OverlayEntry? _toolbarEntry;
  ({int start, int end})? _savedRange;

  @override
  void didUpdateWidget(covariant HighlightableText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text ||
        oldWidget.highlightKey != widget.highlightKey) {
      _selection = null;
      _savedRange = null;
      _removeToolbar();
    }
  }

  @override
  void dispose() {
    _removeToolbar();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SelectableText.rich(
      _buildSpan(),
      onSelectionChanged: _onSelectionChanged,
      contextMenuBuilder: (context, editableTextState) =>
          const SizedBox.shrink(),
    );
  }

  void _onSelectionChanged(
    TextSelection selection,
    SelectionChangedCause? cause,
  ) {
    _selection = selection;
    final range = _selectedRange();
    if (range != null) {
      _savedRange = range;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _savedRange != null) _showToolbarOverlay();
      });
      return;
    }
    Future<void>.delayed(const Duration(milliseconds: 150), () {
      if (!mounted || _selectedRange() != null) return;
      _removeToolbar();
    });
  }

  void _showToolbarOverlay() {
    final previousOwner = _activeToolbarOwner;
    if (previousOwner != null && previousOwner != this) {
      previousOwner._dismissToolbar();
    }
    _removeToolbar();
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize || !renderBox.attached) return;
    final overlay = Overlay.of(context);

    _toolbarEntry = OverlayEntry(
      builder: (overlayContext) {
        final box = context.findRenderObject() as RenderBox?;
        if (box == null || !box.hasSize || !box.attached) {
          return const SizedBox.shrink();
        }
        final screenSize = MediaQuery.sizeOf(overlayContext);
        final topLeft = box.localToGlobal(Offset.zero);
        final toolbarWidth = (screenSize.width - 16)
            .clamp(240.0, 348.0)
            .toDouble();
        const toolbarHeight = 46.0;
        final left = (topLeft.dx + box.size.width / 2 - toolbarWidth / 2)
            .clamp(8.0, screenSize.width - toolbarWidth - 8)
            .toDouble();
        final top = (topLeft.dy - toolbarHeight - 6)
            .clamp(8.0, screenSize.height - toolbarHeight - 8)
            .toDouble();

        return Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _dismissToolbar,
              ),
            ),
            Positioned(
              left: left,
              top: top,
              width: toolbarWidth,
              child: Material(
                elevation: 10,
                color: const Color(0xFF30343B),
                borderRadius: BorderRadius.circular(8),
                clipBehavior: Clip.antiAlias,
                child: SizedBox(
                  height: toolbarHeight,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Row(
                      children: [
                        for (final color in _colors)
                          _ToolbarColorButton(
                            color: color,
                            onPressed: () => _applyFromSaved(color: color),
                          ),
                        _ToolbarIconButton(
                          icon: Icons.format_bold_rounded,
                          tooltip: 'In đậm',
                          onPressed: () => _applyFromSaved(
                            bold: !(_markForSaved()?.bold ?? false),
                          ),
                        ),
                        _ToolbarIconButton(
                          icon: Icons.format_italic_rounded,
                          tooltip: 'In nghiêng',
                          onPressed: () => _applyFromSaved(
                            italic: !(_markForSaved()?.italic ?? false),
                          ),
                        ),
                        _ToolbarIconButton(
                          icon: Icons.format_underlined_rounded,
                          tooltip: 'Gạch chân',
                          onPressed: () => _applyFromSaved(
                            underline: !(_markForSaved()?.underline ?? false),
                          ),
                        ),
                        if (widget.onAddVocabulary != null)
                          _ToolbarIconButton(
                            icon: Icons.add_rounded,
                            tooltip: 'Thêm từ vựng',
                            onPressed: _addVocabularyFromSaved,
                          ),
                        _ToolbarIconButton(
                          icon: Icons.delete_outline_rounded,
                          tooltip: 'Xóa highlight',
                          onPressed: _clearFromSaved,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
    overlay.insert(_toolbarEntry!);
    _activeToolbarOwner = this;
  }

  TextHighlightMark? _markForSaved() {
    final range = _savedRange;
    if (range == null) return null;
    for (final mark in HighlightStore.instance.get(widget.highlightKey)) {
      if (mark.overlaps(range.start, range.end)) return mark;
    }
    return null;
  }

  void _applyFromSaved({
    Color? color,
    bool? bold,
    bool? italic,
    bool? underline,
  }) {
    final range = _savedRange;
    if (range == null) return;
    final existing = _markForSaved();
    final marks = HighlightStore.instance.get(widget.highlightKey).toList()
      ..removeWhere((mark) => mark.overlaps(range.start, range.end))
      ..add(
        TextHighlightMark(
          start: range.start,
          end: range.end,
          color: color ?? existing?.color ?? _colors.last,
          bold: bold ?? existing?.bold ?? false,
          italic: italic ?? existing?.italic ?? false,
          underline: underline ?? existing?.underline ?? false,
        ),
      )
      ..sort((left, right) => left.start.compareTo(right.start));
    unawaited(HighlightStore.instance.set(widget.highlightKey, marks));
    _removeToolbar();
    setState(() {});
  }

  void _addVocabularyFromSaved() {
    final range = _savedRange;
    if (range == null || widget.onAddVocabulary == null) return;
    final selectedText = widget.text.substring(range.start, range.end).trim();
    if (selectedText.isEmpty) return;
    _applyFromSaved(color: _colors.last);
    unawaited(widget.onAddVocabulary!(selectedText));
  }

  void _clearFromSaved() {
    final range = _savedRange;
    if (range == null) return;
    final marks = HighlightStore.instance
        .get(widget.highlightKey)
        .where((mark) => !mark.overlaps(range.start, range.end))
        .toList();
    unawaited(HighlightStore.instance.set(widget.highlightKey, marks));
    _removeToolbar();
    setState(() {});
  }

  void _removeToolbar() {
    final entry = _toolbarEntry;
    _toolbarEntry = null;
    if (entry != null) {
      entry.remove();
      entry.dispose();
    }
    if (_activeToolbarOwner == this) _activeToolbarOwner = null;
  }

  void _dismissToolbar() {
    _selection = null;
    _savedRange = null;
    _removeToolbar();
  }

  ({int start, int end})? _selectedRange() {
    final selection = _selection;
    if (selection == null || !selection.isValid || selection.isCollapsed) {
      return null;
    }
    final base = selection.baseOffset.clamp(0, widget.text.length).toInt();
    final extent = selection.extentOffset.clamp(0, widget.text.length).toInt();
    final start = base < extent ? base : extent;
    final end = base < extent ? extent : base;
    return start < end ? (start: start, end: end) : null;
  }

  TextSpan _buildSpan() {
    final marks = HighlightStore.instance.get(widget.highlightKey).toList()
      ..sort((left, right) => left.start.compareTo(right.start));
    final children = <InlineSpan>[];
    var cursor = 0;
    for (final mark in marks) {
      final start = mark.start.clamp(0, widget.text.length).toInt();
      final end = mark.end.clamp(0, widget.text.length).toInt();
      if (start >= end || start < cursor) continue;
      if (cursor < start) {
        children.add(TextSpan(text: widget.text.substring(cursor, start)));
      }
      children.add(
        TextSpan(
          text: widget.text.substring(start, end),
          style: TextStyle(
            color: AppColors.darkBlue,
            backgroundColor: mark.color.withValues(alpha: 0.72),
            fontWeight: mark.bold ? FontWeight.w800 : null,
            fontStyle: mark.italic ? FontStyle.italic : null,
            decoration: mark.underline ? TextDecoration.underline : null,
            decorationColor: AppColors.darkBlue,
            decorationThickness: 1.6,
          ),
        ),
      );
      cursor = end;
    }
    if (cursor < widget.text.length) {
      children.add(TextSpan(text: widget.text.substring(cursor)));
    }
    return TextSpan(style: widget.style, children: children);
  }
}

class _ToolbarIconButton extends StatelessWidget {
  const _ToolbarIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: SizedBox(
          width: 34,
          height: 40,
          child: Center(child: Icon(icon, size: 19, color: AppColors.white)),
        ),
      ),
    );
  }
}

class _ToolbarColorButton extends StatelessWidget {
  const _ToolbarColorButton({required this.color, required this.onPressed});

  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Tô màu',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: SizedBox(
          width: 28,
          height: 40,
          child: Center(
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(3),
                border: Border.all(color: AppColors.white, width: 0.8),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
