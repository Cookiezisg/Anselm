import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:super_editor/super_editor.dart';

import '../design/colors.dart';
import '../design/tokens.dart';
import '../ui/an_interactive.dart';
import '../ui/icons.dart';

/// The floating inline-format toolbar — appears ABOVE an expanded text selection and toggles bold /
/// italic / strikethrough / inline-code on it. A super_editor **document overlay layer** (the timing-safe
/// mechanism the slash & mention popovers use): it listens to the composer's selection, positions after
/// layout in document coords, and flips nothing fancy — a small centred bar hovering over the selection.
/// 划选浮动格式条:选区上方浮现,切 粗/斜/删/行内码。文档 overlay 层(同 slash/@ 时序安全),听选区、布局后定位。
class AnSelectionToolbar extends DocumentLayoutLayerStatefulWidget {
  const AnSelectionToolbar({super.key, required this.editor, required this.document, required this.composer});

  final Editor editor;
  final Document document;
  final DocumentComposer composer;

  @override
  DocumentLayoutLayerState<AnSelectionToolbar, ToolbarPlacement?> createState() => _AnSelectionToolbarState();
}

// The selection rect + whether the bar hangs BELOW it (flipped when the selection hugs the content top,
// where above would sit off-screen). 选区矩形 + 是否挂下方(选区贴顶时上方会出屏→翻下)。
typedef ToolbarPlacement = ({Rect rect, bool below});

class _AnSelectionToolbarState extends DocumentLayoutLayerState<AnSelectionToolbar, ToolbarPlacement?> {
  static const double _barHeight = AnSize.row + AnSpace.s4 * 2; // row + panel padding 估条高
  @override
  void initState() {
    super.initState();
    widget.composer.selectionNotifier.addListener(_onSelectionChange);
  }

  @override
  void didUpdateWidget(AnSelectionToolbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.composer != oldWidget.composer) {
      oldWidget.composer.selectionNotifier.removeListener(_onSelectionChange);
      widget.composer.selectionNotifier.addListener(_onSelectionChange);
    }
  }

  @override
  void dispose() {
    widget.composer.selectionNotifier.removeListener(_onSelectionChange);
    super.dispose();
  }

  void _onSelectionChange() {
    // Re-position on the next frame if the pipeline isn't mid-build (the caret overlay's own guard). 帧外才重建。
    if (mounted && SchedulerBinding.instance.schedulerPhase != SchedulerPhase.persistentCallbacks) {
      setState(() {});
    }
  }

  @override
  ToolbarPlacement? computeLayoutDataWithDocumentLayout(
    BuildContext contentLayersContext,
    BuildContext documentContext,
    DocumentLayout documentLayout,
  ) {
    final sel = widget.composer.selection;
    if (sel == null || sel.isCollapsed) return null; // only for an EXPANDED selection 仅展开选区
    final rect = documentLayout.getRectForSelection(sel.base, sel.extent);
    if (rect == null) return null;
    // Hang above by default; flip below when above would sit off the top of the content. 默认上方,贴顶翻下。
    return (rect: rect, below: rect.top - AnSpace.s8 - _barHeight < 0);
  }

  @override
  Widget doBuild(BuildContext context, ToolbarPlacement? placement) {
    final sel = widget.composer.selection;
    if (placement == null || sel == null || sel.isCollapsed) return const SizedBox.shrink();
    final rect = placement.rect;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: rect.left + rect.width / 2, // horizontal centre of the selection 选区水平中点
          top: placement.below ? rect.bottom + AnSpace.s8 : rect.top - AnSpace.s8,
          // FractionalTranslation centres the bar horizontally (-0.5w); vertically it either lifts fully
          // above (-1.0h) or hangs below (0). 水平居中;竖直按上/下。
          child: FractionalTranslation(
            translation: Offset(-0.5, placement.below ? 0.0 : -1.0),
            child: _AnFormatBar(editor: widget.editor, document: widget.document, selection: sel),
          ),
        ),
      ],
    );
  }
}

/// The compact floating bar — a white island (hairline + pop shadow + pill) of format toggles. 紧凑浮条。
class _AnFormatBar extends StatelessWidget {
  const _AnFormatBar({required this.editor, required this.document, required this.selection});

  final Editor editor;
  final Document document;
  final DocumentSelection selection;

  // Which of the toggle attributions are applied THROUGHOUT the (single-node) selection → shown active.
  // Cross-node selections skip active-state (the toggle still works). 单节点选区内通贯的属性=激活态。
  Set<Attribution> _activeAttributions() {
    if (selection.base.nodeId != selection.extent.nodeId) return const {};
    final node = document.getNodeById(selection.extent.nodeId);
    if (node is! TextNode) return const {};
    final a = (selection.base.nodePosition as TextNodePosition).offset;
    final b = (selection.extent.nodePosition as TextNodePosition).offset;
    final start = a < b ? a : b;
    final end = a < b ? b : a;
    if (start >= end) return const {};
    return node.text.getAllAttributionsThroughout(SpanRange(start, end - 1));
  }

  void _toggle(Attribution attribution) {
    editor.execute([
      ToggleTextAttributionsRequest(documentRange: selection, attributions: {attribution}),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final active = _activeAttributions();
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AnRadius.chip),
        border: Border.all(color: c.line, width: AnSize.hairline),
        boxShadow: c.shadowPop,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AnSpace.s4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _FormatButton(icon: AnIcons.bold, active: active.contains(boldAttribution), onTap: () => _toggle(boldAttribution)),
            _FormatButton(icon: AnIcons.italic, active: active.contains(italicsAttribution), onTap: () => _toggle(italicsAttribution)),
            _FormatButton(
                icon: AnIcons.strikethrough,
                active: active.contains(strikethroughAttribution),
                onTap: () => _toggle(strikethroughAttribution)),
            _FormatButton(icon: AnIcons.codeBlock, active: active.contains(codeAttribution), onTap: () => _toggle(codeAttribution)),
          ],
        ),
      ),
    );
  }
}

class _FormatButton extends StatelessWidget {
  const _FormatButton({required this.icon, required this.active, required this.onTap});

  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnInteractive(
      onTap: onTap,
      builder: (context, states) {
        final c = context.colors;
        final hot = states.isActive || active;
        return AnimatedContainer(
          duration: AnMotion.fast,
          width: AnSize.row,
          height: AnSize.row,
          decoration: BoxDecoration(
            color: (active ? c.accentSoft : c.surfaceHover).whenActive(hot),
            borderRadius: BorderRadius.circular(AnRadius.button),
          ),
          child: Icon(icon, size: AnSize.icon, color: active ? c.accent : c.ink),
        );
      },
    );
  }
}
