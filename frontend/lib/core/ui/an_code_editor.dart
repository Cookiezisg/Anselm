import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../i18n/strings.g.dart';
import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import 'an_button.dart';
import 'an_code_surface.dart';
import 'an_term_viewport.dart';
import 'an_tooltip.dart';
import 'icons.dart';
import 'syntax_highlighter.dart';

/// E1 — the one code block / light-editing primitive (WRK-040 G5.1). Default = a framed editor block:
/// single frame (border + radius, no inner rules) + compact bar (copy / wrap / edit · language label,
/// normalized case) + line-number gutter + syntax highlight (via the ONE [highlightCode] tokenizer).
/// `inline` degrades to a frameless inline highlight slab (no bar/frame/gutter — e.g. a version-diff
/// row or run-terminal args). Read-only (default) or editable (`editable`).
///
/// Editing is NOT a transparent textarea over a highlighted `<pre>` (the demo's web trick, whose
/// pixel-perfect overlay alignment was WRK-040's #1 HIGH risk) — Flutter's native mechanism is a
/// custom [TextEditingController] whose [TextEditingController.buildTextSpan] returns the highlight
/// spans, so the field renders coloured text itself: cursor, selection, scroll all native, NO overlay
/// to misalign (principle #8 — the framework's mechanism over a hand-rolled overlay). Read-only uses
/// [SelectableText.rich]. Both colour through the SAME [highlightCode] (唯一高亮源 铁律). A package
/// (re_editor) was evaluated and rejected: it owns its highlighting (re_highlight), which would fork
/// the tokenizer + drop CEL + need a separate theme — conflicting with the locked single-tokenizer
/// decision.
///
/// CONTENT-HEIGHT: grows to fit the code; the PARENT (AnPage / AnInspector) scrolls vertically.
/// Read-only non-wrap scrolls HORIZONTALLY internally. Edit mode soft-wraps (a TextField can't cleanly
/// no-wrap + h-scroll; the inline-editable case is short, full-code edit is rare — v1 simplification).
///
/// PERFORMANCE: one [RenderParagraph] (no virtualization — a Flutter limit) + a full re-[highlightCode]
/// per keystroke, so this targets light editing / short snippets (function bodies, CEL, schema). For
/// huge files (>~5000 lines) virtualize/truncate upstream (WRK-040 §9). 无虚拟化 + 每键全量高亮:面向轻编辑/短片段。
///
/// E1——唯一代码块/轻编辑原语。默认框编辑器(单框 + 顶栏 copy/wrap/edit + 语言标签 + 行号 + 高亮);inline 退化为无框内联板。
/// 编辑**不用透明叠层**(demo web 技巧、叠层对齐是 WRK-040 #1 HIGH)——用 Flutter 原生:自定义 TextEditingController 的
/// buildTextSpan 返回高亮 span,field 自渲染着色文本(光标/选区/滚动全原生、零叠层,#8)。read-only 用 SelectableText.rich。
/// 两路同走 highlightCode(唯一高亮源)。re_editor 已评估否决(自带 re_highlight、与单 tokenizer 决策冲突)。内容高、父滚动。
class AnCodeEditor extends StatefulWidget {
  /// The bar + top-padding chrome height — an input to [collapsedHeightFor] only, kept PRIVATE so the
  /// collapse arithmetic has ONE public door (the line-count API) and can't be half-rebuilt in feature
  /// code (WRK-066 B-002). Lockstep with [_bar]/[_area] paddings.
  /// 栏+顶内距 chrome 高——只作 [collapsedHeightFor] 内部输入;收合算术只留一扇公有门(行数 API),
  /// 业务层无从重拼一半。与 bar/area 内距同步。
  static const double _chromeHeight = 44;

  /// Collapsed height for wrapping this editor in an [AnFadeCollapse] around a known line count:
  /// lines × the code face's line box + chrome. The geometry lives HERE — the family head owns its
  /// own line-box arithmetic (WRK-066 B-002); features state a line count, never re-derive font math.
  /// Pass the SAME [reading] the wrapped editor instance gets (the two faces differ in line box).
  /// 收合高度=行数×代码面行盒+chrome。几何归族头(B-002):业务层只说行数、不重推字体算术;
  /// [reading] 须与被包实例同值(两档行盒不同)。
  static double collapsedHeightFor(int lines, {bool reading = false}) {
    final face = reading ? AnText.codeReading : AnText.code;
    return lines * face.fontSize! * face.height! + _chromeHeight;
  }

