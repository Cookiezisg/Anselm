import 'package:flutter/material.dart';

import '../../../core/design/colors.dart';
import '../../../core/design/tokens.dart';
import '../../../core/design/typography.dart';
import '../../../core/model/partial_json.dart';
import '../../../core/ui/ui.dart';
import '../../../i18n/strings.g.dart';
import '../model/tool_card_state.dart';
import '../model/tool_receipts.dart';
import 'tool_card_skins.dart';

// F04 control + approval build cards (WRK-056 §control / §approval). Both are WHOLE-SET replaces (the
// ops language is not used here) — edit passes the COMPLETE branches / form, and OMITTED fields go to
// zero — so the card always renders the full NEW snapshot, never a "未变" delta. Pure-render from args
// (no fetch); the before-diff canvas is the enhancement (fetch seam #50).
// control/approval 都是整体替换(edit 传完整集、省略即归零)——卡永远渲全新快照、绝不渲「未变」。纯 args 渲。

// ── control: the decision ladder (BranchRuleList) ──

/// One control branch: a named [port] taken when the [when] CEL is true (first-true-wins, top→bottom),
/// emitting [emit] (each output field ← a CEL over `input.*`). 一条决策分支。
typedef ControlBranch = ({String port, String when, Map<String, String> emit});

/// Parse the branches from a control build's args (whole-set) — tolerant of a partial stream. 解析分支。
List<ControlBranch> controlBranches(PartialJsonSession args) {
  final out = <ControlBranch>[];
  for (final raw in args.arrayItemsAt(['branches'])) {
    if (raw is! Map) continue;
    final emit = <String, String>{};
    final e = raw['emit'];
    if (e is Map) {
      e.forEach((k, v) => emit[k.toString()] = v.toString());
    }
    out.add((port: (raw['port'] ?? '').toString(), when: (raw['when'] ?? '').toString(), emit: emit));
  }
  return out;
}

/// The DECISION LADDER: ordered rows ①②③ (the number IS the first-true-wins priority), each a port
/// badge + its `when` CEL (mono) + emit chips (`key ← CEL`); the catch-all (`when:"true"`) pins to the
/// bottom as a grey `否则 → port` rung. 决策梯:有序行(序号即 first-true-wins);catch-all 钉底。
Widget controlBranchBody(BuildContext context, ToolCardState state) {
  final t = Translations.of(context);
  final c = context.colors;
  final branches = controlBranches(state.argsSession);
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      toolIntent(context, state),
      for (var i = 0; i < branches.length; i++) _branchRow(context, t, c, i + 1, branches[i]),
      runStatBarOf(context, state),
    ],
  );
}

/// Render the decision ladder from an ALREADY-parsed branch list (get_control's active-version
/// `branches` JSON — a list of `{port, when, emit?}` maps). Shared by F04 build + F06 get. 从已解析分支渲染梯。
Widget controlBranchList(BuildContext context, List<dynamic> branches) {
  final t = Translations.of(context);
  final c = context.colors;
  final parsed = <ControlBranch>[];
  for (final raw in branches) {
    if (raw is! Map) continue;
    final emit = <String, String>{};
    final e = raw['emit'];
    if (e is Map) e.forEach((k, v) => emit[k.toString()] = v.toString());
    parsed.add((port: (raw['port'] ?? '').toString(), when: (raw['when'] ?? '').toString(), emit: emit));
  }
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [for (var i = 0; i < parsed.length; i++) _branchRow(context, t, c, i + 1, parsed[i])],
  );
}

Widget _branchRow(BuildContext context, Translations t, AnColors c, int n, ControlBranch b) {
  final isCatchAll = b.when.trim() == 'true';
  return Padding(
    padding: const EdgeInsets.only(bottom: AnSpace.s6),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text('$n', style: AnText.metaTabular().copyWith(color: c.inkFaint)),
            const SizedBox(width: AnGap.inline),
            AnChip(b.port, tone: AnTone.accent),
            const SizedBox(width: AnGap.inline),
            Expanded(
              child: isCatchAll
                  ? Text('${t.chat.tool.ctlOtherwise} · ${t.chat.tool.ctlWhenTrue}',
                      style: AnText.label.copyWith(color: c.inkFaint))
                  : Text(b.when, style: AnText.mono.copyWith(color: c.inkMuted)),
            ),
          ],
        ),
        if (b.emit.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: AnIndent.dot, top: AnSpace.s2),
            child: Wrap(
              spacing: AnGap.inline,
              runSpacing: AnGap.stackTight,
              children: [
                for (final e in b.emit.entries)
                  Text('${e.key} ← ${e.value}',
                      style: AnText.mono.copyWith(color: c.inkFaint)),
              ],
            ),
          ),
      ],
    ),
  );
}

