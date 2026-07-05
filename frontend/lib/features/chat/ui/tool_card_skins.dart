import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/contract/interaction.dart';
import '../../../core/model/time_format.dart';
import '../../../core/design/colors.dart';
import '../../../core/design/tokens.dart';
import '../../../core/design/typography.dart';
import '../../../core/ui/ui.dart';
import '../../../i18n/strings.g.dart';
import '../model/tool_card_state.dart';
import '../model/tool_receipts.dart';
import 'tool_interaction_gate.dart';

/// Family bodies for the tool card — the MACHINE-WINDOW identity (user decree, 2026-07-03):
/// a tool call is an OPERATION against the outside world, not the model's inner voice, so its
/// machine output NEVER borrows thinking's whisper grammar (no left rail, no bare prose).
/// Everything a machine produced lives inside an explicit contained window — a sunken rounded
/// panel in mono — while the row above stays a bare verb line. Terminal output, diffs, hit
/// lists: same container, different content.
///
/// 工具卡族体——**机器窗口**身份(用户定调,2026-07-03):tool call 是对外部世界的**操作**、不是
/// 模型的内心低语,机器输出**绝不**借用 thinking 的低语语法(无左 rail、无裸散文)。一切机器产物
/// 都住在明确的容器窗里——凹陷圆角等宽面板;上方的行保持裸动词行。终端输出/diff/命中列表:
/// 同一容器、不同内容。
///
/// [ToolWindow] is that container. 机器窗容器。
class ToolWindow extends StatelessWidget {
  const ToolWindow({required this.child, this.header, super.key});

  final Widget child;

  /// Optional window header (e.g. the command line echoed terminal-style). 可选窗头(命令回显)。
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    // The machine window IS the shared sunken panel (its header slot carries the command echo).
    // 机器窗即共享凹陷面板(header 槽承载命令回显)。
    return SizedBox(
      width: double.infinity,
      child: AnSunkenPanel(header: header, child: child),
    );
  }
}

/// The live tail: the last [tailLines] progress lines inside a small machine window while the
/// tool runs — the strongest "it's really working" cue (industry: Claude Code / Cursor). The
/// window grows/shrinks with its content (AnimatedSize via AnExpandReveal host) and dissolves
/// into the expanded body's full window on completion.
///
/// 活尾巴:执行中把 progress 尾 [tailLines] 行装进小机器窗——最强「真的在干活」信号(业界:
/// Claude Code/Cursor)。窗随内容长缩,完成后溶进展开体的完整窗。
class ToolLiveTail extends StatelessWidget {
  const ToolLiveTail({required this.text, this.tailLines = 3, super.key});

  final String text;
  final int tailLines;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final lines = text.trimRight().split('\n');
    final tail = lines.length > tailLines ? lines.sublist(lines.length - tailLines) : lines;
    return ToolWindow(
      child: Text(tail.join('\n'),
          style: AnText.code.copyWith(color: c.inkMuted)),
    );
  }
}

/// Shared intent line (the LLM's self-reported summary) — shown above the window in the
/// dangerous-leaning families (F3/F13/F14: the user judges the self-report).
/// 共用意图行(LLM 自报 summary)——危险倾向族(F3/F13/F14)置于窗上,供用户判断自述。
Widget _intent(BuildContext context, ToolCardState state) {
  final c = context.colors;
  if (state.summary.isEmpty) return const SizedBox.shrink();
  return Padding(
    padding: const EdgeInsets.only(bottom: AnSpace.s6),
    child: Text(state.summary, style: AnText.meta.copyWith(color: c.inkMuted)),
  );
}

/// Cap + honest truncation note for window content. 窗内容封顶+诚实截断注记。
const int _windowCapChars = 6000;

Widget _cappedMono(BuildContext context, String raw, {Color? color}) {
  final t = Translations.of(context);
  final c = context.colors;
  final truncated = raw.length > _windowCapChars;
  final shown = truncated ? raw.substring(0, _windowCapChars) : raw;
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(shown.trimRight(), style: AnText.code.copyWith(color: color ?? c.inkMuted)),
      if (truncated)
        Padding(
          padding: const EdgeInsets.only(top: AnSpace.s4),
          child: Text(t.chat.tool.truncatedNote(chars: raw.length),
              style: AnText.meta.copyWith(color: c.inkFaint)),
        ),
    ],
  );
}

