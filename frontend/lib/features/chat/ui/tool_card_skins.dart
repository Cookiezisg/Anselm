import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/contract/interaction.dart';
import '../../../core/model/partial_json.dart';
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
  const ToolWindow({required this.child, this.header, this.actions = const [], super.key});

  final Widget child;

  /// Optional window header (e.g. the command line echoed terminal-style). 可选窗头(命令回显)。
  final Widget? header;

  /// Header-RIGHT action slot (R3 copy family — copy-full-output/command). Rendered flush-right on the
  /// header row (or a lone row when there's no [header]). 头右动作槽(R3 复制家族:copy 全文/命令)。
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    // The machine window IS the shared sunken panel (its header slot carries the command echo + actions).
    // 机器窗即共享凹陷面板(header 槽承载命令回显 + 动作)。
    final head = (header == null && actions.isEmpty)
        ? null
        : Row(children: [
            if (header != null) Expanded(child: header!) else const Spacer(),
            for (final a in actions) Padding(padding: const EdgeInsets.only(left: AnSpace.s4), child: a),
          ]);
    return SizedBox(
      width: double.infinity,
      child: AnSunkenPanel(header: head, child: child),
    );
  }
}

/// A window COPY action (WRK-056 R3 / #7) — copies [copyPayload] (the UNTRUNCATED full text; a rendered
/// view may cap, the copy never does) and flashes a ✓. Sits in a [ToolWindow.actions] header slot.
/// 窗复制动作:复制未截断全量 + ✓ 一闪。
class WindowCopyButton extends StatefulWidget {
  const WindowCopyButton({required this.copyPayload, super.key});
  final String copyPayload;
  @override
  State<WindowCopyButton> createState() => _WindowCopyButtonState();
}

class _WindowCopyButtonState extends State<WindowCopyButton> {
  bool _done = false;
  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.copyPayload));
    if (!mounted) return;
    setState(() => _done = true);
    Future<void>.delayed(AnMotion.dwell, () {
      if (mounted) setState(() => _done = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AnInteractive(
      onTap: _copy,
      builder: (ctx, states) => Icon(_done ? AnIcons.check : AnIcons.copy,
          size: AnSize.iconSm, color: _done ? c.ok : (states.isActive ? c.ink : c.inkFaint)),
    );
  }
}

/// Whether the call is still IN FLIGHT (args streaming / running) — the family bodies branch on
/// this to render their LIVE stage vs the settled record (WRK-065: the body owns both faces;
/// there is no separate auto-shown live window). 是否在飞——族体据此分流式舞台/落定记录两张脸。
bool toolLive(ToolCardState state) =>
    state.phase == ToolCardPhase.argsStreaming || state.phase == ToolCardPhase.running;

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
final _bashFooterExit = RegExp(r'\[exit code: (-?\d+)\]');
final _bashFooterStrip = RegExp(r'\n*(\[[^\]]*\]\n?)*\[exit code: -?\d+\]\s*$');
final _bashBgSpawn = RegExp(r'Started background command \(bash_id=(bsh_[0-9a-f]+)\):\s*(.*)');
const _bashHeadTrunc = '[truncated'; // '...[truncated N bytes from start]'

/// The Bash settled body (B4.5): the command echo header + a copy action, the output in a bounded
/// scrollback terminal ([AnTermViewport], ANSI + fold), and the footer STRIPPED into a colored bottom
/// bar (exit / note chips). A background spawn shows a thin session-chip body instead. Bash 落定体:
/// $ cmd 头 + copy + 有界终端窗 + 底条(exit/note chips);后台=薄会话 chip 体。
Widget bashToolBody(BuildContext context, ToolCardState state) {
  final c = context.colors;
  final t = Translations.of(context);
  final result = state.resultText;

  // Background spawn → a thin session body (copyable bsh_id + the poll hint). 后台→薄会话体。
  final bg = _bashBgSpawn.firstMatch(result);
  if (bg != null) {
    final id = bg.group(1)!;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      _intent(context, state),
      AnCopyChip(value: id),
      Padding(
        padding: const EdgeInsets.only(top: AnSpace.s6),
        child: Text(t.chat.tool.bashBgHint, style: AnText.meta.copyWith(color: c.inkFaint)),
      ),
    ]);
  }

  // In-flight read: the command echoes in the header WHILE args stream (the live face's identity
  // line — closed-only left the header blank mid-stream). 在途读:流式期命令即回显。
  final cmd = argStringPartial(state.argsText, 'command') ?? '';
  final progress = state.progressText;
  // The body source: progressText (full, no footer) is preferred; else strip the resultText footer.
  // The COPY payload is the full untruncated text (incl. footer when from result). 体源 + 复制全量。
  final usingProgress = progress.isNotEmpty;
  final body = usingProgress ? progress : result.replaceFirst(_bashFooterStrip, '').trimRight();
  final copyPayload = usingProgress ? progress : result;
  // Head-truncation note ONLY when the body IS the resultText and carries the marker (progressText is
  // full — never mark it truncated). 头截断注记仅当体=resultText 且带 marker(progressText 全量不标)。
  final headTruncated = !usingProgress && result.contains(_bashHeadTrunc);

  return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
    _intent(context, state),
    ToolWindow(
      header: cmd.isEmpty
          ? null
          : Text('\$ $cmd', style: AnText.code.copyWith(color: c.ink), maxLines: 8, overflow: TextOverflow.ellipsis),
      actions: [WindowCopyButton(copyPayload: copyPayload)],
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        if (headTruncated)
          Padding(
            padding: const EdgeInsets.only(bottom: AnSpace.s4),
            child: Text(t.chat.tool.bashHeadTruncated, style: AnText.meta.copyWith(color: c.inkFaint)),
          ),
        body.isEmpty
            ? Text(t.chat.tool.bashNoOutput, style: AnText.code.copyWith(color: c.inkFaint))
            : AnTermViewport(text: body),
      ]),
    ),
    ?_bashBottomBar(context, t, result),
  ]);
}

