import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../i18n/strings.g.dart';
import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../model/status_state.dart';
import 'an_input.dart';
import 'an_interactive.dart';
import 'an_status_dot.dart';
import 'dry_intrinsic_width.dart';
import 'icons.dart';
import 'tone.dart';

/// A tag with an optional [tone] and an optional [health] status dot. 标签:可选语气 + 健康点。
class AnTag {
  const AnTag(this.label, {this.tone, this.health});

  final String label;
  final AnTone? tone;
  final AnStatus? health;
}

/// C6 — an editable tag set: a [Wrap] of pills (optional health dot + label + remove-×) with an
/// inline seamless add field. HAND-ROLL (textfield_tags is stale + bakes Material chrome; InputChip
/// brings Material tap-targets/selection-blue and has no separately-focusable delete). Composes on
/// AnInteractive (the ×, kit-canonical hover/focus/press) + AnChip geometry + AnStatusDot + the
/// seamless AnInput grown by [DryIntrinsicWidth]. Stateful — owns + disposes the add field's
/// controller/focus node.
///
/// [readOnly] (or a null [onChanged]) drops the × and the add field → pure display pills (so AnTags is
/// the canonical tag DISPLAY too). [showAddField] lets a HOST control when the add field exists:
/// `null` (default) = the standalone canonical form, the field is always present while editable;
/// `false` = editable pills (× kept) but NO field; `true` = field present AND autofocused on
/// appearance — the host's ➕-button-then-input flow (the KV tags row). [onAddDismissed] fires when
/// the field is abandoned (Esc, or focus leaves it) so the host can flip back to `false`; non-empty
/// text commits on blur first (kit blur-commit convention), Esc discards. The draft controller is
/// cleared on EVERY dismissal/hide — a stale draft can never resurrect. Enter adds AND keeps focus
/// (chaining; the framework's Enter-unfocus default is suppressed). [single] enforces the one-value
/// invariant in STATE. Adding a DUPLICATE is rejected and briefly FLASHES the existing pill (keyed by
/// LABEL, so concurrent removals can't shift the flash onto the wrong pill). Backspace removes the
/// last tag only when the field is empty (scoped, so it never eats a normal backspace).
///
/// a11y: each remove-× is its OWN focusable Semantics(button, label "remove {tag}"); the health dot
/// is decorative (ExcludeSemantics); [FocusTraversalGroup] walks pills then the field in reading order.
/// The pills + field sit in a [TextFieldTapRegion] so tapping a × mid-add is NOT an outside-blur.
///
/// C6——可编辑标签集:Wrap 药丸(健康点+标签+移除×)+ 内联 seamless 添加框。readOnly/onChanged 空=纯展示。
/// showAddField 三态:null=standalone 常驻(默认);false=可编辑但无框;true=有框且现身即聚焦(宿主 ➕→输入框流,
/// 即 KV 标签行)。onAddDismissed=弃框回调(Esc / 焦点离开;非空文本先按套件失焦提交惯例提交,Esc 丢弃);
/// 每次弃/藏都清草稿,陈旧文本绝不复活。Enter 添加且保焦(连加;压掉框架 Enter 失焦默认)。重复=拒+按 label
/// 闪现已存在药丸(并发移除不会闪错)。空框 Backspace 删末标签。药丸+框套 TextFieldTapRegion,点 × 不算外点。
class AnTags extends StatefulWidget {
  const AnTags({
    required this.tags,
    this.onChanged,
    this.readOnly = false,
    this.single = false,
    this.placeholder,
    this.showAddField,
    this.onAddDismissed,
    this.end = false,
    this.reading = false,
    super.key,
  });

  final List<AnTag> tags;

  /// null (or [readOnly]) → display-only pills. 空/只读=纯展示。
  final ValueChanged<List<AnTag>>? onChanged;
  final bool readOnly;

  /// Single mode: adding replaces the one value (enforced in state). 单值模式。
  final bool single;
  final String? placeholder;

  /// Host control over the add field: null = always present while editable (standalone canonical);
  /// false = hidden; true = present + autofocused on appearance. 宿主控制添加框存在性(见类注释)。
  final bool? showAddField;

  /// The add field was abandoned (Esc, or focus left it) — a host that mounts the field on demand
  /// flips its state back off here. 弃框回调(宿主据此收起)。
  final VoidCallback? onAddDismissed;