/// F3 Bash — the terminal window: `$ command` echo header + combined output (progress while
/// it ran, else the result), exit footer left intact (the honest raw record).
/// F3 Bash——终端窗:`$ 命令` 回显头 + 合并输出(有 progress 用之,否则 result),exit footer 原样保留。
Widget bashToolBody(BuildContext context, ToolCardState state) {
  final c = context.colors;
  final cmd = argString(state.argsText, 'command') ?? '';
  final output = state.progressText.isNotEmpty ? state.progressText : state.resultText;
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _intent(context, state),
      ToolWindow(
        header: cmd.isEmpty
            ? null
            : Text('\$ $cmd', style: AnText.code.copyWith(color: c.ink)),
        child: _cappedMono(context, output),
      ),
    ],
  );
}

/// F1 Write — the written content in a code window (language from the extension).
/// F1 Write——写入内容装代码窗(语言按扩展名)。
Widget writeToolBody(BuildContext context, ToolCardState state) {
  final path = argString(state.argsText, 'file_path') ?? '';
  final content = argString(state.argsText, 'content') ?? '';
  if (content.isEmpty) return const SizedBox.shrink();
  return AnCodeEditor(code: content, lang: _langOf(path));
}

/// F1 Edit — old→new as a unified diff (AnVersionDiff: the machine window with green/red
/// gutters, an existing primitive).
/// F1 Edit——old→new 渲 unified diff(AnVersionDiff:带绿红软底的机器窗,现成原语)。
Widget editToolBody(BuildContext context, ToolCardState state) {
  final oldS = argString(state.argsText, 'old_string');
  final newS = argString(state.argsText, 'new_string');
  if (oldS == null && newS == null) return const SizedBox.shrink();
  return AnVersionDiff(
    before: oldS ?? '',
    after: newS ?? '',
    lang: _langOf(argString(state.argsText, 'file_path') ?? ''),
  );
}

/// F2 Glob/Grep/LS — the hit-list window: raw result lines in mono (the backend's formats are
/// already line-oriented; refined per-mode styling can come with real-wire verification).
/// F2 检索族——命中窗:结果行等宽原样(后端格式本就按行;分模式精修等真线缆核验后再上)。
Widget listToolBody(BuildContext context, ToolCardState state) {
  if (state.resultText.trim().isEmpty) return const SizedBox.shrink();
  return ToolWindow(child: _cappedMono(context, state.resultText));
}

/// F16 ask_user — the frozen Q/A record, reconstructed from the SETTLED block (the interaction signal
/// is ephemeral; the DB block is truth): the question from args.message, the answer / skip / empty from
/// the result prose. Reuses the gate's RESOLVED mode (chosen-option章 / free-text quotation / skipped).
/// ask_user 落定 Q/A:问题取 args.message、结果按散文分 已答/跳过/空;复用 gate resolved 模式(选中章/引用/跳过)。
Widget askUserBody(BuildContext context, ToolCardState state) {
  final message = argString(state.argsText, 'message') ?? '';
  final options = argStringList(state.argsText, 'options');
  final declined = state.resultText.startsWith(declinedProsePrefix);
  final empty = state.resultText.trim() == askEmptyAnswerProse;
  return ToolInteractionGate(
    kind: GateKind.ask,
    prompt: message,
    options: options,
    decided: declined ? InteractionAction.decline : InteractionAction.accept,
    decidedAnswer: empty ? '' : state.resultText.trim(),
    autofocus: false,
  );
}

