import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';

import '../design/colors.dart';
import '../design/tokens.dart';
import '../ui/an_code_surface.dart';
import '../ui/icons.dart';

/// An-primitive block component builders for the editor (E2b+). Each reuses super_editor's default
/// builder for the heavy lifting (view-model construction: text direction / alignment / indent /
/// selection wiring) and overrides ONLY [createComponent] to draw the block with our own widgets +
/// tokens — so a blockquote/code/list block in the editor is the SAME shape as everywhere else in the
/// product, not a CSS approximation. Discipline (E0 post-mortem): the builders are `const`/value-equal
/// and hold only immutable token colours, so the presenter's style pass never reallocates a fresh
/// view-model per frame. 编辑器的 An 原语块组件:复用默认 builder 造 view-model,只覆写 createComponent 用自家
/// widget+token 画壳;builder 是值相等的、只揣不可变 token 色,style pass 不会每帧重分配 vm(E0 教训)。

/// Blockquote in the An "quiet-aside" grammar: a 2px [AnColors.lineStrong] left bar + [AnSpace.s12]
/// inset (NOT the default's full background fill). The [AnColors.inkMuted] prose colour is set by the
/// stylesheet's `blockquote` text rule, so it cascades through the shared styleBuilder.
/// 静默旁白引用:2px lineStrong 左条 + s12 缩进(非默认整块填充);inkMuted 文字色由样式表 blockquote 规则给。
class AnBlockquoteComponentBuilder extends BlockquoteComponentBuilder {
  const AnBlockquoteComponentBuilder(this.colors);

  final AnColors colors;

  @override
  Widget? createComponent(
    SingleColumnDocumentComponentContext componentContext,
    SingleColumnLayoutComponentViewModel componentViewModel,
  ) {
    if (componentViewModel is! BlockquoteComponentViewModel) return null;

    return _AnBlockquoteComponent(
      textKey: componentContext.componentKey,
      text: componentViewModel.text,
      styleBuilder: componentViewModel.textStyleBuilder,
      indent: componentViewModel.indent,
      indentCalculator: componentViewModel.indentCalculator,
      textSelection: componentViewModel.selection,
      selectionColor: componentViewModel.selectionColor,
      highlightWhenEmpty: componentViewModel.highlightWhenEmpty,
      underlines: componentViewModel.createUnderlines(),
      barColor: colors.lineStrong,
    );
  }
}

/// Fenced code block in the An code-surface identity: the SAME framed white island the rest of the
/// product uses ([AnCodeSurface] — hairline [AnColors.line] border, [AnRadius.card] round, clipped),
/// wrapping the real editable [ParagraphComponent] (its [componentContext.componentKey] rides it, so
/// selection/caret geometry is the default paragraph's). A code node is a `ParagraphNode` whose
/// blockType is [codeAttribution]; super_editor ships NO code component, so this IS the code block. The
/// mono 13/1.6 text colour is set by the stylesheet's `code` rule; syntax highlight rides the memoized
/// [AnCodeSyntaxStylePhase] (an_editor_syntax.dart).
/// 围栏代码块:复用产品统一的 AnCodeSurface(白岛+发丝边+card 圆角+裁剪),裹住真可编辑 ParagraphComponent;
/// code 节点=blockType 为 code 的段落(super_editor 无代码组件,这就是代码块);mono 文字色由样式表 code 规则给,高亮走记忆化 style phase。
class AnCodeBlockComponentBuilder extends ParagraphComponentBuilder {
  const AnCodeBlockComponentBuilder(this.colors);

  final AnColors colors;

  @override
  SingleColumnLayoutComponentViewModel? createViewModel(Document document, DocumentNode node) {
    if (node is! ParagraphNode || node.getMetadataValue('blockType') != codeAttribution) return null;
    return super.createViewModel(document, node); // reuse — carries blockType=code on the view model
  }

  @override
  Widget? createComponent(
    SingleColumnDocumentComponentContext componentContext,
    SingleColumnLayoutComponentViewModel componentViewModel,
  ) {
    // First non-null wins AND this builder runs first, so a REGULAR paragraph (blockType≠code) falls
    // through to the default here. 常规段落(非 code)在此放行给默认。
    if (componentViewModel is! ParagraphComponentViewModel || componentViewModel.blockType != codeAttribution) {
      return null;
    }
    return AnCodeSurface(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AnSpace.s12, vertical: AnSpace.s8),
        child: ParagraphComponent(key: componentContext.componentKey, viewModel: componentViewModel),
      ),
    );
  }
}

/// Task/checklist item with the An checkbox — the SAME quiet glyph the read-only prose uses
/// ([AnIcons.taskOpen]/[taskDone] at [AnSize.icon], [AnColors.inkFaint]→[ok]), NOT a Material
/// [Checkbox] (oversized, blue, tap-padded — off the reading rhythm). Here the glyph is TAPPABLE
/// (toggles completion via the view model's `setComplete`), and a done task greys to [inkFaint] +
/// strikes through. Tasks aren't in `defaultComponentBuilders`, so this builder must be added
/// explicitly. 任务勾:用只读 prose 同款静默字形(非 Material Checkbox),可点切换完成;完成态 inkFaint+删除线。
class AnTaskComponentBuilder extends TaskComponentBuilder {
  AnTaskComponentBuilder(super.editor, this.colors);