  /// End-align the pill runs — for a flush-right value zone (the KV tags row). 行尾对齐(贴右值区用)。
  final bool end;

  /// Content-tier pills — tags standing as a VALUE inside a content KV row (document properties):
  /// label 13 / pill 24 / padX 10, beside 15 sibling values. Chrome pills (rail, headers, inspector)
  /// keep the default 12 / 22 / 9. 内容档药丸:作为内容 KV 值的标签(文档属性)——13 字/24 高/10 内距,
  /// 与 15 值同列;chrome 处守默认 12/22/9。
  final bool reading;

  @override
  State<AnTags> createState() => _AnTagsState();
}

class _AnTagsState extends State<AnTags> {
  final TextEditingController _ctl = TextEditingController();
  final FocusNode _focus = FocusNode(debugLabel: 'AnTags.add');
  String?
  _flash; // LABEL of a duplicate pill flashing (label-keyed: removals can't shift it) 闪现药丸的 label
  Timer?
  _flashTimer; // held so dispose cancels a pending flash-clear (no "Timer still pending") 持有以便 dispose 取消

  bool get _editable => widget.onChanged != null && !widget.readOnly;
  bool get _fieldShown => _editable && (widget.showAddField ?? true);

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocusChange);
    if (widget.showAddField == true) _requestFocusSoon();
  }

  @override
  void didUpdateWidget(AnTags old) {
    super.didUpdateWidget(old);
    // Host flipped the field ON → focus it (autofocus alone is unreliable when the scope already has
    // focus, e.g. keyboard-activated ➕). Flipped OFF → clear the draft (no stale resurrection).
    // 宿主开框→聚焦(键盘激活 ➕ 时 scope 已持焦,单靠 autofocus 不可靠);关框→清草稿。
    if (widget.showAddField == true && old.showAddField != true) {
      _requestFocusSoon();
    }
    if (widget.showAddField != true && old.showAddField == true) _ctl.clear();
  }

  void _requestFocusSoon() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _fieldShown) _focus.requestFocus();
    });
  }

  void _onFocusChange() {
    if (_focus.hasFocus || !mounted) return;
    // Focus LEFT the add field (tap-outside / Tab-away): commit a non-empty draft (kit blur-commit
    // convention; a duplicate is silently dropped — the field is closing, a flash would be unseen),
    // clear, then tell the host. 焦点离框:非空按失焦提交惯例提交(重复静默丢),清空,再通知宿主。
    final label = _ctl.text.trim();
    if (label.isNotEmpty && _indexOf(label) < 0) {
      widget.onChanged?.call(
        widget.single ? [AnTag(label)] : [...widget.tags, AnTag(label)],
      );
    }
    _ctl.clear();
    widget.onAddDismissed?.call();
  }

  @override
  void dispose() {
    _flashTimer?.cancel();
    _focus.removeListener(_onFocusChange);
    _ctl.dispose();
    _focus.dispose();
    super.dispose();
  }

  int _indexOf(String label) {
    for (var i = 0; i < widget.tags.length; i++) {
      if (widget.tags[i].label.toLowerCase() == label.toLowerCase()) return i;
    }
    return -1;
  }

  void _add() {
    final label = _ctl.text.trim();
    if (label.isEmpty) return;
    final dup = _indexOf(label);
    if (dup >= 0) {
      // decision ④: reject + briefly flash the existing pill (don't add, don't silently swallow). 拒+闪现。
      _ctl.clear();
      setState(() => _flash = widget.tags[dup].label);
      _flashTimer?.cancel();
      _flashTimer = Timer(AnMotion.breath, () {
        if (mounted) setState(() => _flash = null);
      });
      return;
    }
    final next = widget.single
        ? [AnTag(label)]
        : [...widget.tags, AnTag(label)];
    _ctl.clear();
    widget.onChanged!(next);
  }

  void _remove(int i) {
    widget.onChanged!([...widget.tags]..removeAt(i));
  }

  // Esc aborts the add (discard draft + dismiss); Backspace on an EMPTY field removes the last tag
  // (scoped so it never eats a normal backspace). Esc 弃草稿收框;空框退格删末标签(作用域化)。
  KeyEventResult _onKey(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    if (e.logicalKey == LogicalKeyboardKey.escape) {
      _ctl.clear();
      widget.onAddDismissed?.call();
      return KeyEventResult.handled;
    }
    if (e.logicalKey == LogicalKeyboardKey.backspace &&
        _ctl.text.isEmpty &&
        widget.tags.isNotEmpty) {
      _remove(widget.tags.length - 1);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    // TextFieldTapRegion: a × / pill tap mid-add is INSIDE the field's region — not an outside-blur
    // (mirrors AnEditableValue wrapping its Cancel/Save). 套 TapRegion,点 ×/药丸不算外点失焦。
    return TextFieldTapRegion(
      child: FocusTraversalGroup(
        child: Wrap(
          alignment: widget.end ? WrapAlignment.end : WrapAlignment.start,
          spacing: AnSpace.s6,
          runSpacing: AnSpace.s4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (var i = 0; i < widget.tags.length; i++)
              _pill(c, i, widget.tags[i]),
            if (_fieldShown) _addField(c),
          ],
        ),
      ),
    );
  }

  Widget _pill(AnColors c, int i, AnTag tag) {
    final tone = tag.tone ?? AnTone.none;
    final flashing = _flash == tag.label;
    final reduced = AnMotionPref.reduced(context);
    return AnimatedContainer(
      duration: reduced ? Duration.zero : AnMotion.fast,
      height: widget.reading ? AnSize.controlSm : AnSize.badge,
      padding: EdgeInsets.symmetric(
        horizontal: widget.reading ? AnSize.btnPadXSm : AnSize.badgePadX,
      ),
      decoration: BoxDecoration(
        color: flashing ? c.accentSoft : tone.softBg(c),
        borderRadius: BorderRadius.circular(AnRadius.pill),
        border: flashing
            ? Border.all(color: c.accent, width: AnSize.hairline)
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (tag.health != null) ...[
            ExcludeSemantics(child: AnStatusDot(tag.health!)),
            const SizedBox(width: AnSpace.s6),
          ],
          // Flexible + ellipsis: a single tag wider than the row truncates instead of overflowing.
          // Flexible+省略:单标签超宽则截断、不溢出。
          Flexible(
            child: Text(
              tag.label,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: (widget.reading ? AnText.label : AnText.meta).copyWith(
                color: tone == AnTone.none ? c.ink : tone.fg(c),
              ),
            ),
          ),
          if (_editable) ...[
            const SizedBox(width: AnSpace.s6),
            _removeX(c, i, tag),
          ],
        ],
      ),
    );
  }

  Widget _removeX(AnColors c, int i, AnTag tag) {
    return MergeSemantics(
      child: Semantics(
        label: context.t.feedback.removeTag(name: tag.label),
        child: AnInteractive(
          onTap: () => _remove(i),
          builder: (ctx, states) => SizedBox(
            width: AnSize.tagRemoveHit,
            height: AnSize.tagRemoveHit,
            child: Icon(
              AnIcons.close,
              size: AnSize.iconSm,
              color: states.isActive ? c.ink : c.inkFaint,
            ),
          ),
        ),
      ),
    );
  }

  Widget _addField(AnColors c) {
    // Grows with the typed content (DryIntrinsicWidth), floored at inlineEditMin so an empty field
    // stays clickable; pinned to the ACTIVE pill height (reading 24 / chrome badge 22) so the run
    // never jumps when the field joins; text matches the active pill label size (reading label 13 /
    // chrome meta 12 — baseline harmony). 随输入增长、空框不塌;钉当前档药丸高、字号同当前档药丸。
    return SizedBox(
      height: widget.reading ? AnSize.controlSm : AnSize.badge,
      child: Align(
        alignment: Alignment.centerLeft,
        // widthFactor 1: hug the field's width — a bare Align EXPANDS to the Wrap's full width and
        // forces the field onto its own run. widthFactor=1 贴字段宽;裸 Align 会撑满整行、把字段挤到独行。
        widthFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AnSize.tagFieldMaxWidth),
          child: DryIntrinsicWidth(
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: AnSize.inlineEditMin),
              child: Focus(
                onKeyEvent: _onKey,
                child: AnInput(
                  controller: _ctl,
                  focusNode: _focus,
                  seamless: true,
                  style: widget.reading ? AnText.label : AnText.meta,
                  placeholder: widget.placeholder,
                  onSubmitted: (_) => _add(),
                  // Suppress the framework's Enter-unfocus so Enter chains (add → keep typing). 压默认失焦,连加。
                  onEditingComplete: () {},
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
