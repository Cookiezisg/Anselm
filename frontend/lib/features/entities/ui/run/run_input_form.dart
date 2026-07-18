import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/contract/entities/values.dart';
import '../../../../core/design/colors.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/typography.dart';
import '../../../../core/ui/an_button.dart';
import '../../../../core/ui/an_callout.dart';
import '../../../../core/ui/an_dropdown.dart';
import '../../../../core/ui/an_form_field.dart';
import '../../../../core/ui/an_input.dart';
import '../../../../core/ui/an_switch.dart';
import '../../../../core/ui/icons.dart';
import '../../../../i18n/strings.g.dart';
import '../../data/entity_kind.dart';
import '../../state/detail/entity_detail_provider.dart';
import '../../state/rel_graph_provider.dart';
import '../../state/run/run_draft_store.dart';
import '../../state/run/run_fields.dart';
import '../../state/run/run_terminal_controller.dart';
import '../../state/run/run_terminal_state.dart';
import '../../state/selected_entity.dart';

/// The debugger's input form — the entity contract's MIRROR (调试台三律之一, 0718 拍板): the entity's
/// declared shape IS the form. Type-aware fields (string→text, number→numeric text, boolean→switch,
/// object/array→mono JSON area, description as the placeholder); a handler's METHOD dropdown steers
/// which fields render; a workflow's SOURCE picker lists its mounted triggers (+manual) and renders
/// that trigger kind's payload template — cron honestly renders NO payload at all. Values live in the
/// session [RunDraftStore] (per method/source bucket), and re-seed on a reproduce (store revision).
///
/// 调试台入参表单=实体契约的镜子:类型感知字段(描述做占位);handler 方法下拉换字段;workflow 来源
/// 选择器(挂载 triggers+手动)按 trigger kind 渲 payload 模板——cron 如实无 payload。值住 session
/// 草稿库(按方法/来源分桶),重现时经库版本号重播。
class RunInputForm extends ConsumerStatefulWidget {
  const RunInputForm({
    required this.entityRef,
    required this.verbLabel,
    super.key,
  });

  final EntityRef entityRef;
  final String verbLabel; // Run / Call / Invoke / Trigger

  @override
  ConsumerState<RunInputForm> createState() => _RunInputFormState();
}

class _RunInputFormState extends ConsumerState<RunInputForm> {
  static const _payloadKey = '__payload__';

