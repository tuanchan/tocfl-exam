import 'dart:async';

import 'package:flutter/material.dart';

import 'app_theme.dart';

enum AppToastTone { info, success, warning, error }

abstract final class AppToast {
  static OverlayEntry? _entry;
  static GlobalKey<_AppToastCardState>? _cardKey;

  static void show(
    BuildContext context,
    String message, {
    AppToastTone tone = AppToastTone.info,
    Duration duration = const Duration(seconds: 4),
  }) {
    _removeImmediately();
    final overlay = Overlay.of(context, rootOverlay: true);
    final key = GlobalKey<_AppToastCardState>();
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (overlayContext) {
        final media = MediaQuery.of(overlayContext);
        final compact = media.size.width < 430;
        return Positioned(
          top: media.padding.top + 14,
          right: 14,
          left: compact ? 14 : null,
          child: Align(
            alignment: Alignment.topRight,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 390),
              child: _AppToastCard(
                key: key,
                message: message,
                tone: tone,
                duration: duration,
                onDismissed: () => _remove(entry),
              ),
            ),
          ),
        );
      },
    );
    _entry = entry;
    _cardKey = key;
    overlay.insert(entry);
  }

  static void dismiss() {
    final state = _cardKey?.currentState;
    if (state == null) {
      _removeImmediately();
    } else {
      state.dismiss();
    }
  }

  static void _remove(OverlayEntry entry) {
    if (!identical(_entry, entry)) return;
    _entry = null;
    _cardKey = null;
    entry.remove();
  }

  static void _removeImmediately() {
    final entry = _entry;
    _entry = null;
    _cardKey = null;
    entry?.remove();
  }
}

class _AppToastCard extends StatefulWidget {
  const _AppToastCard({
    super.key,
    required this.message,
    required this.tone,
    required this.duration,
    required this.onDismissed,
  });

  final String message;
  final AppToastTone tone;
  final Duration duration;
  final VoidCallback onDismissed;

  @override
  State<_AppToastCard> createState() => _AppToastCardState();
}

class _AppToastCardState extends State<_AppToastCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slide;
  Timer? _timer;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
      reverseDuration: const Duration(milliseconds: 180),
    );
    final curved = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _slide = Tween<Offset>(
      begin: const Offset(1.15, 0),
      end: Offset.zero,
    ).animate(curved);
    _controller.forward();
    _timer = Timer(widget.duration, dismiss);
  }

  Future<void> dismiss() async {
    if (_closing || !mounted) return;
    _closing = true;
    _timer?.cancel();
    try {
      await _controller.reverse();
    } on TickerCanceled {
      return;
    }
    if (mounted) widget.onDismissed();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = switch (widget.tone) {
      AppToastTone.info => AppColors.blue,
      AppToastTone.success => const Color(0xFF218739),
      AppToastTone.warning => const Color(0xFFE17A00),
      AppToastTone.error => AppColors.red,
    };
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      label: '${widget.message}. Chạm để đóng thông báo.',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: dismiss,
          child: SlideTransition(
            position: _slide,
            child: FadeTransition(
              opacity: _controller,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(14, 12, 16, 12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    border: Border(
                      left: BorderSide(color: accent, width: 5),
                      top: BorderSide(color: accent.withValues(alpha: 0.35)),
                      right: BorderSide(color: accent.withValues(alpha: 0.35)),
                      bottom: BorderSide(color: accent.withValues(alpha: 0.35)),
                    ),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.22),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Text(
                    widget.message,
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w800,
                      height: 1.35,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