/// F16 decide_approval — the verdict record: NOT_PARKED reframed as a calm note (a product-normal), else
/// the judgment章 (批准/否决 + reason) + a consequence bar (flowrun.status + node status counts, from
/// nodeSummary.byStatus when the run is capped, else counted off nodes[] — never dumps the raw JSON).
/// decide_approval 裁决记录:NOT_PARKED 友好呈现;否则 判词章(批准/否决+reason)+ 后果条(flowrun.status +
/// 节点状态计数,超 80 用 nodeSummary.byStatus 否则自数 nodes[],绝不倾倒 JSON)。
Widget decideApprovalBody(BuildContext context, ToolCardState state) {
  final t = Translations.of(context);
  final c = context.colors;

  // NOT_PARKED — first-decision-wins / timed out / wrong node id: a calm amber note, never red. 友好呈现。
  if (state.resultText.contains(notParkedProse)) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(AnIcons.info, size: AnSize.icon, color: c.warn),
      const SizedBox(width: AnSpace.s6),
      Expanded(child: Text(t.chat.tool.notParked, style: AnText.reading.copyWith(color: c.inkMuted))),
    ]);
  }

  final decision = argString(state.argsText, 'decision');
  final reason = argString(state.argsText, 'reason');
  final isYes = decision == 'yes';

  Map<String, dynamic>? out;
  try {
    final d = jsonDecode(state.resultText);
    if (d is Map<String, dynamic>) out = d;
  } catch (_) {}
  final fr = out?['flowrun'] as Map<String, dynamic>?;
  final flowStatus = fr?['status'] as String?;
  final summary = out?['nodeSummary'] as Map<String, dynamic>?;
  final counts = <String, int>{};
  int? shown, total;
  if (summary != null) {
    final by = summary['byStatus'];
    if (by is Map) {
      by.forEach((k, v) => counts[k.toString()] = (v as num).toInt());
    }
    shown = (summary['shownNodes'] as num?)?.toInt();
    total = (summary['totalNodes'] as num?)?.toInt();
  } else {
    final nodes = out?['nodes'];
    if (nodes is List) {
      for (final n in nodes) {
        final s = (n is Map ? n['status']?.toString() : null) ?? '?';
        counts[s] = (counts[s] ?? 0) + 1;
      }
    }
  }

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // Judgment章 (green approve / red reject) + the reason (the司法 record, full text). 判词章+理由。
      AnBadge(isYes ? t.chat.tool.approveVerdict : t.chat.tool.rejectVerdict,
          tone: isYes ? AnTone.ok : AnTone.danger),
      if (reason != null && reason.isNotEmpty) ...[
        const SizedBox(height: AnGap.stack),
        Text(reason, style: AnText.reading.copyWith(color: c.ink)),
      ],
      // Consequence bar: the flowrun's status + per-status node counts. 后果条:flowrun 状态 + 节点计数。
      if (flowStatus != null || counts.isNotEmpty) ...[
        const SizedBox(height: AnGap.block),
        Wrap(
          spacing: AnSpace.s6,
          runSpacing: AnSpace.s4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (flowStatus != null) AnBadge(flowStatus, tone: AnStatus.fromRaw(flowStatus).tone),
            for (final e in counts.entries)
              Text('${e.key} ${e.value}', style: AnText.metaTabular().copyWith(color: c.inkFaint)),
          ],
        ),
        if (shown != null && total != null && shown < total)
          Padding(
            padding: const EdgeInsets.only(top: AnSpace.s4),
            child: Text(t.chat.tool.nodesShown(shown: '$shown', total: '$total'),
                style: AnText.meta.copyWith(color: c.inkFaint)),
          ),
      ],
    ],
  );
}

/// F16 list_approval_inbox — the parked-approvals snapshot as a thin table (ref · summary · waited ·
/// run), oldest-first (backend-sorted), capped at 20 with an honest "+N more". The `rendered` markdown
/// is FLATTENED to its first line (never rendered in a cell — AnThinTable is single-line). count 0 → a
/// muted empty state. 停泊审批快照薄表(最久等的在最上,封顶 20+诚实 +N);rendered 只取首行拍平;空→静音空态。
Widget listApprovalInboxBody(BuildContext context, ToolCardState state) {
  final t = Translations.of(context);
  final c = context.colors;
  Map<String, dynamic>? out;
  try {
    final d = jsonDecode(state.resultText);
    if (d is Map<String, dynamic>) out = d;
  } catch (_) {}
  final parked = (out?['parked'] as List?) ?? const [];
  final count = (out?['count'] as num?)?.toInt() ?? parked.length;
  if (count == 0) {
    return Text(t.chat.tool.inboxEmptyState, style: AnText.reading.copyWith(color: c.inkFaint));
  }
  const cap = 20;
  final rows = <Map<String, String>>[];
  for (final p in parked.take(cap)) {
    if (p is! Map) continue;
    final rendered = p['rendered']?.toString() ?? '';
    final first = rendered
        .split('\n')
        .map((l) => l.trim())
        .firstWhere((l) => l.isNotEmpty, orElse: () => '—');
    final parkedAt = DateTime.tryParse(p['parkedAt']?.toString() ?? '');
    final flowrunId = p['flowrunId']?.toString() ?? '';
    rows.add({
      'ref': p['ref']?.toString() ?? '',
      'summary': first,
      'wait': fmtWaitedSince(parkedAt),
      'run': flowrunId.length > 10 ? '${flowrunId.substring(0, 10)}…' : flowrunId,
    });
  }
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      AnThinTable(
        columns: [
          AnTableColumn('ref', label: t.chat.tool.inboxRef),
          AnTableColumn('summary', label: t.chat.tool.inboxSummary),
          AnTableColumn('wait', label: t.chat.tool.inboxWait),
          AnTableColumn('run', label: t.chat.tool.inboxRun),
        ],
        rows: rows,
      ),
      if (count > cap)
        Padding(
          padding: const EdgeInsets.only(top: AnSpace.s4),
          child: Text(t.chat.tool.inboxMore(n: '${count - cap}'),
              style: AnText.meta.copyWith(color: c.inkFaint)),
        ),
    ],
  );
}