  @override
  void initState() {
    super.initState();
    // Default the handler method to the first one (drives which fields render). 默认选第一个方法。
    if (widget.entityRef.kind == EntityKind.handler) {
      final methods = runMethods(ref.read(entityDetailProvider(widget.entityRef)).value);
      if (methods.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final c = ref.read(runTerminalProvider(widget.entityRef).notifier);
          if (ref.read(runTerminalProvider(widget.entityRef)).method.isEmpty) {
            c.setMethod(methods.first.name);
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = context.t.entities.run;
    final p = runTerminalProvider(widget.entityRef);
    final state = ref.watch(p);
    final c = ref.read(p.notifier);
    final store = ref.watch(runDraftStoreProvider);
    // initState defaults the method only if detail is already loaded — if it lands AFTER mount, catch it
    // here so the dropdown never sticks on placeholder (Run with an empty method → backend error).
    // initState 只在 detail 已载时设默认;detail 后到则在此补,否则下拉停 placeholder、空 method 点 Run 报错。
    if (widget.entityRef.kind == EntityKind.handler) {
      ref.listen(entityDetailProvider(widget.entityRef), (_, next) {
        final ms = runMethods(next.value);
        if (ms.isNotEmpty && ref.read(p).method.isEmpty) c.setMethod(ms.first.name);
      });
    }
    // Render fields + method list read from the SAME canonical source the controller coerces from — no
    // props threading, so render and coerce can't drift. 渲染字段/方法与 controller 强转同源,不经 props、不会漂移。
    final detail = ref.watch(entityDetailProvider(widget.entityRef)).value;
    final methods = runMethods(detail);
    final fields = runInputFields(widget.entityRef.kind, detail, method: state.method);
    // A reproduce bumps the store revision → this rebuilds and the value-keys below re-seed the
    // uncontrolled inputs. 重现自增版本→重建、下方 key 换代、非受控输入重播。
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.entityRef.kind == EntityKind.handler) ...[
            AnFormField(
              label: r.method,
              child: AnDropdown<String>(
                block: true,
                value: state.method.isEmpty ? null : state.method,
                enabled: !state.isRunning,
                options: [
                  for (final m in methods)
                    AnDropdownOption(value: m.name, label: m.name, meta: m.streaming ? r.streaming : null),
                ],
                onChanged: c.setMethod,
              ),
            ),
            const SizedBox(height: AnSpace.s12),
          ],
          if (widget.entityRef.kind == EntityKind.workflow)
            ..._workflowInputs(context, c, state, store)
          else if (fields.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AnSpace.s4),
              child: Text(r.noInputs, style: AnText.meta.copyWith(color: context.colors.inkFaint)),
            )
          else
            for (final f in fields) ...[
              _field(context, c, f, state, store),
              const SizedBox(height: AnSpace.s12),
            ],
          if (state.inputError != null) ...[
            AnCallout(_inputErrorText(context, state.inputError!), severity: AnCalloutSeverity.danger),
            const SizedBox(height: AnSpace.s12),
          ],
          _runButton(context, c, state),
        ],
      ),
    );
  }

  Key _seedKey(RunTerminalState state, RunDraftStore store, String name) =>
      ValueKey('${widget.entityRef}/${state.method}/${state.source}/$name/${store.revision}');

  Widget _field(BuildContext context, RunTerminalController c, Field f, RunTerminalState state,
      RunDraftStore store) {
    final key = _seedKey(state, store, f.name);
    final Widget input;
    if (f.type == 'boolean') {
      // A native boolean control — not a true/false dropdown (契约镜子:布尔穿开关的衣服). 布尔=开关。
      input = Align(
        alignment: AlignmentDirectional.centerStart,
        child: AnSwitch(
          key: key,
          value: c.draft[f.name] as bool? ?? false,
          semanticLabel: f.name,
          onChanged: state.isRunning ? null : (v) {
            c.setField(f.name, v);
            setState(() {}); // switch is CONTROLLED — reflect the flip 开关受控,翻转即重画
          },
        ),
      );
    } else {
      final multi = f.type == 'object' || f.type == 'array';
      input = AnInput(
        key: key,
        block: true,
        multiline: multi,
        mono: multi || f.type == 'number',
        enabled: !state.isRunning,
        // The declared description IS the placeholder (0718 拍板: 描述进框,不再单独一行). 描述做占位。
        placeholder: (f.description ?? '').isEmpty ? null : f.description,
        initialValue: c.draft[f.name] as String?,
        onChanged: (v) => c.setField(f.name, v),
      );
    }
    return AnFormField(
      label: f.name,
      labelTrailing: Text(f.type, style: AnText.meta.copyWith(color: context.colors.inkFaint)),
      child: input,
    );
  }

  // ── workflow: source picker + per-kind payload template 来源选择器+分 kind 模板 ──

  List<Widget> _workflowInputs(
      BuildContext context, RunTerminalController c, RunTerminalState state, RunDraftStore store) {
    final r = context.t.entities.run;
    // Mounted triggers = the graph's equip edges out of this workflow into trigger nodes (relation
    // 域现成,零新端点). 挂载 triggers=relgraph 里本 wf 指向 trigger 的 equip 边。
    final graph = ref.watch(relGraphProvider).value;
    final triggers = <({String id, String name})>[];
    if (graph != null) {
      final names = {for (final n in graph.nodes) '${n.kind}:${n.id}': n.name};
      for (final e in graph.edges) {
        if (e.kind == 'equip' &&
            e.fromKind == 'workflow' &&
            e.fromId == widget.entityRef.id &&
            e.toKind == 'trigger') {
          triggers.add((id: e.toId, name: names['trigger:${e.toId}'] ?? e.toName));
        }
      }
    }
    // The picked trigger's KIND decides the template (watch keeps it warm; render/coerce stay
    // same-judged via wfSourceKind on the controller side). 选中 trigger 的 kind 定模板(watch 保温)。
    final sourceKind = state.source == 'manual'
        ? 'manual'
        : ref
                .watch(entityDetailProvider(EntityRef(EntityKind.trigger, state.source)))
                .value
                ?.trigger
                ?.kind
                .name ??
            'manual';
    return [
      AnFormField(
        label: r.source,
        child: AnDropdown<String>(
          block: true,
          value: state.source,
          enabled: !state.isRunning,
          options: [
            AnDropdownOption(value: 'manual', label: r.sourceManual),
            for (final t in triggers) AnDropdownOption(value: t.id, label: t.name),
          ],
          onChanged: c.setSource,
        ),
      ),
      const SizedBox(height: AnSpace.s12),
      ...switch (sourceKind) {
        // cron releases no payload — the form honestly renders NOTHING here (绝不硬造空 JSON 框骗人).
        // cron 无 payload:如实什么都不渲。
        'cron' => const <Widget>[],
        'fsnotify' => [
            _templateField(context, c, state, store, name: 'path', hint: r.fsnotifyPathHint),
            const SizedBox(height: AnSpace.s12),
            _templateField(context, c, state, store, name: 'event', hint: r.fsnotifyEventHint),
            const SizedBox(height: AnSpace.s12),
          ],
        'sensor' => [
            _templateField(context, c, state, store, name: 'value', hint: r.sensorValueHint, mono: true),
            const SizedBox(height: AnSpace.s12),
          ],
        // webhook / manual: one JSON payload body (webhook 的 payload=请求体本身). 单 JSON 体。
        _ => [
            AnFormField(
              label: r.payload,
              labelTrailing: sourceKind == 'webhook'
                  ? Text(r.webhookBody, style: AnText.meta.copyWith(color: context.colors.inkFaint))
                  : null,
              child: AnInput(
                key: _seedKey(state, store, _payloadKey),
                block: true,
                multiline: true,
                mono: true,
                enabled: !state.isRunning,
                placeholder: sourceKind == 'webhook' ? r.webhookBodyHint : r.payloadHint,
                initialValue: c.draft[_payloadKey] as String?,
                onChanged: (v) => c.setField(_payloadKey, v),
              ),
            ),
            const SizedBox(height: AnSpace.s12),
          ],
      },
    ];
  }

  Widget _templateField(BuildContext context, RunTerminalController c, RunTerminalState state,
      RunDraftStore store,
      {required String name, required String hint, bool mono = false}) {
    return AnFormField(
      label: name,
      child: AnInput(
        key: _seedKey(state, store, name),
        block: true,
        mono: mono,
        enabled: !state.isRunning,
        placeholder: hint,
        initialValue: c.draft[name] as String?,
        onChanged: (v) => c.setField(name, v),
      ),
    );
  }

  Widget _runButton(BuildContext context, RunTerminalController c, RunTerminalState state) {
    final r = context.t.entities.run;
    if (state.isRunning) {
      return AnButton(label: r.cancel, block: true, onPressed: c.cancel);
    }
    return AnButton(
      label: state.isTerminal ? r.runAgain : widget.verbLabel,
      icon: AnIcons.run,
      variant: AnButtonVariant.primary,
      block: true,
      onPressed: c.run,
    );
  }

  // Map the controller's coercion error code → localized text. 把强转错误码映射成本地化文案。
  String _inputErrorText(BuildContext context, String code) {
    final r = context.t.entities.run;
    if (code == 'payloadInvalid') return r.payloadInvalid;
    if (code == 'payloadObject') return r.payloadObject;
    if (code.startsWith('field:')) return r.fieldInvalid(name: code.substring(6));
    return code;
  }
}
