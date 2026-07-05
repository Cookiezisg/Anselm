/// AnDocEditor's CUSTOM COMPONENT BUILDERS — the pieces of AnMarkdown's visual grammar that
/// super_editor's stylesheet cannot express (verified against dev.40 source): the horizontal rule's
/// color/thickness are hardcoded, the blockquote has no left-bar hook, list markers only expose
/// dot color/size (not gap/indent geometry), the task checkbox is a raw Material Checkbox with a
/// hardcoded strikethrough, and a code block has NO component at all (it renders as a bare paragraph).
/// Each builder here clones the upstream component's editing contract (the componentKey / proxy wiring
/// that keeps caret + selection + IME working) and swaps ONLY the visuals to the AnMarkdown baseline.
/// Registered BEFORE `defaultComponentBuilders` (first-non-null-wins), with `TaskComponentBuilder`
/// re-added manually (SuperEditor only auto-appends it when NO custom list is passed).
///
/// AnDocEditor 的自定义组件集——AnMarkdown 视觉语法里样式表表达不了的部分(对照 dev.40 源码核实):HR 颜色/粗细
/// 硬编、引用无左条钩子、列表记号只开放点色/点尺寸、任务勾是硬编删除线的裸 Material Checkbox、代码块根本没有
/// 组件(渲成裸段落)。每个 builder 克隆上游的编辑契约(componentKey/proxy 接线,保光标/选区/IME),只把视觉换成
/// AnMarkdown 基准。注册在 `defaultComponentBuilders` 之前(先非空者胜);`TaskComponentBuilder` 须手动补回
/// (传自定义列表时 SuperEditor 不再自动追加)。
library;

import 'dart:async';

import 'package:flutter/material.dart' show Tooltip;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:super_editor/super_editor.dart';

import '../../i18n/strings.g.dart';
import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import 'an_button.dart';
import 'an_code_surface.dart';
import 'icons.dart';
import 'syntax_highlighter.dart';

// ── markdown geometry tokens (the AnMarkdown baseline, MEASURED @ reading 15) 基准几何(15 档实测) ──
// AnMarkdown markers: start 12 · glyph box ('•' 15.3 / '1.' 30.5 at the 15px reading rung) · gap 8 →
// unordered text lands at 35.4, ordered at 50.6 (probed; the two families never column-align in the
// baseline). RE-PROBE these whenever AnText.reading retunes. 基准记号:起12·字形盒('•' 15.3/'1.' 30.5,
// 15 档)·隔8 → 无序文本 35.4、有序 50.6(探针实测;两族本不同列)。reading 重调时必须重探针。
const double _kMarkerGap = AnSpace.s8;
const double _kUlColumn = 35.5;
const double _kOlColumn = 50.5;

double _anUlIndent(TextStyle style, int indent) => _kUlColumn * (indent + 1);
double _anOlIndent(TextStyle style, int indent) => _kOlColumn * (indent + 1);

// ── horizontal rule 分隔线 ──

/// The AnMarkdown hairline rule (`c.line` @ [AnSize.hairline]) — upstream hardcodes grey/1 with no
/// stylesheet hook. 基准细分隔线;上游硬编灰/1、无样式钩子。
class AnHrComponentBuilder implements ComponentBuilder {
  const AnHrComponentBuilder(this.colors);

  final AnColors colors;

  @override
  SingleColumnLayoutComponentViewModel? createViewModel(Document document, DocumentNode node) => null;

  @override
  Widget? createComponent(
      SingleColumnDocumentComponentContext componentContext, SingleColumnLayoutComponentViewModel componentViewModel) {
    if (componentViewModel is! HorizontalRuleComponentViewModel) return null;
    return HorizontalRuleComponent(
      componentKey: componentContext.componentKey,
      color: colors.line,
      thickness: AnSize.hairline,
      selection: componentViewModel.selection?.nodeSelection as UpstreamDownstreamNodeSelection?,
      selectionColor: componentViewModel.selectionColor,
      showCaret: componentViewModel.caret != null,
      caretColor: componentViewModel.caretColor,
      opacity: componentViewModel.opacity,
    );
  }
}

