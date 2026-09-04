import 'dart:convert' show utf8;
import 'dart:math' as math;
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;

import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../ui/an_button.dart';
import '../ui/an_callout.dart';
import '../ui/icons.dart';
import '../../i18n/strings.g.dart';

/// A bounded, read-only document face for content at the API boundary. The regular editor builds one
/// rich document layout, which is the wrong primitive for a single 1 MiB paragraph. This face keeps the
/// source complete, lays out only small chunks in a lazy sliver, and makes the read-only tradeoff explicit.
/// 大文档的有界只读脸:1 MiB 单段正文不再进入一个巨型富文本布局;源文完整保留,小块惰性排版,并明确说明只读取舍。
class AnLargeDocumentPreview extends StatefulWidget {
  const AnLargeDocumentPreview({required this.markdown, super.key});

  static const int maxInlineBytes = 1 << 20;

  final String markdown;

  /// The backend accepts at most this many UTF-8 bytes. The equality case is valid on the wire but is
  /// still too large for the rich editor's single-layout path, so it uses this safe preview face too.
  /// 后端按 UTF-8 bytes 限制;等于上限在 API 合法,但仍不适合富文本单布局,故也走安全预览。
  static bool requiresBoundedPreview(String markdown) =>
      utf8.encode(markdown).length >= maxInlineBytes;

  /// Split without inventing or removing bytes. Prefer a line boundary, but a giant unbroken line is
  /// cut at the cap so no individual render object receives an unbounded string.
  /// 不增删源文切块:优先在换行处切;巨型无换行行则按帽切,保证单个 render object 不收巨串。
  @visibleForTesting
  static List<String> chunksOf(String text, {int maxChars = AnCap.window}) {
    if (maxChars <= 0) throw ArgumentError.value(maxChars, 'maxChars');
    if (text.isEmpty) return const [''];

    final chunks = <String>[];
    var start = 0;
    while (start < text.length) {
      var end = math.min(start + maxChars, text.length);
      if (end < text.length) {
        final lineEnd = text.lastIndexOf('\n', end - 1);
        if (lineEnd >= start) end = lineEnd + 1;
      }
      chunks.add(text.substring(start, end));
      start = end;
    }
    return chunks;
  }

  @override
  State<AnLargeDocumentPreview> createState() => _AnLargeDocumentPreviewState();
}

class _AnLargeDocumentPreviewState extends State<AnLargeDocumentPreview> {
  late List<String> _chunks;
  bool _copied = false;
  bool _copyFailed = false;
  Timer? _copyTimer;

  @override
  void initState() {
    super.initState();
    _chunks = AnLargeDocumentPreview.chunksOf(widget.markdown);
  }

  @override
  void didUpdateWidget(covariant AnLargeDocumentPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.markdown != widget.markdown) {
      _chunks = AnLargeDocumentPreview.chunksOf(widget.markdown);
      _copied = false;
      _copyFailed = false;
    }
  }

  @override
  void dispose() {
    _copyTimer?.cancel();
    super.dispose();
  }

  Future<void> _copyAll() async {
    try {
      await Clipboard.setData(ClipboardData(text: widget.markdown));
      if (!mounted) return;
      setState(() {
        _copied = true;
        _copyFailed = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _copied = false;
        _copyFailed = true;
      });
    }
    _copyTimer?.cancel();
    _copyTimer = Timer(AnMotion.dwell, () {
      if (!mounted) return;
      setState(() {
        _copied = false;
        _copyFailed = false;
      });
    });
  }

  Widget _header(BuildContext context) {
    final t = context.t;
    final label = _copied
        ? t.feedback.copied
        : (_copyFailed ? t.feedback.copyFailed : t.library.documentCopyAll);
    return Padding(
      padding: const EdgeInsets.only(bottom: AnGap.block),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AnCallout(
            t.library.documentTooLargeHint,
            title: t.library.documentTooLargeTitle,
            severity: AnCalloutSeverity.info,
          ),
          const SizedBox(height: AnGap.inlineLoose),
          Align(
            alignment: Alignment.centerLeft,
            child: AnButton(
              label: label,
              icon: _copied ? AnIcons.check : AnIcons.copy,
              size: AnButtonSize.sm,
              outline: true,
              onPressed: _copyAll,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        if (index == 0) return _header(context);
        final chunk = _chunks[index - 1];
        return Text(
          chunk,
          style: AnText.reading.copyWith(color: c.ink),
          textDirection: Directionality.of(context),
        );
      }, childCount: _chunks.length + 1),
    );
  }
}