  const AnCodeEditor({
    required this.code,
    this.lang,
    this.editable = false,
    this.inline = false,
    this.compact = false,
    this.wrap = false,
    this.reading = false,
    this.live = false,
    this.seamless = false,
    this.maxHeight,
    this.onChanged,
    this.onInput,
    this.copyPayload,
    super.key,
  });

  /// The source text (display value; the source of truth when not editing). 源文本(非编辑态即真相)。
  final String code;

  /// Read-only override for what the COPY action puts on the clipboard — use when [code] is a capped
  /// DISPLAY value but copy should carry the full untruncated content (e.g. the Write tool card).
  /// Null = copy the displayed [code]. Ignored while editing. 复制载荷覆盖(显示截断但复制全量时用)。
  final String? copyPayload;

  /// Language key (e.g. `py` / `cel` / `json`) — sets the bar label; v1 tokenization is unified. 语言键。
  final String? lang;

  /// Editable → a pencil enters edit mode (non-inline) or always-edit (inline). 可编辑。
  final bool editable;

  /// Inline → frameless inline highlight slab (no bar / frame / gutter). 内联无框。
  final bool inline;

  /// Compact → tighter vertical padding. 紧凑。
  final bool compact;

  /// Wrap → soft-wrap long lines instead of horizontal scroll (read-only). 自动换行(只读)。
  final bool wrap;

  /// CONTENT-tier code (mono 13/1.6, [AnText.codeReading]) — code the person READS inside the 15
  /// column: markdown/doc fenced blocks, entity source/prompt blocks. Machine windows (tool cards,
  /// terminal twins) keep the default [AnText.code] 12. Gutter and code area switch TOGETHER (they
  /// share the token so line numbers stay row-aligned — WRK-040 §4). 内容档代码(13/1.6):15 列里人读
  /// 的代码;机器窗守默认 12。行号槽与代码区同切(共 token 保行对齐)。
  final bool reading;

  /// LIVE face (WRK-066 族二 · 2026-07-11 拍板): the SAME frame/bar/gutter/highlighting — FULL content
  /// inside a bounded stick-to-bottom viewport ([AnStickViewport]: everything present, scrollable,
  /// pinned to the newest line while streaming; a transcript row never owns an unbounded wall).
  /// live→settled is a ZERO-jump swap in HEIGHT and chrome: same shell, same highlight, same line
  /// numbers, same tier. The settled viewport rests at the TOP (archive reading order) — a recorded
  /// decree, not an accident (批2 复审: «un-pin» alone would imply the offset survives; it does not,
  /// the archive starts at line 1). Ignored when [inline] or [editable].
  /// 活脸(族二 · 拍板):同框同栏同行号同高亮——**全量内容**装有界贴底视口(AnStickViewport:全在、可滚、
  /// 流入期钉底跟最新行;transcript 行不背无界墙)。live→settled **高度与 chrome 零跳变**;落定视口
  /// 静置于顶(档案从第 1 行读起——记录在案的裁决,批2 复审)。inline/editable 下忽略。
  final bool live;

  /// Seamless → a FRAMED editor is ALWAYS live-edit in place: click lands the caret, type immediately,
  /// NO pencil / Cancel / Save — while keeping the frame + gutter + copy + language label + highlight.
  /// Requires [editable] && !inline && !live. Edits stream out per keystroke via [onInput]; an external
  /// [code] change is adopted only when the field is unfocused (two-way sync, no cursor jump). For the
  /// document editor's embedded code block (the one substrate that can match entities/function's gutter).
  /// seamless → 有框编辑器常驻直接编辑:点即光标、直接打字、无铅笔/存/取消,但保留框+gutter+copy+语言标+高亮;
  /// 需 editable & !inline & !live;编辑经 onInput 逐键流出,外部 code 仅失焦时采纳(两向同步不跳光标)。供文档编辑器嵌入代码块。
  final bool seamless;

  /// Bounded viewport for BOTH faces (an [AnSize] tier, e.g. [AnSize.codeViewport]) — the zero-jump
  /// contract (拍板 #2): a transcript consumer passes the SAME tier for live and settled, so the
  /// settle only un-pins the viewport, never changes the height. null = content height when the
  /// parent is unbounded (entity pages). live defaults to [AnSize.codeViewport] when null (a
  /// transcript row never owns an unbounded wall).
  /// 双脸同钳的有界视口(AnSize 档):transcript 消费方两脸传同档 → 落定只解除钉底、高度零跳变;
  /// null=无界父下内容高(实体页)。live 期 null 时兜底 codeViewport(transcript 行不背无界墙)。
  final double? maxHeight;

