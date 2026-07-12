import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:super_editor/super_editor.dart';

import '../../i18n/strings.g.dart';
import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../ui/an_interactive.dart';
import '../ui/icons.dart';

/// The floating inline-format toolbar — appears ABOVE an expanded text selection and toggles bold /
/// italic / strikethrough / inline-code, plus LINK (tap opens a small URL input in place of the bar;
/// Enter applies a [LinkAttribution] to the captured selection, Esc cancels; when the selection already
/// carries a link, the same button UNLINKS it). A super_editor **document overlay layer** (the timing-safe
/// mechanism the slash & mention popovers use): it listens to the composer's selection, positions after
/// layout in document coords. The URL-input session CAPTURES the selection + placement when it opens —
/// the editor's live selection may clear when the input takes focus, and the attribution still applies
/// to the captured range. 划选浮动格式条:粗/斜/删/行内码 + 链接(点开原位 URL 输入;回车上链、Esc 取消;
/// 已带链接则同键去链)。URL 会话开启时**快照**选区+落点——输入夺焦会清编辑器活选区,上链仍打在快照区间。
class AnSelectionToolbar extends DocumentLayoutLayerStatefulWidget {
  const AnSelectionToolbar({
    super.key,
    required this.editor,
    required this.document,
    required this.composer,
    this.editorFocusNode,
  });

  final Editor editor;
  final Document document;
  final DocumentComposer composer;

  /// The editor's focus node — focus returns here when the URL input closes. 编辑器焦点(URL 输入关后归还)。
  final FocusNode? editorFocusNode;

  @override
  DocumentLayoutLayerState<AnSelectionToolbar, ToolbarPlacement?>
  createState() => _AnSelectionToolbarState();
}

// The selection rect + whether the bar hangs BELOW it (flipped when the selection hugs the content top,
// where above would sit off-screen). 选区矩形 + 是否挂下方(选区贴顶时上方会出屏→翻下)。
typedef ToolbarPlacement = ({Rect rect, bool below});

class _AnSelectionToolbarState
    extends DocumentLayoutLayerState<AnSelectionToolbar, ToolbarPlacement?> {
  // The open URL-input session: the SNAPSHOTTED selection + placement (survives the editor's selection
  // clearing when the input field takes focus). Null = the normal format bar. URL 输入会话快照;null=常规条。
  ({DocumentSelection sel, ToolbarPlacement placement})? _linkSession;

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
    if (mounted &&
        SchedulerBinding.instance.schedulerPhase !=
            SchedulerPhase.persistentCallbacks) {
      setState(() {});
    }
  }

  void _openLinkInput(DocumentSelection sel, ToolbarPlacement placement) {
    setState(() => _linkSession = (sel: sel, placement: placement));
  }

  void _closeLinkInput({String? url}) {
    final session = _linkSession;
    setState(() => _linkSession = null);
    if (session == null) return;
    final trimmed = url?.trim() ?? '';
    if (trimmed.isNotEmpty) {
      // Bare domains get https:// — the common paste shape. 裸域名补 https://。
      final normalized =
          trimmed.contains('://') || trimmed.startsWith('mailto:')
          ? trimmed
          : 'https://$trimmed';
      widget.editor.execute([
        AddTextAttributionsRequest(
          documentRange: session.sel,
          attributions: {LinkAttribution(normalized)},
        ),
      ]);
    }
    widget.editorFocusNode?.requestFocus();
  }

  @override
  ToolbarPlacement? computeLayoutDataWithDocumentLayout(
    BuildContext contentLayersContext,
    BuildContext documentContext,
    DocumentLayout documentLayout,
  ) {
    // A live URL session pins its snapshotted placement (the editor selection may already be gone).
    // URL 会话钉住快照落点(编辑器选区此刻可能已清)。
    final session = _linkSession;
    if (session != null) return session.placement;
    final sel = widget.composer.selection;
    if (sel == null || sel.isCollapsed) {
      return null; // only for an EXPANDED selection 仅展开选区
    }
    final rect = documentLayout.getRectForSelection(sel.base, sel.extent);
    if (rect == null) return null;
    // Hang above by default; flip below when above would sit off the top of the content. 默认上方,贴顶翻下。
    return (rect: rect, below: rect.top - AnSpace.s8 - _AnFormatBar.kHeight < 0);
  }

  @override
  Widget doBuild(BuildContext context, ToolbarPlacement? placement) {
    final session = _linkSession;
    final sel = session?.sel ?? widget.composer.selection;
    if (placement == null || sel == null || sel.isCollapsed) {
      return const SizedBox.shrink();
    }
    final rect = placement.rect;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left:
              rect.left +
              rect.width / 2, // horizontal centre of the selection 选区水平中点
          top: placement.below
              ? rect.bottom + AnSpace.s8
              : rect.top - AnSpace.s8,
          // FractionalTranslation centres the bar horizontally (-0.5w); vertically it either lifts fully
          // above (-1.0h) or hangs below (0). 水平居中;竖直按上/下。
          child: FractionalTranslation(
            translation: Offset(-0.5, placement.below ? 0.0 : -1.0),
            child: session != null
                ? _LinkInputBar(
                    onDone: (url) => _closeLinkInput(url: url),
                    onCancel: _closeLinkInput,
                  )
                : _AnFormatBar(
                    editor: widget.editor,
                    document: widget.document,
                    selection: sel,
                    onLink: () => _openLinkInput(sel, placement),
                  ),
          ),
        ),
      ],
    );
  }
}

