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
  /// The bar + top-padding chrome height, exposed so consumers can compute a collapse threshold (e.g.
  /// [AnFadeCollapse] height around a known line count) without eyeballing a literal in feature code.
  /// 栏 + 顶内距 chrome 高,导出供消费方算收合阈值(围绕已知行数),免在业务层裸写魔数。
  static const double chromeHeight = 44;

  const AnCodeEditor({
    required this.code,
    this.lang,
    this.editable = false,
    this.inline = false,
    this.compact = false,
    this.wrap = false,
    this.reading = false,
    this.live = false,
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
  /// live→settled is a ZERO-jump swap: same shell, same highlight, same line numbers — the only
  /// difference is the viewport un-pins. Streaming highlight cost is handled by per-line memoization
  /// (C-track). Ignored when [inline] or [editable].
  /// 活脸(族二 · 拍板):同框同栏同行号同高亮——**全量内容**装有界贴底视口(AnStickViewport:全在、可滚、
  /// 流入期钉底跟最新行;transcript 行不背无界墙)。live→settled 零跳变(唯一区别=视口解除钉底)。流式
  /// 高亮成本走逐行记忆化(C 轨)。inline/editable 下忽略。
  final bool live;

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
  bool get _isEditing => _inlineEdit || _editing;

  @override
  void initState() {
    super.initState();
    _wrap = widget.wrap;
    if (_inlineEdit) _attachController(widget.code);
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
    if (mounted) setState(() {}); // gutter + a11y label recompute (cursor preserved by the controller) 重算行号/a11y
    if (textChanged) widget.onInput?.call(t);
  }

  @override
  void didUpdateWidget(AnCodeEditor old) {
    super.didUpdateWidget(old);
    // Keep the (inline-)edit controller's language in sync; do NOT clobber its text (user owns it
    // while editing — streaming targets the read-only path via `code`). 同步语言、不动用户编辑中的文本。
    if (old.lang != widget.lang) _controller?.lang = widget.lang;
  }

  @override
  void dispose() {
    _copyTimer?.cancel();
    _controller?.removeListener(_onEditChanged);
    _controller?.dispose();
    _editFocus.dispose();
    super.dispose();
  }

  String get _currentText => _isEditing ? (_controller?.text ?? widget.code) : widget.code;
  int get _lineCount => '\n'.allMatches(_currentText).length + 1;

  // ── bar actions ──
  void _copy() {
    // Editing → copy the live edited text; else copy the full-content override if given, else the display.
    final payload = _isEditing ? _currentText : (widget.copyPayload ?? widget.code);
    Clipboard.setData(ClipboardData(text: payload)).then((_) {
      if (!mounted) return;
      setState(() {
        _copied = true;
        _copyFailed = false;
      });
      _resetCopyAfterDelay();
    }, onError: (_) {
      // No-permission / insecure context → flag failure honestly (don't claim success). 失败如实标记、不谎报。
      if (!mounted) return;
      setState(() {
        _copyFailed = true;
        _copied = false;
      });
      _resetCopyAfterDelay();
    });
  }

  void _resetCopyAfterDelay() {
    _copyTimer?.cancel();
    _copyTimer = Timer(const Duration(milliseconds: 1200), () {
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
    WidgetsBinding.instance.addPostFrameCallback((_) => _editFocus.requestFocus());
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

  // ── live face (拍板): FULL content + highlight + gutter in a bounded stick-to-bottom viewport —
  // the SAME body as settled, pinned to the newest line. 活脸:全量+高亮+行号,有界贴底视口钉最新行。──
  Widget _framedLive(BuildContext context) {
    final c = context.colors;
    final lines = _lineCount;
    final bodyRow = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _gutter(c, lines),
        Expanded(child: _area(context, c)),
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
            AnStickViewport(child: bodyRow),
          ],
        ),
      ),
    );
  }

  // The code text style — mono code face; plain (untokenized) text is muted, tokens colour over it.
  // 代码字体样式;未着色文本走 muted、token 覆盖其上。
  TextStyle _codeStyle(AnColors c) => (widget.reading ? AnText.codeReading : AnText.code).copyWith(color: c.inkMuted);

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
      return _EditField(controller: _controller!, focusNode: _editFocus, style: _codeStyle(c), accent: c.accent, onTab: _insertTab);
    }
    return SelectableText.rich(
      TextSpan(style: _codeStyle(c), children: highlightCode(widget.code, lang: widget.lang, colors: context.syntax)),
    );
  }

  // ── framed editor block ──
  Widget _framed(BuildContext context) {
    final c = context.colors;
    final lines = _lineCount;
    final bodyRow = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _gutter(c, lines),
        Expanded(child: _area(context, c)),
      ],
    );
    return Semantics(
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
              if (constraints.maxHeight.isFinite)
                Flexible(child: SingleChildScrollView(child: bodyRow))
              else
                bodyRow,
            ],
          ),
        ),
      ),
    );
  }

  Widget _bar(BuildContext context, AnColors c) {
    final t = context.t;
    final actions = <Widget>[];
    if (_editing) {
      actions.add(AnButton(label: t.action.cancel, size: AnButtonSize.sm, onPressed: _cancel));
      actions.add(const SizedBox(width: AnSpace.s4));
      actions.add(AnButton(label: t.action.save, size: AnButtonSize.sm, variant: AnButtonVariant.primary, onPressed: _save));
    } else {
      final copyTip = _copied ? t.feedback.copied : (_copyFailed ? t.feedback.copyFailed : t.action.copy);
      actions.add(_barIcon(_copied ? AnIcons.check : AnIcons.copy, copyTip, _copy));
      actions.add(const SizedBox(width: AnSpace.s4)); // demo .bar gap 4px 钮间距
      actions.add(_barIcon(AnIcons.wrap, t.action.wrap, _toggleWrap));
      if (widget.editable) {
        actions.add(const SizedBox(width: AnSpace.s4));
        actions.add(_barIcon(AnIcons.edit, t.action.edit, _enterEdit));
      }
    }
    final lang = _langLabel(widget.lang);
    return Padding(
      padding: const EdgeInsets.only(left: AnSpace.s12, right: AnSpace.s12, top: AnSpace.s8),
      child: Row(
        children: [
          ...actions,
          const Spacer(),
          // Decorative label — the language is already in the container's a11y label (avoid reading
          // "Python" twice). 装饰标签:语言已在容器 a11y label,避免念两遍。
          if (lang != null) ExcludeSemantics(child: Text(lang, style: AnText.meta.copyWith(color: c.inkFaint))),
        ],
      ),
    );
  }

  // A small icon action (copy / wrap / edit) — AnButton.iconOnly carries the a11y label + hover; a
  // Tooltip mirrors the demo's title. 小图标动作:复用 AnButton.iconOnly(带 a11y 标签 + hover)+ Tooltip。
  Widget _barIcon(IconData icon, String label, VoidCallback onTap) {
    return Tooltip(
      message: label,
      child: AnButton.iconOnly(icon, size: AnButtonSize.sm, semanticLabel: label, onPressed: onTap),
    );
  }

  Widget _gutter(AnColors c, int lines) {
    final top = widget.compact ? AnSpace.s4 : AnSpace.s8;
    final bottom = widget.compact ? AnSpace.s4 : AnSpace.s12;
    final nums = [for (var i = 1; i <= lines; i++) '$i'].join('\n');
    // Decorative — a screen reader shouldn't navigate to and read every line number; the line count is
    // in the container label. 装饰:屏读不该逐个念行号(行数已在容器 label)。
    return ExcludeSemantics(
      child: ConstrainedBox(
        // Floor width (>=4 digits); the mono digits right-align within. 槽下界(容 4 位数),mono 数字右对齐。
        constraints: const BoxConstraints(minWidth: AnSize.trail),
        child: Padding(
          padding: EdgeInsets.only(left: AnSpace.s12, right: AnSpace.s8, top: top, bottom: bottom),
          child: Text(
            nums,
            textAlign: TextAlign.right,
            style: (widget.reading ? AnText.codeReading : AnText.code).copyWith(color: c.inkFaint),
          ),
        ),
      ),
    );
  }

  Widget _area(BuildContext context, AnColors c) {
    final pad = EdgeInsets.only(
      left: AnSpace.s8,
      right: AnSpace.s16,
      top: widget.compact ? AnSpace.s4 : AnSpace.s8,
      bottom: widget.compact ? AnSpace.s4 : AnSpace.s12,
    );
    if (_isEditing) {
      return Padding(
        padding: pad,
        child: _EditField(controller: _controller!, focusNode: _editFocus, style: _codeStyle(c), accent: c.accent, onTab: _insertTab),
      );
    }
    final text = SelectableText.rich(
      TextSpan(style: _codeStyle(c), children: highlightCode(widget.code, lang: widget.lang, colors: context.syntax)),
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
    required this.accent,
    required this.onTab,
  });

  final _HighlightController controller;
  final FocusNode focusNode;
  final TextStyle style;
  final Color accent;
  final VoidCallback onTab;

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.tab): onTab},
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        style: style,
        cursorColor: accent,
        cursorWidth: AnSize.caret,
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

  @override
  TextSpan buildTextSpan({required BuildContext context, TextStyle? style, required bool withComposing}) {
    // Per-token spans; the composing-region underline is not separately drawn (v1) — the text still
    // updates live. 逐 token span;v1 不单独画输入法 composing 下划线(文本仍实时更新)。
    return TextSpan(style: style, children: highlightCode(text, lang: lang, colors: context.syntax));
  }
}

// Language label map — port of the demo LANG table; unknown keys title-case the raw key. 语言标签(移植 demo)。
const Map<String, String> _langLabels = {
  'py': 'Python', 'python': 'Python', 'js': 'JavaScript', 'javascript': 'JavaScript',
  'ts': 'TypeScript', 'typescript': 'TypeScript', 'json': 'JSON', 'md': 'Markdown',
  'markdown': 'Markdown', 'cel': 'CEL', 'sh': 'Shell', 'bash': 'Shell', 'go': 'Go',
  'sql': 'SQL', 'html': 'HTML', 'css': 'CSS', 'yaml': 'YAML', 'yml': 'YAML',
  'toml': 'TOML', 'rs': 'Rust', 'rust': 'Rust',
};

String? _langLabel(String? lang) {
  if (lang == null || lang.isEmpty) return null;
  final k = lang.toLowerCase();
  return _langLabels[k] ?? (lang[0].toUpperCase() + lang.substring(1));
}
