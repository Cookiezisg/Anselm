import 'package:flutter/widgets.dart';

import '../../i18n/strings.g.dart';
import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import 'an_a11y.dart';
import 'an_button.dart';
import 'an_dropdown.dart';
import 'an_edit_affordance.dart';
import 'an_lead_value.dart';
import 'an_seamless_field.dart';
import 'icons.dart';

/// How an editable value is edited in place. 就地编辑方式。
enum AnEditKind {
  /// Free text via a pencil → seamless field. 自由文本(铅笔 → seamless 框)。
  input,

  /// A closed set via an always-present inline dropdown. 枚举(常驻内联下拉)。
  select,
}

/// The kit's in-place value editor — the shared edit core of AnField + AnKv (the demo's `field.js`
/// editText / editSelect). A row of [leading] (key / label) + a flush-right value.
///
/// [AnEditKind.input]: display-only until you click the pencil that reveals on hover at the VALUE's
/// FAR RIGHT (the affordance rail); the value then swaps to a seamless field with Cancel / Save
/// co-located at that same far right — a single anchor beside the value being edited, never hopping
/// sides. Commit on Enter / Save / blur; cancel on Esc / Cancel. Abort wins via a one-shot [_finished]
/// guard, and the confirm buttons sit in a [TextFieldTapRegion] so tapping them is NOT a blur-commit
/// (cancel-priority). Focus returns to the pencil only on a KEYBOARD finish (Enter/Esc), not on a
/// pointer Cancel/Save / blur — see [_finish]. Entering edit announces politely. The display value
/// mirrors the field's style so toggling never jumps. The resting display is ALWAYS single-line
/// right-ellipsis (editable values are flush-right by decree — long prose is not an inline-editable
/// value's job).
///
/// [AnEditKind.select]: the value zone is an always-present ghost [AnDropdown] (it IS the editor — a
/// pick commits, outside-tap / Esc dismiss it harmlessly), so there's no dangling edit state to get
/// stuck in; like every resting value it sits flush-right with NO reserved rail (the input rows'
/// pencil only takes width on hover — the 两端对齐 mechanic). [rowHeight] is parameterized (Field
/// [AnSize.islandHead] / Kv [AnSize.row]) and [valueStyle] carries the value TIER (content 15 /
/// chrome 13), mirrored into the editing field so toggling never jumps.
///
/// 就地值编辑核(AnField + AnKv 共用,= demo field.js)。input:平时只读,hover 时 value 最右冒铅笔 →
/// 点铅笔值换 seamless 框、同一最右位置换 取消/保存(单锚贴值、绝不换边)。Enter/保存/失焦提交、Esc/取消 弃;
/// abort 经一次性 _finished 守卫优先,取消/保存套 TextFieldTapRegion 不触发失焦提交;仅键盘完成回落焦点到铅笔;
/// 进编辑礼貌宣告;展示值镜像编辑框样式不跳,且恒单行右省略(可编辑值钦定贴右)。select:值区=常驻 ghost 下拉
/// (它即编辑器),与他行静态值同样贴右、不留轨(铅笔仅悬停占宽——两端对齐机制)。rowHeight 参数化(Field
/// islandHead / Kv row);valueStyle 携值档(内容 15 / chrome 13)、镜像进编辑框,切换不跳。
class AnEditableValue extends StatefulWidget {
  const AnEditableValue({
    required this.leading,
    required this.fieldLabel,
    required this.value,
    required this.onChanged,
    this.rowHeight = AnSize.row,
    this.valueColor,
    this.valueStyle,
    this.editor = AnEditKind.input,
    this.options = const [],
    this.mono = false,
    this.startEditing = false,
    super.key,
  }) : assert(
         !startEditing || editor == AnEditKind.input,
         'startEditing applies to AnEditKind.input only — select has no edit state to open. 仅 input 适用',
       );