/// The Bash bottom bar — the stripped footer as colored chips: a NOTE chip (blocked/timeout/cancelled)
/// XOR the exit chip (exit -1 is redundant beside a note). null when there's no exit footer. 底条。
Widget? _bashBottomBar(BuildContext context, Translations t, String result) {
  final m = _bashFooterExit.firstMatch(result);
  if (m == null) return null;
  final code = int.parse(m.group(1)!);
  Widget chip;
  if (RegExp(r'\[blocked:').hasMatch(result)) {
    chip = AnBadge(t.chat.tool.bashBlocked, tone: AnTone.danger);
  } else if (_bashTimeoutBar.hasMatch(result)) {
    chip = AnBadge(t.chat.tool.timedOut, tone: AnTone.danger);
  } else if (RegExp(r'\[cancelled\]').hasMatch(result)) {
    chip = AnBadge(t.chat.tool.bashCancelled, tone: AnTone.none);
  } else {
    chip = AnBadge(t.chat.tool.exit(code: code), tone: code == 0 ? AnTone.ok : AnTone.danger);
  }
  return Padding(padding: const EdgeInsets.only(top: AnSpace.s6), child: Align(alignment: Alignment.centerLeft, child: chip));
}

final _bashTimeoutBar = RegExp(r'\[command timed out after');

// ── BashOutput (B4.6) ──
final _statusFooterStrip = RegExp(r'\n*(\[note:[^\]]*\]\n?)?\[status: [^\]]*\]\s*$');
final _statusFooterRe = RegExp(r'\[status: (running|exited \(code (-?\d+)\)|killed|errored)\]');
final _dropNoteRe = RegExp(r'\[note: (\d+) bytes dropped');

