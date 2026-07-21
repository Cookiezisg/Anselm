import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/contract/entities/relation.dart';
import '../../../../core/design/colors.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/typography.dart';
import '../../../../core/ui/an_button.dart';
import '../../../../core/ui/an_cast_row.dart';
import '../../../../core/ui/an_code_editor.dart';
import '../../../../core/ui/an_dropdown.dart';
import '../../../../i18n/strings.g.dart';
import '../../data/entity_kind.dart';
import '../../data/entity_labels.dart';
import '../../state/detail/entity_detail.dart';
import '../../state/detail/entity_detail_provider.dart';
import '../../state/rel_graph_provider.dart';
import '../../state/run/recent_runs_provider.dart';
import '../../state/run/run_draft_store.dart';
import '../../state/run/run_fields.dart';
import '../../state/run/run_terminal_controller.dart';
import '../../state/run/run_terminal_state.dart';
import '../../state/selected_entity.dart';

/// Translate a run's wire ORIGIN word (triggeredBy / flowrun origin) into human text — «manual» reads
/// «手动», «cron» reads «调度», … (both the recent ledger and the payload-source menu speak human, never
/// the wire word — task ④). An unknown word shows raw (never guessed). 来源 wire 词→人话;未知词原样。
String runOriginLabel(Translations t, String origin) {
  final o = t.entities.run.origin;
  return switch (origin) {
    'manual' || 'user' => o.manual,
    'chat' => o.chat,
    'agent' => o.agent,
    'workflow' => o.workflow,
    'cron' => o.cron,
    'webhook' => o.webhook,
    'fsnotify' => o.fsnotify,
    'sensor' => o.sensor,
    _ => origin,
  };
}

/// The debugger's JSON-first input card (v3 业界共识形, 0719 拍板 — Lambda / Trigger.dart / Inngest): the
/// input IS one JSON editor prefilled with a runnable example, with a Lambda/Postman toolbar — «哪里填哪个»
/// disappears, the user changes a value and runs. Composed ENTIRELY from kit primitives (零手搓样式):
/// [AnCodeEditor] seamless (frame + gutter + highlight, same as the document editor's embedded code
/// block), [AnDropdown] ghost chips (payload source / handler method / workflow source) and an
/// [AnButton] verb. The editor lives on the SESSION [RunDraftStore] as JSON TEXT; a keystroke lints
/// live (bad JSON → a red line + the verb disabled); ⌘↵ submits from inside the editor (0719 用户裁定:
/// the toolbar's ⌘↵ keycap read as visual clutter next to Example▾/Method▾/verb — the CHORD itself
/// stays wired, only its keycap glyph is gone).
///
/// 调试台 JSON-first 输入卡:输入=一块预填可跑示例的 JSON 编辑器 + Lambda/Postman 工具条;全用原语拼(零手搓)。
/// 逐键实时 lint(坏 JSON→红行 + 动词禁用);⌘↵ 在编辑器内提交(0719 用户裁定:工具条上的 ⌘↵ 键帽与
/// Example▾/Method▾/动词钮太挤、视觉噪音,已删——快捷键本身照旧生效,只删键帽渲染)。
class RunEditorCard extends ConsumerStatefulWidget {
  const RunEditorCard({required this.entityRef, super.key});

  final EntityRef entityRef;

  @override
  ConsumerState<RunEditorCard> createState() => _RunEditorCardState();
}

class _RunEditorCardState extends ConsumerState<RunEditorCard> {
  /// The live lint verdict — a coerce error code (payloadInvalid / payloadObject) or null when valid.
  /// Local (not Riverpod) so a keystroke never churns the lifecycle state. 实时 lint 判词(本地态)。
  String? _jsonError;

  /// The payload-source chip's current fill — 'example' or a recent run's id. 填充来源:示例/某次运行 id。
  String _fillSource = 'example';

  /// Track the seed identity so a FILL / dimension switch clears the stale lint + resets the chip. The
  /// editor re-keys on the same identity → a fresh seed, so the two stay in lockstep. 种子身份追踪。
  String _seedId = '';