  final AnColors colors;

  @override
  Widget? createComponent(
    SingleColumnDocumentComponentContext componentContext,
    SingleColumnLayoutComponentViewModel componentViewModel,
  ) {
    if (componentViewModel is! TaskComponentViewModel) return null;
    return _AnTaskComponent(key: componentContext.componentKey, viewModel: componentViewModel, colors: colors);
  }
}

class _AnTaskComponent extends StatefulWidget {
  const _AnTaskComponent({super.key, required this.viewModel, required this.colors});

  final TaskComponentViewModel viewModel;
  final AnColors colors;

  @override
  State<_AnTaskComponent> createState() => _AnTaskComponentState();
}

// The proxy mixins forward all DocumentComponent / TextComposable calls to the inner TextComponent
// (via _textKey) — the same pattern super_editor's own TaskComponent uses, so selection/caret geometry
// is the default's. 代理 mixin 把组件行为转发给内层 TextComponent(与默认 TaskComponent 同法)。
class _AnTaskComponentState extends State<_AnTaskComponent>
    with ProxyDocumentComponent<_AnTaskComponent>, ProxyTextComposable {
  final _textKey = GlobalKey();

  @override
  GlobalKey get childDocumentComponentKey => _textKey;

  @override
  TextComposable get childTextComposable => childDocumentComponentKey.currentState as TextComposable;

  // A completed task greys to inkFaint + strikes through (the "done" affordance). 完成态:inkFaint+删除线。
  TextStyle _computeStyles(Set<Attribution> attributions) {
    final style = widget.viewModel.textStyleBuilder(attributions);
    if (!widget.viewModel.isComplete) return style;
    return style.copyWith(
      color: widget.colors.inkFaint,
      decoration: style.decoration == null
          ? TextDecoration.lineThrough
          : TextDecoration.combine([TextDecoration.lineThrough, style.decoration!]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = widget.viewModel;
    final done = vm.isComplete;
    return Directionality(
      textDirection: vm.textDirection,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: vm.indentCalculator(vm.textStyleBuilder({}), vm.indent)),
          // The tappable An glyph, nudged down to sit on the first text line's centre (16 glyph in the
          // 24px reading line box). 可点字形,下移到首行文字中线。
          Padding(
            padding: const EdgeInsetsDirectional.only(end: AnSpace.s8, top: AnSpace.s4),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: vm.setComplete != null ? () => vm.setComplete!(!done) : null,
              child: Icon(
                AnIcons.task(done: done),
                size: AnSize.icon,
                color: done ? widget.colors.ok : widget.colors.inkFaint,
              ),
            ),
          ),
          Expanded(
            child: TextComponent(
              key: _textKey,
              text: vm.text,
              textDirection: vm.textDirection,
              textAlign: vm.textAlignment,
              textStyleBuilder: _computeStyles,
              inlineWidgetBuilders: vm.inlineWidgetBuilders,
              textSelection: vm.selection,
              selectionColor: vm.selectionColor,
              highlightWhenEmpty: vm.highlightWhenEmpty,
              underlines: vm.createUnderlines(),
            ),
          ),
        ],
      ),
    );
  }
}

/// Mirrors super_editor's `BlockquoteComponent` (same structure so selection/caret geometry is
/// untouched — the [textKey] rides the inner [TextComponent]) but swaps the shell to the quiet-aside
/// skin. 镜像默认结构(选区/光标几何不变),只换壳皮。
class _AnBlockquoteComponent extends StatelessWidget {
  const _AnBlockquoteComponent({
    required this.textKey,
    required this.text,
    required this.styleBuilder,
    required this.indent,
    required this.indentCalculator,
    required this.textSelection,
    required this.selectionColor,
    required this.highlightWhenEmpty,
    required this.underlines,
    required this.barColor,
  });

  final GlobalKey textKey;
  final AttributedText text;
  final AttributionStyleBuilder styleBuilder;
  final int indent;
  final TextBlockIndentCalculator indentCalculator;
  final TextSelection? textSelection;
  final Color selectionColor;
  final bool highlightWhenEmpty;
  final List<Underlines> underlines;
  final Color barColor;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        padding: const EdgeInsets.only(left: AnSpace.s12),
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: barColor, width: 2)),
        ),
        child: Row(
          children: [
            SizedBox(width: indentCalculator(styleBuilder({}), indent)),
            Expanded(
              child: TextComponent(
                key: textKey,
                text: text,
                textStyleBuilder: styleBuilder,
                textSelection: textSelection,
                selectionColor: selectionColor,
                highlightWhenEmpty: highlightWhenEmpty,
                underlines: underlines,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