/// BashOutput settled body — a poll snapshot: bsh_id header (+ filter note) · the NEW output in a
/// bounded terminal · a status bottom bar (running = STATIC accent, never breathing — R5) + a
/// ring-overflow note chip. «no new output» / «session not found» degrade honestly. BashOutput 轮询体。
Widget bashOutputBody(BuildContext context, ToolCardState state) {
  final c = context.colors;
  final t = Translations.of(context);
  final result = state.resultText;
  if (result.startsWith('Background shell process not found')) {
    // The dead session: state the wire fact, then a neutral non-committal hint (never a single cause).
    // 会话不存在:陈述线缆事实 + 中性穷举 hint。
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Text(result.trim(), style: AnText.code.copyWith(color: c.danger)),
      Padding(
        padding: const EdgeInsets.only(top: AnSpace.s4),
        child: Text(t.chat.tool.bashSessionGoneHint, style: AnText.meta.copyWith(color: c.inkFaint)),
      ),
    ]);
  }
  final bashId = argString(state.argsText, 'bash_id') ?? '';
  final filter = argString(state.argsText, 'filter');
  final body = result.replaceFirst(_statusFooterStrip, '').trimRight();
  final noNew = body.trim() == '(no new output since last poll)' || body.isEmpty;

  return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
    Row(children: [
      if (bashId.isNotEmpty) AnCopyChip(value: bashId),
      if (filter != null && filter.isNotEmpty) ...[
        const SizedBox(width: AnSpace.s6),
        Text(t.chat.tool.grepFilter(p: filter), style: AnText.meta.copyWith(color: c.inkFaint)),
      ],
    ]),
    const SizedBox(height: AnSpace.s6),
    ToolWindow(
      actions: [WindowCopyButton(copyPayload: result)],
      child: noNew
          ? Text(t.chat.tool.bashNoNew, style: AnText.code.copyWith(color: c.inkFaint))
          : AnTermViewport(text: body),
    ),
    ?_bashStatusBar(context, t, result),
  ]);
}

/// The BashOutput status bottom bar — a STATIC status chip (running = accent, no breath) + a
/// ring-overflow note. status 底条:静态状态 chip(运行中=accent 无呼吸)+ 溢出 note。
Widget? _bashStatusBar(BuildContext context, Translations t, String result) {
  final m = _statusFooterRe.firstMatch(result);
  if (m == null) return null;
  final s = m.group(1)!;
  Widget chip;
  if (s == 'running') {
    chip = AnBadge(t.chat.tool.statusRunning, tone: AnTone.accent);
  } else if (s == 'killed') {
    chip = AnBadge(t.chat.tool.statusKilled, tone: AnTone.none);
  } else if (s == 'errored') {
    chip = AnBadge(t.chat.tool.statusErrored, tone: AnTone.danger);
  } else {
    chip = AnBadge(t.chat.tool.statusExited(code: int.parse(m.group(2)!)), tone: AnTone.danger);
  }
  final drop = _dropNoteRe.firstMatch(result);
  return Padding(
    padding: const EdgeInsets.only(top: AnSpace.s6),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      chip,
      if (drop != null) ...[
        const SizedBox(width: AnSpace.s6),
        AnBadge(t.chat.tool.bashDropped(n: drop.group(1)!), tone: AnTone.warn),
      ],
    ]),
  );
}

/// KillShell settled body (B4.7, thin) — the result sentence + a copyable bsh_id. KillShell 薄体。
Widget killShellBody(BuildContext context, ToolCardState state) {
  final c = context.colors;
  final bashId = argString(state.argsText, 'bash_id') ?? '';
  return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
    if (bashId.isNotEmpty) AnCopyChip(value: bashId),
    Padding(
      padding: const EdgeInsets.only(top: AnSpace.s6),
      child: Text(state.resultText.trim(), style: AnText.code.copyWith(color: c.inkMuted)),
    ),
  ]);
}

/// F1 Write — TWO faces, ONE shell (WRK-066 族二): LIVE = the file content streams through the
/// editor's live face (full highlight + gutter, bounded stick-to-bottom viewport; the head slices
/// its own O(tail)); SETTLED = the SAME editor un-pinned at the SAME tier (zero jump), display
/// capped at [AnCap.window] with COPY carrying the full content.
/// F1 Write——两脸一壳(族二):活=编辑器 live 脸(全量高亮+行号,有界贴底视口,O(tail) 族头内建);
/// 落定=同一编辑器同档解除钉底(零跳变),显示按 AnCap.window 封顶、copy 保全量。
Widget writeToolBody(BuildContext context, ToolCardState state) {
  final c = context.colors;
  final t = Translations.of(context);
  final path = state.argsSession.closedStringAt(['file_path']) ?? '';
  if (toolLive(state)) {
    final content = state.argsSession.liveStringNamed('content') ?? '';
    if (path.isEmpty && content.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      if (path.isNotEmpty)
        Padding(padding: const EdgeInsets.only(bottom: AnSpace.s4), child: AnPathChip(path: path)),
      if (content.isNotEmpty)
        AnCodeEditor(code: content, lang: langOf(path), reading: true, live: true, maxHeight: AnSize.codeViewport),
    ]);
  }
  final content = state.argsSession.closedStringAt(['content']) ?? '';
  if (content.isEmpty) return const SizedBox.shrink();
  final over = content.length > AnCap.window;
  final shown = over ? content.substring(0, AnCap.window) : content;
  return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
    if (path.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: AnSpace.s4), child: AnPathChip(path: path)),
    // 拍板 #2 zero jump: both faces share the SAME viewport tier — the settle only un-pins; the old
    // AnFadeCollapse is retired here (an expanding fold is a height jump by definition). copyPayload
    // keeps copy = full content while display is capped. 零跳变:两脸同档,落定仅解除钉底;折叠退役
    // (展开即高度跳变);copy 保全量。
    AnCodeEditor(code: shown, copyPayload: content, lang: langOf(path), reading: true, maxHeight: AnSize.codeViewport),
    if (over)
      Padding(
        padding: const EdgeInsets.only(top: AnSpace.s4),
        child: Text(t.chat.tool.contentTruncated, style: AnText.meta.copyWith(color: c.inkFaint)),
      ),
  ]);
}

