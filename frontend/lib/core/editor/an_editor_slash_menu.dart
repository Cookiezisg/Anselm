import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';

import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../ui/an_menu_surface.dart';
import '../ui/icons.dart';

/// One slash-menu command — a block type the `/` menu can turn the current paragraph into. [requests]
/// returns the editor requests that perform the conversion on [nodeId] (empty for "plain paragraph" —
/// the tag deletion alone leaves a paragraph). [keywords] widen the match beyond the label (English +
/// aliases) so `/h1`, `/quote`, `/code` all hit. 一条 slash 命令:把当前段落转成某块型;requests 出转换请求。
class SlashCommand {
  const SlashCommand({
    required this.label,
    required this.icon,
    required this.keywords,
    required this.requests,
  });

  final String label;
  final IconData icon;
  final List<String> keywords;
  final List<EditRequest> Function(String nodeId) requests;

  bool matches(String query) {
    if (query.isEmpty) return true;
    final q = query.toLowerCase();
    return label.toLowerCase().contains(q) || keywords.any((k) => k.toLowerCase().contains(q));
  }
}

/// The full slash palette — every block type E2 renders, in the reading order a writer expects. Labels
/// are Chinese for now (the editor lives in a dev harness; i18n lands when it's wired into the documents
/// ocean, E9). slash 全表——覆盖 E2 所有块型;标签暂中文(接进文档海洋 E9 时走 i18n)。
final List<SlashCommand> slashCommands = [
  SlashCommand(label: '正文', icon: AnIcons.paragraph, keywords: ['text', 'p', 'paragraph', 'zhengwen'], requests: _paragraph),
  SlashCommand(label: '标题 1', icon: AnIcons.heading1, keywords: ['h1', 'heading', 'biaoti'], requests: _h1),
  SlashCommand(label: '标题 2', icon: AnIcons.heading2, keywords: ['h2', 'heading', 'biaoti'], requests: _h2),
  SlashCommand(label: '标题 3', icon: AnIcons.heading3, keywords: ['h3', 'heading', 'biaoti'], requests: _h3),
  SlashCommand(label: '引用', icon: AnIcons.quote, keywords: ['quote', 'blockquote', 'yinyong'], requests: _quote),
  SlashCommand(label: '代码块', icon: AnIcons.codeBlock, keywords: ['code', 'fenced', 'daima'], requests: _code),
  SlashCommand(label: '无序列表', icon: AnIcons.listBulleted, keywords: ['ul', 'bullet', 'list', 'liebiao'], requests: _ul),
  SlashCommand(label: '有序列表', icon: AnIcons.listNumbered, keywords: ['ol', 'ordered', 'number', 'liebiao'], requests: _ol),
  SlashCommand(label: '任务', icon: AnIcons.todo, keywords: ['task', 'todo', 'checkbox', 'renwu'], requests: _task),
];

List<EditRequest> _paragraph(String id) =>
    [ChangeParagraphBlockTypeRequest(nodeId: id, blockType: paragraphAttribution)];
List<EditRequest> _h1(String id) => [ChangeParagraphBlockTypeRequest(nodeId: id, blockType: header1Attribution)];
List<EditRequest> _h2(String id) => [ChangeParagraphBlockTypeRequest(nodeId: id, blockType: header2Attribution)];
List<EditRequest> _h3(String id) => [ChangeParagraphBlockTypeRequest(nodeId: id, blockType: header3Attribution)];
List<EditRequest> _quote(String id) =>
    [ChangeParagraphBlockTypeRequest(nodeId: id, blockType: blockquoteAttribution)];
List<EditRequest> _code(String id) => [ChangeParagraphBlockTypeRequest(nodeId: id, blockType: codeAttribution)];
List<EditRequest> _ul(String id) => [ConvertParagraphToListItemRequest(nodeId: id, type: ListItemType.unordered)];
List<EditRequest> _ol(String id) => [ConvertParagraphToListItemRequest(nodeId: id, type: ListItemType.ordered)];
List<EditRequest> _task(String id) => [ConvertParagraphToTaskRequest(nodeId: id)];

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
  DocumentLayoutLayerState<AnSlashMenuOverlay, SlashPlacement?> createState() => _AnSlashMenuOverlayState();
}

// The resolved menu placement: the top-left corner (document coords) already flip-adjusted. 已翻转的落点。
typedef SlashPlacement = ({double left, double top});

class _AnSlashMenuOverlayState extends DocumentLayoutLayerState<AnSlashMenuOverlay, SlashPlacement?> {
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

    // Estimated menu height (rows + the panel's s4 top/bottom padding), capped at the panel's maxHeight.
    // 菜单估高(行 + 面板上下 s4 内距),不超面板 maxHeight。
    final menuHeight = (widget.matches.length * AnSize.row + AnSpace.s8).clamp(0.0, 328.0);
    final box = context.findRenderObject() as RenderBox?;
    final layerHeight = (box != null && box.hasSize) ? box.size.height : double.infinity;

    // Hang BELOW the trigger by default; flip ABOVE only if below would overflow the content AND above
    // fits. 默认挂下方;仅当下方溢出内容且上方放得下时,翻到上方。
    final wouldOverflow = anchor.bottom + AnSpace.s4 + menuHeight > layerHeight;
    final fitsAbove = anchor.top - AnSpace.s4 - menuHeight >= 0;
    final top = (wouldOverflow && fitsAbove) ? anchor.top - AnSpace.s4 - menuHeight : anchor.bottom + AnSpace.s4;
    return (left: anchor.left, top: top);
  }

  @override
  Widget doBuild(BuildContext context, SlashPlacement? placement) {
    if (placement == null || widget.matches.isEmpty) return const SizedBox.shrink();
    // A Stack with a single Positioned child — empty areas don't hit-test, so taps outside the menu pass
    // through to the editor below (NOT IgnorePointer — the menu itself must catch its own taps). 空处穿透。
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          top: placement.top,
          left: placement.left,
          child: AnSlashMenu(commands: widget.matches, activeIndex: widget.activeIndex, onSelect: widget.onSelect),
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
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 208, maxWidth: 268, maxHeight: 328),
      child: AnMenuSurface(
        children: [
          for (var i = 0; i < commands.length; i++)
            AnMenuRow(
              onTap: () => onSelect(commands[i]),
              highlighted: i == activeIndex,
              builder: (ctx, active) => Row(
                children: [
                  Icon(commands[i].icon, size: AnSize.icon, color: active ? c.ink : c.inkMuted),
                  const SizedBox(width: AnSpace.s8),
                  Text(commands[i].label, style: AnText.body.copyWith(color: c.ink)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
