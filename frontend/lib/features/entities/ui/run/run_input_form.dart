import 'dart:convert';

import 'package:flutter/widgets.dart';

import '../../../../core/contract/entities/values.dart';
import '../../../../core/design/colors.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/typography.dart';
import '../../../../core/ui/an_button.dart';
import '../../../../core/ui/an_callout.dart';
import '../../../../core/ui/an_dropdown.dart';
import '../../../../core/ui/an_input.dart';
import '../../../../core/ui/icons.dart';
import '../../../../i18n/strings.g.dart';
import '../../data/entity_kind.dart';

/// The run terminal's typed input form — renders the bound entity's declared inputs as type-appropriate
/// controls (string/number → text, boolean → dropdown, object/array → JSON textarea), a method picker for
/// handlers (fields follow the selected method), and an optional JSON payload for workflows (no declared
/// schema). On submit it coerces each field to its declared type (object/array via jsonDecode, surfacing a
/// parse error inline) and delegates the execute to [onRun]. Field [type] is the backend's COARSE open set
/// (schema.go:37) — anything unrecognized is treated as a string.
///
/// run 终端的类型化入参表单——按声明类型渲控件(string/number→文本,boolean→下拉,object/array→JSON 文本域),
/// handler 选方法(字段随方法切),workflow 可选 JSON payload。提交时按类型强转(object/array 经 jsonDecode、
/// 失败内联报错)、执行交给 onRun。Field.type 是后端粗粒度开放集,未识别按 string。
class RunInputForm extends StatefulWidget {
  const RunInputForm({
    required this.kind,
    required this.inputs,
    required this.methods,
    required this.busy,
    required this.terminal,
    required this.verbLabel,
    required this.onRun,
    required this.onCancel,
    super.key,
  });

  /// fn/ag declared inputs (empty for hd/wf). fn/ag 声明入参。
  final List<Field> inputs;

  /// hd methods (empty otherwise) — the picker + its inputs. hd 方法。
  final List<MethodSpec> methods;

  final EntityKind kind;
  final bool
  busy; // running → inputs disabled, button shows Cancel 运行中禁用、按钮转 Cancel
  final bool
  terminal; // a previous run finished → button reads "Run again" 上次跑完→"再跑一次"
  final String verbLabel; // Run / Call / Invoke / Trigger
  final void Function(Map<String, Object?> request, String method) onRun;
  final VoidCallback onCancel;

  @override
  State<RunInputForm> createState() => _RunInputFormState();
}

class _RunInputFormState extends State<RunInputForm> {
  String? _method;
  final Map<String, Object?> _vals = {};
  String? _error;

  static const _payloadKey = '__payload__';

  @override
  void initState() {
    super.initState();
    if (widget.kind == EntityKind.handler && widget.methods.isNotEmpty) {
      _method = widget.methods.first.name;
    }
  }

  List<Field> get _fields => switch (widget.kind) {
    EntityKind.handler =>
      widget.methods.where((m) => m.name == _method).isEmpty
          ? const []
          : widget.methods.firstWhere((m) => m.name == _method).inputs,
    EntityKind.function || EntityKind.agent => widget.inputs,
    EntityKind.workflow => const [],
  };

  void _submit() {
    final req = <String, Object?>{};
    if (widget.kind == EntityKind.workflow) {
      final raw = (_vals[_payloadKey] as String?)?.trim() ?? '';
      if (raw.isNotEmpty) {
        final Object? decoded;
        try {
          decoded = jsonDecode(raw);
        } catch (_) {
          setState(() => _error = context.t.entities.run.payloadInvalid);
          return;
        }
        if (decoded is! Map<String, dynamic>) {
          setState(() => _error = context.t.entities.run.payloadObject);
          return;
        }
        req.addAll(decoded);
      }
    } else {
      for (final f in _fields) {
        if (f.type == 'boolean') {
          final b = _vals[f.name];
          if (b is bool) req[f.name] = b;
          continue;
        }
        final raw = (_vals[f.name] as String?)?.trim() ?? '';
        if (raw.isEmpty) continue;
        switch (f.type) {
          case 'number':
            req[f.name] = num.tryParse(raw) ?? raw;
          case 'object' || 'array':
            try {
              req[f.name] = jsonDecode(raw);
            } catch (_) {
              setState(
                () =>
                    _error = context.t.entities.run.fieldInvalid(name: f.name),
              );
              return;
            }
          default:
            req[f.name] = raw;
        }
      }
    }
    setState(() => _error = null);
    widget.onRun(req, _method ?? '');
  }