  /// The visual left zone (a key [Text], or a label + hint column). 视觉左区(key 文本 / label+hint 列)。
  final Widget leading;

  /// Identifies the field for the edit-entry announcement + the pencil's a11y label (N pencils in one
  /// list must be distinguishable). 用于编辑宣告 + 铅笔 a11y 标签的字段名(一列多铅笔须可分辨)。
  final String fieldLabel;
  final String value;
  final ValueChanged<String> onChanged;

  /// Row floor height (Field [AnSize.islandHead] / Kv [AnSize.row]). 行高下限。
  final double rowHeight;

  /// Display value colour (Field [AnColors.inkMuted] / Kv [AnColors.inkFaint]); defaults to inkMuted. 值色。
  final Color? valueColor;

  /// The value TIER style, mirrored across display AND the editing field (the no-jump contract) —
  /// content rows pass [AnText.valueReading], chrome rows the default [AnText.value]. 值档样式,
  /// 展示与编辑框同镜像(不跳契约):内容行传 valueReading、chrome 行默认 value。
  final TextStyle? valueStyle;

  final AnEditKind editor;

  /// Options for [AnEditKind.select]. 枚举选项。
  final List<AnDropdownOption<String>> options;
  final bool mono;

  /// Open directly in edit mode ([AnEditKind.input] only) — for galleries / matrix coverage of the
  /// editing state, or a freshly-added row. 直接进编辑态(仅 input,供 gallery/matrix + 新增行)。
  final bool startEditing;

  @override
  State<AnEditableValue> createState() => _AnEditableValueState();
}

class _AnEditableValueState extends State<AnEditableValue> {
  late final TextEditingController _ctl;
  late final FocusNode _pencilFocus;
  bool _editing = false;
  bool _finished = false; // one-shot per edit session 每次编辑一次性
  bool _hovered = false;

  @override
  void initState() {
    super.initState();
    // Eager init (never a late-final field initializer — lazy first-read can fire in teardown). 急切初始化。
    _ctl = TextEditingController(text: widget.value);
    _pencilFocus = FocusNode(debugLabel: 'AnEditableValue.pencil');
    _pencilFocus.addListener(_onPencilFocus);
    if (widget.startEditing && widget.editor == AnEditKind.input) {
      _editing = true;
      _ctl.selection = TextSelection.collapsed(
        offset: _ctl.text.length,
      ); // caret at end 光标落末
    }
  }

  void _onPencilFocus() {
    if (mounted) {
      setState(
        () {},
      ); // reveal the pencil when it takes keyboard focus 键盘聚焦时显铅笔
    }
  }

  @override
  void didUpdateWidget(AnEditableValue old) {
    super.didUpdateWidget(old);
    // External value change refreshes the resting text — never clobbers an in-progress edit. 外部改值刷新静态文字、不打断编辑。
    if (widget.value != old.value && !_editing) _ctl.text = widget.value;
  }

  @override
  void dispose() {
    _pencilFocus.removeListener(_onPencilFocus);
    _ctl.dispose();
    _pencilFocus.dispose();
    super.dispose();
  }

  void _begin() {
    // Reset from the current value — discards any text left over from a PRIOR ABORTED edit (didUpdateWidget
    // only syncs on an external value change, and an abort leaves widget.value unchanged). 重置丢弃上次取消遗留文本。
    _ctl.text = widget.value;
    // Caret at END — editing a value, NOT renaming, so no select-all. 光标落末(改值非重命名,不全选)。
    _ctl.selection = TextSelection.collapsed(offset: _ctl.text.length);
    setState(() {
      _editing = true;
      _finished = false;
    });
    // Entering edit is a mode change the reader cannot see — nothing else says it. 进编辑=看不见的模式切换。
    AnA11y.announce(
      context,
      context.t.a11y.editingField(field: widget.fieldLabel),
    );
  }

