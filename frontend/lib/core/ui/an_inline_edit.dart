import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import 'an_edit_affordance.dart';
import 'an_input.dart';
import 'dry_intrinsic_width.dart';

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
    this.enabled = true,
    this.startEditing = false,
    super.key,
  });

  final String value;
  final ValueChanged<String> onCommit;
  final bool enabled;

  /// Open directly in edit mode (e.g. a freshly created entity awaiting its first name). 直接进编辑态。
  final bool startEditing;

  @override
  State<AnInlineEdit> createState() => _AnInlineEditState();
}

class _AnInlineEditState extends State<AnInlineEdit> {
  late final TextEditingController _ctl = TextEditingController(text: widget.value);
  late String _committed = widget.value;
  late bool _editing = widget.startEditing;

  @override
  void initState() {
    super.initState();
    if (_editing) _selectAll(); // startEditing opens already selected — same as tapping the pencil 直接进编辑也全选
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
  void _selectAll() => _ctl.selection = TextSelection(baseOffset: 0, extentOffset: _ctl.text.length);

  void _begin() => setState(() {
        _ctl.text = _committed;
        _selectAll();
        _editing = true;
      });

  void _commit() {
    final next = _ctl.text;
    setState(() {
      _committed = next;
      _editing = false;
    });
    widget.onCommit(next);
  }

  void _abort() => setState(() {
        _ctl.text = _committed;
        _editing = false;
      });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SizedBox(
      height: AnSize.control, // fixed footprint — idle & editing share it, no jump 定高,静态/编辑共用、不跳
      child: Row(
        children: [
          // Flexible (not Expanded): content-sized until the affordance needs room — then the field
          // scrolls / the text ellipsizes (never overflow). Flexible:内容定宽,affordance 需位时框横滚/文字省略。
          Flexible(
            child: _editing
                ? _EditZone(controller: _ctl, onCommit: _commit, onAbort: _abort)
                : Text(
                    _committed,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    style: AnText.body.copyWith(color: c.ink),
                  ),
          ),
          const SizedBox(width: AnSpace.s8), // one gap, BOTH states — an unequal gap would twitch on toggle 同一间距、避免切换横抖
          AnEditAffordance(
            editing: _editing,
            onEdit: widget.enabled ? _begin : null,
            onCommit: _commit,
            onAbort: _abort,
          ),
        ],
      ),
    );
  }
}

/// The editing zone: a seamless field sized to its content (via [_DryIntrinsicWidth]) but never
/// narrower than [AnSize.inlineEditMin] (an empty field stays clickable) nor wider than the space
/// the affordance leaves (the enclosing [Flexible] caps it → field scrolls at the cap). A trailing
/// pad reserves room so the last glyph isn't clipped under the caret at end-of-line (flutter#24612).
/// No placeholder — a hint would pollute the intrinsic width on older SDKs (flutter#93337).
///
/// 编辑区:seamless 框按内容定宽(_DryIntrinsicWidth),不窄于 inlineEditMin(空框可点)、不宽于 affordance 让出
/// 的空间(外层 Flexible 封顶 → 到顶转横滚);尾部留位,光标在行尾不压住末字符(flutter#24612)。不给 placeholder
/// (hint 会污染固有宽,flutter#93337)。Enter 存、Esc 弃。
class _EditZone extends StatelessWidget {
  const _EditZone({required this.controller, required this.onCommit, required this.onAbort});

  final TextEditingController controller;
  final VoidCallback onCommit;
  final VoidCallback onAbort;

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): onAbort,
      },
      child: DryIntrinsicWidth(
        child: Padding(
          padding: const EdgeInsetsDirectional.only(end: AnSize.caretEndPad), // caret room at line end 行尾光标留位
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: AnSize.inlineEditMin),
            child: AnInput(
              controller: controller,
              seamless: true,
              autofocus: true,
              onSubmitted: (_) => onCommit(),
            ),
          ),
        ),
      ),
    );
  }
}