  @override
  Widget build(BuildContext context) {
    final r = context.t.entities.run;
    final fields = _fields;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.kind == EntityKind.handler) ...[
          _label(context, r.method),
          const SizedBox(height: AnSpace.s4),
          AnDropdown<String>(
            block: true,
            value: _method,
            enabled: !widget.busy,
            options: [
              for (final m in widget.methods)
                AnDropdownOption(
                  value: m.name,
                  label: m.name,
                  meta: m.streaming ? r.streaming : null,
                ),
            ],
            onChanged: (v) => setState(() => _method = v),
          ),
          const SizedBox(height: AnSpace.s12),
        ],
        if (widget.kind == EntityKind.workflow)
          _payloadField(context)
        else if (fields.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AnSpace.s4),
            child: Text(
              r.noInputs,
              style: AnText.meta.copyWith(color: context.colors.inkFaint),
            ),
          )
        else
          for (final f in fields) ...[
            _field(context, f),
            const SizedBox(height: AnSpace.s12),
          ],
        if (_error != null) ...[
          AnCallout(_error!, severity: AnCalloutSeverity.danger),
          const SizedBox(height: AnSpace.s12),
        ],
        _runButton(context),
      ],
    );
  }

  Widget _field(BuildContext context, Field f) {
    final key = ValueKey('${_method ?? ''}/${f.name}');
    final Widget input;
    if (f.type == 'boolean') {
      final r = context.t.entities.run;
      input = AnDropdown<bool>(
        key: key,
        block: true,
        value: _vals[f.name] as bool?,
        enabled: !widget.busy,
        options: [
          AnDropdownOption(value: true, label: r.boolTrue),
          AnDropdownOption(value: false, label: r.boolFalse),
        ],
        onChanged: (v) => setState(() => _vals[f.name] = v),
      );
    } else {
      final multi = f.type == 'object' || f.type == 'array';
      input = AnInput(
        key: key,
        block: true,
        multiline: multi,
        mono: multi || f.type == 'number',
        enabled: !widget.busy,
        initialValue: _vals[f.name] as String?,
        onChanged: (v) => _vals[f.name] = v,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _label(context, f.name, type: f.type, desc: f.description),
        const SizedBox(height: AnSpace.s4),
        input,
      ],
    );
  }

  Widget _payloadField(BuildContext context) {
    final r = context.t.entities.run;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _label(context, r.payload),
        const SizedBox(height: AnSpace.s4),
        AnInput(
          block: true,
          multiline: true,
          mono: true,
          enabled: !widget.busy,
          initialValue: _vals[_payloadKey] as String?,
          onChanged: (v) => _vals[_payloadKey] = v,
        ),
        const SizedBox(height: AnSpace.s12),
      ],
    );
  }

  Widget _label(
    BuildContext context,
    String name, {
    String? type,
    String? desc,
  }) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Flexible(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AnText.strong.copyWith(color: c.ink),
              ),
            ),
            if (type != null) ...[
              const SizedBox(width: AnSpace.s6),
              Text(type, style: AnText.meta.copyWith(color: c.inkFaint)),
            ],
          ],
        ),
        if (desc != null && desc.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: AnSpace.s2),
            child: Text(desc, style: AnText.meta.copyWith(color: c.inkMuted)),
          ),
      ],
    );
  }

  Widget _runButton(BuildContext context) {
    final r = context.t.entities.run;
    if (widget.busy) {
      return AnButton(label: r.cancel, block: true, onPressed: widget.onCancel);
    }
    return AnButton(
      label: widget.terminal ? r.runAgain : widget.verbLabel,
      icon: AnIcons.run,
      variant: AnButtonVariant.primary,
      block: true,
      onPressed: _submit,
    );
  }
}
