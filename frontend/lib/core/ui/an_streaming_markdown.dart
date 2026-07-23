import 'package:flutter/widgets.dart';

import '../design/tokens.dart';
import '../design/an_fonts.dart' show AnFace;
import 'an_markdown.dart';

/// Markdown for a STREAMING (still-growing) text — the open-block answer to S9. A bare
/// [AnMarkdown] re-parses the WHOLE string on every coalesced frame (GptMarkdown is a regex
/// component walker), so a long answer streaming into one text block cost O(full text) per frame,
/// worsening linearly as it grew — the last steady-state hot path the O(tail) playbook didn't
/// cover, because prose cannot be tail-sliced naively (headings/lists/fences carry context).
///
/// The fix: text that has streamed PAST a safe paragraph boundary can never change again (deltas
/// only append), so it is committed into per-paragraph [AnMarkdown] widgets that keep their
/// IDENTITY across frames (identical instance → the element never rebuilds → GptMarkdown never
/// re-parses). Each frame parses only (a) newly settled paragraphs, once, and (b) the ACTIVE TAIL
/// segment. Total parse work over a whole answer ≈ one pass — the theoretical floor.
///
/// A "safe" boundary is a blank-line run where: the fence parity so far is EVEN (a ``` fence is
/// still open ⇒ the blank line is INSIDE code), and the next non-blank line is not indented code
/// (an indented block may span blank lines; splitting would fracture it). Segments join with the
/// same [AnFlow.block] gap AnMarkdown itself renders between blocks, so the settled swap (the
/// closed block re-renders as ONE AnMarkdown via the transcript's id cache) lands on the same
/// geometry. If the text stops being an append (a reconnect snapshot replaced it), everything
/// resets honestly.
///
/// 流式(仍在长的)文本的 markdown——open 块的 S9 答案。裸 [AnMarkdown] 每合并帧全文重解析(正则
/// 组件游走),长答案单块流入=每帧 O(全文)、随长度线性恶化——O(tail) 剧本唯一没盖住的稳态热路径
/// (prose 不能裸切尾:标题/列表/围栏带上下文)。修法:流过**安全段界**的文本永不再变(delta 只追
/// 加),提交成逐段 [AnMarkdown](实例恒同→element 不重建→不重解析);每帧只解析 (a) 新落定段一次
/// + (b) 活动尾段。整答案总解析量≈一遍,理论地板。「安全」段界=空行处且:此前围栏奇偶为偶(奇=
/// 空行在代码里)、其后首个非空行非缩进码(缩进块可跨空行,切开会碎)。段间距=AnMarkdown 自己的块
/// 距 [AnFlow.block],落定换单件渲染时几何一致。文本不再是追加(重连快照整替)→ 诚实全清重来。
class AnStreamingMarkdown extends StatefulWidget {
  const AnStreamingMarkdown(this.text, {this.prose, super.key});

  final String text;

  /// Passed through to each segment's [AnMarkdown]. 透传给每段。
  final AnFace? prose;

  @override
  State<AnStreamingMarkdown> createState() => _AnStreamingMarkdownState();
}

class _AnStreamingMarkdownState extends State<AnStreamingMarkdown> {
  final List<Widget> _settled = [];
  int _settledChars = 0;

  /// Line-leading ``` fences seen inside the settled prefix — ODD means a fence is open across the
  /// boundary and blank lines are code, not paragraph breaks. 稳定前缀内行首围栏数——奇=围栏未闭。
  int _fenceCount = 0;

  /// Append detection without an O(prefix) compare: the last 16 committed chars must still be
  /// there. A miss = the text was REPLACED (reconnect snapshot) → full reset. 追加判定探针(免
  /// O(前缀) 比较):已提交尾 16 字符仍在;失配=整替(重连快照)→全清。
  String _probe = '';

  void _reset() {
    _settled.clear();
    _settledChars = 0;
    _fenceCount = 0;
    _probe = '';
  }

