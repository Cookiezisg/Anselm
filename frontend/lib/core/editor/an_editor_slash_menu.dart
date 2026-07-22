import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';

import '../../i18n/strings.g.dart';
import '../design/colors.dart';
import 'an_editor_components.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../ui/an_menu_surface.dart';
import '../ui/icons.dart';

/// What a slash command needs to build its requests: the trigger paragraph, the live document, and
/// whether that paragraph will be EMPTY once the `/query` tag is submitted away (computed by the caller
/// from the composing tag — the requests are built BEFORE the submit runs, so the node still holds the
/// tag text at this point). 命令构建请求所需:触发段/活文档/提交删 tag 后该段是否为空(调用方据 composing tag
/// 预判——请求在 Submit 前构建,此刻节点还揣着 tag 文本)。
typedef SlashContext = ({
  String nodeId,
  Document document,
  bool emptyAfterSubmit,
});

/// One slash-menu command — a block type the `/` menu can turn the current paragraph into. [labelOf]
/// resolves the display label from the live locale (the palette is a top-level const-ish list, so it can't
/// capture a BuildContext — callers pass `Translations.of(context)`). [requests] returns the editor
/// requests that perform the conversion; block-INSERTING commands (divider / table) use
/// [SlashContext.emptyAfterSubmit] to keep a non-empty paragraph and insert below it instead of destroying
/// its text. [keywords] widen the match beyond the label (English + pinyin aliases) so `/h1`, `/quote`,
/// `/code` all hit. 一条 slash 命令:标签经 labelOf 走 slang(顶层表拿不到 context,调用方传 Translations);
/// requests 出转换请求——插块型命令(分隔线/表格)据 emptyAfterSubmit 对非空段落下插、不毁其文本。
class SlashCommand {
  const SlashCommand({
    required this.labelOf,
    required this.icon,
    required this.keywords,
    required this.requests,
  });

  final String Function(Translations t) labelOf;
  final IconData icon;
  final List<String> keywords;
  final List<EditRequest> Function(SlashContext ctx) requests;

  bool matches(String query, Translations t) {
    if (query.isEmpty) return true;
    final q = query.toLowerCase();
    return labelOf(t).toLowerCase().contains(q) ||
        keywords.any((k) => k.toLowerCase().contains(q));
  }
}

/// The full slash palette — every block type the editor renders, in the reading order a writer expects.
/// slash 全表——覆盖编辑器所有块型,按书写者预期的阅读序。
final List<SlashCommand> slashCommands = [
  SlashCommand(
    labelOf: (t) => t.library.slash.text,
    icon: AnIcons.paragraph,
    keywords: ['text', 'p', 'paragraph', 'zhengwen'],
    requests: _paragraph,
  ),
  SlashCommand(
    labelOf: (t) => t.library.slash.h1,
    icon: AnIcons.heading1,
    keywords: ['h1', 'heading', 'biaoti'],
    requests: _h1,
  ),
  SlashCommand(
    labelOf: (t) => t.library.slash.h2,
    icon: AnIcons.heading2,
    keywords: ['h2', 'heading', 'biaoti'],
    requests: _h2,
  ),
  SlashCommand(
    labelOf: (t) => t.library.slash.h3,
    icon: AnIcons.heading3,
    keywords: ['h3', 'heading', 'biaoti'],
    requests: _h3,
  ),
  SlashCommand(
    labelOf: (t) => t.library.slash.quote,
    icon: AnIcons.quote,
    keywords: ['quote', 'blockquote', 'yinyong'],
    requests: _quote,
  ),
  SlashCommand(
    labelOf: (t) => t.library.slash.code,
    icon: AnIcons.codeBlock,
    keywords: ['code', 'fenced', 'daima'],
    requests: _code,
  ),
  SlashCommand(
    labelOf: (t) => t.library.slash.table,
    icon: AnIcons.table,
    keywords: ['table', 'grid', 'biaoge'],
    requests: _table,
  ),
  SlashCommand(
    labelOf: (t) => t.library.slash.bulleted,
    icon: AnIcons.listBulleted,
    keywords: ['ul', 'bullet', 'list', 'liebiao'],
    requests: _ul,
  ),
  SlashCommand(
    labelOf: (t) => t.library.slash.numbered,
    icon: AnIcons.listNumbered,
    keywords: ['ol', 'ordered', 'number', 'liebiao'],
    requests: _ol,
  ),
  SlashCommand(
    labelOf: (t) => t.library.slash.todo,
    icon: AnIcons.todo,
    keywords: ['task', 'todo', 'checkbox', 'renwu'],
    requests: _task,
  ),
  SlashCommand(
    labelOf: (t) => t.library.slash.divider,
    icon: AnIcons.divider,
    keywords: ['divider', 'hr', 'rule', 'fenge'],
    requests: _divider,
  ),
];