// ── approval: the form preview (ApprovalFormPreview) ──

/// The {{ input.x }} moustache → an inline-code chip, so the approval template's placeholders read as
/// distinct variable slots when rendered. `{{ payload.x }}` would be rejected server-side, so only
/// `input.*` appears. moustache 占位 → 内联码 chip(变量槽可辨)。
String approvalTemplateToMarkdown(String template) =>
    template.replaceAllMapped(RegExp(r'\{\{\s*input\.([\w.]+)\s*\}\}'), (m) => '`${m[1]}`');

/// The APPROVAL FORM PREVIEW — what the approver will see: the rendered template (placeholders as chips)
/// + the rules strip (timeout badge → its behaviour, note-allowed) + a mock decision row. Reconstructed
/// from the args (whole snapshot). 审批表单预览:审批人视角(渲染模板 + 规则条 + mock 决策行)。
Widget approvalFormBody(BuildContext context, ToolCardState state) {
  final t = Translations.of(context);
  final c = context.colors;
  final template = argString(state.argsText, 'template') ?? '';
  final allowReason = _boolArg(state.argsText, 'allowReason');
  final timeout = argString(state.argsText, 'timeout');
  final behavior = argString(state.argsText, 'timeoutBehavior');

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(t.chat.tool.apfPreviewHint, style: AnText.label.copyWith(color: c.inkFaint)),
      const SizedBox(height: AnSpace.s4),
      // The family card (A-001 — the hand-rolled white-island shell retires; content-flow card =
      // chip radius via AnCard, B-043). SizedBox keeps the full-width span. 族卡:手搓白岛退役,
      // 流内卡走 AnCard(chip 圆角);SizedBox 保满宽。
      SizedBox(
        width: double.infinity,
        child: AnCard(
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (template.isNotEmpty) AnMarkdown(approvalTemplateToMarkdown(template)),
            const SizedBox(height: AnGap.block),
            // The rules strip: timeout → behaviour, note-allowed. 规则条:超时→行为、可填备注。
            Wrap(
              spacing: AnGap.inline,
              runSpacing: AnSpace.s4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (timeout != null && timeout.isNotEmpty) ...[
                  AnChip(timeout, tone: AnTone.none),
                  Text('${t.chat.tool.apfOnTimeout} ${behavior ?? ''}',
                      style: AnText.meta.copyWith(color: _behaviorColor(c, behavior))),
                ] else
                  Text(t.chat.tool.apfTimeoutNever, style: AnText.meta.copyWith(color: c.inkFaint)),
                if (allowReason)
                  AnChip(t.chat.tool.apfAllowReason, tone: AnTone.none),
              ],
            ),
            const SizedBox(height: AnGap.block),
            // Mock decision row (disabled preview — the approver's future buttons). mock 决策行。
            Row(
              children: [
                AnButton(label: t.chat.tool.apfApprove, variant: AnButtonVariant.primary, onPressed: null),
                const SizedBox(width: AnGap.inline),
                AnButton(label: t.chat.tool.apfReject, variant: AnButtonVariant.danger, onPressed: null),
              ],
            ),
          ],
          ),
        ),
      ),
      runStatBarOf(context, state),
    ],
  );
}

Color _behaviorColor(AnColors c, String? behavior) => switch (behavior) {
      'approve' => c.ok,
      'reject' => c.danger,
      'fail' => c.warn,
      _ => c.inkFaint,
    };

/// Parse a boolean arg from a (possibly partial) args fragment. 从 args 解析 bool。
bool _boolArg(String argsFragment, String key) =>
    RegExp('"$key"\\s*:\\s*true').hasMatch(argsFragment);