  /// Commit callback (demo `an-change`) — fired on Save with the edited text. 保存提交。
  final ValueChanged<String>? onChanged;

  /// Per-keystroke callback (demo `an-input`). 逐键输入。
  final ValueChanged<String>? onInput;

  @override
  State<AnCodeEditor> createState() => _AnCodeEditorState();
}

class _AnCodeEditorState extends State<AnCodeEditor> {
  late bool _wrap;
  bool _editing = false;
  bool _copied = false;
  bool _copyFailed = false;
  Timer? _copyTimer;
  _HighlightController? _controller;
  String _lastEditText = '';
  final FocusNode _editFocus = FocusNode(debugLabel: 'AnCodeEditor');

  // Inline + editable = always editing (e.g. run-terminal args, no bar). inline 可编辑=常驻编辑。
  bool get _inlineEdit => widget.inline && widget.editable;
  // FRAMED + always-editing in place (no pencil, no Cancel/Save) — for the document editor's embedded code
  // block: click lands the caret, type immediately, but keep the full frame + gutter + copy + language
  // label. Requires editable & !inline & !live. 有框常驻直接编辑(无铅笔/存取消),供文档编辑器嵌入的代码块:
  // 点即光标、直接打字,但保留框+gutter+copy+语言标。
  bool get _seamlessEdit =>
      widget.seamless && widget.editable && !widget.inline && !widget.live;
  bool get _isEditing => _inlineEdit || _seamlessEdit || _editing;

  // Per-widget highlight memo (C-012/013): the read-only faces re-run the full tokenizer every build, and
  // a settled code card re-renders on the 1s ticker + inside live turns → a large file re-highlights every
  // frame. Cache the spans on (code, colors); recompute only when either changes. Per-State (no global
  // thrash): live streaming naturally re-highlights the growing code (cache miss = same cost as before).
  // 逐组件高亮记忆化:只读脸每 build 重跑 tokenizer,settled 卡随 ticker/live 回合重建→大文件逐帧重高亮;
  // 按 (code,colors) 缓存,变才重算;per-State(无全局 thrash),流式增长码自然 miss=原成本。
  List<TextSpan>? _spanCache;
  String? _spanCode;
  SyntaxColors? _spanColors;

  List<TextSpan> _highlight(String code, SyntaxColors colors) {
    if (_spanCache != null &&
        _spanCode == code &&
        identical(_spanColors, colors)) {
      return _spanCache!;
    }
    final spans = highlightCode(code, lang: widget.lang, colors: colors);
    _spanCache = spans;
    _spanCode = code;
    _spanColors = colors;
    return spans;
  }

  @override
  void initState() {
    super.initState();
    _wrap = widget.wrap;
    // Seamless/inline editors are live from mount — attach the controller up front. Do NOT requestFocus
    // (unlike _enterEdit): a native click lands the caret; auto-focus would steal focus/scroll on mount
    // (e.g. many code blocks in one document). seamless/inline 挂载即活;不 requestFocus(点击落光标,自动夺焦会抢滚动)。
    if (_inlineEdit || _seamlessEdit) _attachController(widget.code);
  }

  // Create the edit controller + listen so the gutter line numbers and the a11y line count stay in
  // sync with every keystroke (the demo's per-input repaint of lineNos; State.build owns both). The
  // listener also routes per-keystroke + programmatic (Tab) changes to onInput — ONE text path.
  // 建编辑控制器并监听:行号 + a11y 行数随每次键入刷新(demo 的逐输入 repaint);文本变化统一经此回调 onInput。
  void _attachController(String text) {
    _controller = _HighlightController(lang: widget.lang, text: text);
    _lastEditText = text;
    _controller!.addListener(_onEditChanged);
  }

  void _onEditChanged() {
    final t = _controller?.text ?? '';
    final textChanged = t != _lastEditText;
    _lastEditText = t;
    if (mounted) {
      setState(
        () {},
      ); // gutter + a11y label recompute (cursor preserved by the controller) 重算行号/a11y
    }
    if (textChanged) widget.onInput?.call(t);
  }