/// The compact floating bar — a white island (hairline + pop shadow + pill) of format toggles. 紧凑浮条。
class _AnFormatBar extends StatelessWidget {
  const _AnFormatBar({
    required this.editor,
    required this.document,
    required this.selection,
    required this.onLink,
  });

  final Editor editor;
  final Document document;
  final DocumentSelection selection;
  final VoidCallback onLink;

  /// The bar's SELF-REPORTED height for the placement flip: row-tall content inside the s4 vertical
  /// inset — bound to this widget's own padding (build: `EdgeInsets.all(s4)` around row-tall buttons);
  /// the swapped-in [_LinkInputBar] shares the identical vertical structure (`vertical: s4` + row-tall
  /// field). 条自报高(定位翻转用):row 内容 + 上下 s4 内距——绑定本条自身 padding 结构,URL 输入脸同构。
  static const double kHeight = AnSize.row + AnSpace.s4 * 2;

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
      ToggleTextAttributionsRequest(
        documentRange: selection,
        attributions: {attribution},
      ),
    ]);
  }

  /// Linked throughout → strip the existing link(s); otherwise open the URL input. 已通贯带链→去链;否则开输入。
  void _linkAction(Set<Attribution> active) {
    final links = active.whereType<LinkAttribution>().toSet();
    if (links.isNotEmpty) {
      editor.execute([
        RemoveTextAttributionsRequest(
          documentRange: selection,
          attributions: links,
        ),
      ]);
    } else {
      onLink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final active = _activeAttributions();
    final linked = active.whereType<LinkAttribution>().isNotEmpty;
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
            _FormatButton(
              icon: AnIcons.bold,
              active: active.contains(boldAttribution),
              onTap: () => _toggle(boldAttribution),
            ),
            _FormatButton(
              icon: AnIcons.italic,
              active: active.contains(italicsAttribution),
              onTap: () => _toggle(italicsAttribution),
            ),
            _FormatButton(
              icon: AnIcons.strikethrough,
              active: active.contains(strikethroughAttribution),
              onTap: () => _toggle(strikethroughAttribution),
            ),
            _FormatButton(
              icon: AnIcons.codeBlock,
              active: active.contains(codeAttribution),
              onTap: () => _toggle(codeAttribution),
            ),
            _FormatButton(
              icon: AnIcons.link,
              active: linked,
              onTap: () => _linkAction(active),
            ),
          ],
        ),
      ),
    );
  }
}

/// The in-place URL input — swaps into the bar's spot; Enter applies, Esc cancels. Same island chrome.
/// 原位 URL 输入条:回车上链、Esc 取消;同款白岛壳。
class _LinkInputBar extends StatefulWidget {
  const _LinkInputBar({required this.onDone, required this.onCancel});

  final ValueChanged<String> onDone;
  final VoidCallback onCancel;

  @override
  State<_LinkInputBar> createState() => _LinkInputBarState();
}

class _LinkInputBarState extends State<_LinkInputBar> {
  final TextEditingController _controller = TextEditingController();
  // Own ONE FocusNode — building it inline in build() leaks a node per rebuild. 一个焦点节点,勿在 build 里新建。
  final FocusNode _keyFocus = FocusNode(skipTraversal: true);

  @override
  void dispose() {
    _controller.dispose();
    _keyFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = Translations.of(context);
    // Outside-click dismisses (cancel) — the session otherwise only exits via Enter/Esc, and a floating
    // orphan input reads as a bug. 外点即取消——否则只有回车/Esc 能退,悬空输入条像 bug。
    return TapRegion(
      onTapOutside: (_) => widget.onCancel(),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(AnRadius.chip),
          border: Border.all(color: c.line, width: AnSize.hairline),
          boxShadow: c.shadowPop,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AnSpace.s8,
            vertical: AnSpace.s4,
          ),
          child: SizedBox(
            width: AnSize.linkField,
            height: AnSize.row,
            child: Row(
              children: [
                Icon(AnIcons.link, size: AnSize.iconSm, color: c.inkFaint),
                const SizedBox(width: AnSpace.s6),
                Expanded(
                  child: KeyboardListener(
                    focusNode: _keyFocus,
                    onKeyEvent: (e) {
                      if (e.logicalKey.keyLabel == 'Escape') widget.onCancel();
                    },
                    child: TextField(
                      controller: _controller,
                      autofocus: true,
                      style: AnText.mono.copyWith(color: c.ink),
                      decoration: InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        hintText: t.documents.linkHint,
                        hintStyle: AnText.body.copyWith(color: c.inkFaint),
                      ),
                      onSubmitted: widget.onDone,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FormatButton extends StatelessWidget {
  const _FormatButton({
    required this.icon,
    required this.active,
    required this.onTap,
  });

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
          child: Icon(
            icon,
            size: AnSize.icon,
            color: active ? c.accent : c.ink,
          ),
        );
      },
    );
  }
}