  @override
  void didUpdateWidget(AnStreamingMarkdown old) {
    super.didUpdateWidget(old);
    // The cached segments captured the old face — rebuild them under the new one (a font-axis
    // flip is a rare user action; one full re-parse is fine). 缓存段捕获旧字体脸——换脸全重建。
    if (old.prose != widget.prose) _reset();
  }

  bool _isAppend(String text) {
    if (text.length < _settledChars) return false;
    final start = _settledChars - _probe.length;
    return start >= 0 && text.substring(start, _settledChars) == _probe;
  }

  static final RegExp _fenceLine = RegExp(r'^ {0,3}(```|~~~)');
  static final RegExp _indentedCode = RegExp(r'^(?: {4,}|\t)\S');

  /// Count line-leading fences inside [text] (which always starts at a line start). 数行首围栏。
  static int _fencesIn(String text) {
    var n = 0;
    var lineStart = 0;
    while (lineStart <= text.length) {
      final nl = text.indexOf('\n', lineStart);
      final line = nl < 0
          ? text.substring(lineStart)
          : text.substring(lineStart, nl);
      if (_fenceLine.hasMatch(line)) n++;
      if (nl < 0) break;
      lineStart = nl + 1;
    }
    return n;
  }

  /// The first non-blank line at/after [from]. [from] 起首个非空行。
  static String _nextContentLine(String text, int from) {
    var lineStart = from;
    while (lineStart < text.length) {
      final nl = text.indexOf('\n', lineStart);
      final line = nl < 0
          ? text.substring(lineStart)
          : text.substring(lineStart, nl);
      if (line.trim().isNotEmpty) return line;
      if (nl < 0) break;
      lineStart = nl + 1;
    }
    return '';
  }

  /// Advance the settled frontier: commit every region that has streamed past a safe paragraph
  /// boundary as ONE cached segment. 推进稳定前沿:流过安全段界的区域逐段提交缓存。
  void _advance(String text) {
    var searchFrom = _settledChars;
    while (true) {
      final brk = text.indexOf('\n\n', searchFrom);
      if (brk < 0) return;
      // Swallow the whole blank-line run; the tail resumes at content. 吃整段空行,尾从内容起。
      var after = brk + 2;
      while (after < text.length && text[after] == '\n') {
        after++;
      }
      // Never commit right up to the end — the run may still be growing (more \n incoming).
      // 不提交到最末——空行串可能还在长。
      if (after >= text.length) return;

      final candidate = text.substring(_settledChars, after);
      final fences = _fencesIn(candidate);
      final fenceOpen = (_fenceCount + fences).isOdd;
      final splitsIndentedCode = _indentedCode.hasMatch(
        _nextContentLine(text, after),
      );
      if (fenceOpen || splitsIndentedCode) {
        // Not a safe boundary — keep scanning; the candidate stays in the tail. 非安全界,继续扫。
        searchFrom = after;
        continue;
      }

      final body = candidate.trimRight();
      if (body.isNotEmpty) {
        _settled.add(
          Padding(
            // The gap AnMarkdown renders between blocks — segments must join seamlessly with the
            // settled single-widget render. 段间距=AnMarkdown 块距,与落定单件渲染无缝对齐。
            padding: const EdgeInsets.only(bottom: AnFlow.block),
            child: AnMarkdown(body, prose: widget.prose),
          ),
        );
      }
      _fenceCount += fences;
      _settledChars = after;
      _probe = text.substring(
        _settledChars < 16 ? 0 : _settledChars - 16,
        _settledChars,
      );
      searchFrom = after;
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.text;
    if (!_isAppend(text)) _reset();
    _advance(text);
    final tail = text.substring(_settledChars);
    if (_settled.isEmpty) return AnMarkdown(tail, prose: widget.prose);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ..._settled,
        if (tail.trim().isNotEmpty) AnMarkdown(tail, prose: widget.prose),
      ],
    );
  }
}
