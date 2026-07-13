import 'dart:convert';

import '../../../core/contract/messages/block_content.dart';
import '../../../core/messages/args_session.dart';
import '../../../core/messages/block_tree_reducer.dart';
import '../../../core/model/partial_json.dart';

/// The tool card's lifecycle phase — derived, never stored (WRK-053 §2). Wire anchors:
/// argsStreaming = tool_call still open (args flow as deltas); running = tool_call closed but no
/// tool_result child yet; the four terminals split on the tool_result child (error status / the
/// backend's fixed deny/cancel prose / plain success). awaitingConfirm is fed by the interaction
/// signal layer (V6) — the chassis renders it, the wiring lands with the humanloop batch.
///
/// 工具卡生命周期相位——**派生、不存**(WRK-053 §2)。线缆锚点:argsStreaming=tool_call 未关(args
/// delta 流入);running=tool_call 已关但无 tool_result 子块;四种终态按 tool_result 子块分流
/// (error 状态 / 后端固定的拒绝·取消散文 / 普通成功)。awaitingConfirm 由 interaction 信号层喂
/// (V6)——底盘先会渲,接线随人在环批次。
enum ToolCardPhase {
  argsStreaming,
  awaitingConfirm,
  running,
  succeeded,
  failed,
  denied,
  cancelled,
}

/// The backend's FIXED refusal/cancel prose on a completed tool_result (wire contract, not
/// heuristics: `humanloopapp.DenyFeedback` and friends — a denied dangerous call closes
/// status=completed by design, so prose is the only signal).
///
/// 后端在 completed tool_result 上的**固定**拒绝/取消散文(线缆契约、非启发式:humanloop 的
/// DenyFeedback 等——被拒的危险调用按设计以 completed 关闭,散文是唯一信号)。
const String deniedProsePrefix = 'The user denied running this tool';
const String declinedProsePrefix = 'The user declined to answer this question';
const String cancelledBeforeRunProse = 'The run was cancelled before this tool ran';

/// ask_user's exact completed-but-empty answer (backend `ask/ask.go`): an accept with a blank answer
/// closes status=completed with this prose — the card reads it as 空答案, not a real answer.
/// ask_user 的空答案精确串:accept 但答案为空以 completed 关闭并带此串——卡读作「空答案」。
const String askEmptyAnswerProse = '(the user submitted an empty answer)';

/// decide_approval's NOT_PARKED message (backend `flowrun.go` ErrNodeNotParked, surfaced as the error
/// tool_result text). A product-NORMAL (first-decision-wins / timed out / wrong node id), not a crash —
/// the card reframes it, never a red failure. 首决胜/超时/节点误标的产品正常态,卡友好呈现、非红崩。
const String notParkedProse = 'approval node is not awaiting a decision';

/// One tool call's render-ready projection of its [BlockNode] subtree (tool_call + nested
/// progress / tool_result children). Pure — and memoized on the node's subtree [BlockNode.revision]
/// (WRK-061 W0): the same node at the same revision returns the SAME instance, so a card that reads
/// the state several times per build (and every build between frames) derives it once per change.
///
/// 一次工具调用的渲染投影:tool_call 及其嵌套 progress/tool_result 子块。纯——且按节点子树
/// [BlockNode.revision] 记忆化(WRK-061 W0):同节点同版本返回**同一实例**,变更一次才派生一次。
class ToolCardState {
  const ToolCardState({
    required this.phase,
    required this.toolName,
    required this.summary,
    required this.danger,
    required this.argsText,
    required this.resultText,
    required this.errorText,
    required this.progressText,
    required this.progressLive,
    this.entityName = '',
    this.nested = const [],
    PartialJsonSession? session,
  }) : _session = session;

  final ToolCardPhase phase;
  final String toolName;