String? _langOf(String path) {
  final i = path.lastIndexOf('.');
  if (i < 0) return null;
  return switch (path.substring(i + 1).toLowerCase()) {
    'dart' => 'dart',
    'py' => 'python',
    'go' => 'go',
    'js' || 'ts' || 'tsx' || 'jsx' => 'javascript',
    'json' => 'json',
    'md' => 'markdown',
    'sh' || 'bash' => 'bash',
    'yaml' || 'yml' => 'yaml',
    _ => null,
  };
}

// ── F4 builds 构建族 ────────────────────────────────────────────────────────

/// Extract a build call's MAIN CONTENT (the thing being authored) from its args — tolerant of
/// a PARTIAL mid-stream fragment, which is the family's whole show: the code/prompt/document
/// streams into the window as the LLM types it.
/// 从 args 提取构建调用的**主内容**(被创作之物)——容忍流中不完整片段;这正是本族的重头戏:
/// 代码/提示词/文档随 LLM 打字流进窗里。
String? buildContentOf(String toolName, String argsFragment) {
  if (toolName.endsWith('_function') || toolName.endsWith('_handler')) {
    // ops-based: the set_code op's `code` (functions); handlers are structured ops — fall
    // through to `code` too (add_method carries `body`, try it second).
    // ops 型:set_code 的 `code`;handler 结构化 ops——先试 `code` 再试 add_method 的 `body`。
    return argStringPartial(argsFragment, 'code') ?? argStringPartial(argsFragment, 'body');
  }
  if (toolName.endsWith('_agent')) return argStringPartial(argsFragment, 'prompt');
  if (toolName.endsWith('_document')) return argStringPartial(argsFragment, 'content');
  if (toolName.endsWith('_skill')) return argStringPartial(argsFragment, 'body');
  return null; // workflow/control/approval/trigger: JSON config — the body shows args 图/配置走 JSON
}

String? _buildLang(String toolName) {
  if (toolName.endsWith('_function') || toolName.endsWith('_handler')) return 'python';
  if (toolName.endsWith('_document') || toolName.endsWith('_skill')) return 'markdown';
  return null;
}

/// The LIVE builds window: the content streaming in as the LLM emits args — plain mono while
/// flowing (a re-highlight per delta would burn the frame budget), swapped for the highlighted
/// editor once settled (in [buildToolBody]).
/// builds 活窗:内容随 LLM 吐 args 流入——流动期纯等宽(逐 delta 重新高亮烧帧预算),落定后
/// (在 [buildToolBody])换高亮编辑器。
Widget buildLiveBody(BuildContext context, ToolCardState state) {
  final content = buildContentOf(state.toolName, state.argsText);
  if (content == null || content.isEmpty) return const SizedBox.shrink();
  final c = context.colors;
  final lines = content.split('\n');
  const tail = 8; // a taller window than the terminal tail — code is the show 代码是主角,窗更高
  final shown = lines.length > tail ? lines.sublist(lines.length - tail) : lines;
  return ToolWindow(
    child: Text(shown.join('\n'), style: AnText.code.copyWith(color: c.inkMuted)),
  );
}

/// The settled builds body: intent · authored content (highlighted) · the RESULT BAR — id,
/// version, env outcome. envStatus is the family's honest half-success: the entity landed but
/// its sandbox env may still be building or have failed (envError shown red).
/// builds 落定体:意图 · 创作内容(高亮)· **结果条**——id/版本/env 结局。envStatus 是本族的
/// 诚实半成功:实体落了、沙箱 env 可能还在构建或已失败(envError 红显)。
Widget buildToolBody(BuildContext context, ToolCardState state) {
  final content = buildContentOf(state.toolName, state.argsText);
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _intent(context, state),
      if (content != null && content.isNotEmpty)
        AnCodeEditor(code: content, lang: _buildLang(state.toolName))
      else if (state.argsText.isNotEmpty)
        ToolWindow(child: _cappedMono(context, state.argsText)),
      RunStatBar(state: state),
    ],
  );
}

