import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';

import '../design/tokens.dart';
import '../ui/an_menu_surface.dart';
import '../ui/an_mention_picker.dart';
import '../ui/an_ref_pill.dart';
import '../ui/icons.dart';

/// An entity @mention embedded INLINE in the editor's text as an [AttributedText] placeholder object (not
/// styled text) — so it renders as a real icon+name pill, not just coloured text. The document persists
/// only the [id] (`[[id]]` wikilink, the backend's link-edge contract); [name]/[kind] are resolved for
/// display and cached (re-resolved via `MentionSource.resolveNames` on load). 内联实体提及:作 placeholder 对象
/// 嵌进文本→渲成图标+名药丸(非纯文字);只 id 落盘(`[[id]]`),名/kind 显示用、load 时经 resolveNames 重解析。
@immutable
class MentionPlaceholder {
  const MentionPlaceholder({
    required this.id,
    required this.name,
    required this.kind,
  });

  /// The entity id — the ONLY thing persisted (`[[id]]`). 唯一落盘。
  final String id;

  /// Display name (resolved; may be stale/absent → the pill falls back to the id). 显示名(可回落 id)。
  final String name;

  /// Wire kind string (function/handler/agent/workflow/document…) → the pill glyph via [AnIcons.byKey].
  /// 线缆 kind → 药丸图标。
  final String kind;

  @override
  bool operator ==(Object other) =>
      other is MentionPlaceholder &&
      other.id == id &&
      other.name == name &&
      other.kind == kind;

  @override
  int get hashCode => Object.hash(id, name, kind);
}

/// The inline-widget builder that turns a [MentionPlaceholder] into the pill. Returns null for any other
/// placeholder so the chain falls through to the defaults. Added to the stylesheet's inlineWidgetBuilders.
/// placeholder→药丸;非本类返 null 放行。挂进样式表 inlineWidgetBuilders。
Widget? anMentionInlineWidgetBuilder(
  BuildContext context,
  TextStyle textStyle,
  Object placeholder,
) {
  if (placeholder is! MentionPlaceholder) return null;
  return _MentionPill(mention: placeholder, textStyle: textStyle);
}

/// The @mention picker as a super_editor document overlay layer — the SAME timing-safe mechanism the
/// slash menu uses (positions after layout, in document coords). Anchored to the `@` trigger; the host
/// drives the async candidate search + keyboard state. @ picker=文档 overlay 层(同 slash 时序安全机制)。
class AnMentionOverlay extends DocumentLayoutLayerStatefulWidget {
  const AnMentionOverlay({
    super.key,
    required this.composing,
    required this.items,
    required this.activeIndex,
    required this.onPick,
  });

  final ComposingStableTag? composing;
  final List<AnMentionRowData> items;
  final int activeIndex;
  final ValueChanged<int> onPick;

  @override
  DocumentLayoutLayerState<AnMentionOverlay, ({double left, double top})?>
  createState() => _AnMentionOverlayState();
}

class _AnMentionOverlayState
    extends
        DocumentLayoutLayerState<
          AnMentionOverlay,
          ({double left, double top})?
        > {
  @override
  ({double left, double top})? computeLayoutDataWithDocumentLayout(
    BuildContext contentLayersContext,
    BuildContext documentContext,
    DocumentLayout documentLayout,
  ) {
    final composing = widget.composing;
    if (composing == null || widget.items.isEmpty) return null;
    final anchorPos = composing.contentBounds.start;
    if (documentLayout.getComponentByNodeId(anchorPos.nodeId) == null) {
      return null;
    }
    final anchor = documentLayout.getRectForPosition(anchorPos);
    if (anchor == null) return null;

    // Shared caret-anchored placement (A-104) — flip above when below overflows (same as slash). 同 slash 翻转。
    final box = context.findRenderObject() as RenderBox?;
    final layerHeight = (box != null && box.hasSize)
        ? box.size.height
        : double.infinity;
    return AnMenuSurface.caretPlacement(
      anchor: anchor,
      rows: widget.items.length,
      layerHeight: layerHeight,
    );
  }

  @override
  Widget doBuild(BuildContext context, ({double left, double top})? placement) {
    if (placement == null || widget.items.isEmpty) {
      return const SizedBox.shrink();
    }
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          top: placement.top,
          left: placement.left,
          // AnMentionPanel only caps its HEIGHT (it's normally sized to the composer's width); floating at
          // the caret it needs a bounded width or it lays out unbounded. 面板只封高,浮层处须给定宽。
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: AnSize.menuMinWidth,
              maxWidth: AnSize.menuMaxWidth,
            ),
            child: AnMentionPanel(
              items: widget.items,
              activeIndex: widget.activeIndex,
              onPick: widget.onPick,
            ),
          ),
        ),
      ],
    );
  }
}

class _MentionPill extends StatelessWidget {
  const _MentionPill({required this.mention, required this.textStyle});

  final MentionPlaceholder mention;
  final TextStyle textStyle;

  @override
  Widget build(BuildContext context) {
    final label = mention.name.isEmpty ? mention.id : mention.name;
    // LineHeight sizes the inline box to the surrounding line so the pill sits ON the text baseline
    // (the same wrapper the package's inline image builder uses) — it MUST stay here in core/editor
    // (core/ui never imports super_editor). The shell inside is the family inline face (批5 A-029 —
    // the hand-rolled capsule retires; display-only, no gestures: caret hit-testing/IME stay whole).
    // LineHeight 让药丸贴基线(须留 editor 层,core/ui 不进 super_editor);内壳=族行内脸(纯展示,
    // 无手势——光标命中/IME 不破)。
    return LineHeight(
      style: textStyle,
      child: AnRefPill.inline(kind: mention.kind, label: label),
    );
  }
}