  // One-shot per session ([_finished]); abort (Cancel / Esc) wins if it lands first. Commit trims (no
  // dirty whitespace). The returnFocus decision is explained inline below. 一次性;abort 先到胜;提交去首尾空白。
  void _finish(bool commit, {required bool returnFocus}) {
    if (_finished) return;
    _finished = true;
    final next = _ctl.text.trim();
    if (!returnFocus) {
      // Pointer finish (Cancel/Save click / blur): drop focus from the about-to-be-removed editing zone
      // (the field or the button) BEFORE the rebuild — otherwise, when that focused node is removed,
      // Flutter RESTORES focus to the nearest survivor (the pencil), re-revealing + focus-ringing it.
      // Doing it pre-rebuild (synchronously) avoids the restoration entirely; a click elsewhere then
      // takes focus via its own gesture. 指针完成:重建前(同步)卸掉编辑区焦点,杜绝被自动恢复到铅笔。
      FocusManager.instance.primaryFocus?.unfocus();
    }
    setState(() => _editing = false);
    if (commit && next != widget.value) widget.onChanged(next);
    // returnFocus is decided by the SOURCE of the finish, NOT the input modality: the KEYBOARD paths
    // (Enter/Esc in the field) pass true so keyboard nav continues on the pencil; the POINTER paths (a
    // Cancel/Save click, blur) pass false — a click must NOT focus the pencil, else `revealPencil`
    // (reads hasFocus) pins it visible AND it paints its focus ring instead of returning to its hidden
    // resting state. NB: FocusManager.highlightMode can't tell mouse from keyboard on desktop — a MOUSE
    // pointer is also `traditional` (only finger-touch is `touch`) — so the call site decides.
    // returnFocus 按完成「来源」判定:键盘路径回落铅笔续导航;指针路径不回落(否则铅笔卡可见+画焦点框)。
    if (returnFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _pencilFocus.requestFocus();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final reduced = AnMotionPref.reduced(context);

    return Semantics(
      container: true,
      explicitChildNodes:
          true, // key / value / pencil / Cancel/Save each individually reachable 各自可达、不 merge
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: AnimatedContainer(
          duration: reduced
              ? Duration.zero
              : AnMotion
                    .fast, // hover / editing tint = functional micro-feedback 功能性微反馈
          constraints: BoxConstraints(minHeight: widget.rowHeight),
          padding: const EdgeInsets.symmetric(
            horizontal: AnSpace.s8,
            vertical: AnSpace.s4,
          ),
          decoration: BoxDecoration(
            color: c.surfaceHover.whenActive(_hovered || _editing),
            borderRadius: BorderRadius.circular(AnRadius.button),
          ),
          child: widget.editor == AnEditKind.select
              ? _selectRow()
              : _inputRow(c),
        ),
      ),
    );
  }

  // select: the value zone is an always-present ghost dropdown — no pencil, no editing state, so no
  // dangling state on dismiss (a pick commits; outside-tap / Esc just close it). The ghost dropdown
  // IS the always-live editor (no hover-reveal), so it fills flush-right like every other value's
  // resting state — no reserved rail. Its trigger renders the SAME tier style as the sibling text
  // values (a mixed list must not show one value a rung small).
  // select:常驻 ghost 下拉即编辑器,贴右填满、不留轨;触发器与同列文本值同档样式(混排列表不许有值矮一档)。
  Widget _selectRow() {
    return AnLeadValue(
      leading: widget.leading,
      trailing: AnDropdown<String>(
        options: widget.options,
        value: widget.value,
        variant: AnDropdownVariant.ghost,
        triggerStyle: widget.valueStyle ?? AnText.value(mono: widget.mono),
        menuAlignEnd: true,
        onChanged: widget.onChanged,
      ),
    );
  }