/// F4 fn/hd — the ENV SELF-HEAL timeline: when the sandbox env took more than one attempt to build,
/// the fixer revised deps with an LLM and retried (≤3). Each `envFixAttempts` entry (`{attempt, deps,
/// ok, error?}`) renders as ✓ ready / ✗ failed + its deps + the error tail — the "it fixed itself"
/// moment. Only shown when the array is present (single-shot success omits it).
/// env 自愈时间线:env 装了不止一次(改依赖重试 ≤3)时逐 attempt 渲 ✓/✗ + deps + error——「自己治好自己」。
Widget envFixTimeline(BuildContext context, List<dynamic> attempts) {
  final t = Translations.of(context);
  final c = context.colors;
  return Padding(
    padding: const EdgeInsets.only(top: AnSpace.s8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(t.chat.tool.envFixTitle, style: AnText.label.copyWith(color: c.inkFaint)),
        const SizedBox(height: AnSpace.s4),
        for (final raw in attempts)
          if (raw is Map) _envFixRow(context, raw),
      ],
    ),
  );
}

Widget _envFixRow(BuildContext context, Map<dynamic, dynamic> a) {
  final t = Translations.of(context);
  final c = context.colors;
  final ok = a['ok'] == true;
  final deps = (a['deps'] as List?)?.map((e) => e.toString()).join(' ') ?? '';
  final error = a['error']?.toString() ?? '';
  return Padding(
    padding: const EdgeInsets.only(bottom: AnSpace.s4),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(ok ? AnIcons.check : AnIcons.close,
                size: AnSize.iconSm, color: ok ? c.ok : c.danger),
            const SizedBox(width: AnGap.inline),
            Text(t.chat.tool.envFixAttempt(n: '${a['attempt']}'),
                style: AnText.label.copyWith(color: c.inkMuted)),
            if (deps.isNotEmpty) ...[
              const SizedBox(width: AnGap.inline),
              Flexible(
                child: Text(deps,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AnText.codeInline.copyWith(color: c.inkFaint)),
              ),
            ],
          ],
        ),
        if (!ok && error.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: AnSize.iconSm + AnGap.inline, top: AnSpace.s2),
            child: Text(error,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AnText.code.copyWith(color: c.danger)),
          ),
      ],
    ),
  );
}

/// The backend EntityKind wire value a build tool operates on (create_function → 'function'), used by
/// [RunStatBar] for the provenance RefPill + the dual-key id fallback. null = not an entity-CRUD build.
/// 构建工具作用的实体 kind 线缆值(RefPill + 双键 id 用);null=非 entity-CRUD。
String? buildEntityKind(String toolName) {
  const kinds = ['function', 'handler', 'agent', 'workflow', 'control', 'approval', 'document', 'skill', 'trigger'];
  for (final k in kinds) {
    if (toolName.endsWith('_$k')) return k;
  }
  return null;
}

/// The settled RESULT BAR (公共化 from the old _BuildResultBar) — the outcome in one line: a provenance
/// [AnRefPill] (the entity just built; label = its name from args, else id) + version + env 三色 +
/// restarted, plus an optional envError line. The pill's onTap DEGRADES to copy-id until the panel-nav
/// registry lands (B3 #8); it will then become a real select-intent deep-link. Reused across F4 builds;
/// F8 exec extends it (B5).
///
/// 结果条(旧 _BuildResultBar 公共化):凭据 RefPill(刚建的实体,label=args.name 否则 id)+ vN + env 三色
/// + 重启 + envError 行。pill 的 onTap 在面板注册表(B3 #8)就绪前**降级复制 id**,届时升级为真 select 深链。
class RunStatBar extends StatelessWidget {
  const RunStatBar({required this.state, super.key});

  final ToolCardState state;