List<EditRequest> _paragraph(SlashContext c) => [
  ChangeParagraphBlockTypeRequest(
    nodeId: c.nodeId,
    blockType: paragraphAttribution,
  ),
];
List<EditRequest> _h1(SlashContext c) => [
  ChangeParagraphBlockTypeRequest(
    nodeId: c.nodeId,
    blockType: header1Attribution,
  ),
];
List<EditRequest> _h2(SlashContext c) => [
  ChangeParagraphBlockTypeRequest(
    nodeId: c.nodeId,
    blockType: header2Attribution,
  ),
];
List<EditRequest> _h3(SlashContext c) => [
  ChangeParagraphBlockTypeRequest(
    nodeId: c.nodeId,
    blockType: header3Attribution,
  ),
];
List<EditRequest> _quote(SlashContext c) => [
  ChangeParagraphBlockTypeRequest(
    nodeId: c.nodeId,
    blockType: blockquoteAttribution,
  ),
];
// Code block = the embedded [CodeBlockNode] (AnCodeEditor), same as the markdown codec + the ```` ``` ````
// on-type shortcut — NOT a codeAttribution paragraph. 代码块=嵌入 CodeBlockNode,与 codec/on-type 一致。
List<EditRequest> _code(SlashContext c) =>
    _insertBlock(c, CodeBlockNode(id: Editor.createNodeId(), code: ''));
List<EditRequest> _ul(SlashContext c) => [
  ConvertParagraphToListItemRequest(
    nodeId: c.nodeId,
    type: ListItemType.unordered,
  ),
];
List<EditRequest> _ol(SlashContext c) => [
  ConvertParagraphToListItemRequest(
    nodeId: c.nodeId,
    type: ListItemType.ordered,
  ),
];
List<EditRequest> _task(SlashContext c) => [
  ConvertParagraphToTaskRequest(nodeId: c.nodeId),
];

/// Insert [block] at the trigger paragraph (replace if it'll be empty post-submit, below if not) + a
/// fresh paragraph after it, and park the caret there so the writer keeps typing.
/// 插块(提交后空段→替换/非空→下插)+ 尾随新段落收光标。
List<EditRequest> _insertBlock(SlashContext c, DocumentNode block) {
  final paraId = Editor.createNodeId();
  return [
    if (c.emptyAfterSubmit)
      ReplaceNodeRequest(existingNodeId: c.nodeId, newNode: block)
    else
      InsertNodeAfterNodeRequest(existingNodeId: c.nodeId, newNode: block),
    InsertNodeAfterNodeRequest(
      existingNodeId: block.id,
      newNode: ParagraphNode(id: paraId, text: AttributedText('')),
    ),
    ChangeSelectionRequest(
      DocumentSelection.collapsed(
        position: DocumentPosition(
          nodeId: paraId,
          nodePosition: const TextNodePosition(offset: 0),
        ),
      ),
      SelectionChangeType.insertContent,
      'slash-insert-block',
    ),
  ];
}

List<EditRequest> _divider(SlashContext c) =>
    _insertBlock(c, HorizontalRuleNode(id: Editor.createNodeId()));

List<EditRequest> _table(SlashContext c) {
  TextNode cell() =>
      TextNode(id: Editor.createNodeId(), text: AttributedText(''));
  // Header row + one body row × 3 columns — the smallest markdown-serializable grid worth starting from.
  // 表头行 + 一行正文 × 3 列——最小可序列化起手表。
  return _insertBlock(
    c,
    TableBlockNode(
      id: Editor.createNodeId(),
      cells: [
        [cell(), cell(), cell()],
        [cell(), cell(), cell()],
      ],
    ),
  );
}