// ── blockquote 引用 ──

/// The quiet-aside register: a 2px `lineStrong` left bar + s12 inset (AnMarkdown's BlockQuoteWidget
/// grammar; prose ink comes from the stylesheet's inkMuted rule). Upstream draws only a background
/// fill — no bar hook. 静默旁白:2px lineStrong 左条 + s12 缩进(墨色归样式表);上游只有背景填充、无左条钩子。
class AnBlockquoteComponentBuilder implements ComponentBuilder {
  const AnBlockquoteComponentBuilder(this.colors);

  final AnColors colors;

  @override
  SingleColumnLayoutComponentViewModel? createViewModel(Document document, DocumentNode node) => null;

  @override
  Widget? createComponent(
      SingleColumnDocumentComponentContext componentContext, SingleColumnLayoutComponentViewModel componentViewModel) {
    if (componentViewModel is! BlockquoteComponentViewModel) return null;
    // The componentKey rides the inner TextComponent (upstream's own pattern) so caret/selection
    // queries resolve against the text; the bar is inert chrome around it. componentKey 在内层
    // TextComponent(上游同款),光标/选区照常;左条是惰性外壳。
    return Container(
      decoration: BoxDecoration(
        border: BorderDirectional(start: BorderSide(color: colors.lineStrong, width: AnSize.gripLine)),
      ),
      padding: const EdgeInsetsDirectional.only(start: AnSpace.s12),
      child: TextComponent(
        key: componentContext.componentKey,
        text: componentViewModel.text,
        textDirection: componentViewModel.textDirection,
        textAlign: componentViewModel.textAlignment,
        textStyleBuilder: componentViewModel.textStyleBuilder,
        inlineWidgetBuilders: componentViewModel.inlineWidgetBuilders,
        textSelection: componentViewModel.selection,
        selectionColor: componentViewModel.selectionColor,
        highlightWhenEmpty: componentViewModel.highlightWhenEmpty,
        underlines: componentViewModel.createUnderlines(),
      ),
    );
  }
}

// ── list items 列表 ──

/// AnMarkdown's list markers: a quiet 3px `inkFaint` dot / a tabular-figure `inkFaint` numeral, marker
/// column start 12 · gap 8. Upstream's stylesheet hooks cover dot color/size but NOT the gap (hardcoded
/// 10) nor the numeral's color/font (it inherits full-ink prose), so the marker WIDGETS are swapped here.
/// 基准列表记号:3px inkFaint 圆点 / 等宽数字 inkFaint 序号,记号列 起12·隔8。样式表钩子管不到间隙(硬编 10)
/// 与序号色/字体(继承正文全墨),故在此换记号 widget。
class AnListItemComponentBuilder implements ComponentBuilder {
  const AnListItemComponentBuilder(this.colors);

  final AnColors colors;

  @override
  SingleColumnLayoutComponentViewModel? createViewModel(Document document, DocumentNode node) => null;

  @override
  Widget? createComponent(
      SingleColumnDocumentComponentContext componentContext, SingleColumnLayoutComponentViewModel componentViewModel) {
    if (componentViewModel is UnorderedListItemComponentViewModel) {
      return UnorderedListItemComponent(
        componentKey: componentContext.componentKey,
        text: componentViewModel.text,
        styleBuilder: componentViewModel.textStyleBuilder,
        indent: componentViewModel.indent,
        indentCalculator: _anUlIndent,
        dotBuilder: _dot,
        dotStyle: componentViewModel.dotStyle,
        textSelection: componentViewModel.selection,
        textDirection: componentViewModel.textDirection,
        textAlignment: componentViewModel.textAlignment,
        selectionColor: componentViewModel.selectionColor,
        highlightWhenEmpty: componentViewModel.highlightWhenEmpty,
        underlines: componentViewModel.createUnderlines(),
        inlineWidgetBuilders: componentViewModel.inlineWidgetBuilders,
      );
    }
    if (componentViewModel is OrderedListItemComponentViewModel) {
      return OrderedListItemComponent(
        componentKey: componentContext.componentKey,
        indent: componentViewModel.indent,
        listIndex: componentViewModel.ordinalValue!,
        text: componentViewModel.text,
        textDirection: componentViewModel.textDirection,
        textAlignment: componentViewModel.textAlignment,
        styleBuilder: componentViewModel.textStyleBuilder,
        indentCalculator: _anOlIndent,
        numeralBuilder: _numeral,
        numeralStyle: componentViewModel.numeralStyle,
        textSelection: componentViewModel.selection,
        selectionColor: componentViewModel.selectionColor,
        highlightWhenEmpty: componentViewModel.highlightWhenEmpty,
        underlines: componentViewModel.createUnderlines(),
        inlineWidgetBuilders: componentViewModel.inlineWidgetBuilders,
      );
    }
    return null;
  }