  Widget _inputRow(AnColors c) {
    final revealPencil = _hovered || _pencilFocus.hasFocus;
    return AnLeadValue(
      leading: widget.leading,
      trailing: _inputValueZone(c),
      // SINGLE affordance anchor at the value's FAR RIGHT: a hover-revealed pencil while idle,
      // Cancel/Save while editing — co-located, never hopping sides, beside the value it edits. The
      // pencil stays in the tree at opacity 0 so it's keyboard-reachable; Cancel/Save live in a
      // TextFieldTapRegion so tapping them isn't a blur-commit (cancel-priority), returnFocus:false as
      // a pointer finish. 单锚在值最右:idle 铅笔、editing 取消/保存,同处不换边、贴其所编之值;铅笔
      // opacity 0 常驻可达;按钮套 TapRegion 不触发失焦提交、点击不回落焦点。
      afterValue: _editing
          ? TextFieldTapRegion(
              child: AnEditAffordance(
                editing: true,
                onCommit: () => _finish(true, returnFocus: false),
                onAbort: () => _finish(false, returnFocus: false),
              ),
            )
          // Idle: the pencil collapses to ZERO width so the value sits flush-right; on hover / keyboard
          // focus it grows to a control width, pushing the value left to make room. The button stays in
          // the tree (clipped, opacity 0) so it's still tab-reachable — gaining focus flips `revealPencil`
          // and expands it. 静态:铅笔收成 0 宽让值贴右;悬停/键盘聚焦长出、把值挤左腾位。钮常驻(裁剪+透明0)
          // 仍可 Tab 到——聚焦即翻 revealPencil 展开。
          // widthFactor collapses the slot to 0 at rest (value flush-right) and to the button's width on
          // reveal (value pushed left), clipping the overflow — no unbounded-height OverflowBox, no space
          // reserved at rest. widthFactor 静态收 0(值贴右)、揭示时取钮宽(值挤左),裁溢出;无无界高 OverflowBox、静态不占位。
          : ClipRect(
              child: Align(
                alignment: Alignment.centerRight,
                widthFactor: revealPencil ? 1.0 : 0.0,
                child: Opacity(
                  opacity: revealPencil ? 1 : 0,
                  child: AnButton.iconOnly(
                    AnIcons.edit,
                    size: AnButtonSize.sm,
                    // Field-specific label — N pencils in one list must be distinguishable to a screen
                    // reader. 按字段命名,列表多铅笔可分辨。
                    semanticLabel: context.t.a11y.editField(
                      field: widget.fieldLabel,
                    ),
                    focusNode: _pencilFocus,
                    onPressed: _begin,
                  ),
                ),
              ),
            ),
    );
  }

  Widget _inputValueZone(AnColors c) {
    final base = widget.valueStyle ?? AnText.value(mono: widget.mono);
    final color = widget.valueColor ?? c.inkMuted;
    if (_editing) {
      return AnSeamlessField(
        controller: _ctl,
        mono: widget.mono,
        tabular:
            true, // value column: digits always tabular (idle ↔ editing same width) 值列数字恒等宽
        style:
            base, // the tier mirror — display and field MUST share it (no-jump) 值档镜像,展示/编辑同式
        framed:
            true, // demo edit frame (no row-height growth, right-only horizontal) 编辑框(不加行高、右生长)
        onCommit: () => _finish(true, returnFocus: true),
        onAbort: () => _finish(false, returnFocus: true),
        onTapOutside: (_) => _finish(
          true,
          returnFocus: false,
        ), // blur-commit; focus stays where clicked 失焦提交、焦点不回落
      );
    }
    // Display mirrors the seamless field's style (shared value-column style) so idle ↔ editing never
    // changes size/face; empty shows an em-dash; always single-line right-ellipsis (flush-right decree).
    // 展示走值列样式单源(切换不跳),空显 —,恒单行右省略(贴右钦定)。
    final display = widget.value.isEmpty ? '—' : widget.value;
    return Text(
      display,
      textAlign: TextAlign.right,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: base.copyWith(color: color),
    );
  }
}
