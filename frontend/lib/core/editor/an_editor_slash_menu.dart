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
    this.insertsMedia = false,
  });

  final String Function(Translations t) labelOf;
  final IconData icon;
  final List<String> keywords;
  final List<EditRequest> Function(SlashContext ctx) requests;

  /// Marks the ONE command that cannot be expressed as [requests] alone: inserting media needs a file
  /// picked and uploaded FIRST, and only then is there an id to write into the document.
  ///
  /// It is a flag rather than an async variant of [requests] because `core/editor` is deliberately
  /// Riverpod-free — it cannot reach the media port itself. The host supplies a callback; this flag is
  /// how the palette says "call it", keeping the palette declarative and the layering intact.
  ///
  /// 标记**唯一**一条无法只用 [requests] 表达的命令:插媒体要**先**选文件、**先**上传,之后才存在一个可以
  /// 写进文档的 id。
  ///
  /// 它是一个标志、而非 [requests] 的异步变体,因为 `core/editor` **刻意不沾 Riverpod**——它自己够不着媒体
  /// 端口。宿主提供回调,而本标志是调色板说「去调它」的方式:调色板保持声明式,分层不破。
  final bool insertsMedia;

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
  // LAST, and the position is not cosmetic: the palette has a bounded height, so putting a new entry
  // at the FRONT pushes every block type down a row and moves the hit target of commands a writer
  // reaches for constantly. It also matches the list's stated order — block types in the order a
  // writer expects, and media is the one entry that is not a block conversion at all.
  // **放在最后**,而且这个位置不是装饰:调色板有高度上限,故把新条目放在**开头**会把每一个块型都挤下一行、
  // 移动写作者天天要点的那些命令的命中区。它也符合本表自述的顺序——块型按书写者预期的阅读序,而媒体是
  // 其中**唯一**一条根本不是块型转换的。
  SlashCommand(
    labelOf: (t) => t.library.slash.media,
    icon: AnIcons.image,
    keywords: [
      'media',
      'image',
      'picture',
      'photo',
      'video',
      'audio',
      'tupian',
      'meiti',
    ],
    // No requests of its own — the host picks + uploads, then the editor writes the insert.
    // 自己不出 requests——宿主选文件 + 上传,再由编辑器写入插入请求。
    requests: (_) => const [],
    insertsMedia: true,
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
// on-type shortcut — NOT a codeAttribution paragraph. `focusInside`: the caret belongs INSIDE the block
// (you insert a code block to type code), so skip the trailing paragraph + caret-park — the block's own
// AnCodeEditor autofocuses instead (WRK-083 L15). 代码块=嵌入 CodeBlockNode。focusInside:光标该进块内(插代码
// 块就是为了写代码),故不追加尾段/不 park 光标——由块自己的 AnCodeEditor autofocus。
List<EditRequest> _code(SlashContext c) => _insertBlock(
  c,
  CodeBlockNode(id: Editor.createNodeId(), code: ''),
  focusInside: true,
);
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

/// Insert [block] at the trigger paragraph (replace if it'll be empty post-submit, below if not).
///
/// [focusInside] chooses where the caret lands. Default (false): append a fresh paragraph after the
/// block and park the caret THERE — right for atomic blocks with no inner editing (a divider), and for
/// blocks whose caret story is a separate concern. true: the block owns an inner editor and the writer
/// wants to type INTO it (a code block), so neither the trailing paragraph nor the document-caret move
/// is added — the block's embedded editor autofocuses instead (WRK-083 L15). Adding an empty paragraph
/// there would be the very bug: the writer types and it lands below the empty block.
///
/// 插块(提交后空段→替换/非空→下插)。[focusInside] 决定光标落点。默认(false):在块后加一空段并把光标 park 到那里
/// ——对无内部编辑的原子块(分隔线)、以及光标另有归属的块合适。true:块自带内部编辑器、作者想往**里**打字(代码块),
/// 故既不追加尾段、也不移动文档光标——由块的嵌入编辑器 autofocus(WRK-083 L15)。此时再加空段正是那个 bug:一打字就
/// 落到空块下面。
List<EditRequest> _insertBlock(
  SlashContext c,
  DocumentNode block, {
  bool focusInside = false,
}) {
  // focusInside NEVER replaces the trigger paragraph. The block insert shares its execute() with
  // SubmitComposingActionTagRequest, whose reaction cleans up the tag ON the trigger paragraph at the end
  // of the same transaction — replacing that paragraph out from under it throws `Null as TextNode` deep in
  // super_editor's action_tags reactor. So focusInside always inserts AFTER the trigger and leaves the
  // (now empty) trigger paragraph for the editor to reconcile; the caret goes to the block's embedded
  // editor, not to any paragraph, so the leftover empty line is invisible and harmless. Atomic blocks
  // (divider) keep the classic replace-or-append + caret-park below (WRK-083 L15).
  // focusInside **绝不替换**触发段落。插块与 SubmitComposingActionTagRequest 共用一次 execute(),后者的 reaction 在
  // 同一事务末尾**在触发段落上**清理 tag——把那个段落从它脚下换掉,会在 super_editor 的 action_tags reactor 深处抛
  // `Null as TextNode`。故 focusInside 恒在触发段**之后**插块、把(现已空的)触发段留给编辑器自行调和;光标交给块的嵌入
  // 编辑器、不落任何段落,残留空行因此不可见且无害。原子块(分隔线)照旧走替换/追加 + 光标 park 到下方。
  if (focusInside) {
    return [
      InsertNodeAfterNodeRequest(existingNodeId: c.nodeId, newNode: block),
    ];
  }
  final insert = c.emptyAfterSubmit
      ? ReplaceNodeRequest(existingNodeId: c.nodeId, newNode: block)
      : InsertNodeAfterNodeRequest(existingNodeId: c.nodeId, newNode: block);
  final paraId = Editor.createNodeId();
  return [
    insert,
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
    // Same reason as the code block, and the user said so in exactly those terms: you insert a table in
    // order to type into its CELLS. Parking the caret in a paragraph below means the first thing you type
    // lands under an empty grid (WRK-083 L15). 与代码块同理,而用户的原话正是这个意思:插表格就是为了往**格子里**
    // 打字。把光标 park 到下方段落,意味着你打的第一个字落在一张空表**下面**。
    focusInside: true,
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
