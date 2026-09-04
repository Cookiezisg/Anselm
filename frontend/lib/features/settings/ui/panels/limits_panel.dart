import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/contract/api_error.dart';
import '../../../../core/contract/limits.dart';
import '../../../../core/design/colors.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/typography.dart';
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

  /// The raw load failure — the product copy is always localised; only the stable wire code is
  /// exposed through the tooltip. Backend messages may contain diagnostics or gateway text and
  /// must never become the face of the settings page. 原始载入错——脸永远用本地化产品文案;
  /// 后端 message 可能是诊断/网关文本,不得上脸;仅稳定 wire code 进 tooltip。
  Object? _loadError;

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
      if (mounted) setState(() => _loadError = e);
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
      final fresh = await ref
          .read(settingsRepositoryProvider)
          .patchLimits(body);
      if (mounted) setState(() => _limits = fresh);
    } on ApiException catch (e) {
      // Violation: inline toast + reload (roll the field back to server truth). 越界:回滚到服务端真相。
      ref
          .read(noticeCenterProvider.notifier)
          .show(e.message, tone: AnTone.danger);
      await _load();
    }
  }

  Future<void> _resetAll() async {
    final t = Translations.of(context);
    final ok = await ref
        .read(overlayProvider.notifier)
        .confirm(
          title: t.settings.limits.resetAllTitle,
          message: t.settings.limits.resetAllWarning,
          confirmLabel: t.settings.limits.resetAll,
          cancelLabel: t.settings.keys.cancel,
          barrierLabel: t.settings.limits.resetAllTitle,
        );
    if (!ok) return;
    try {
      final fresh = await ref.read(settingsRepositoryProvider).resetLimits();
      if (mounted) setState(() => _limits = fresh);
    } on ApiException {
      await _load();
      if (mounted) {
        ref
            .read(noticeCenterProvider.notifier)
            .show(t.settings.limits.resetFailed, tone: AnTone.danger);
      }
    } catch (_) {
      // A transport failure may happen after the server committed. Reload first so the visible
      // value never pretends the old local snapshot is authoritative.
      // 传输可能发生在服务端已提交之后,先重读,绝不把旧本地快照冒充权威值。
      await _load();
      if (mounted) {
        ref
            .read(noticeCenterProvider.notifier)
            .show(t.settings.limits.resetFailed, tone: AnTone.danger);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Translations.of(context);
    final c = context.colors;
    final schema = _schema;
    final loadError = _loadError;
    if (loadError != null) {
      // Whole-pane load failure = AnState (the inline label+danger voice is reserved for form
      // save errors). The face speaks human; the technical detail (wire code / raw error) rides a
      // tooltip. 整面载入失败归 AnState;脸说人话,技术细节(码/原始错)收 tooltip。
      final human = t.settings.limits.errorHint;
      final detail = loadError is ApiException ? loadError.code : '$loadError';
      return AnTooltip(
        message: detail,
        child: AnState(
          kind: AnStateKind.error,
          size: AnStateSize.inset,
          title: t.settings.limits.errorTitle,
          hint: human,
          action: AnButton(
            label: t.settings.limits.retry,
            size: AnButtonSize.sm,
            outline: true,
            onPressed: () {
              setState(() => _loadError = null);
              _load();
            },
          ),
        ),
      );
    }
    if (schema == null || _limits == null) {
      return const AnDeferredLoading(child: AnSkeleton.lines(6));
    }
    final groups = <String, List<LimitField>>{};
    for (final f in schema) {
      groups.putIfAbsent(f.group, () => []).add(f);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const AnScopeBadge(AnSettingScope.machine),
            const SizedBox(width: AnSpace.s8),
            Expanded(
              child: Text(
                t.settings.limits.scopeNote,
                style: AnText.label.copyWith(color: c.inkMuted),
              ),
            ),
            AnButton(
              label: t.settings.limits.resetAll,
              size: AnButtonSize.sm,
              outline: true,
              variant: AnButtonVariant.danger,
              onPressed: _resetAll,
            ),
          ],
        ),
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
                  onInvalid: () => ref
                      .read(noticeCenterProvider.notifier)
                      .show(
                        t.settings.limits.invalidValue(
                          range: _formatLimitRange(f),
                        ),
                        tone: AnTone.danger,
                      ),
                  onReset: () => _commit(f, f.defaultValue),
                ),
            ],
          ),
          const SizedBox(height: AnSpace.s16),
        ],
      ],
    );
  }
}

String _formatLimitNumber(double value) =>
    value == value.roundToDouble() ? '${value.round()}' : '$value';

/// Keep the server's bound semantics visible without pretending an unbounded max exists.
/// 用数学区间保留服务端的开闭边界,并明确 max=0 的上界缺席。
String _formatLimitRange(LimitField field) {
  final min = _formatLimitNumber(field.min);
  final hasMax = field.max > 0;
  if (field.exclusive && hasMax) {
    return '($min, ${_formatLimitNumber(field.max)})';
  }
  if (field.exclusive) return '> $min';
  if (hasMax) return '[$min, ${_formatLimitNumber(field.max)}]';
  return '≥ $min';
}

bool _isValidLimitValue(LimitField field, double value) {
  if (!value.isFinite) return false;
  final aboveMin = field.exclusive ? value > field.min : value >= field.min;
  final belowMax =
      field.max <= 0 ||
      (field.exclusive ? value < field.max : value <= field.max);
  return aboveMin && belowMax;
}

class _LimitRow extends StatefulWidget {
  const _LimitRow({
    required this.field,
    required this.value,
    required this.onCommit,
    required this.onInvalid,
    required this.onReset,
    super.key,
  });

  final LimitField field;
  final double value;
  final ValueChanged<double> onCommit;
  final VoidCallback onInvalid;
  final VoidCallback onReset;

  @override
  State<_LimitRow> createState() => _LimitRowState();
}

class _LimitRowState extends State<_LimitRow> {
  late final TextEditingController _text = TextEditingController(
    text: _fmt(widget.value),
  );

  static String _fmt(double v) => _formatLimitNumber(v);

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _commit() {
    final v = double.tryParse(_text.text.trim());
    if (v == null || !_isValidLimitValue(widget.field, v)) {
      _text.text = _fmt(widget.value);
      widget.onInvalid();
      return;
    }
    if (v == widget.value) {
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
      desc:
          '${f.desc} (${f.unit}) · ${t.settings.limits.rangeHint(range: _formatLimitRange(f), defaultValue: _fmt(f.defaultValue))}',
      modified: widget.value != f.defaultValue,
      onReset: widget.onReset,
      resetLabel: t.settings.resetToDefault,
      child: SizedBox(
        width: 140,
        child: AnInput(
          controller: _text,
          mono: true,
          // Leave editingComplete at Flutter's default: it unfocuses and invokes onSubmitted once.
          // 不自定义 editingComplete,避免与回车的 onSubmitted 重复提交同一 PATCH。
          onSubmitted: (_) => _commit(),
          // Commit on tap-away too — else typing a value then clicking elsewhere (no Enter) loses it.
          // 点走也提交,否则输入后不按 Enter 直接点别处会丢值。
          onTapOutside: (_) => _commit(),
        ),
      ),
    );
  }
}