  // The marker builders OWN the baseline geometry (start 12 · glyph · gap 8): upstream drops the builder
  // output at the indent column's LEAD edge (no alignment wrapper), so the leading pad must live here.
  // The WidgetSpan-in-Text trick mirrors upstream: the glyph rides the text line box, centring on the
  // line like the baseline's '•' character does. marker builder 自带基准几何(起12·字形·隔8):上游把输出
  // 直接放在缩进列首(无对齐包装),前导内距须在此。WidgetSpan 骑行盒技巧同上游,圆点随行居中。
  Widget _dot(BuildContext context, UnorderedListItemComponent component) {
    final attributions = component.text.getAllAttributionsAt(0).toSet();
    return Text.rich(
      TextSpan(
        children: [
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Container(
              width: 3,
              height: 3,
              // Optical centre at the baseline's '•' glyph centre (12 + 15.3/2 ≈ 19.7). 光学中心对基准字形心。
              margin: const EdgeInsetsDirectional.only(start: 18),
              decoration: BoxDecoration(shape: BoxShape.circle, color: colors.inkFaint),
            ),
          ),
        ],
      ),
      style: component.styleBuilder(attributions),
    );
  }

  Widget _numeral(BuildContext context, OrderedListItemComponent component) => Padding(
        padding: const EdgeInsetsDirectional.only(start: AnSpace.s12),
        // Reading-sized tabular figures (the AnMarkdown marker style); the natural glyph width leaves
        // exactly the baseline's gap-8 before the text. 阅读档等宽数字(基准同款);自然字宽恰余隔 8。
        child: Text('${component.listIndex}.',
            style: AnText.reading
                .copyWith(fontFeatures: const [FontFeature.tabularFigures()], color: colors.inkFaint)),
      );
}

// ── task 待办 ──

/// AnMarkdown's task row: a quiet 16px glyph — `taskDone` in `ok` / `taskOpen` in `inkFaint` — start 12 ·
/// gap 8, NO strikethrough on done items. Upstream is a raw Material Checkbox + hardcoded lineThrough.
/// The glyph stays TAPPABLE (toggles completion through the view model's setComplete, same as upstream).
/// 基准任务行:16px 安静字形(勾=ok/空=inkFaint),起12·隔8,完成**无删除线**;上游=裸 Checkbox+硬编删除线。
/// 字形可点(经 viewModel.setComplete 切换,同上游)。
class AnTaskComponentBuilder implements ComponentBuilder {
  AnTaskComponentBuilder(Editor editor, this.colors) : _delegate = TaskComponentBuilder(editor);

  final TaskComponentBuilder _delegate;
  final AnColors colors;

  @override
  SingleColumnLayoutComponentViewModel? createViewModel(Document document, DocumentNode node) =>
      _delegate.createViewModel(document, node);

  @override
  Widget? createComponent(
      SingleColumnDocumentComponentContext componentContext, SingleColumnLayoutComponentViewModel componentViewModel) {
    if (componentViewModel is! TaskComponentViewModel) return null;
    return _AnTaskComponent(key: componentContext.componentKey, viewModel: componentViewModel, colors: colors);
  }
}

class _AnTaskComponent extends StatefulWidget {
  const _AnTaskComponent({required this.viewModel, required this.colors, super.key});

  final TaskComponentViewModel viewModel;
  final AnColors colors;

