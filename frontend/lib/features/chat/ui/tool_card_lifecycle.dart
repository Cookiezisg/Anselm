import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/colors.dart';
import '../../../core/design/tokens.dart';
import '../../../core/design/typography.dart';
import '../../../core/router/panel_registry.dart';
import '../../../core/ui/an_chip.dart';
import '../../../core/ui/an_kv.dart';
import '../../../core/ui/an_window.dart';
import '../../../core/ui/an_ref_pill.dart';
import '../../../i18n/strings.g.dart';
import '../model/tool_card_state.dart';
import '../model/tool_receipts.dart';
import 'tool_card_entity_get.dart' show kEntityContentCap;

// F05 lifecycle bodies (B3.6) — the family soul is THE THIN CARD: one statement + an undeniable
// receipt. The bodies are minimal: a live ref pill to the entity panel + a grey contract note, or —
// for delete — the impact audit (ToolDependentsBlock). F05 极薄卡:一行陈述 + 不可抵赖凭据。

const int _depCap =
    24; // pill Wrap cap (impact ledger; the count line still reports the full N). 药丸封顶。

/// A live ref pill to the entity's panel (registry-gated — inert if no panel), then a grey note. Most
/// lifecycle cards are exactly this: «here's the thing you touched, and what it means». 活 pill + 灰注记。
Widget lifecycleRefNote(
  BuildContext context, {
  required String kind,
  required String id,
  String? note,
  Color? noteColor,
}) {
  final c = context.colors;
  final navigable = hasPanelFor(kind);
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      AnRefPill(
        kind: kind,
        label: id,
        id: navigable ? id : null,
        onTap: navigable
            ? (target) {
                final loc = panelLocationFor(target.kind, target.id);
                if (loc != null && context.mounted) context.go(loc);
              }
            : null,
      ),
      if (note != null && note.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: AnSpace.s6),
          child: Text(
            note,
            style: AnText.meta.copyWith(color: noteColor ?? c.inkFaint),
          ),
        ),
    ],
  );
}

/// THE DELETE AUDIT BLOCK (WRK-056 #15) — «delete is an audit; damage seen on the spot». A danger
/// count line («N 处引用受影响») + a Wrap of tappable [AnRefPill]s (jump-to-fix), capped at [_depCap]
/// with a `+N` overflow, + the backend `note`. A tombstone kind with no panel stays inert (a dead
/// entity gets no live jump). 删除审计块:N 处引用 + 可点药丸跳修 + note。
class ToolDependentsBlock extends StatelessWidget {
  const ToolDependentsBlock({required this.deps, this.note, super.key});

  final Dependents deps;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final t = Translations.of(context);
    final c = context.colors;
    final shown = deps.refs.take(_depCap).toList();
    final overflow = deps.refs.length - shown.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // The count is the FULL N (never truncated) — honest impact. 计数报全量,诚实损伤。
        Text(
          t.chat.tool.depsAffected(n: '${deps.count}'),
          style: AnText.label.copyWith(color: c.danger),
        ),
        const SizedBox(height: AnSpace.s6),
        Wrap(
          spacing: AnGap.inline,
          runSpacing: AnGap.stackTight,
          children: [
            for (final r in shown) _depPill(context, r),
            if (overflow > 0)
              Text(
                t.chat.tool.moreHits(n: '$overflow'),
                style: AnText.meta.copyWith(color: c.inkFaint),
              ),
          ],
        ),
        if (note != null && note!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: AnSpace.s6),
            child: Text(note!, style: AnText.meta.copyWith(color: c.inkFaint)),
          ),
      ],
    );
  }

  Widget _depPill(BuildContext context, ({String kind, String id}) r) {
    final navigable = hasPanelFor(r.kind);
    return AnRefPill(
      kind: r.kind,
      label: r.id,
      id: navigable ? r.id : null,
      onTap: navigable
          ? (target) {
              final loc = panelLocationFor(target.kind, target.id);
              if (loc != null && context.mounted) context.go(loc);
            }
          : null,
    );
  }
}

/// A delete body: the impact audit if there are dependents, else nothing (the receipt IS the card).
/// [agentForm] reads the string-tail dependents (delete_agent). 删除体:有依赖→审计块,否则回执即卡。
Widget Function(BuildContext, ToolCardState) deleteBody({
  bool agentForm = false,
}) => (context, state) {
  final deps = agentForm
      ? parseAgentDependents(state.resultText)
      : parseDependents(state.resultText);
  if (deps == null || deps.count == 0) return const SizedBox.shrink();
  final note = _obj(state.resultText)?['note'] as String?;
  return ToolDependentsBlock(deps: deps, note: note);
};

Map<String, dynamic>? _obj(String s) {
  try {
    final d = jsonDecode(s);
    if (d is Map<String, dynamic>) return d;
  } catch (_) {}
  return null;
}

/// update_meta delta body — SINGLE-ENDED (the old value isn't on the wire, so `→ b`, never a fake
/// `a → b`): an AnKv of the changed fields (from args) + a ref pill + an optional note. update_meta
/// 单端 delta:改了什么只列什么(→ b,不假双端)+ ref pill。
Widget metaDeltaBody(
  BuildContext context, {
  required String kindWire,
  required String id,
  required String argsText,
  required String idKey,
  String? note,
}) {
  final t = Translations.of(context);
  final rows = <AnKvRow>[];
  final name = argString(argsText, 'name');
  if (name != null) {
    rows.add(AnKvRow(t.chat.tool.kvName, '→ $name', mono: true));
  }
  final desc = argString(argsText, 'description');
  if (desc != null) {
    rows.add(
      AnKvRow(
        t.chat.tool.kvDescription,
        '→ ${truncate(desc, AnTrunc.line)}',
        wrap: true,
      ),
    );
  }
  final tags = argStringList(argsText, 'tags');
  if (RegExp('"tags"\\s*:').hasMatch(argsText)) {
    rows.add(AnKvRow.tags(t.chat.tool.kvTags, tags));
  }
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      if (rows.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: AnSpace.s6),
          child: AnKv(rows: rows, dense: true),
        ),
      lifecycleRefNote(context, kind: kindWire, id: id, note: note),
    ],
  );
}

/// activate_skill body — the injected output is an INSTRUCTION PAYLOAD (machine-window identity, not
/// prose), capped at [kEntityContentCap] chars with an honest truncation note (fork answers land in no
/// panel). A grey line surfaces the pre-authorization side-effect. activate_skill:注入载荷→capped 机器窗
/// + 预授权注记。
Widget activateSkillBody(BuildContext context, ToolCardState state) {
  final t = Translations.of(context);
  final c = context.colors;
  final out = state.resultText;
  if (out.isEmpty) return const SizedBox.shrink();
  final over = out.length > kEntityContentCap;
  final shown = over ? out.substring(0, kEntityContentCap) : out;
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        t.chat.tool.skillPreauthNote,
        style: AnText.meta.copyWith(color: c.warn),
      ),
      const SizedBox(height: AnSpace.s6),
      // The truncation note rides the window's footer slot (codex 族一 规则④,批4 复审). 注记进 footer 槽。
      AnWindow(
        footer: over ? Text(t.chat.tool.contentTruncated) : null,
        child: Text(
          shown,
          style: AnText.code.copyWith(color: c.inkMuted),
          maxLines: 200,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ],
  );
}
