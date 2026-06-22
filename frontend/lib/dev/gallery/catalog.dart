import 'package:flutter/widgets.dart';

import '../../core/design/colors.dart';
import '../../core/design/tokens.dart';
import '../../core/design/typography.dart';
import '../../core/ui/ui.dart';
import 'specimen.dart';

// Gallery catalog — dev-only tool, so plain strings here are exempt from the i18n rule (like test
// code; never shipped). Grows one category per build group (G0–G6).
// 画廊目录——dev-only 工具,此处明文串豁免 i18n 规则(同测试代码,永不发布)。每组追加一类目。
final List<GalleryCategory> galleryCatalog = [
  _g1Controls,
];

// ── G1 — Foundational controls ──
final GalleryCategory _g1Controls = GalleryCategory('基础控件 Controls', AnIcons.sliders, [
  GalleryItem('AnStatusDot', '语义状态点;run 呼吸', [
    for (final s in AnStatus.values) GallerySpecimen(s.name, (_) => AnStatusDot(s)),
  ]),
  GalleryItem('AnBadge', '状态/标签药丸 + 可选点', [
    GallerySpecimen('neutral', (_) => const AnBadge('neutral')),
    GallerySpecimen('ok', (_) => const AnBadge('passed', tone: AnTone.ok)),
    GallerySpecimen('warn', (_) => const AnBadge('pending', tone: AnTone.warn)),
    GallerySpecimen('danger', (_) => const AnBadge('failed', tone: AnTone.danger)),
    GallerySpecimen('accent', (_) => const AnBadge('active', tone: AnTone.accent)),
    GallerySpecimen('dot=done', (_) => const AnBadge('completed', tone: AnTone.ok, dot: AnStatus.done)),
    GallerySpecimen('dot=run', (_) => const AnBadge('running', tone: AnTone.accent, dot: AnStatus.run)),
    GallerySpecimen('超长截断', (_) => const AnBadge('a-very-long-tag-that-must-truncate-not-blow-out', tone: AnTone.ok), stress: true, maxWidth: 150),
    GallerySpecimen('注入转义', (_) => const AnBadge('<b>not</b> & <i>html</i>', tone: AnTone.warn), stress: true),
  ]),
  GalleryItem('AnGroupLabel', '极薄分组小标题', [
    GallerySpecimen('default', (_) => const AnGroupLabel('Entities'), span: true),
    GallerySpecimen('超长截断', (_) => const AnGroupLabel('a very long section caption that should ellipsis instead of wrapping'), stress: true, maxWidth: 150),
  ]),
  GalleryItem('AnButton', '统一动作钮:变体/尺寸/图标/态', [
    GallerySpecimen('ghost', (_) => AnButton(label: 'Ghost', onPressed: () {})),
    GallerySpecimen('primary', (_) => AnButton(label: 'Run', icon: AnIcons.run, variant: AnButtonVariant.primary, onPressed: () {})),
    GallerySpecimen('danger', (_) => AnButton(label: 'Delete', variant: AnButtonVariant.danger, onPressed: () {})),
    GallerySpecimen('danger outline', (_) => AnButton(label: 'Delete', icon: AnIcons.trash, variant: AnButtonVariant.danger, outline: true, onPressed: () {})),
    GallerySpecimen('icon', (_) => AnButton.iconOnly(AnIcons.more, semanticLabel: 'More', onPressed: () {})),
    GallerySpecimen('size=sm', (_) => AnButton(label: 'Small', size: AnButtonSize.sm, onPressed: () {})),
    GallerySpecimen('disabled', (_) => const AnButton(label: 'Disabled', onPressed: null)),
    GallerySpecimen('block', (_) => AnButton(label: 'Block', icon: AnIcons.enter, block: true, onPressed: () {}), span: true),
    GallerySpecimen('超长截断', (_) => AnButton(label: 'a-really-long-button-label-that-must-ellipsis-within-its-box', block: true, onPressed: () {}), stress: true, maxWidth: 170),
  ]),
  GalleryItem('AnInput', '值叶子:单行/多行/等宽', [
    GallerySpecimen('default', (_) => const AnInput(placeholder: 'Type…')),
    GallerySpecimen('mono', (_) => const AnInput(initialValue: 'fn_3a9f', mono: true)),
    GallerySpecimen('readonly', (_) => const AnInput(initialValue: 'read only', readOnly: true)),
    GallerySpecimen('disabled', (_) => const AnInput(initialValue: 'disabled', enabled: false)),
    GallerySpecimen('multiline full', (_) => const AnInput(placeholder: 'Multiple lines…', multiline: true, full: true), span: true),
    GallerySpecimen('超长值', (_) => const AnInput(initialValue: 'this-is-an-extremely-long-single-line-value-that-should-scroll-horizontally-and-never-overflow-the-bordered-box', full: true), stress: true, maxWidth: 180),
  ]),
  GalleryItem('AnActionGroup', '动作组:对齐/间距/换行', [
    GallerySpecimen('default', (_) => AnActionGroup([AnButton(label: 'Cancel', onPressed: () {}), AnButton(label: 'Save', variant: AnButtonVariant.primary, onPressed: () {})]), span: true),
    GallerySpecimen('end compact', (_) => AnActionGroup([AnButton(label: 'A', size: AnButtonSize.sm, onPressed: () {}), AnButton(label: 'B', size: AnButtonSize.sm, onPressed: () {})], end: true, compact: true), span: true),
    GallerySpecimen('stack', (_) => AnActionGroup([AnButton(label: 'First', block: true, onPressed: () {}), AnButton(label: 'Second', block: true, onPressed: () {})], stack: true), span: true),
  ]),
  GalleryItem('AnEditAffordance', '就地编辑:文字 ↔ 输入框 + 光标(定高不跳)', [
    GallerySpecimen('idle (点铅笔进编辑)', (_) => const _EditDemo(initial: 'Untitled workflow')),
    GallerySpecimen('editing 态', (_) => const _EditDemo(initial: 'Editing title', startEditing: true)),
    GallerySpecimen('超长·idle', (_) => const _EditDemo(initial: 'A very long entity title that must ellipsis when idle'), stress: true, maxWidth: 180),
    GallerySpecimen('超长·editing', (_) => const _EditDemo(initial: 'A very long title being edited that must shrink, scroll, and never overflow the row', startEditing: true), stress: true, maxWidth: 220),
  ]),
  GalleryItem('AnDropdown', '受控单选下拉 + 富行菜单', [
    GallerySpecimen('label + meta', (_) => const _DropdownDemo(initial: 'fn')),
    GallerySpecimen('single value(无 meta)', (_) => const _DropdownDemo(initial: 'med', simple: true)),
    GallerySpecimen('placeholder', (_) => const _DropdownDemo(initial: null, simple: true)),
    GallerySpecimen('ghost', (_) => const _DropdownDemo(initial: 'ag', ghost: true)),
    GallerySpecimen('disabled', (_) => const AnDropdown<String>(options: [], value: null, onChanged: null, placeholder: 'disabled', enabled: false)),
    GallerySpecimen('block', (_) => const _DropdownDemo(initial: 'wf', block: true), span: true),
    GallerySpecimen('两区都超长', (_) => AnDropdown<String>(
          options: const [AnDropdownOption(value: 'x', label: 'An extremely long entity name that must ellipsis on the left', meta: 'a_very_long_identifier_that_also_truncates')],
          value: 'x',
          onChanged: (_) {},
        ), stress: true, maxWidth: 200),
    GallerySpecimen('海量选项', (_) => const _DropdownDemo(initial: '0', massive: true), stress: true),
  ]),
]);