  @override
  State<_AnTaskComponent> createState() => _AnTaskComponentState();
}

class _AnTaskComponentState extends State<_AnTaskComponent>
    with ProxyDocumentComponent<_AnTaskComponent>, ProxyTextComposable {
  final _textKey = GlobalKey();

  @override
  GlobalKey<State<StatefulWidget>> get childDocumentComponentKey => _textKey;

  @override
  TextComposable get childTextComposable => childDocumentComponentKey.currentState as TextComposable;

  @override
  Widget build(BuildContext context) {
    final vm = widget.viewModel;
    final c = widget.colors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: vm.indentCalculator(vm.textStyleBuilder({}), vm.indent)),
        Padding(
          // top nudge centres the 16px glyph on the 15/1.6 (24px) first text line. 顶部微调对齐首行。
          padding: const EdgeInsetsDirectional.only(start: AnSpace.s12, end: _kMarkerGap, top: 4),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: vm.setComplete == null ? null : () => vm.setComplete!(!vm.isComplete),
            child: Icon(
              vm.isComplete ? AnIcons.taskDone : AnIcons.taskOpen,
              size: AnSize.icon,
              color: vm.isComplete ? c.ok : c.inkFaint,
            ),
          ),
        ),
        Expanded(
          child: TextComponent(
            key: _textKey,
            text: vm.text,
            textDirection: vm.textDirection,
            textAlign: vm.textAlignment,
            // NO strikethrough on completion — the AnMarkdown register keeps done items readable.
            // 完成不划线,保持可读(基准语法)。
            textStyleBuilder: vm.textStyleBuilder,
            inlineWidgetBuilders: vm.inlineWidgetBuilders,
            textSelection: vm.selection,
            selectionColor: vm.selectionColor,
            highlightWhenEmpty: vm.highlightWhenEmpty,
            underlines: vm.createUnderlines(),
          ),
        ),
      ],
    );
  }
}

// ── code block 代码块 ──

/// The fenced-code chrome — AnCodeEditor's exact anatomy (AnCodeSurface frame · top bar with copy +
/// language label · line-number gutter · the code face) around super_editor's own TextComponent, so the
/// block LOOKS like the one code anatomy while staying natively EDITABLE (caret/selection/IME proxy via
/// [ProxyTextDocumentComponent], the TaskComponent contract). Token syntax colouring inside the editable
/// text is a follow-up (needs an attribution reaction); the frame/gutter/bar are pixel-parity today.
/// 围栏代码壳:AnCodeEditor 同款解剖(AnCodeSurface 框·顶栏 copy+语言标·行号槽·代码字面)包住 super_editor 原生
/// TextComponent——看起来是唯一代码解剖、编辑仍原生(Proxy 契约)。可编辑文本内的逐 token 着色是后续(需
/// attribution reaction);框/行号/顶栏今日像素对齐。
class AnCodeBlockComponentBuilder implements ComponentBuilder {
  const AnCodeBlockComponentBuilder(this.colors, {required this.languageOf, required this.copyLabel});

  final AnColors colors;

  /// Resolves the fence language for a node (kept on node metadata by [AnCodeBlockElementConverter] —
  /// the view model doesn't carry it). 取节点的围栏语言(converter 存 metadata;VM 不带)。
  final String? Function(String nodeId) languageOf;

  /// i18n copy-button label (core/ui stays i18n-free — injected). 复制钮 a11y 文案(注入)。
  final String copyLabel;

  @override
  SingleColumnLayoutComponentViewModel? createViewModel(Document document, DocumentNode node) => null;

  @override
  Widget? createComponent(
      SingleColumnDocumentComponentContext componentContext, SingleColumnLayoutComponentViewModel componentViewModel) {
    if (componentViewModel is! ParagraphComponentViewModel) return null;
    if (componentViewModel.blockType != codeAttribution) return null;
    return _AnCodeBlockComponent(
      componentKey: componentContext.componentKey,
      viewModel: componentViewModel,
      colors: colors,
      language: languageOf(componentViewModel.nodeId),
      copyLabel: copyLabel,
    );
  }
}

