import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/contract/entities/function.dart';
import '../../../../../core/contract/entities/values.dart';
import '../../../../../core/design/colors.dart';
import '../../../../../core/design/tokens.dart';
import '../../../../../core/design/typography.dart';
import '../../../../../core/model/status_state.dart';
import '../../../../../core/ui/an_action_group.dart';
import '../../../../../core/ui/an_button.dart';
import '../../../../../core/ui/an_callout.dart';
import '../../../../../core/ui/an_code_editor.dart';
import '../../../../../core/ui/an_code_surface.dart';
import '../../../../../core/ui/an_dropdown.dart';
import '../../../../../core/ui/an_fade_collapse.dart';
import '../../../../../core/ui/an_field.dart';
import '../../../../../core/ui/an_info_card.dart';
import '../../../../../core/ui/an_input.dart';
import '../../../../../core/ui/an_row.dart';
import '../../../../../core/ui/an_section.dart';
import '../../../../../core/ui/an_tags.dart';
import '../../../../../core/ui/an_transform_box.dart';
import '../../../../../core/ui/icons.dart';
import '../../../../../i18n/strings.g.dart';
import '../../../data/entity_kind.dart';
import '../../../data/entity_providers.dart';
import '../../../data/entity_format.dart';
import '../../../state/detail/entity_detail_provider.dart';
import '../../../state/detail/version_list_provider.dart';
import '../../../state/selected_entity.dart';
import '../detail_sections.dart';

/// Function 概览。读态:变换盒 hero(签名即接口)→ 代码(50 行渐隐收合)→ 环境合卡(envError 直出)。
/// 编辑走**显式草稿模式**(拍板):编辑 → 草稿态(签名字段/代码/依赖/py 可改)→ 保存(changeReason,
/// diff 成 ops 走 `:edit` 升新版本)/ 放弃。保存后详情+版本 family 失效、从真相重取。
class FunctionOverview extends ConsumerStatefulWidget {
  const FunctionOverview({required this.fn, super.key});

  final FunctionEntity fn;

  @override
  ConsumerState<FunctionOverview> createState() => _FunctionOverviewState();
}

class _FunctionOverviewState extends ConsumerState<FunctionOverview> {
  /// 50 code lines at the code style's line box, plus the editor chrome — the collapse threshold.
  /// 代码样式行盒 × 50 行 + 编辑器 chrome = 收合高度。
  static const double _collapsedCodeHeight = 50 * 12 * 1.6 + 44;

  static const List<String> _fieldTypes = ['string', 'number', 'boolean', 'object', 'array'];

  bool _editing = false;
  bool _saving = false;
  String? _error;

  // Draft state (populated on entering edit mode). 草稿态(进入编辑时填充)。
  late TextEditingController _code;
  late TextEditingController _python;
  late TextEditingController _reason;
  List<Field> _inputs = const [];
  List<Field> _outputs = const [];
  List<String> _deps = const [];

  @override
  void initState() {
    super.initState();
    _code = TextEditingController();
    _python = TextEditingController();
    _reason = TextEditingController();
  }

  @override
  void dispose() {
    _code.dispose();
    _python.dispose();
    _reason.dispose();
    super.dispose();
  }

  void _enterEdit(FunctionVersion v) {
    _code.text = v.code;
    _python.text = v.pythonVersion;
    _reason.clear();
    setState(() {
      _inputs = List.of(v.inputs);
      _outputs = List.of(v.outputs);
      _deps = List.of(v.dependencies);
      _error = null;
      _editing = true;
    });
  }

  void _discard() => setState(() {
        _editing = false;
        _error = null;
      });

  List<Map<String, dynamic>> _ops(FunctionVersion v) {
    bool fieldsChanged(List<Field> a, List<Field> b) =>
        a.length != b.length ||
        Iterable.generate(a.length).any((i) => a[i] != b[i]);
    return [
      if (_code.text != v.code) {'op': 'set_code', 'code': _code.text},
      if (fieldsChanged(_inputs, v.inputs))
        {'op': 'set_inputs', 'inputs': [for (final f in _inputs) f.toJson()]},
      if (fieldsChanged(_outputs, v.outputs))
        {'op': 'set_outputs', 'outputs': [for (final f in _outputs) f.toJson()]},
      if (!_sameList(_deps, v.dependencies))
        {'op': 'set_dependencies', 'dependencies': _deps},
      if (_python.text.trim() != v.pythonVersion && _python.text.trim().isNotEmpty)
        {'op': 'set_python_version', 'version': _python.text.trim()},
    ];
  }

  static bool _sameList(List<String> a, List<String> b) =>
      a.length == b.length && Iterable.generate(a.length).every((i) => a[i] == b[i]);