/// F1 Edit — TWO faces, ONE diff shell (WRK-066 族二): LIVE = the two-act surgery through
/// [AnVersionDiff]'s live face (all − rows then all + rows, the SAME row pipeline/bar as settled —
/// a mid-stream LCS would lie); SETTLED = the unified diff at the SAME tier (zero jump); a
/// `replace_all` edit adds an «N 处全部替换» note. new_string="" = a pure deletion (all-red).
/// F1 Edit——两脸一壳(族二):活=diff live 两幕(先全 − 后全 +,与落定同行管线同 bar;流中 LCS 会撒谎);
/// 落定=同档 unified diff(零跳变)+replace_all 注记。
Widget editToolBody(BuildContext context, ToolCardState state) {
  final t = Translations.of(context);
  final path = state.argsSession.closedStringAt(['file_path']) ?? '';
  if (toolLive(state)) {
    final oldS = state.argsSession.liveStringNamed('old_string') ?? '';
    final newS = state.argsSession.liveStringNamed('new_string') ?? '';
    if (path.isEmpty && oldS.isEmpty && newS.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      if (path.isNotEmpty)
        Padding(padding: const EdgeInsets.only(bottom: AnSpace.s4), child: AnPathChip(path: path)),
      // Empty-stream guard is built into the diff (rows.isEmpty → shrink, 复审 #29). 空流守卫内建。
      AnVersionDiff(before: oldS, after: newS, lang: langOf(path), live: true, maxHeight: AnSize.codeViewport),
    ]);
  }
  final oldS = state.argsSession.closedStringAt(['old_string']);
  final newS = state.argsSession.closedStringAt(['new_string']);
  if (oldS == null && newS == null) return const SizedBox.shrink();
  final replaceAll = RegExp(r'"replace_all"\s*:\s*true').hasMatch(state.argsText);
  final replacedN = RegExp(r'Replaced (\d+) occurrence').firstMatch(state.resultText)?.group(1);
  return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
    if (path.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: AnSpace.s4), child: AnPathChip(path: path)),
    AnVersionDiff(
      before: oldS ?? '',
      after: newS ?? '',
      lang: langOf(path),
      maxHeight: AnSize.codeViewport,
      note: (replaceAll && replacedN != null) ? t.chat.tool.replaceAllNote(n: replacedN) : null,
    ),
  ]);
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
      Expanded(child: Text(t.chat.tool.notParked, style: AnText.body.copyWith(color: c.inkMuted))),
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
        Text(reason, style: AnText.body.copyWith(color: c.ink)),
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
    return Text(t.chat.tool.inboxEmptyState, style: AnText.body.copyWith(color: c.inkFaint));
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

// ── F4 builds 构建族 ────────────────────────────────────────────────────────