// ── small stateful demo wrappers (specimens need live state) 小型有态演示包 ──

// final (not const): AnIcons.* are runtime IconData (thin-weight family). 非 const:图标是运行期 IconData。
final List<AnDropdownOption<String>> _entityOptions = [
  AnDropdownOption(value: 'fn', label: 'Function', meta: 'fn_3a9f', icon: AnIcons.function),
  AnDropdownOption(value: 'hd', label: 'Handler', meta: 'hd_71c2', icon: AnIcons.handler),
  AnDropdownOption(value: 'ag', label: 'Agent', meta: 'ag_0e88', icon: AnIcons.agent),
  AnDropdownOption(value: 'wf', label: 'Workflow', meta: 'wf_4d10', icon: AnIcons.workflow),
];

// Single-value options (label only, no meta) — the common case for a plain select. 单值(仅标签、无 meta)。
final List<AnDropdownOption<String>> _simpleOptions = const [
  AnDropdownOption(value: 'low', label: 'Low'),
  AnDropdownOption(value: 'med', label: 'Medium'),
  AnDropdownOption(value: 'high', label: 'High'),
];

class _DropdownDemo extends StatefulWidget {
  const _DropdownDemo({
    this.initial,
    this.ghost = false,
    this.block = false,
    this.massive = false,
    this.simple = false,
  });