  @override
  void didUpdateWidget(AnCodeEditor old) {
    super.didUpdateWidget(old);
    // Keep the (inline-)edit controller's language in sync; do NOT clobber its text (user owns it
    // while editing — streaming targets the read-only path via `code`). 同步语言、不动用户编辑中的文本。
    if (old.lang != widget.lang) _controller?.lang = widget.lang;
    // Seamless two-way sync: while the field is FOCUSED the user owns the text (edits flow OUT via
    // onInput); an external/programmatic `code` change is adopted only when the field is UNFOCUSED — no
    // cursor jump, no feedback loop with the write-back. seamless 两向同步:有焦点时用户为准(edits 经 onInput 出);
    // 外部 code 变化仅在失焦时采纳,不跳光标、不与写回成环。
    if (_seamlessEdit &&
        _controller != null &&
        !_editFocus.hasFocus &&
        old.code != widget.code &&
        _controller!.text != widget.code) {
      _controller!.value = TextEditingValue(
        text: widget.code,
        selection: TextSelection.collapsed(offset: widget.code.length),
      );
      _lastEditText = widget.code;
    }
  }

  @override
  void dispose() {
    _copyTimer?.cancel();
    _controller?.removeListener(_onEditChanged);
    _controller?.dispose();
    _editFocus.dispose();
    super.dispose();
  }

  String get _currentText =>
      _isEditing ? (_controller?.text ?? widget.code) : widget.code;
  int get _lineCount => '\n'.allMatches(_currentText).length + 1;

  // ── bar actions ──
  void _copy() {
    // Editing → copy the live edited text; else copy the full-content override if given, else the display.
    final payload = _isEditing
        ? _currentText
        : (widget.copyPayload ?? widget.code);
    Clipboard.setData(ClipboardData(text: payload)).then(
      (_) {
        if (!mounted) return;
        setState(() {
          _copied = true;
          _copyFailed = false;
        });
        _resetCopyAfterDelay();
      },
      onError: (_) {
        // No-permission / insecure context → flag failure honestly (don't claim success). 失败如实标记、不谎报。
        if (!mounted) return;
        setState(() {
          _copyFailed = true;
          _copied = false;
        });
        _resetCopyAfterDelay();
      },
    );
  }

  void _resetCopyAfterDelay() {
    _copyTimer?.cancel();
    // Bar isomorphism (复审 #38): the ✓ dwell is the ONE AnMotion tier, same as AnVersionDiff/AnChip.
    // bar 同构:✓ 驻留走唯一 AnMotion 档,与 diff/chip 一致。
    _copyTimer = Timer(AnMotion.dwell, () {
      if (mounted) {
        setState(() {
          _copied = false;
          _copyFailed = false;
        });
      }
    });
  }

  void _toggleWrap() => setState(() => _wrap = !_wrap);

