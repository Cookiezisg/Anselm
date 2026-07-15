import 'package:flutter/widgets.dart';

import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import 'an_button.dart';
import 'an_edit_affordance.dart';
import 'an_seamless_field.dart';

/// B6 — in-place rename: a title that swaps to a CONTENT-SIZED edit field. IDLE shows [value] as
/// text with the pencil a gap after it (ellipsis + pencil-pins-right when long). EDITING swaps in a
/// seamless field that GROWS with the typed content while Cancel / Save ride along just after it;
/// once the content fills the row the buttons pin to the right edge and the field scrolls (caret
/// stays visible). Enter commits, Esc aborts. Idle & editing share one fixed-height row, so toggling
/// never jumps.
///
/// The grow-then-cap is framework-native (researched: IntrinsicWidth beats per-keystroke TextPainter
/// measuring — the latter must re-mirror [AnText.body] byte-exact, the variable-font width drift
/// `typography.dart` already documents): [_DryIntrinsicWidth] sizes the field to its OWN render tree
/// (WYSIWYG, no style mirror), and [Flexible] caps it at the space the affordance leaves — so the
/// locale-variable button width self-reserves via the Row's flex pass (no hand-computed `−buttonW`).
///
/// B6——就地重命名:标题 ↔ 随内容自适应的编辑框。idle 文字 + 铅笔跟字尾(超长省略+钉右);editing 换 seamless 框、
/// 随打字增长,取消/保存紧跟其后;内容撑满行后按钮钉右、框转横滚(光标可见)。Enter 存、Esc 弃。idle/editing 共用
/// 一条定高行、切换不跳。增长封顶用框架原生(研究结论:IntrinsicWidth 胜过逐键 TextPainter 量宽——后者须逐字节
/// 重镜像 AnText.body,即 typography.dart 记过的变量字体宽度漂移):_DryIntrinsicWidth 按输入框自身渲染树定宽
/// (所见即所得、不镜像字体),Flexible 把它封到 affordance 让出的空间——本地化按钮宽经 Row 的 flex 自动让位
/// (无须手算「−按钮宽」)。
class AnInlineEdit extends StatefulWidget {
  const AnInlineEdit({
    required this.value,
    required this.onCommit,
    this.onAbort,
    this.enabled = true,
    this.startEditing = false,
    this.commitOnTapOutside = false,
    this.style,
    this.minHeight = AnSize.control,
    this.affordanceSize = AnButtonSize.sm,
    super.key,
  });

  final String value;
  final ValueChanged<String> onCommit;

  /// Fired when an edit is abandoned (Esc / Cancel) — the resting text is unchanged. A host that MOUNTS
  /// this only while editing (e.g. a sidebar row's rename, unmounted on done) wires this to drop its
  /// editing state so the row reverts to its display widget instead of flashing the idle pencil.
  /// 弃编辑(Esc/取消)回调,静态文字不变。仅在编辑时挂载本件的宿主(如 rail 行改名,完事即卸)接它清编辑态、回展示件、不闪 idle 铅笔。
  final VoidCallback? onAbort;
  final bool enabled;

  /// Open directly in edit mode (e.g. a freshly created entity awaiting its first name). 直接进编辑态。
  final bool startEditing;

  /// Blur-commit: an outside tap while EDITING commits (rather than the default Enter/✓/Esc-only). The
  /// document title/description opt IN (an idle click elsewhere on the page should save an in-progress
  /// rename); rail / entity / chat rename leave it false (a stray click must not silently rename).
  /// 失焦提交:编辑中点别处即保存(默认只 Enter/✓/Esc)。仅文档标题/描述传 true;rail/实体改名保持 false。
  final bool commitOnTapOutside;

  /// Text style for BOTH the idle title and the editing field (so toggling never changes face/size) —
  /// e.g. an H2 title rename in AnOceanHeader. Defaults to [AnText.body]. The colour is always ink.
  /// idle 与编辑共用的文字样式(切换不改面/号),如 AnOceanHeader 的 H2 标题改名;默认 body,色恒 ink。
  final TextStyle? style;

  /// Row height — raise it for a tall [style] (e.g. [AnSize.islandHead] for an H2 title). 行高(高样式时调大)。
  final double minHeight;

  /// Pencil tier — md beside content-tier titles (a 12px sm pencil reads a system too small next to
  /// 15/w400), sm in dense rows. 铅笔档位:内容档标题旁用 md,密集行守 sm。
  final AnButtonSize affordanceSize;

  @override
  State<AnInlineEdit> createState() => _AnInlineEditState();
}

class _AnInlineEditState extends State<AnInlineEdit> {
  late final TextEditingController _ctl = TextEditingController(
    text: widget.value,
  );
  late String _committed = widget.value;
  late bool _editing = widget.startEditing;
  bool _hovered = false; // pointer hovering the row → reveals the pencil 悬停揭示铅笔
  bool _focusWithin =
      false; // keyboard focus anywhere inside → also reveals (a11y) 键盘焦点在内也揭示

  @override
  void initState() {
    super.initState();
    // startEditing opens already selected — same as tapping the pencil 直接进编辑也全选
    if (_editing) _selectAll();
  }