  @override
  Widget build(BuildContext context) {
    final t = Translations.of(context);
    final c = context.colors;
    Map<String, dynamic>? out;
    try {
      final d = jsonDecode(state.resultText);
      if (d is Map<String, dynamic>) out = d;
    } catch (_) {}
    if (out == null) return const SizedBox.shrink();

    final kind = buildEntityKind(state.toolName);
    // Dual-key id: create returns `id`, edit returns `<entity>Id` (agentId / functionId / …). 双键兜。
    final id = (out['id'] ?? (kind == null ? null : out['${kind}Id'])) as String?;
    // Label: only CREATE's args.name is the entity name (top-level or in set_meta); on EDIT the first
    // "name" in args is a nested op field (e.g. add_method's method.name) — use the id there.
    // label:仅 create 的 args.name 是实体名;edit 的首个 "name" 是嵌套 op 字段(如方法名)→ 用 id。
    final label = state.toolName.startsWith('create_') ? (argStringPartial(state.argsText, 'name') ?? id) : id;
    final version = out['version'];
    final envStatus = out['envStatus'] as String?;
    final envError = out['envError'] as String?;
    final restarted = out['restarted'] == true;
    // handler-edit only: the resident instance's state after the edit. crashed = the honest brick
    // (env ready but __init__ broke); stopped is BENIGN (a never-spawned handler — census correction,
    // don't over-alarm); running = healthy. handler edit 专属:crashed=真 brick,stopped=良性(未 spawn)。
    final runtimeState = out['runtimeState'] as String?;
    final runtimeWarning = out['runtimeWarning'] as String?;
    final restartNote = out['restartNote'] as String?;
    final envFixAttempts = out['envFixAttempts'] as List?;

    final faint = AnText.meta.copyWith(color: c.inkFaint);
    final metaSpans = <InlineSpan>[];
    void sep() {
      if (metaSpans.isNotEmpty) metaSpans.add(TextSpan(text: ' · ', style: faint));
    }
    if (version != null) {
      sep();
      metaSpans.add(TextSpan(text: 'v$version', style: AnText.metaTabular().copyWith(color: c.inkMuted)));
    }
    if (envStatus != null) {
      sep();
      metaSpans.add(TextSpan(
          text: switch (envStatus) {
            'ready' => t.chat.tool.envReady,
            'failed' => t.chat.tool.envFailed,
            _ => t.chat.tool.envBuilding,
          },
          style: AnText.meta.copyWith(color: switch (envStatus) {
            'ready' => c.ok,
            'failed' => c.danger,
            _ => c.warn,
          })));
    }
    if (runtimeState != null) {
      sep();
      metaSpans.add(TextSpan(
          text: switch (runtimeState) {
            'running' => t.chat.tool.runtimeRunning,
            'crashed' => t.chat.tool.runtimeCrashed,
            _ => t.chat.tool.runtimeStopped,
          },
          style: AnText.meta.copyWith(color: switch (runtimeState) {
            'running' => c.ok,
            'crashed' => c.danger,
            _ => c.inkFaint, // stopped = benign muted 良性静音
          })));
    }
    if (restarted) {
      sep();
      metaSpans.add(TextSpan(text: t.chat.tool.restarted, style: faint));
    }

    final chips = <Widget>[
      if (id != null && kind != null)
        AnRefPill(
            kind: kind,
            label: label ?? id,
            id: id,
            // Degrade: copy the id until the panel-nav registry lands (B3). 深链降级:复制 id。
            onTap: (tgt) => Clipboard.setData(ClipboardData(text: tgt.id)))
      else if (id != null)
        Text(id, style: AnText.codeInline.copyWith(color: c.inkMuted)),
      if (metaSpans.isNotEmpty) Text.rich(TextSpan(children: metaSpans)),
    ];
    if (chips.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: AnSpace.s6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AnSpace.s6,
            runSpacing: AnSpace.s4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: chips,
          ),
          if (envError != null && envError.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: AnSpace.s4),
              child: Text(envError, style: AnText.code.copyWith(color: c.danger)),
            ),
          // restartNote (empty-ops rebuild wiped in-memory state) = an amber heads-up, not an error.
          // restartNote(空 ops 重建抹内存态)= 琥珀提醒、非错。
          if (restartNote != null && restartNote.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: AnSpace.s4),
              child: Text(restartNote, style: AnText.label.copyWith(color: c.warn)),
            ),
          // runtimeWarning ONLY for a real crash (census correction: stopped false-alarms on a
          // never-spawned handler, so a stopped badge alone suffices there). runtimeWarning 仅 crashed 显。
          if (runtimeState == 'crashed' && runtimeWarning != null && runtimeWarning.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: AnSpace.s4),
              child: Text(runtimeWarning, style: AnText.code.copyWith(color: c.danger)),
            ),
          if (envFixAttempts != null && envFixAttempts.length > 1)
            envFixTimeline(context, envFixAttempts),
        ],
      ),
    );
  }
}