  void _enterEdit() {
    setState(() {
      _attachController(widget.code);
      _editing = true;
    });
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _editFocus.requestFocus(),
    );
  }

  void _save() {
    final v = _controller?.text ?? widget.code;
    setState(() => _editing = false);
    _disposeController();
    widget.onChanged?.call(v);
  }

  void _cancel() {
    setState(() => _editing = false);
    _disposeController();
  }

  void _disposeController() {
    // Defer so the current frame's field (still mounted this build) keeps its controller. 延后释放。
    final c = _controller;
    _controller = null;
    c?.removeListener(_onEditChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => c?.dispose());
  }

  // Tab inserts 4 spaces at the selection instead of leaving the field (demo code-editor.js). The
  // controller listener picks up the value change → gutter + onInput. Tab→4 空格(同 demo),listener 已处理后续。
  void _insertTab() {
    final c = _controller;
    if (c == null) return;
    final start = c.selection.start < 0 ? c.text.length : c.selection.start;
    final end = c.selection.end < 0 ? c.text.length : c.selection.end;
    c.value = TextEditingValue(
      text: c.text.replaceRange(start, end, '    '),
      selection: TextSelection.collapsed(offset: start + 4),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.inline) return _inlineBody(context);
    if (widget.live && !widget.editable) return _framedLive(context);
    return _framed(context);
  }

  // ── live O(tail) slice (批2 复审防线): the head owns its per-frame bound — materialize only the
  // last [AnCap.window] chars (aligned to a line start) for highlight+layout; gutter numbers stay
  // HONEST via an incremental head-line count (append-only streams advance O(delta)). A SOURCE SWAP
  // (an in-flight→close snapshot whose bytes differ, a shrink) is caught by O(1) sampled probes into
  // the counted head — any mismatch recounts from scratch (批2 复审: the cut-only guard missed
  // same-State replacements and minted fake line numbers). 活脸切尾:族头自扛每帧上界——只物化最后
  // AnCap.window 字符(对齐行首),行号增量头行计数(追加流 O(delta));换源(在途→close 快照字节不同/缩短)
  // 由 O(1) 头部采样探针识破,任一失配即全量重算(批2 复审:仅比切点的守卫漏掉同 State 整替、铸假行号)。──
  int _liveHeadChars = 0;
  int _liveHeadLines = 0;
  int _livePrevLen = 0;
  final List<(int, int)> _liveProbes =
      []; // sampled (index, codeUnit) inside the counted head 头部采样

  bool _headStillSame(String code) {
    if (code.length < _livePrevLen) return false; // raw shrink = swap 裸缩短即换源
    for (final (i, u) in _liveProbes) {
      if (i >= code.length || code.codeUnitAt(i) != u) return false;
    }
    return true;
  }

  void _resetLiveCount() {
    _liveHeadChars = 0;
    _liveHeadLines = 0;
    _liveProbes.clear();
  }

  String _liveSlice(String code) {
    if (code.length <= AnCap.window) {
      _resetLiveCount();
      _livePrevLen = code.length;
      return code;
    }
    if (!_headStillSame(code)) _resetLiveCount();
    _livePrevLen = code.length;
    var cut = code.length - AnCap.window;
    final nl = code.indexOf('\n', cut);
    // A single giant line keeps the raw char cut (the cap is the real bound; mid-line is overwritten
    // by the next delta's re-slice). 单巨行保持裸切(帽兜底)。
    if (nl >= 0 && nl + 1 < code.length) cut = nl + 1;
    if (cut < _liveHeadChars) _resetLiveCount();
    var added = 0;
    for (var i = _liveHeadChars; i < cut; i++) {
      if (code.codeUnitAt(i) == 0x0A) added++;
    }
    if (cut > _liveHeadChars) {
      // Sample the newly counted span (≤2 probes per advance, list stays small: the head only
      // advances ~once per delta). 对新计入区采样(每次推进 ≤2 探针)。
      _liveProbes.add((_liveHeadChars, code.codeUnitAt(_liveHeadChars)));
      _liveProbes.add((cut - 1, code.codeUnitAt(cut - 1)));
      if (_liveProbes.length > 64) {
        _liveProbes.removeRange(0, _liveProbes.length - 64);
      }
    }
    _liveHeadChars = cut;
    _liveHeadLines += added;
    return code.substring(cut);
  }

  // ── live face (拍板): FULL content + highlight + gutter in a bounded stick-to-bottom viewport —
  // the SAME body as settled, pinned to the newest line. 活脸:全量+高亮+行号,有界贴底视口钉最新行。──
  Widget _framedLive(BuildContext context) {
    final c = context.colors;
    final slice = _liveSlice(widget.code);
    final sliceLines = '\n'.allMatches(slice).length + 1;
    final lines = _liveHeadLines + sliceLines; // honest total 诚实总行数
    final bodyRow = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Gutter numbers continue from the sliced head — an honest continuation cue (line 847 says
        // «there is more above» without a note). 行号从被切头部续排——诚实的延续线索。
        _gutter(c, sliceLines, startLine: _liveHeadLines + 1),
        Expanded(child: _area(context, c, codeOverride: slice)),
      ],
    );
    return Semantics(
      container: true,
      label: _a11yLabel(context, lines),
      child: AnCodeSurface(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _bar(context, c),
            // White-face fades (拍板 #1 灰底退役) + the shared viewport tier. 白面渐隐+共享视口档。
            AnStickViewport(
              maxHeight: widget.maxHeight ?? AnSize.codeViewport,
              fadeColor: c.surface,
              child: bodyRow,
            ),
          ],
        ),
      ),
    );
  }

  // The code text style — mono code face; plain (untokenized) text is muted, tokens colour over it.
  // 代码字体样式;未着色文本走 muted、token 覆盖其上。
  TextStyle _codeStyle(AnColors c) =>
      (widget.reading ? AnText.codeReading : AnText.code).copyWith(
        color: c.inkMuted,
      );

  String _a11yLabel(BuildContext context, int lines) {
    final label = _langLabel(widget.lang);
    return label == null
        ? context.t.a11y.codeBlockPlain(lines: lines)
        : context.t.a11y.codeBlock(lang: label, lines: lines);
  }

  // ── inline (frameless) ──
  Widget _inlineBody(BuildContext context) {
    final c = context.colors;
    if (_inlineEdit) {
      return _EditField(
        controller: _controller!,
        focusNode: _editFocus,
        style: _codeStyle(c),
        ink: c.ink,
        onTab: _insertTab,
      );
    }
    return SelectableText.rich(
      TextSpan(
        style: _codeStyle(c),
        children: _highlight(widget.code, context.syntax),
      ),
    );
  }

  // ── framed editor block ──
  Widget _framed(BuildContext context) {
    final c = context.colors;
    final lines = _lineCount;
    // The zero-jump clamp (拍板 #2): with a maxHeight tier the settled face keeps the SAME bounded
    // window the live face had — the existing bounded-height branch below turns it into a fixed
    // viewport with an inner scroll. 零跳变钳:传档时落定保留 live 同款有界窗(下方有界分支变内滚视口)。
    final bodyRow = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _gutter(c, lines),
        Expanded(child: _area(context, c)),
      ],
    );
    final framed = Semantics(
      container: true,
      label: _a11yLabel(context, lines),
      child: AnCodeSurface(
        focused: _editing, // accent border while editing 编辑态 accent 边
        // Content-height when the height is UNBOUNDED (a scrolling page/inspector hosts it); when the
        // frame is height-CONSTRAINED (a fixed panel, or a cell shorter than the code) the body scrolls
        // vertically while the bar stays fixed. Resolves the scroll-host dual without crashing either
        // way (WRK-040 §4). 无界=内容高(父滚动);有界=body 纵滚、bar 固定。两态都不崩。
        child: LayoutBuilder(
          builder: (ctx, constraints) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _bar(context, c),
              // The zero-jump clamp sits on the BODY — mirroring _framedLive's viewport position
              // (bar outside the clamp), so the settle only un-pins and the total height is
              // IDENTICAL across faces (批2 复审: a whole-frame clamp made settle 44px shorter).
              // In a BOUNDED host the clamp rides a Flexible so a short parent stays silent-safe
              // (批2 复审: the bare ConstrainedBox overflowed hosts shorter than bar+viewport).
              // 钳在 body(与 live 视口同位,bar 在钳外):落定仅解除钉底、两脸总高全等;有界宿主下钳
              // 骑 Flexible,矮宿主静默安全(批2 复审:裸 ConstrainedBox 曾溢出)。
              if (constraints.maxHeight.isFinite)
                Flexible(
                  child: widget.maxHeight == null
                      ? SingleChildScrollView(child: bodyRow)
                      : ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight: widget.maxHeight!,
                          ),
                          child: SingleChildScrollView(child: bodyRow),
                        ),
                )
              else if (widget.maxHeight != null)
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: widget.maxHeight!),
                  child: SingleChildScrollView(child: bodyRow),
                )
              else
                bodyRow,
            ],
          ),
        ),
      ),
    );
    return framed;
  }

  Widget _bar(BuildContext context, AnColors c) {
    final t = context.t;
    final actions = <Widget>[];
    if (_editing) {
      actions.add(
        AnButton(
          label: t.action.cancel,
          size: AnButtonSize.sm,
          onPressed: _cancel,
        ),
      );
      actions.add(const SizedBox(width: AnSpace.s4));
      actions.add(
        AnButton(
          label: t.action.save,
          size: AnButtonSize.sm,
          variant: AnButtonVariant.primary,
          onPressed: _save,
        ),
      );
    } else {
      final copyTip = _copied
          ? t.feedback.copied
          : (_copyFailed ? t.feedback.copyFailed : t.action.copy);
      actions.add(
        _barIcon(_copied ? AnIcons.check : AnIcons.copy, copyTip, _copy),
      );
      // Wrap toggle is inert while editing (the edit field always soft-wraps) — hide it in seamless.
      // seamless 下编辑区恒软换行,wrap 开关无意义,隐藏。
      if (!_seamlessEdit) {
        actions.add(const SizedBox(width: AnSpace.s4)); // demo .bar gap 4px 钮间距
        actions.add(_barIcon(AnIcons.wrap, t.action.wrap, _toggleWrap));
      }
      // The pencil ENTERS pencil-gated edit; seamless is ALWAYS editing, so no pencil. 铅笔=进编辑;seamless 常驻、无铅笔。
      if (widget.editable && !_seamlessEdit) {
        actions.add(const SizedBox(width: AnSpace.s4));
        actions.add(_barIcon(AnIcons.edit, t.action.edit, _enterEdit));
      }
    }
    final lang = _langLabel(widget.lang);
    return Padding(
      padding: const EdgeInsets.only(
        left: AnSpace.s12,
        right: AnSpace.s12,
        top: AnSpace.s8,
      ),
      child: Row(
        children: [
          ...actions,
          const Spacer(),
          // Decorative label — the language is already in the container's a11y label (avoid reading
          // "Python" twice). 装饰标签:语言已在容器 a11y label,避免念两遍。
          if (lang != null)
            ExcludeSemantics(
              child: Text(lang, style: AnText.meta.copyWith(color: c.inkFaint)),
            ),
        ],
      ),
    );
  }

  // A small icon action (copy / wrap / edit) — AnButton.iconOnly carries the a11y label + hover; a
  // Tooltip mirrors the demo's title. 小图标动作:复用 AnButton.iconOnly(带 a11y 标签 + hover)+ Tooltip。
  Widget _barIcon(IconData icon, String label, VoidCallback onTap) {
    // AnTooltip, not Material Tooltip — bar isomorphism with AnVersionDiff (复审 #38). 同构用 AnTooltip。
    return AnTooltip(
      message: label,
      child: AnButton.iconOnly(
        icon,
        size: AnButtonSize.sm,
        semanticLabel: label,
        onPressed: onTap,
      ),
    );
  }

  Widget _gutter(AnColors c, int lines, {int startLine = 1}) {
    final top = widget.compact ? AnSpace.s4 : AnSpace.s8;
    final bottom = widget.compact ? AnSpace.s4 : AnSpace.s12;
    final nums = [
      for (var i = startLine; i < startLine + lines; i++) '$i',
    ].join('\n');
    // Decorative — a screen reader shouldn't navigate to and read every line number; the line count is
    // in the container label. 装饰:屏读不该逐个念行号(行数已在容器 label)。
    return ExcludeSemantics(
      child: ConstrainedBox(
        // Floor width (>=4 digits); the mono digits right-align within. 槽下界(容 4 位数),mono 数字右对齐。
        constraints: const BoxConstraints(minWidth: AnSize.trail),
        child: Padding(
          padding: EdgeInsets.only(
            left: AnSpace.s12,
            right: AnSpace.s8,
            top: top,
            bottom: bottom,
          ),
          child: Text(
            nums,
            textAlign: TextAlign.right,
            style: (widget.reading ? AnText.codeReading : AnText.code).copyWith(
              color: c.inkFaint,
            ),
          ),
        ),
      ),
    );
  }

  Widget _area(BuildContext context, AnColors c, {String? codeOverride}) {
    final pad = EdgeInsets.only(
      left: AnSpace.s8,
      right: AnSpace.s16,
      top: widget.compact ? AnSpace.s4 : AnSpace.s8,
      bottom: widget.compact ? AnSpace.s4 : AnSpace.s12,
    );
    if (_isEditing) {
      return Padding(
        padding: pad,
        child: _EditField(
          controller: _controller!,
          focusNode: _editFocus,
          style: _codeStyle(c),
          ink: c.ink,
          onTab: _insertTab,
        ),
      );
    }
    final text = SelectableText.rich(
      TextSpan(
        style: _codeStyle(c),
        children: _highlight(codeOverride ?? widget.code, context.syntax),
      ),
    );
    // Read-only non-wrap scrolls horizontally; wrap lets the text reflow to the available width. 只读非 wrap 横滚。
    if (_wrap) return Padding(padding: pad, child: text);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: pad,
      child: text,
    );
  }
}