  @override
  void didUpdateWidget(AnInlineEdit old) {
    super.didUpdateWidget(old);
    // A parent-driven value change (NOT echoing our own commit) refreshes the resting text — but
    // never clobbers an in-progress edit. 父级改值(非回显本地提交)时刷新静态文字,但不打断进行中的编辑。
    if (widget.value != old.value && widget.value != _committed) {
      _committed = widget.value;
      if (!_editing) _ctl.text = widget.value;
    }
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  // Rename UX: select-all on entry so the first keystroke replaces (Finder / F2 convention). 进编辑全选。
  void _selectAll() => _ctl.selection = TextSelection(
    baseOffset: 0,
    extentOffset: _ctl.text.length,
  );

  void _begin() => setState(() {
    _ctl.text = _committed;
    _selectAll();
    _editing = true;
  });

  // Keyboard finishes (Enter/Esc) RETURN focus to the pencil so keyboard nav continues; POINTER finishes
  // (Save/Cancel click, blur) drop focus SYNCHRONOUSLY before the rebuild — else removing the focused
  // field/button restores focus to the pencil, pinning it revealed + focus-ringed (mirrors AnEditableValue._finish).
  // 键盘完成回落铅笔续导航;指针完成重建前同步卸焦,杜绝铅笔被恢复焦点卡显。
  void _commit({bool returnFocus = true}) {
    final next = _ctl.text;
    if (!returnFocus) FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _committed = next;
      _editing = false;
    });
    widget.onCommit(next);
  }

  void _abort({bool returnFocus = true}) {
    if (!returnFocus) FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _ctl.text = _committed;
      _editing = false;
    });
    widget.onAbort?.call();
  }

  void _setHover(bool v) {
    if (_hovered != v && mounted) setState(() => _hovered = v);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    // READ-ONLY (enabled:false): a plain title with NO edit affordance — a disabled/greyed pencil is a
    // phantom control (e.g. a skill's name IS its identity, not renamable). Same fixed footprint + face as
    // idle so nothing around it shifts. 只读:纯标题、无 affordance(灰死铅笔=幽灵控件;如 skill 名即身份不可改),同定高同字面。
    if (!widget.enabled) {
      return SizedBox(
        height: widget.minHeight,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            _committed,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            style: (widget.style ?? AnText.body).copyWith(color: c.ink),
          ),
        ),
      );
    }

    final reduced = AnMotionPref.reduced(context);
    // The pencil reveals on hover OR keyboard focus-within, and stays lit while editing. 悬停/键盘聚焦/编辑时显。
    final affordanceVisible = _editing || _hovered || _focusWithin;

    final affordance = AnEditAffordance(
      editing: _editing,
      size: widget.affordanceSize,
      onEdit: _begin,
      onCommit: () => _commit(returnFocus: false), // Save click = pointer
      onAbort: () => _abort(returnFocus: false), // Cancel click = pointer
    );
    // Cancel-priority: with blur-commit ON, a tap on Cancel/Save must be "inside" the field's tap group so
    // it doesn't ALSO fire onTapOutside (a blur-commit). 取消优先:失焦提交时把 ✓✕ 纳入字段 tap 组,点它们不触发失焦提交。
    final gatedAffordance = widget.commitOnTapOutside
        ? TextFieldTapRegion(child: affordance)
        : affordance;

    return MouseRegion(
      onEnter: (_) => _setHover(true),
      onExit: (_) => _setHover(false),
      child: Focus(
        canRequestFocus:
            false, // an observer, not a tab stop — reports descendant focus only 只观察焦点、非 tab 位
        skipTraversal: true,
        onFocusChange: (v) {
          if (_focusWithin != v && mounted) setState(() => _focusWithin = v);
        },
        child: SizedBox(
          height: widget
              .minHeight, // fixed footprint — idle & editing share it, no jump 定高,静态/编辑共用、不跳
          child: Row(
            // min: under a LOOSE host the row hugs its content; a tight host (Expanded) is unaffected.
            // min:loose 宿主下收紧到内容宽;tight 宿主(Expanded)不受影响。
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: _editing
                    ? AnSeamlessField(
                        controller: _ctl,
                        style: widget.style,
                        framed: true,
                        onCommit: () =>
                            _commit(returnFocus: true), // Enter = keyboard
                        onAbort: () =>
                            _abort(returnFocus: true), // Esc = keyboard
                        // Blur-commit only when opted in — clicking away otherwise must NOT silently rename.
                        onTapOutside: widget.commitOnTapOutside
                            ? (_) => _commit(returnFocus: false)
                            : null,
                      )
                    : Text(
                        _committed,
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.ellipsis,
                        style: (widget.style ?? AnText.body).copyWith(
                          color: c.ink,
                        ),
                      ),
              ),
              const SizedBox(
                width: AnSpace.s8,
              ), // gap reserved in BOTH states — opacity-only reveal never twitches 同定间距,渐显不跳
              // Opacity-0 keeps the pencil LAID OUT (no jump) AND hit / keyboard reachable (a Tab onto it
              // flips _focusWithin → fades in). reduced-motion → instant show/hide. 透明 0 保版位+可命中/可 Tab;reduced 直显隐。
              AnimatedOpacity(
                opacity: affordanceVisible ? 1 : 0,
                duration: reduced ? Duration.zero : AnMotion.fast,
                child: gatedAffordance,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