  /// The call's PRIMARY target entity's display name (backend-resolved from the arg id via the touchpoint
  /// Namer), so a card's target chip shows "sync_inventory" instead of "fn_a1b2…". Empty when the tool
  /// touches no nameable entity (the chip falls back to the arg id). 主目标实体显示名(后端解析),空则退回 id。
  final String entityName;

  /// The LLM's self-reported one-line intent — lands with the tool_call CLOSE (decision #1:
  /// shown inside the expanded body, never the collapsed line for cataloged tools).
  /// LLM 自报一句话意图——随 tool_call Close 落定(拍板 #1:入展开体,编目工具的收起行不用它)。
  final String summary;

  /// safe / cautious / dangerous — the per-call self-report. 每次调用的危险自报。
  final String danger;

  /// Final args JSON, or the raw streamed fragment while argsStreaming (may be un-parseable
  /// mid-flight and still contain the framework keys — render tolerantly).
  /// 最终参数 JSON;argsStreaming 期为原始流片段(中途可能不可解析、且仍含框架键——须容忍渲染)。
  final String argsText;

  /// The node-scoped INCREMENTAL args parse session (WRK-061 W0) — live windows read
  /// [PartialJsonSession.liveStringAt] / [PartialJsonSession.arrayItemsAt] instead of re-scanning
  /// [argsText] every build. Null only for directly-constructed states (gallery fixtures): the
  /// [argsSession] getter then builds one from [argsText], cached per instance (settled = one feed ever).
  /// 节点级增量 args 会话——活窗读它而非每 build 重扫 argsText。直构 state(gallery fixture)为 null,
  /// getter 按实例惰建缓存(settled 只喂一次)。
  final PartialJsonSession? _session;

  PartialJsonSession get argsSession =>
      _session ?? (_fallbackSessions[this] ??= PartialJsonSession()..append(argsText));

  static final Expando<PartialJsonSession> _fallbackSessions = Expando('toolCardArgs');

  final String resultText;

  /// The result JSON decoded to a `Map`, or null (non-object / unparseable / empty). Memoized PER INSTANCE
  /// via an [Expando] (C-028, the same idiom as [argsSession]): family bodies / receipts decode
  /// [resultText] every build, and settled cards re-render on the 1s ticker + inside live turns — so
  /// without this a KB~百KB result JSON re-parses every frame, N cards × per frame. [ToolCardState.of] is
  /// memoized on the node revision, so the same instance (hence its cache) survives until the result
  /// actually changes → a new instance re-decodes. 结果 JSON 解为 Map,per-instance 记忆化(同 argsSession);
  /// 族体/回执每 build 重解析同一 settled 结果,revision 变才新实例重解。
  Map<String, dynamic>? get resultObj {
    final cached = _resultObjCache[this];
    if (cached != null) return identical(cached, _kNoObj) ? null : cached as Map<String, dynamic>;
    Map<String, dynamic>? r;
    try {
      final d = jsonDecode(resultText);
      if (d is Map<String, dynamic>) r = d;
    } catch (_) {}
    _resultObjCache[this] = r ?? _kNoObj;
    return r;
  }

  static final Expando<Object> _resultObjCache = Expando('toolCardResultObj');
  static final Object _kNoObj = Object(); // sentinel: decoded to null (Expando can't store null) 空哨兵

  final String errorText;

  /// The nested progress block's accumulated text (wire snapshot key is `text`).
  /// 嵌套 progress 块的累计文本(线缆快照键是 `text`)。
  final String progressText;
  final bool progressLive;

  /// The E3 nested trajectory — the tool_call's child blocks that are NOT its tool_result / progress
  /// (a Subagent / invoke_agent run's streamed reasoning/text/tool_call subtree, nested by parentBlockId).
  /// LIVE only (never persisted to message_blocks) → empty on a history reload; the durable record is the
  /// run's transcript (get_subagent_trace / get_agent_execution). E3 嵌套轨迹:子块子树(仅流不落盘)。
  final List<BlockNode> nested;