/// The slash popover as a super_editor **document overlay layer** — the robust, timing-safe way to anchor
/// a popover to the caret. super_editor calls [computeLayoutDataWithDocumentLayout] AFTER the content is
/// laid out (so [DocumentLayout.getRectForPosition] can NEVER null-check-throw on a half-built SuperText,
/// the bug the naive OverlayPortal approach hit), and the layer's coordinate space IS the document's — so
/// [Positioned] places the menu in document coords directly, no localToGlobal + no post-frame retry dance.
/// The whole freeze-prone overlay problem dissolves into the framework's own content-layer pipeline.
/// slash 弹层=super_editor 文档 overlay 层:框架在**布局就绪后**给 layout 算 Rect(getRectForPosition 绝不在半布局上崩),
/// 层坐标即文档坐标→直接 Positioned;整个卡死高危的浮层问题化进框架自己的 content-layer 管线。
class AnSlashMenuOverlay extends DocumentLayoutLayerStatefulWidget {
  const AnSlashMenuOverlay({
    super.key,
    required this.tag,
    required this.matches,
    required this.activeIndex,
    required this.onSelect,
  });

  final IndexedTag? tag;
  final List<SlashCommand> matches;
  final int activeIndex;
  final void Function(SlashCommand) onSelect;

  @override
  DocumentLayoutLayerState<AnSlashMenuOverlay, SlashPlacement?> createState() =>
      _AnSlashMenuOverlayState();
}

// The resolved menu placement: the top-left corner (document coords) already flip-adjusted. 已翻转的落点。
typedef SlashPlacement = ({double left, double top});

class _AnSlashMenuOverlayState
    extends DocumentLayoutLayerState<AnSlashMenuOverlay, SlashPlacement?> {
  @override
  SlashPlacement? computeLayoutDataWithDocumentLayout(
    BuildContext contentLayersContext,
    BuildContext documentContext,
    DocumentLayout documentLayout,
  ) {
    final tag = widget.tag;
    if (tag == null || widget.matches.isEmpty) return null;
    // The node can be momentarily absent right after a conversion/delete — treat as "no menu this frame".
    // 转换/删除瞬间节点可能暂缺→本帧不画。
    if (documentLayout.getComponentByNodeId(tag.nodeId) == null) return null;
    final anchor = documentLayout.getRectForPosition(tag.start);
    if (anchor == null) return null;

    // Shared caret-anchored placement (A-104) — hang below by default, flip above only if below
    // overflows AND above fits (mention shares this exact math). 共享落点:默认下挂,下溢且上容才翻上。
    final box = context.findRenderObject() as RenderBox?;
    final layerHeight = (box != null && box.hasSize)
        ? box.size.height
        : double.infinity;
    return AnMenuSurface.caretPlacement(
      anchor: anchor,
      rows: widget.matches.length,
      layerHeight: layerHeight,
    );
  }

  @override
  Widget doBuild(BuildContext context, SlashPlacement? placement) {
    if (placement == null || widget.matches.isEmpty) {
      return const SizedBox.shrink();
    }
    // A Stack with a single Positioned child — empty areas don't hit-test, so taps outside the menu pass
    // through to the editor below (NOT IgnorePointer — the menu itself must catch its own taps). 空处穿透。
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          top: placement.top,
          left: placement.left,
          child: AnSlashMenu(
            commands: widget.matches,
            activeIndex: widget.activeIndex,
            onSelect: widget.onSelect,
          ),
        ),
      ],
    );
  }
}

/// The slash popover panel — the shared [AnMenuSurface] chrome (white panel, hairline, pop shadow) with
/// one [AnMenuRow] per command: the block-type glyph + label, the keyboard-active row [highlighted] (focus
/// stays in the editor — aria-activedescendant style). Positioned at the caret by [AnSlashMenuOverlay];
/// this widget only draws. slash 弹层:AnMenuSurface 壳 + 每命令一行(图标+标签),键盘活动行 highlighted(焦点留编辑器)。
class AnSlashMenu extends StatelessWidget {
  const AnSlashMenu({
    required this.commands,
    required this.activeIndex,
    required this.onSelect,
    super.key,
  });

  final List<SlashCommand> commands;
  final int activeIndex;
  final void Function(SlashCommand) onSelect;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = Translations.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(
        minWidth: AnSize.menuMinWidth,
        maxWidth: AnSize.menuMaxWidth,
        maxHeight: AnSize.menuMaxHeight,
      ),
      child: AnMenuSurface(
        children: [
          for (var i = 0; i < commands.length; i++)
            AnMenuRow(
              onTap: () => onSelect(commands[i]),
              highlighted: i == activeIndex,
              builder: (ctx, active) => Row(
                children: [
                  Icon(
                    commands[i].icon,
                    size: AnSize.icon,
                    color: active ? c.ink : c.inkMuted,
                  ),
                  const SizedBox(width: AnSpace.s8),
                  Text(
                    commands[i].labelOf(t),
                    style: AnText.body.copyWith(color: c.ink),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
