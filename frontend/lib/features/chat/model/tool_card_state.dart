import '../../../core/contract/messages/block_content.dart';
import '../../../core/messages/block_tree_reducer.dart';

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
/// progress / tool_result children). Pure and cheap — recomputed per build, no caching.
///
/// 一次工具调用的渲染投影:tool_call 及其嵌套 progress/tool_result 子块。纯且廉价——每 build
/// 重算、不缓存。
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
  });

  final ToolCardPhase phase;
  final String toolName;

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

  final String resultText;
  final String errorText;

  /// The nested progress block's accumulated text (wire snapshot key is `text`).
  /// 嵌套 progress 块的累计文本(线缆快照键是 `text`)。
  final String progressText;
  final bool progressLive;

  bool get hasBody =>
      summary.isNotEmpty || argsText.isNotEmpty || progressText.isNotEmpty || resultText.isNotEmpty || errorText.isNotEmpty;

  /// Derive from a tool_call node. [awaitingConfirm] is the interaction-signal overlay (V6).
  /// 从 tool_call 节点派生;awaitingConfirm 是 interaction 信号覆盖层(V6 接线)。
  factory ToolCardState.of(BlockNode node, {bool awaitingConfirm = false}) {
    BlockNode? result;
    BlockNode? progress;
    for (final c in node.children) {
      if (c.kind == BlockKind.toolResult) result ??= c;
      if (c.kind == BlockKind.progress) progress ??= c;
    }
    final resultText = result?.displayText ?? '';
    final phase = _phase(node, result, resultText, awaitingConfirm);
    return ToolCardState(
      phase: phase,
      toolName: node.name ?? '',
      summary: node.summary ?? '',
      danger: node.danger ?? '',
      argsText: node.argumentsText,
      resultText: resultText,
      errorText: result?.error ?? '',
      progressText: _progressText(progress),
      progressLive: progress?.isOpen ?? false,
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