/// The editable code field — a [TextField] whose controller paints the highlight (no overlay). Tab is
/// trapped to indent (4 spaces) instead of moving focus out (demo behaviour); text changes flow through
/// the controller listener (gutter + onInput). 可编辑代码框:Tab 拦为缩进、文本变化经控制器 listener。
class _EditField extends StatelessWidget {
  const _EditField({
    required this.controller,
    required this.focusNode,
    required this.style,
    required this.ink,
    required this.onTab,
  });

  final _HighlightController controller;
  final FocusNode focusNode;
  final TextStyle style;

  /// The caret colour — [AnColors.ink], per the house caret law (a caret is INK, never accent: the
  /// old accent caret turned the document's code block blue mid-prose, and read as a link/selection
  /// signal). 光标色=ink(房内光标法:光标是墨、绝不 accent——旧 accent 光标让文档码块在正文中途变蓝、
  /// 且读作链接/选中信号)。
  final Color ink;
  final VoidCallback onTab;

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.tab): onTab},
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        style: style,
        cursorColor: ink,
        cursorWidth: AnSize.caret,
        // Derive the caret height from the EFFECTIVE code style (the house law: a caret hugs the style
        // it sits on, never a platform default). Left null, Flutter takes the full leaded LINE BOX and
        // then macOS adds 2 → 22.8 for the 13/1.6 reading tier: a caret 76% taller than its glyphs
        // (measured on-device), the "thunderously big caret" in the document's code blocks. It also
        // split by platform (macOS lineBox+2 vs Win/Linux lineBox−4 = 6px apart). All code faces are
        // single-size, so one derived value is exact for every line. 按有效代码样式推导光标高(房法:光标贴
        // 所在样式、绝不用平台默认)。留 null 则取整行盒、macOS 再 +2 = 13/1.6 档的 22.8——比字形高 76%
        // (真机实测),即文档码块里那根「雷霆大光标」;且跨平台差 6px。代码面单一字号,故一个派生值对每行都准。
        cursorHeight: style.fontSize! + AnSize.caretRise,
        maxLines: null,
        keyboardType: TextInputType.multiline,
        // Collapsed decoration = no underline / fill (the frame owns the chrome). 无装饰(框管外观)。
        decoration: const InputDecoration(
          isCollapsed: true,
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );
  }
}

