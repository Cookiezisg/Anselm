import 'package:flutter/material.dart';

import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import 'icons.dart';

/// A transient bottom toast (dark ink card, white text). tone colors the leading glyph.
/// Call [showAnToast]; it inserts an overlay entry that fades in, waits, fades out.
/// 短暂的底部提示(深墨卡、白字)。tone 着色行首图标。调 [showAnToast] 插入自动淡入淡出的浮层。
enum AnToastTone { neutral, ok, warn, danger }

void showAnToast(
  BuildContext context,
  String message, {
  AnToastTone tone = AnToastTone.neutral,
  Duration duration = const Duration(seconds: 3),
}) {
  final overlay = Overlay.of(context);
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (ctx) => _AnToast(
      message: message,
      tone: tone,
      duration: duration,
      onDone: () => entry.remove(),
    ),
  );
  overlay.insert(entry);
}

class _AnToast extends StatefulWidget {
  const _AnToast({
    required this.message,
    required this.tone,
    required this.duration,
    required this.onDone,
  });

  final String message;
  final AnToastTone tone;
  final Duration duration;
  final VoidCallback onDone;

  @override
  State<_AnToast> createState() => _AnToastState();
}

class _AnToastState extends State<_AnToast> with SingleTickerProviderStateMixin {
  late final AnimationController _ac =
      AnimationController(vsync: this, duration: AnMotion.mid);

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    await _ac.forward();
    await Future<void>.delayed(widget.duration);
    if (!mounted) return;
    await _ac.reverse();
    widget.onDone();
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final IconData? glyph = switch (widget.tone) {
      AnToastTone.neutral => null,
      AnToastTone.ok => AnIcons.success,
      AnToastTone.warn => AnIcons.error,
      AnToastTone.danger => AnIcons.error,
    };
    final Color glyphColor = switch (widget.tone) {
      AnToastTone.neutral => c.surface,
      AnToastTone.ok => c.ok,
      AnToastTone.warn => c.warn,
      AnToastTone.danger => c.danger,
    };
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.only(bottom: AnSpace.s32),
        child: FadeTransition(
          opacity: _ac,
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AnSpace.s16, vertical: AnSpace.s12),
              decoration: BoxDecoration(
                color: c.ink,
                borderRadius: BorderRadius.circular(AnRadius.button),
                boxShadow: c.shadowPop,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (glyph != null) ...[
                    Icon(glyph, size: AnSize.iconSm, color: glyphColor),
                    const SizedBox(width: AnSpace.s8),
                  ],
                  Text(widget.message, style: AnText.body.copyWith(color: c.surface)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