  final String? initial;
  final bool ghost;
  final bool block;
  final bool massive;

  /// Single-value options (no meta). 单值选项(无 meta)。
  final bool simple;

  @override
  State<_DropdownDemo> createState() => _DropdownDemoState();
}

class _DropdownDemoState extends State<_DropdownDemo> {
  late String? _value = widget.initial;

  @override
  Widget build(BuildContext context) {
    final options = widget.massive
        ? [for (var i = 0; i < 80; i++) AnDropdownOption(value: '$i', label: 'Option number $i', meta: 'opt_$i')]
        : (widget.simple ? _simpleOptions : _entityOptions);
    return AnDropdown<String>(
      options: options,
      value: _value,
      variant: widget.ghost ? AnDropdownVariant.ghost : AnDropdownVariant.normal,
      menuAlignEnd: widget.ghost,
      block: widget.block,
      onChanged: (v) => setState(() => _value = v),
    );
  }
}

// The real in-place edit interaction (the demo's "logic box vs display box" lesson): a FIXED-HEIGHT
// row so toggling display↔edit never jumps. Editing uses a SEAMLESS AnInput (text-height, no box) +
// Flexible so it slots in where the text was and never overflows; idle text ellipsis-truncates.
// 就地编辑真交互(demo「逻辑框/展示框」教训):定高行,切换不跳。编辑用 seamless AnInput(文字高、无框)+
// Flexible 原位替换、不溢出;静态文字超长省略。
class _EditDemo extends StatefulWidget {
  const _EditDemo({required this.initial, this.startEditing = false});

  final String initial;
  final bool startEditing;

  @override
  State<_EditDemo> createState() => _EditDemoState();
}

class _EditDemoState extends State<_EditDemo> {
  late final TextEditingController _ctl = TextEditingController(text: widget.initial);
  late String _committed = widget.initial;
  late bool _editing = widget.startEditing;

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SizedBox(
      height: AnSize.control, // fixed footprint — display & edit share it, no jump 定高,展示/编辑共用、不跳
      child: Row(
        children: [
          Flexible(
            child: _editing
                ? AnInput(controller: _ctl, seamless: true, autofocus: true)
                : Text(_committed,
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: AnText.body.copyWith(color: c.ink)),
          ),
          const SizedBox(width: AnSpace.s8),
          AnEditAffordance(
            editing: _editing,
            onEdit: () => setState(() => _editing = true),
            onCommit: () => setState(() {
              _committed = _ctl.text;
              _editing = false;
            }),
            onAbort: () => setState(() {
              _ctl.text = _committed;
              _editing = false;
            }),
          ),
        ],
      ),
    );
  }
}