/// A [TextEditingController] that renders syntax-highlighted spans via [buildTextSpan] — the native
/// Flutter way to colour an editable field (no transparent overlay). Reads [SyntaxColors] from the
/// context each build, so it tracks the theme automatically. 高亮控制器:buildTextSpan 原生着色、自动跟主题。
class _HighlightController extends TextEditingController {
  _HighlightController({this.lang, super.text});

  String? lang;

  // buildTextSpan runs on EVERY text OR SELECTION change (Flutter re-styles the field on caret moves too),
  // so a selection-only move used to re-tokenize the whole file (C-014). Cache the token spans on
  // (text, colors) — a caret move keeps both, so it reuses; a keystroke changes text → recompute.
  // 选区移动也触发 buildTextSpan→整文件重高亮;按 (text,colors) 缓存,移光标复用、打字才重算。
  List<TextSpan>? _spanCache;
  String? _spanText;
  SyntaxColors? _spanColors;

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    // Per-token spans; the composing-region underline is not separately drawn (v1) — the text still
    // updates live. 逐 token span;v1 不单独画输入法 composing 下划线(文本仍实时更新)。
    final colors = context.syntax;
    if (_spanCache == null ||
        _spanText != text ||
        !identical(_spanColors, colors)) {
      _spanCache = highlightCode(text, lang: lang, colors: colors);
      _spanText = text;
      _spanColors = colors;
    }
    return TextSpan(style: style, children: _spanCache);
  }
}