/// Extract a build call's MAIN CONTENT (the thing being authored) from its args — tolerant of
/// a PARTIAL mid-stream fragment, which is the family's whole show: the code/prompt/document
/// streams into the window as the LLM types it.
/// 从 args 提取构建调用的**主内容**(被创作之物)——容忍流中不完整片段;这正是本族的重头戏:
/// 代码/提示词/文档随 LLM 打字流进窗里。
String? buildContentOf(String toolName, PartialJsonSession args) {
  if (toolName.endsWith('_function')) {
    // ops-based: the set_code op's `code`. liveStringNamed matches the key at ANY depth,
    // in-flight first. ops 型:set_code 的 `code`,任意深度、在途优先。
    return args.liveStringNamed('code');
  }
  if (toolName.endsWith('_handler')) {
    // Handler wire keys: add_method carries `body`, set_init carries `initBody`, set_shutdown
    // carries `shutdownBody` (backend apply.go — there is NO `code` key on the handler wire; the
    // old `code ?? body` chain left init/shutdown streaming INVISIBLE). Only one value streams at
    // a time, so the window follows the IN-FLIGHT one first (whichever is growing right now),
    // else the newest closed of the three. handler 线缆键:body/initBody/shutdownBody(线缆无 code
    // 键——旧链让 init/shutdown 流入期全盲)。同一时刻只有一个值在流:窗先跟在途者,否则取最新闭合。
    const keys = {'body', 'initBody', 'shutdownBody'};
    final inFlight = args.inFlightString;
    final last = inFlight?.path.lastOrNull;
    if (inFlight != null && last is String && keys.contains(last)) return inFlight.text;
    return args.liveStringNamed('body') ??
        args.liveStringNamed('initBody') ??
        args.liveStringNamed('shutdownBody');
  }
  if (toolName.endsWith('_agent')) return args.liveStringNamed('prompt');
  if (toolName.endsWith('_document')) return args.liveStringNamed('content');
  if (toolName.endsWith('_skill')) return args.liveStringNamed('body');
  return null; // workflow/control/approval/trigger: JSON config — the body shows args 图/配置走 JSON
}