class _AnCodeBlockComponent extends StatefulWidget {
  const _AnCodeBlockComponent({
    required this.componentKey,
    required this.viewModel,
    required this.colors,
    required this.language,
    required this.copyLabel,
  });

  final GlobalKey componentKey;
  final ParagraphComponentViewModel viewModel;
  final AnColors colors;
  final String? language;
  final String copyLabel;

  @override
  State<_AnCodeBlockComponent> createState() => _AnCodeBlockComponentState();
}

class _AnCodeBlockComponentState extends State<_AnCodeBlockComponent> {
  final _innerTextKey = GlobalKey();
  bool _copied = false;
  bool _copyFailed = false;
  Timer? _copyTimer;

  @override
  void dispose() {
    _copyTimer?.cancel();
    super.dispose();
  }

  // AnCodeEditor's copy contract, mirrored: honest failure (never claim success on a clipboard
  // throw) + a CANCELLABLE 1200ms reset (an un-cancellable delay let a rapid double-copy's stale
  // callback clear the fresh check early). 镜像 AnCodeEditor:失败如实标记 + 可取消 1200ms 复位
  // (不可取消的延迟会让连点的旧回调提前清掉新 ✓)。
  void _copy() {
    Clipboard.setData(ClipboardData(text: widget.viewModel.text.toPlainText())).then((_) {
      if (!mounted) return;
      setState(() {
        _copied = true;
        _copyFailed = false;
      });
      _resetCopyAfterDelay();
    }, onError: (_) {
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

  // AnCodeEditor's language label normalization (display case). 语言标签的展示大小写。
  String? get _langLabel {
    final lang = widget.language?.trim();
    if (lang == null || lang.isEmpty) return null;
    return lang[0].toUpperCase() + lang.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    final vm = widget.viewModel;
    final c = widget.colors;
    final lines = '\n'.allMatches(vm.text.toPlainText()).length + 1;
    return ProxyTextDocumentComponent(
      key: widget.componentKey,
      textComponentKey: _innerTextKey,
      child: AnCodeSurface(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // bar — copy · … · language label (AnCodeEditor's bar geometry). 顶栏:复制 … 语言标。
            Padding(
              padding: const EdgeInsets.only(left: AnSpace.s12, right: AnSpace.s12, top: AnSpace.s8),
              child: Row(
                children: [
                  Tooltip(
                    // Same three-state tip as AnCodeEditor's bar (copied / failed / copy). 与 AnCodeEditor 同三态提示。
                    message: _copied
                        ? context.t.feedback.copied
                        : (_copyFailed ? context.t.feedback.copyFailed : widget.copyLabel),
                    child: AnButton.iconOnly(
                      _copied ? AnIcons.check : AnIcons.copy,
                      size: AnButtonSize.sm,
                      semanticLabel: widget.copyLabel,
                      onPressed: _copy,
                    ),
                  ),
                  const Spacer(),
                  if (_langLabel != null)
                    ExcludeSemantics(child: Text(_langLabel!, style: AnText.meta.copyWith(color: c.inkFaint))),
                ],
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // gutter — same paddings/style as AnCodeEditor so rows align with the code face
                // (logical lines; a soft-wrapped long line drifts — same v1 trade AnCodeEditor's wrap
                // mode makes). 行号槽:同款内距/字面,行盒对齐(逻辑行;软换行长行漂移,同 AnCodeEditor wrap 取舍)。
                ExcludeSemantics(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: AnSize.trail),
                    child: Padding(
                      padding: const EdgeInsets.only(
                          left: AnSpace.s12, right: AnSpace.s8, top: AnSpace.s8, bottom: AnSpace.s12),
                      child: Text(
                        [for (var i = 1; i <= lines; i++) '$i'].join('\n'),
                        textAlign: TextAlign.right,
                        style: AnText.codeReading.copyWith(color: c.inkFaint), // lockstep with the code rule (content rung) 与代码规则同档
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(
                        left: AnSpace.s8, right: AnSpace.s16, top: AnSpace.s8, bottom: AnSpace.s12),
                    child: TextComponent(
                      key: _innerTextKey,
                      text: vm.text,
                      textDirection: vm.textDirection,
                      textAlign: vm.textAlignment,
                      textStyleBuilder: vm.textStyleBuilder,
                      inlineWidgetBuilders: vm.inlineWidgetBuilders,
                      textSelection: vm.selection,
                      selectionColor: vm.selectionColor,
                      highlightWhenEmpty: vm.highlightWhenEmpty,
                      underlines: vm.createUnderlines(),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── fence language round-trip 围栏语言往返 ──

/// Parses a fenced block INCLUDING its language (`\`\`\`python` → `class="language-python"`), which
/// super_editor's built-in parser silently DROPS — an edited document would save back without its
/// language tags. Language rides node metadata; [AnCodeBlockSerializer] writes it back out.
/// 解析围栏时保住语言(上游静默丢弃——编辑过的文档保存会丢语言标)。语言存节点 metadata,序列化器写回。
class AnCodeBlockElementConverter implements ElementToNodeConverter {
  const AnCodeBlockElementConverter();

  @override
  DocumentNode? handleElement(md.Element element) {
    if (element.tag != 'code') return null; // block-level only — inline code parses on the inline path 内联走别路
    final cls = element.attributes['class'] ?? '';
    final lang = cls.startsWith('language-') ? cls.substring('language-'.length) : null;
    // The fence's closing newline otherwise becomes a trailing empty editor line (the spike's
    // whitespace drift); the serializer's writeln restores it. 去掉闭合围栏的尾换行(spike 的漂移),序列化补回。
    final text = element.textContent.endsWith('\n')
        ? element.textContent.substring(0, element.textContent.length - 1)
        : element.textContent;
    return ParagraphNode(
      id: Editor.createNodeId(),
      text: AttributedText(text),
      metadata: {
        'blockType': codeAttribution,
        if (lang != null && lang.isNotEmpty) 'language': lang,
      },
    );
  }
}

/// Serializes a code paragraph as a language-tagged fence (upstream writes a bare ```). Registered as a
/// custom serializer, so it wins before the built-in paragraph serializer. 代码段序列化成带语言的围栏
/// (上游写裸 ```);自定义序列化器先于内建生效。
class AnCodeBlockSerializer extends NodeTypedDocumentNodeMarkdownSerializer<ParagraphNode> {
  const AnCodeBlockSerializer();

  @override
  String? serialize(Document document, DocumentNode node, {NodeSelection? selection}) {
    if (node is! ParagraphNode) return null;
    if (node.getMetadataValue('blockType') != codeAttribution) return null;
    return doSerialization(document, node, selection: selection);
  }

  @override
  String doSerialization(Document document, ParagraphNode node, {NodeSelection? selection}) {
    final lang = node.getMetadataValue('language') as String? ?? '';
    final buffer = StringBuffer()
      ..writeln('```$lang')
      ..writeln(node.text.toPlainText())
      ..write('```');
    return buffer.toString();
  }
}

// ── group boundary rhythm 组边界节奏 ──

/// The AnMarkdown rule "EVERY block transition breathes [AnFlow.block]" applied to list/task GROUP
/// boundaries the stylesheet can't see: `.after()` matches block NAMES only, and an unordered and an
/// ordered item are both named `listItem` — so a `- bullets` list running into a `1.` list (or a task
/// group) read glued at the tight in-group gap. This phase gives the FIRST item of every group (any
/// neighbour of a different family/type) the full block gap. 基准律「所有块过渡=12」补到样式表看不见的
/// 组边界:`.after()` 只认块名,无序/有序同名 `listItem`——两族相接(或接任务组)会以组内 4 紧贴。本 phase 给
/// 每组首项(邻居异族/异型)整块间距。
class AnListBoundaryStylePhase extends SingleColumnLayoutStylePhase {
  @override
  SingleColumnLayoutViewModel style(Document document, SingleColumnLayoutViewModel viewModel) {
    return SingleColumnLayoutViewModel(
      padding: viewModel.padding,
      componentViewModels: [
        for (final vm in viewModel.componentViewModels) _restyled(document, vm),
      ],
    );
  }

  SingleColumnLayoutComponentViewModel _restyled(Document document, SingleColumnLayoutComponentViewModel vm) {
    final node = document.getNodeById(vm.nodeId);
    if (node == null) return vm;
    final prev = document.getNodeBeforeById(node.id);
    if (prev == null) return vm;

    final bool boundary;
    if (node is ListItemNode) {
      boundary = prev is! ListItemNode || prev.type != node.type;
    } else if (node is TaskNode) {
      boundary = prev is! TaskNode;
    } else {
      return vm;
    }
    final resolved = vm.padding.resolve(TextDirection.ltr);
    if (!boundary || resolved.top >= AnFlow.block) return vm;
    final restyled = vm.copy();
    restyled.padding = resolved.copyWith(top: AnFlow.block);
    return restyled;
  }
}

// ── code syntax highlight 代码语法高亮 ──

/// Per-token syntax colouring for EDITABLE code blocks — a style phase that recolours the VIEW MODEL's
/// text copy (never the document): tokenize via the ONE [highlightCode] tokenizer (AnCodeEditor's — no
/// second highlighter, 铁律) and ride the colours in as [ColorAttribution] spans, which the default
/// inline styler already maps to ink. Because view models are per-layout copies, nothing reaches the
/// document or the markdown serializer, there is no edit-reaction loop, and every keystroke restyles
/// automatically. Memoized per node (text+lang) so untouched code blocks skip re-tokenizing.
/// 可编辑代码块的逐 token 上色——样式 phase 只染**视图模型**的文本拷贝(绝不动文档):经唯一 [highlightCode]
/// 分词(AnCodeEditor 同源,不二写高亮器),颜色以 [ColorAttribution] 骑行(默认内联 styler 原生映射)。VM 是
/// 每次布局的拷贝:不进文档、不进序列化、无 reaction 回环,每键自动重染;按节点(文本+语言)记忆化,未动的
/// 代码块跳过重分词。
class AnCodeHighlightStylePhase extends SingleColumnLayoutStylePhase {
  AnCodeHighlightStylePhase(this.syntax, this.languageOf);

  final SyntaxColors syntax;
  final String? Function(String nodeId) languageOf;

  final _memo = <String, (String, String?, List<(SpanRange, Color)>)>{};

  @override
  SingleColumnLayoutViewModel style(Document document, SingleColumnLayoutViewModel viewModel) {
    if (_memo.length > 256) _memo.clear(); // deleted-node hygiene (docs are small) 删除节点卫生
    return SingleColumnLayoutViewModel(
      padding: viewModel.padding,
      componentViewModels: [
        for (final vm in viewModel.componentViewModels) _highlighted(vm),
      ],
    );
  }

  SingleColumnLayoutComponentViewModel _highlighted(SingleColumnLayoutComponentViewModel vm) {
    if (vm is! ParagraphComponentViewModel || vm.blockType != codeAttribution) return vm;
    final plain = vm.text.toPlainText();
    final lang = languageOf(vm.nodeId);
    var memo = _memo[vm.nodeId];
    if (memo == null || memo.$1 != plain || memo.$2 != lang) {
      memo = (plain, lang, _tokenRanges(plain, lang));
      _memo[vm.nodeId] = memo;
    }
    if (memo.$3.isEmpty) return vm;
    final restyled = vm.copy();
    final coloured = vm.text.copy();
    for (final (range, color) in memo.$3) {
      coloured.addAttribution(ColorAttribution(color), range);
    }
    restyled.text = coloured;
    return restyled;
  }

  /// Flattens the tokenizer's spans into offset ranges (SpanRange is END-INCLUSIVE). 摊平 token 区间(闭区间)。
  List<(SpanRange, Color)> _tokenRanges(String code, String? lang) {
    final ranges = <(SpanRange, Color)>[];
    var offset = 0;
    for (final span in highlightCode(code, lang: lang, colors: syntax)) {
      final len = span.text?.length ?? 0;
      if (len == 0) continue;
      final color = span.style?.color;
      if (color != null) ranges.add((SpanRange(offset, offset + len - 1), color));
      offset += len;
    }
    return ranges;
  }
}