  Future<void> _save(FunctionVersion v) async {
    final ops = _ops(v);
    if (ops.isEmpty) {
      _discard(); // nothing changed — a no-op save is a discard 无改动=放弃
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final entityRef = EntityRef(EntityKind.function, widget.fn.id);
      await ref
          .read(entityRepositoryProvider)
          .editFunction(widget.fn.id, ops: ops, changeReason: _reason.text.trim());
      if (!mounted) return;
      setState(() {
        _editing = false;
        _saving = false;
      });
      // New active version server-side — reconcile detail + versions from truth. 从真相重取。
      ref.invalidate(entityDetailProvider(entityRef));
      ref.invalidate(versionListProvider(entityRef));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = context.t.entities.detail;
    final fn = widget.fn;
    final v = fn.activeVersion;
    if (v == null) return insetEmpty(d.state.noActiveVersion);
    return _editing ? _draft(context, d, v) : _view(context, d, fn, v);
  }

  // ── read mode ───────────────────────────────────────────────────────────────
  Widget _view(BuildContext context, dynamic d, FunctionEntity fn, FunctionVersion v) {
    final codeLines = '\n'.allMatches(v.code).length + 1;
    final meta = v.dependencies.isEmpty
        ? 'Python ${v.pythonVersion}'
        : 'Python ${v.pythonVersion} · ${d.hero.deps(n: v.dependencies.length)}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (fn.description.isNotEmpty || fn.tags.isNotEmpty)
          AnSection(variant: AnSectionVariant.plain, children: [
            if (fn.description.isNotEmpty) AnField(label: d.kv.desc, value: fn.description, wrap: true),
            if (fn.tags.isNotEmpty) kvList([(d.kv.tags, fn.tags.join(' · '))]),
          ]),
        AnSection(
          variant: AnSectionVariant.plain,
          actions: [
            AnButton(
              label: d.edit.edit,
              icon: AnIcons.edit,
              size: AnButtonSize.sm,
              onPressed: () => _enterEdit(v),
            ),
          ],
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AnSpace.s16),
              child: AnTransformBox(
                title: fn.name,
                icon: AnIcons.function,
                inputs: [for (final f in v.inputs) AnTransformField(f.name, f.type)],
                outputs: [for (final f in v.outputs) AnTransformField(f.name, f.type)],
                phase: v.envStatus == 'failed' ? AnTransformPhase.failed : AnTransformPhase.idle,
                status: AnStatus.fromRaw(v.envStatus),
                statusLabel: 'env ${v.envStatus}',
                meta: meta,
                emptyInputsLabel: d.hero.noInputs,
                emptyOutputsLabel: d.hero.noOutputs,
              ),
            ),
          ],
        ),
        AnSection(label: d.sec.code, variant: AnSectionVariant.plain, children: [
          AnFadeCollapse(
            collapsible: codeLines > 50,
            collapsedHeight: _collapsedCodeHeight,
            expandLabel: d.codeToggle.expand(n: codeLines),
            collapseLabel: d.codeToggle.collapse,
            child: AnCodeEditor(code: v.code, lang: 'py', wrap: true),
          ),
        ]),
        AnSection(label: d.sec.env, variant: AnSectionVariant.plain, children: [
          if (v.envError != null && v.envError!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: AnSpace.s8),
              child: AnCallout(v.envError!, severity: AnCalloutSeverity.danger),
            ),
          AnInfoCard(
            title: d.card.venv,
            icon: AnIcons.byKey('check'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                kvList([
                  (d.kv.python, v.pythonVersion),
                  (d.kv.envId, v.envId),
                  (d.kv.status, v.envStatus),
                  (d.kv.syncedAt, fmtTime(v.envSyncedAt)),
                ]),
                const SizedBox(height: AnSpace.s8),
                if (v.dependencies.isEmpty)
                  Text(d.val.none, style: AnText.meta)
                else
                  for (final dep in v.dependencies) AnRow(label: dep, passive: true),
              ],
            ),
          ),
        ]),
      ],
    );
  }

  // ── draft mode ──────────────────────────────────────────────────────────────
  Widget _draft(BuildContext context, dynamic d, FunctionVersion v) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Stacked (NOT grid): AnAutoGrid measures children at unbounded width, which fights the
        // editor rows' Expanded. 纵向堆叠而非 grid(AutoGrid 无界宽测量与编辑行 Expanded 冲突)。
        AnSection(label: d.sec.input, variant: AnSectionVariant.plain, children: [
          _fieldsEditor(d, _inputs, (next) => setState(() => _inputs = next), addLabel: d.edit.addInput),
          _fieldsEditor(d, _outputs, (next) => setState(() => _outputs = next), addLabel: d.edit.addOutput),
        ]),
        AnSection(label: d.sec.code, variant: AnSectionVariant.plain, children: [
          // inline+editable = always-editing (no per-block pencil bar — the draft owns save/discard);
          // AnCodeSurface restores the frame inline drops. inline 可编辑=常驻编辑(无块内铅笔栏,
          // 草稿统一管保存/放弃);框由 AnCodeSurface 补回。
          AnCodeSurface(
            focused: true,
            child: Padding(
              padding: const EdgeInsets.all(AnSpace.s8),
              child: AnCodeEditor(
                code: _code.text,
                lang: 'py',
                editable: true,
                inline: true,
                onInput: (s) => _code.text = s,
              ),
            ),
          ),
        ]),
        AnSection(label: d.sec.env, variant: AnSectionVariant.plain, children: [
          // Plain bounded rows (NOT AnField's child slot — it hands the control unbounded width,
          // which fights AnTags/AnInput's internal flex). 有界普通行,不用 AnField child 槽(无界宽与
          // AnTags/AnInput 内部 flex 冲突)。
          _labelled(d.card.deps, AnTags(
            tags: [for (final dep in _deps) AnTag(dep)],
            onChanged: (next) => setState(() => _deps = [for (final t in next) t.label]),
          )),
          _labelled(d.kv.python, AnInput(controller: _python, mono: true)),
        ]),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: AnSpace.s8),
            child: AnCallout('${d.edit.saveFailed}: $_error', severity: AnCalloutSeverity.danger),
          ),
        Padding(
          padding: const EdgeInsets.only(top: AnSpace.s16),
          child: Row(
            children: [
              Expanded(
                child: AnInput(controller: _reason, placeholder: d.edit.changeReason),
              ),
              const SizedBox(width: AnSpace.s12),
              AnActionGroup([
                AnButton(label: d.edit.discard, size: AnButtonSize.sm, onPressed: _saving ? null : _discard),
                AnButton(
                  label: d.edit.save,
                  variant: AnButtonVariant.primary,
                  size: AnButtonSize.sm,
                  onPressed: _saving ? null : () => _save(v),
                ),
              ]),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: AnSpace.s4),
          child: Text(d.edit.saveHint, style: AnText.meta.copyWith(color: c.inkFaint)),
        ),
      ],
    );
  }

  Widget _labelled(String label, Widget control) => Padding(
        padding: const EdgeInsets.symmetric(vertical: AnSpace.s4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          SizedBox(
            width: 120,
            child: Builder(
                builder: (context) =>
                    Text(label, style: AnText.label.copyWith(color: context.colors.ink))),
          ),
          const SizedBox(width: AnSpace.s12),
          Expanded(child: control),
        ]),
      );

  Widget _fieldsEditor(dynamic d, List<Field> fields, ValueChanged<List<Field>> onChanged,
      {required String addLabel}) {
    return AnInfoCard(
      title: addLabel == d.edit.addInput ? d.sec.input : d.sec.output,
      icon: AnIcons.byKey(addLabel == d.edit.addInput ? 'enter' : 'run'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < fields.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: AnSpace.s4),
              child: Row(children: [
                Expanded(
                  child: AnInput(
                    initialValue: fields[i].name,
                    placeholder: d.edit.fieldName,
                    mono: true,
                    onChanged: (s) {
                      final next = List.of(fields);
                      next[i] = fields[i].copyWith(name: s);
                      onChanged(next);
                    },
                  ),
                ),
                const SizedBox(width: AnSpace.s8),
                // Fixed width: a bare Row child gets unbounded width, and the dropdown's inner
                // two-zone flex can't take that. 定宽:Row 裸子件吃无界宽,下拉内部 flex 接不住。
                SizedBox(
                  width: 120,
                  child: AnDropdown(
                    options: [for (final t in _fieldTypes) AnDropdownOption(value: t, label: t)],
                    value: fields[i].type,
                    block: true,
                    onChanged: (t) {
                      final next = List.of(fields);
                      next[i] = fields[i].copyWith(type: t);
                      onChanged(next);
                    },
                  ),
                ),
                AnButton.iconOnly(
                  AnIcons.close,
                  semanticLabel: d.edit.removeField,
                  onPressed: () => onChanged([...fields]..removeAt(i)),
                ),
              ]),
            ),
          AnButton(
            label: addLabel,
            icon: AnIcons.plus,
            size: AnButtonSize.sm,
            onPressed: () => onChanged([...fields, const Field(name: '', type: 'string')]),
          ),
        ],
      ),
    );
  }
}