  @override
  void initState() {
    super.initState();
    // Default the handler method to the first one (drives which fields the example is built from). If
    // detail lands AFTER mount the listener in build() catches it. 默认选第一个方法(示例据此生成)。
    if (widget.entityRef.kind == EntityKind.handler) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final methods = runMethods(
          ref.read(entityDetailProvider(widget.entityRef)).value,
        );
        final c = ref.read(runTerminalProvider(widget.entityRef).notifier);
        if (methods.isNotEmpty &&
            ref.read(runTerminalProvider(widget.entityRef)).method.isEmpty) {
          c.setMethod(methods.first.name);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ref0 = widget.entityRef;
    final p = runTerminalProvider(ref0);
    final state = ref.watch(p);
    final c = ref.read(p.notifier);
    final store = ref.watch(runDraftStoreProvider);
    final detail = ref.watch(entityDetailProvider(ref0)).value;
    // Handler: the method may land after mount — set the default so the example is never built off an
    // empty method. handler 方法可能后到,补默认。
    if (ref0.kind == EntityKind.handler) {
      ref.listen(entityDetailProvider(ref0), (_, next) {
        final ms = runMethods(next.value);
        if (ms.isNotEmpty && ref.read(p).method.isEmpty) {
          c.setMethod(ms.first.name);
        }
      });
    }
    // Workflow: WATCH the picked trigger's detail so its KIND resolves (the seed template depends on it)
    // and this rebuilds when it loads. workflow:watch 触发源 detail 使 kind 解析、载入即重建。
    String sourceKind = 'manual';
    if (ref0.kind == EntityKind.workflow && state.source != 'manual') {
      final td = ref.watch(
        entityDetailProvider(EntityRef(EntityKind.trigger, state.source)),
      );
      sourceKind = td.value?.trigger?.kind.name ?? 'manual';
    }

    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        // The seed identity: bucket dimension + detail-loaded + sourceKind (both resolve async) + fill
        // revision. On a change the editor re-keys (fresh seed) and the lint/chip reset — so a seed that
        // was transient before the detail loaded is re-committed once it resolves. 种子身份:维度+detail
        // 载入+来源kind(皆异步解析)+填充版本;detail 未载前的瞬态种子在解析后重新落定。
        final seedId =
            '$ref0/${state.method}/${state.source}/${detail != null}/$sourceKind/${store.revision}';
        if (seedId != _seedId) {
          _seedId = seedId;
          _jsonError = null; // a fresh seed is always valid JSON 新种子恒合法
          _fillSource = 'example';
        }
        final text = c.draftText; // seeds the bucket if empty 空桶则种入
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _toolbar(context, c, state, detail),
            const SizedBox(height: AnSpace.s8),
            CallbackShortcuts(
              bindings: {
                const SingleActivator(
                  LogicalKeyboardKey.enter,
                  meta: true,
                ): () =>
                    _submit(c, state),
                const SingleActivator(
                  LogicalKeyboardKey.enter,
                  control: true,
                ): () =>
                    _submit(c, state),
              },
              child: AnCodeEditor(
                key: ValueKey(seedId),
                code: text,
                lang: 'json',
                editable: true,
                seamless: true,
                onInput: (v) {
                  c.setDraftText(v);
                  final err = _lint(v);
                  if (err != _jsonError) setState(() => _jsonError = err);
                },
              ),
            ),
            if (_jsonError != null) ...[
              const SizedBox(height: AnSpace.s6),
              Text(
                _lintText(context, _jsonError!),
                style: AnText.meta.copyWith(color: context.colors.danger),
              ),
            ],
          ],
        );
      },
    );
  }

  // ── toolbar (Lambda/Postman 位形): payload source · kind chip … verb ─────────────────────────
  Widget _toolbar(
    BuildContext context,
    RunTerminalController c,
    RunTerminalState state,
    EntityDetail? detail,
  ) {
    final chips = <Widget>[Flexible(child: _payloadSourceChip(context, c))];
    if (widget.entityRef.kind == EntityKind.handler) {
      chips
        ..add(const SizedBox(width: AnSpace.s6))
        ..add(Flexible(child: _methodChip(context, c, state, detail)));
    } else if (widget.entityRef.kind == EntityKind.workflow) {
      chips
        ..add(const SizedBox(width: AnSpace.s6))
        ..add(Flexible(child: _sourceChip(context, c, state)));
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Row(mainAxisSize: MainAxisSize.min, children: chips),
        ),
        const SizedBox(width: AnSpace.s8),
        _verbButton(context, c, state),
      ],
    );
  }

  /// Payload-source chip («示例 ▾» / a recent run): the default is the runnable example; picking a recent
  /// run fills its real input back (task ③ — Lambda 命名事件 / n8n pin 的轻量版). payload 来源 chip。
  Widget _payloadSourceChip(BuildContext context, RunTerminalController c) {
    final r = context.t.entities.run;
    final runs =
        ref.watch(recentRunsProvider(widget.entityRef)).value ??
        const <RecentRun>[];
    // A workflow row does NOT project its entry payload — offering it as a payload source would fill an
    // empty object, so only fn/hd/ag runs appear as reusable inputs. wf 行未投影 payload,不作可复用源。
    final reusable = widget.entityRef.kind == EntityKind.workflow
        ? const <RecentRun>[]
        : runs.where((run) => run.input.isNotEmpty).toList();
    return AnDropdown<String>(
      variant: AnDropdownVariant.ghost,
      value: _fillSource,
      options: [
        AnDropdownOption(value: 'example', label: r.example),
        for (final run in reusable)
          AnDropdownOption(
            value: run.id,
            label: AnCastRow.timeLabel(
              context,
              run.startedAt ?? DateTime.now(),
            ),
            meta: runOriginLabel(context.t, run.triggeredBy),
          ),
      ],
      onChanged: (v) {
        if (v == 'example') {
          c.loadExample();
        } else {
          final run = reusable.where((run) => run.id == v).firstOrNull;
          if (run != null) c.loadInput(run);
        }
        // The fill bumps the store revision → build() resets _fillSource from _seedId; no local set. 由 build 复位。
      },
    );
  }

  /// Handler METHOD chip — swaps which schema the example is built from + the draft bucket. hd 方法 chip。
  Widget _methodChip(
    BuildContext context,
    RunTerminalController c,
    RunTerminalState state,
    EntityDetail? detail,
  ) {
    final r = context.t.entities.run;
    final methods = runMethods(detail);
    return AnDropdown<String>(
      variant: AnDropdownVariant.ghost,
      value: state.method.isEmpty ? null : state.method,
      placeholder: r.method,
      options: [
        for (final m in methods)
          AnDropdownOption(
            value: m.name,
            label: m.name,
            meta: m.streaming ? r.streaming : null,
          ),
      ],
      onChanged: state.isRunning ? null : c.setMethod,
    );
  }

  /// Workflow SOURCE chip — the picked trigger decides the payload template (cron/webhook/…); its options
  /// are the mounted triggers (relation-域 equip edges) + manual. wf 来源 chip。
  Widget _sourceChip(
    BuildContext context,
    RunTerminalController c,
    RunTerminalState state,
  ) {
    final r = context.t.entities.run;
    final graph = ref.watch(relGraphProvider).value;
    final triggers = <({String id, String name})>[];
    if (graph != null) {
      final names = {for (final n in graph.nodes) '${n.kind}:${n.id}': n.name};
      for (final EntityRelation e in graph.edges) {
        if (e.kind == 'equip' &&
            e.fromKind == 'workflow' &&
            e.fromId == widget.entityRef.id &&
            e.toKind == 'trigger') {
          triggers.add((
            id: e.toId,
            name: names['trigger:${e.toId}'] ?? e.toName,
          ));
        }
      }
    }
    return AnDropdown<String>(
      variant: AnDropdownVariant.ghost,
      value: state.source,
      options: [
        AnDropdownOption(value: 'manual', label: r.sourceManual),
        for (final tr in triggers)
          AnDropdownOption(value: tr.id, label: tr.name),
      ],
      onChanged: state.isRunning ? null : c.setSource,
    );
  }

  /// The verb CTA — run / stop; disabled while the JSON is invalid (lint gate). 动词钮:运行/停止;lint 禁用。
  Widget _verbButton(
    BuildContext context,
    RunTerminalController c,
    RunTerminalState state,
  ) {
    final r = context.t.entities.run;
    if (state.isRunning) {
      return AnButton(
        label: r.cancel,
        size: AnButtonSize.sm,
        onPressed: c.cancel,
      );
    }
    return AnButton(
      label: widget.entityRef.kind.verbLabel(context.t),
      size: AnButtonSize.sm,
      variant: AnButtonVariant.primary,
      onPressed: _jsonError == null ? () => _submit(c, state) : null,
    );
  }

  void _submit(RunTerminalController c, RunTerminalState state) {
    if (state.isRunning || _jsonError != null) return;
    c.run();
  }

  // ── live lint: parse → must be a JSON object (empty = a no-arg run). 实时 lint:解析→须对象;空=无参跑。
  String? _lint(String text) {
    final raw = text.trim();
    if (raw.isEmpty) return null;
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      return 'payloadInvalid';
    }
    return decoded is Map<String, dynamic> ? null : 'payloadObject';
  }

  String _lintText(BuildContext context, String code) {
    final r = context.t.entities.run;
    return code == 'payloadObject' ? r.payloadObject : r.payloadInvalid;
  }
}