/// The builds body — TWO faces, ONE shell (WRK-066 族二). LIVE: the authored content streaming
/// through the editor's live face (full highlight + gutter, bounded stick-to-bottom viewport —
/// the head slices its own O(tail)). SETTLED: intent · the SAME editor un-pinned at the SAME tier
/// (zero jump) · the RESULT BAR — id, version, env outcome (envStatus = the family's honest
/// half-success). Machine window: default 12 face (no `reading`).
/// builds 体——两脸一壳(族二):活=编辑器 live 脸(全量高亮+行号,有界贴底,O(tail) 族头内建);落定=
/// 意图 · 同一编辑器同档解除钉底(零跳变)· 结果条(env 诚实半成功)。机器窗守 12 档。
Widget buildToolBody(BuildContext context, ToolCardState state) {
  final content = buildContentOf(state.toolName, state.argsSession);
  final lang = langOfEntityKind(buildEntityKind(state.toolName));
  if (toolLive(state)) {
    if (content == null || content.isEmpty) return const SizedBox.shrink();
    return AnCodeEditor(code: content, lang: lang, live: true, maxHeight: AnSize.codeViewport);
  }
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _intent(context, state),
      if (content != null && content.isNotEmpty)
        AnCodeEditor(code: content, lang: lang, maxHeight: AnSize.codeViewport)
      else if (state.argsText.isNotEmpty)
        ToolWindow(child: _cappedMono(context, state.argsText)),
      runStatBarOf(context, state),
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
  // Hanging indent by STRUCTURE (批3 文法 #4: no token arithmetic) — the icon is its own column,
  // head + error share the Expanded so the error naturally aligns under the text, not the glyph.
  // 结构化悬挂缩进(文法 #4 禁 token 算术):图标独立列,头行与错误行同住 Expanded 自然对齐。
  return Padding(
    padding: const EdgeInsets.only(bottom: AnSpace.s4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(ok ? AnIcons.check : AnIcons.close,
            size: AnSize.iconSm, color: ok ? c.ok : c.danger),
        const SizedBox(width: AnGap.inline),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
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
                  padding: const EdgeInsets.only(top: AnSpace.s2),
                  child: Text(error,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AnText.code.copyWith(color: c.danger)),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

/// The backend EntityKind wire value a build tool operates on (create_function → 'function'), used by
/// the result-bar adapter [runStatBarOf] for the provenance RefPill + the dual-key id fallback. null = not an entity-CRUD build.
/// 构建工具作用的实体 kind 线缆值(RefPill + 双键 id 用);null=非 entity-CRUD。
String? buildEntityKind(String toolName) {
  const kinds = ['function', 'handler', 'agent', 'workflow', 'control', 'approval', 'document', 'skill', 'trigger'];
  for (final k in kinds) {
    if (toolName.endsWith('_$k')) return k;
  }
  return null;
}

/// The settled RESULT-BAR adapter (WRK-066 批3 条族四并一) — parses the build receipt out of
/// resultText and projects it onto the family head [AnStatBar]: the provenance [AnRefPill] →
/// leading (the bar's subject; onTap DEGRADES to copy-id until the panel-nav registry lands),
/// vN / env / runtime / restarted → stats (colour exits ONLY through AnTone — 文法 #6),
/// envError / restartNote / runtimeWarning → notes. The env self-heal timeline is F4 domain
/// furniture — a SIBLING below the bar, never a family slot.
///
/// 结果条适配器(批3 四并一):回执 → AnStatBar 槽位投影——凭据 pill 进 leading(条的主语;深链降级
/// 复制 id)、vN/env/runtime/重启进 stats(色只经 AnTone 出口,文法 #6)、三注记进 notes;env 自愈
/// 时间线是 F4 域家具,挂条下同胞、不进当家件。
Widget runStatBarOf(BuildContext context, ToolCardState state) {
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
  // Label: only CREATE's args.name is the entity name; on EDIT the first "name" in args is a nested
  // op field — use the id there. label:仅 create 的 args.name 是实体名;edit 用 id。
  final label = state.toolName.startsWith('create_') ? (argStringPartial(state.argsText, 'name') ?? id) : id;
  final envStatus = out['envStatus'] as String?;
  // handler-edit only: crashed = the honest brick; stopped is BENIGN (never-spawned — census
  // correction, don't over-alarm); running = healthy RESIDENT state (ok green, deliberately NOT
  // AnStatus.fromRaw's in-flight accent — 域覆盖,勿"顺手统一"). handler edit 专属声调域覆盖。
  final runtimeState = out['runtimeState'] as String?;
  final runtimeWarning = out['runtimeWarning'] as String?;
  final envFixAttempts = out['envFixAttempts'] as List?;

  final stats = <AnStat>[
    if (out['version'] != null) AnStat('v${out['version']}', tabular: true),
    if (envStatus != null)
      AnStat(
          switch (envStatus) {
            'ready' => t.chat.tool.envReady,
            'failed' => t.chat.tool.envFailed,
            _ => t.chat.tool.envBuilding,
          },
          tone: switch (envStatus) { 'ready' => AnTone.ok, 'failed' => AnTone.danger, _ => AnTone.warn }),
    if (runtimeState != null)
      AnStat(
          switch (runtimeState) {
            'running' => t.chat.tool.runtimeRunning,
            'crashed' => t.chat.tool.runtimeCrashed,
            _ => t.chat.tool.runtimeStopped,
          },
          tone: switch (runtimeState) { 'running' => AnTone.ok, 'crashed' => AnTone.danger, _ => AnTone.none }),
    if (out['restarted'] == true) AnStat(t.chat.tool.restarted),
  ];
  final leading = <Widget>[
    if (id != null && kind != null)
      AnRefPill(
          kind: kind,
          label: label ?? id,
          id: id,
          // Degrade: copy the id until the panel-nav registry lands (B3). 深链降级:复制 id。
          onTap: (tgt) => Clipboard.setData(ClipboardData(text: tgt.id)))
    else if (id != null)
      Text(id, style: AnText.codeInline.copyWith(color: c.inkMuted)),
  ];
  if (leading.isEmpty && stats.isEmpty) return const SizedBox.shrink();

  final bar = AnStatBar(leading: leading, stats: stats, notes: [
    if (out['envError'] case final String e when e.isNotEmpty) AnStatNote(e), // danger = mono voice
    // restartNote (empty-ops rebuild wiped in-memory state) = an amber heads-up, not an error.
    // restartNote(空 ops 重建抹内存态)= 琥珀提醒、非错。
    if (out['restartNote'] case final String n when n.isNotEmpty) AnStatNote(n, tone: AnTone.warn),
    // runtimeWarning ONLY for a real crash (stopped false-alarms on a never-spawned handler).
    // runtimeWarning 仅 crashed 显。
    if (runtimeState == 'crashed' && runtimeWarning != null && runtimeWarning.isNotEmpty)
      AnStatNote(runtimeWarning),
  ]);
  if (envFixAttempts == null || envFixAttempts.length <= 1) return bar;
  return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [bar, envFixTimeline(context, envFixAttempts)]);
}
