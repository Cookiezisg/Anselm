import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/contract/api_error.dart';
import '../../../../core/contract/limits.dart';
import '../../../../core/design/colors.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/typography.dart';
import '../../../../core/ui/an_scope_badge.dart';
import '../../../../core/ui/an_setting_row.dart';
import '../../../../core/ui/ui.dart';
import '../../../../i18n/strings.g.dart';
import '../../data/settings_repository.dart';

/// ⑩ 高级限额 (WRK-062 §3, S5): SCHEMA-DRIVEN — the panel renders `GET /limits/schema` (group →
/// AnSection; per-field min/max/unit/desc) against the nested limits JSON, and PATCHes a partial
/// nested merge on commit (blur/submit). Machine-wide (one settings.json per machine); a violation
/// 400 shows inline and rolls the field back. Zero re-declared Go constants.
///
/// 高级限额:schema 驱动——按 schema 分组渲染,提交时部分嵌套合并 PATCH;全机一份;越界 400 行内+回滚;
/// 零复刻 Go 常量。
class LimitsPanel extends ConsumerStatefulWidget {
  const LimitsPanel({super.key});

  @override
  ConsumerState<LimitsPanel> createState() => _LimitsPanelState();
}

class _LimitsPanelState extends ConsumerState<LimitsPanel> {
  Map<String, dynamic>? _limits;
  List<LimitField>? _schema;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = ref.read(settingsRepositoryProvider);
    try {
      final schema = await repo.limitsSchema();
      final limits = await repo.getLimits();
      if (mounted) {
        setState(() {
          _schema = schema;
          _limits = limits;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  double? _valueAt(String dottedKey) {
    dynamic node = _limits;
    for (final seg in dottedKey.split('.')) {
      if (node is! Map<String, dynamic>) return null;
      node = node[seg];
    }
    return (node as num?)?.toDouble();
  }

  Future<void> _commit(LimitField f, double value) async {
    // Build the partial nested body from the dotted key. 点路径构部分嵌套体。
    final segs = f.key.split('.');
    final body = <String, dynamic>{};
    Map<String, dynamic> cur = body;
    for (var i = 0; i < segs.length - 1; i++) {
      cur = cur[segs[i]] = <String, dynamic>{};
    }
    cur[segs.last] = f.unit == 'ratio' ? value : value.round();
    try {
      final fresh = await ref.read(settingsRepositoryProvider).patchLimits(body);
      if (mounted) setState(() => _limits = fresh);
    } on ApiException catch (e) {
      // Violation: inline toast + reload (roll the field back to server truth). 越界:回滚到服务端真相。
      ref.read(overlayProvider.notifier).showToast(e.message, tone: AnToastTone.danger);
      await _load();
    }
  }

  Future<void> _resetAll() async {
    final t = Translations.of(context);
    final ok = await ref.read(overlayProvider.notifier).confirm(
          title: t.settings.limits.resetAllTitle,
          message: t.settings.limits.scopeNote,
          confirmLabel: t.settings.limits.resetAll,
          cancelLabel: t.settings.keys.cancel,
          barrierLabel: t.settings.limits.resetAllTitle,
        );
    if (!ok) return;
    final fresh = await ref.read(settingsRepositoryProvider).resetLimits();
    if (mounted) setState(() => _limits = fresh);
  }

  @override
  Widget build(BuildContext context) {
    final t = Translations.of(context);
    final c = context.colors;
    final schema = _schema;
    if (_error != null) {
      return Text(_error!, style: AnText.label.copyWith(color: c.danger));
    }
    if (schema == null || _limits == null) {
      return Text('…', style: AnText.label.copyWith(color: c.inkFaint));
    }
    final groups = <String, List<LimitField>>{};
    for (final f in schema) {
      groups.putIfAbsent(f.group, () => []).add(f);
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        const AnScopeBadge(AnSettingScope.machine),
        const SizedBox(width: AnSpace.s8),
        Expanded(
          child: Text(t.settings.limits.scopeNote,
              style: AnText.label.copyWith(color: c.inkMuted)),
        ),
        AnButton(
          label: t.settings.limits.resetAll,
          size: AnButtonSize.sm,
          variant: AnButtonVariant.danger,
          onPressed: _resetAll,
        ),
      ]),
      const SizedBox(height: AnSpace.s16),
      for (final entry in groups.entries) ...[
        AnSection(
          label: entry.key,
          variant: AnSectionVariant.quiet,
          children: [
            for (final f in entry.value)
              _LimitRow(
                key: ValueKey('${f.key}:${_valueAt(f.key)}'),
                field: f,
                value: _valueAt(f.key) ?? f.defaultValue,
                onCommit: (v) => _commit(f, v),
                onReset: () => _commit(f, f.defaultValue),
              ),
          ],
        ),
        const SizedBox(height: AnSpace.s16),
      ],
    ]);
  }
}

class _LimitRow extends StatefulWidget {
  const _LimitRow(
      {required this.field,
      required this.value,
      required this.onCommit,
      required this.onReset,
      super.key});

  final LimitField field;
  final double value;
  final ValueChanged<double> onCommit;
  final VoidCallback onReset;

  @override
  State<_LimitRow> createState() => _LimitRowState();
}

class _LimitRowState extends State<_LimitRow> {
  late final TextEditingController _text = TextEditingController(text: _fmt(widget.value));

  static String _fmt(double v) => v == v.roundToDouble() ? '${v.round()}' : '$v';

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _commit() {
    final v = double.tryParse(_text.text.trim());
    if (v == null || v == widget.value) {
      _text.text = _fmt(widget.value);
      return;
    }
    widget.onCommit(v);
  }

  @override
  Widget build(BuildContext context) {
    final t = Translations.of(context);
    final f = widget.field;
    return AnSettingRow(
      label: f.key,
      desc: '${f.desc} (${f.unit})',
      modified: widget.value != f.defaultValue,
      onReset: widget.onReset,
      resetLabel: t.settings.resetToDefault,
      child: SizedBox(
        width: 140,
        child: AnInput(
          controller: _text,
          mono: true,
          onSubmitted: (_) => _commit(),
          onEditingComplete: _commit,
        ),
      ),
    );
  }
}