// Language label map — port of the demo LANG table; unknown keys title-case the raw key. 语言标签(移植 demo)。
const Map<String, String> _langLabels = {
  'py': 'Python',
  'python': 'Python',
  'js': 'JavaScript',
  'javascript': 'JavaScript',
  'ts': 'TypeScript',
  'typescript': 'TypeScript',
  'json': 'JSON',
  'md': 'Markdown',
  'markdown': 'Markdown',
  'cel': 'CEL',
  'sh': 'Shell',
  'bash': 'Shell',
  'go': 'Go',
  'sql': 'SQL',
  'html': 'HTML',
  'css': 'CSS',
  'yaml': 'YAML',
  'yml': 'YAML',
  'toml': 'TOML',
  'rs': 'Rust',
  'rust': 'Rust',
};

String? _langLabel(String? lang) {
  if (lang == null || lang.isEmpty) return null;
  final k = lang.toLowerCase();
  return _langLabels[k] ?? (lang[0].toUpperCase() + lang.substring(1));
}

/// Extension → language key for the ONE highlight/label pipeline (WRK-066 A-023: a foundation
/// capability — feature layers keep no private tables). 扩展名→语言键(地基能力,feature 禁私表)。
String? langOf(String path) {
  final dot = path.lastIndexOf('.');
  if (dot < 0 || dot >= path.length - 1) return null;
  return switch (path.substring(dot + 1).toLowerCase()) {
    'dart' => 'dart',
    'py' => 'python',
    'go' => 'go',
    'js' || 'jsx' || 'mjs' => 'javascript',
    'ts' || 'tsx' => 'typescript',
    'json' => 'json',
    'md' || 'markdown' => 'markdown',
    'sh' || 'bash' || 'zsh' => 'bash',
    'yaml' || 'yml' => 'yaml',
    'toml' => 'toml',
    'rs' => 'rust',
    'sql' => 'sql',
    'html' => 'html',
    'css' => 'css',
    _ => null,
  };
}

/// Entity kind → authored-content language (fn/handler bodies are Python; document/skill are
/// markdown; prompts/graph configs carry none). 实体 kind→内容语言(fn/hd=Python,doc/skill=markdown)。
String? langOfEntityKind(String? kind) => switch (kind) {
  'function' || 'handler' => 'python',
  'document' || 'skill' => 'markdown',
  _ => null,
};
