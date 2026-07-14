import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';

import '../design/colors.dart';
import '../design/tokens.dart';
import '../ui/an_code_editor.dart';
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

/// A fenced code block rendered as an EMBEDDED [AnCodeEditor] — the SAME widget the entities/function
/// pages use, in a directly-editable ([AnCodeEditor.seamless]) framed mode, so the document code block is
/// pixel-1:1 with the entity pages (frame + syntax highlight + copy + language label + LINE-NUMBER GUTTER)
/// AND editable in place (click → caret → type). Unlike a super_editor text paragraph, [CodeBlockNode] is a
/// [BlockNode] — an ATOMIC BOX like an image — so super_editor NEVER places a text caret inside it; the
/// embedded AnCodeEditor's own TextField owns the caret / selection / IME / highlight, and the surrounding
/// document treats the block atomically (block-select, backspace-at-start delete). This is the ONLY
/// substrate that can deliver the gutter (super_editor owns a paragraph's soft-wrap line-breaking, so an
/// external gutter can't row-align). Edits stream out per keystroke ([AnCodeEditor.onInput]) → a whole-node
/// [ReplaceNodeRequest] keeping the same id, so the markdown codec (an_editor_markdown.dart, which converts
/// CodeBlockNode ⇄ a code ParagraphNode at the seam) round-trips.
/// TRADE-OFFS (recorded, user-signed 0714): the code block is an atomic box, so a document selection can't
/// flow continuously through it (select code INSIDE the field), and its edits carry the TextField's own
/// undo (separate from super_editor's document history) — the inherent cost of embedding a real editor.
/// 代码块=嵌入的真 AnCodeEditor(entities/function 同款,有框直接编辑):与实体页逐像素一致(框+高亮+copy+语言标+
/// **行号**)且就地可编辑;它是 BlockNode(原子块,像图片)——super_editor 从不在里面放文本光标,光标/选区/IME/高亮
/// 全归 AnCodeEditor 的 TextField。行号只有它自管布局才能对齐(super_editor 管段落软换行→外挂行号对不齐)。编辑经
/// onInput 逐键整节点替换(同 id),codec 在缝处 CodeBlockNode⇄code 段落往返。代价(用户 0714 签):原子块→选区不
/// 连续穿过、撤销走 TextField 自己的栈(与文档历史分离)——嵌真编辑器的固有成本。
class CodeBlockNode extends BlockNode {
  CodeBlockNode({required this.id, required this.code, this.language, super.metadata}) {
    initAddToMetadata({NodeMetadata.blockType: codeAttribution});
  }

  @override
  final String id;
  final String code;
  final String? language;

  CodeBlockNode copyWithCode(String newCode) =>
      CodeBlockNode(id: id, code: newCode, language: language, metadata: Map.from(metadata));

  @override
  String? copyContent(dynamic selection) {
    if (selection is! UpstreamDownstreamNodeSelection) return null;
    return !selection.isCollapsed ? code : null;
  }

  @override
  bool hasEquivalentContent(DocumentNode other) =>
      other is CodeBlockNode && code == other.code && language == other.language;

  @override
  DocumentNode copyWithAddedMetadata(Map<String, dynamic> newProperties) =>
      CodeBlockNode(id: id, code: code, language: language, metadata: {...metadata, ...newProperties});

  @override
  DocumentNode copyAndReplaceMetadata(Map<String, dynamic> newMetadata) =>
      CodeBlockNode(id: id, code: code, language: language, metadata: newMetadata);

  CodeBlockNode copy() => CodeBlockNode(id: id, code: code, language: language, metadata: Map.from(metadata));

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CodeBlockNode &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          code == other.code &&
          language == other.language;

  @override
  int get hashCode => id.hashCode ^ code.hashCode ^ language.hashCode;
}

/// The code block's view model (mirrors [ImageComponentViewModel]: a selection-aware box vm, value-equal
/// so the presenter's style pass never reallocates per frame). 代码块 vm(镜像 ImageComponentViewModel,值相等)。
class CodeBlockComponentViewModel extends SingleColumnLayoutComponentViewModel with SelectionAwareViewModelMixin {
  CodeBlockComponentViewModel({
    required super.nodeId,
    super.createdAt,
    super.maxWidth,
    super.padding = EdgeInsets.zero,
    required this.code,
    this.language,
    DocumentNodeSelection? selection,
    Color selectionColor = Colors.transparent,
  }) {
    this.selection = selection;
    this.selectionColor = selectionColor;
  }

  String code;
  String? language;

  @override
  CodeBlockComponentViewModel copy() => CodeBlockComponentViewModel(
        nodeId: nodeId,
        createdAt: createdAt,
        maxWidth: maxWidth,
        padding: padding,
        code: code,
        language: language,
        selection: selection,
        selectionColor: selectionColor,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      super == other &&
          other is CodeBlockComponentViewModel &&
          runtimeType == other.runtimeType &&
          nodeId == other.nodeId &&
          code == other.code &&
          language == other.language &&
          selection == other.selection &&
          selectionColor == other.selectionColor;

  @override
  int get hashCode =>
      super.hashCode ^
      nodeId.hashCode ^
      code.hashCode ^
      language.hashCode ^
      selection.hashCode ^
      selectionColor.hashCode;
}

class AnCodeBlockComponentBuilder implements ComponentBuilder {
  const AnCodeBlockComponentBuilder(this.editor, this.colors, this.codeKeys);

  final Editor editor;
  final AnColors colors;

  /// One stable [GlobalKey] per code-node id, so the embedded [AnCodeEditor]'s State (its controller /
  /// focus / caret) survives the whole-node replace we run on each keystroke (ReplaceNode remove+insert
  /// would otherwise remount + drop the caret). Held on [AnEditorState]. 每代码节点一把稳定 key,保 AnCodeEditor
  /// State 跨整节点替换(否则 remove+insert 会 remount 丢光标)。
  final Map<String, GlobalKey> codeKeys;

  @override
  SingleColumnLayoutComponentViewModel? createViewModel(Document document, DocumentNode node) {
    if (node is! CodeBlockNode) return null;
    return CodeBlockComponentViewModel(
      nodeId: node.id,
      code: node.code,
      language: node.language,
      padding: const EdgeInsets.only(top: AnFlow.block), // one house block gap above (like every stacked block) 块上距
    );
  }

  @override
  Widget? createComponent(
    SingleColumnDocumentComponentContext componentContext,
    SingleColumnLayoutComponentViewModel componentViewModel,
  ) {
    if (componentViewModel is! CodeBlockComponentViewModel) return null;
    final editorKey = codeKeys.putIfAbsent(componentViewModel.nodeId, () => GlobalKey());
    // BoxComponent (NOT ImageComponent's IgnorePointer) supplies the block geometry super_editor needs
    // while letting pointers reach the embedded TextField. componentKey rides the BoxComponent root
    // (the _layout contract: key on the returned subtree's ROOT). BoxComponent 供块几何、不挡指针;componentKey 挂根。
    return BoxComponent(
      key: componentContext.componentKey,
      child: AnCodeEditor(
        key: editorKey,
        code: componentViewModel.code,
        lang: componentViewModel.language,
        reading: true,
        wrap: true,
        editable: true,
        seamless: true,
        onInput: (newCode) => editor.execute([
          ReplaceNodeRequest(
            existingNodeId: componentViewModel.nodeId,
            newNode: CodeBlockNode(
              id: componentViewModel.nodeId,
              code: newCode,
              language: componentViewModel.language,
            ),
          ),
        ]),
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
          border: Border(left: BorderSide(color: barColor, width: AnSize.quoteBar)),
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