  bool get hasBody =>
      summary.isNotEmpty || argsText.isNotEmpty || progressText.isNotEmpty || resultText.isNotEmpty || errorText.isNotEmpty || nested.isNotEmpty;

  /// Derive from a tool_call node. [awaitingConfirm] is the interaction-signal overlay (V6).
  /// Memoized in the node's revision-keyed slot — same (revision, awaitingConfirm) → cached instance.
  /// 从 tool_call 节点派生;awaitingConfirm 是 interaction 信号覆盖层(V6 接线)。同 (版本,人闸旗) 返缓存实例。
  factory ToolCardState.of(BlockNode node, {bool awaitingConfirm = false}) {
    final cached = node.derivedCache;
    if (node.derivedCacheRev == node.revision &&
        cached is (bool, ToolCardState) &&
        cached.$1 == awaitingConfirm) {
      return cached.$2;
    }
    final state = ToolCardState._derive(node, awaitingConfirm);
    node.derivedCache = (awaitingConfirm, state);
    node.derivedCacheRev = node.revision;
    return state;
  }

  factory ToolCardState._derive(BlockNode node, bool awaitingConfirm) {
    BlockNode? result;
    BlockNode? progress;
    final nested = <BlockNode>[];
    for (final c in node.children) {
      if (c.kind == BlockKind.toolResult) {
        result ??= c;
      } else if (c.kind == BlockKind.progress) {
        progress ??= c;
      } else if (c.kind == BlockKind.message) {
        // A nested subagent TURN arrives (live, E3) as a `message` wrapper whose Open.ParentID is this
        // tool_call; its real reasoning/text/tool_call trajectory is the wrapper's CHILDREN. Flatten so the
        // peek pane renders the trace, not an empty wrapper — the actual backend shape (subagent/emit.go).
        // The fixture / reload path already puts raw blocks directly under the call, so both still work.
        // 嵌套 subagent 回合(live E3)是个 message 包装,其真轨迹在它的子块——摊平,否则真后端下 peek 渲空。
        nested.addAll(c.children);
      } else {
        // Raw E3 trajectory blocks nested directly under a tool_call (fixture / reload). 直接挂 call 下的轨迹块。
        nested.add(c);
      }
    }
    final resultText = result?.displayText ?? '';
    final phase = _phase(node, result, resultText, awaitingConfirm);
    return ToolCardState(
      phase: phase,
      toolName: node.name ?? '',
      summary: node.summary ?? '',
      danger: node.danger ?? '',
      entityName: node.entityName ?? '',
      argsText: node.argumentsText,
      session: argsSessionOf(node),
      resultText: resultText,
      errorText: result?.error ?? '',
      progressText: _progressText(progress),
      progressLive: progress?.isOpen ?? false,
      nested: nested,
    );
  }

  static ToolCardPhase _phase(
      BlockNode node, BlockNode? result, String resultText, bool awaitingConfirm) {
    if (node.isOpen) return ToolCardPhase.argsStreaming;
    if (node.status == 'cancelled') return ToolCardPhase.cancelled;
    if (result == null) {
      return awaitingConfirm ? ToolCardPhase.awaitingConfirm : ToolCardPhase.running;
    }
    if (result.isError) return ToolCardPhase.failed;
    if (resultText.startsWith(deniedProsePrefix) || resultText.startsWith(declinedProsePrefix)) {
      return ToolCardPhase.denied;
    }
    if (resultText.startsWith(cancelledBeforeRunProse)) return ToolCardPhase.cancelled;
    return ToolCardPhase.succeeded;
  }

  /// progress snapshot key is `text` (wire asymmetry vs other blocks' `content`); live falls
  /// back to the delta buffer. progress 快照键是 `text`(线缆不对称);live 回落 delta 缓冲。
  static String _progressText(BlockNode? p) {
    if (p == null) return '';
    final snap = p.content?['text'];
    if (snap is String && snap.isNotEmpty) return snap;
    return p.deltaText;
  }
}
