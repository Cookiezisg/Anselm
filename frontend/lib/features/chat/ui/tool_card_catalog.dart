import '../../../i18n/strings.g.dart';
import '../model/tool_card_state.dart';

/// One tool's collapsed-line grammar: the deterministic verb pair (decision #1 — registry
/// verbs are the collapsed line's voice; the LLM's `summary` stays inside the expanded body)
/// plus the target chip text. V3a ships the GENERIC entry only; family tables land per batch
/// (WRK-053 §6: V3b shell+fs → V3c builds → …) and grow this file into the frontend twin of
/// the backend's touch catalog.
///
/// 一个工具的收起行文法:确定性动词对(拍板 #1——收起行的声音是注册表动词,LLM `summary` 留在
/// 展开体)+ 目标 chip 文本。V3a 只带**通用**条目;族表按批次落(WRK-053 §6),本文件将长成后端
/// touch catalog 的前端孪生。
class ToolCardStrings {
  const ToolCardStrings({required this.verb, required this.target});

  /// The verb for the current phase — gerund while live, past tense settled, honest terminals.
  /// 当前相位的动词——进行时(live)/过去时(settled)/诚实终态。
  final String verb;

  /// The mono target chip; empty = verb self-sufficient. 等宽目标 chip;空=动词自足。
  final String target;
}

/// Resolve the collapsed line for [state]. Generic grammar (V3a): verb = 正在调用/已调用
/// (+ terminal overrides), target = the raw tool name — every un-cataloged tool (incl. the
/// entire MCP-dynamic family) renders honestly through this fallback, never a silent hole.
///
/// 解析收起行。通用文法(V3a):动词=正在调用/已调用(+终态覆盖),目标=原始工具名——一切未编目
/// 工具(含整个 MCP 动态族)经此兜底诚实渲染,绝不无声。
ToolCardStrings toolCardStrings(ToolCardState state, Translations t) {
  final verb = switch (state.phase) {
    ToolCardPhase.argsStreaming || ToolCardPhase.running => t.chat.tool.calling,
    ToolCardPhase.awaitingConfirm => t.chat.tool.awaitingConfirm,
    ToolCardPhase.denied => t.chat.tool.denied,
    ToolCardPhase.cancelled => t.chat.tool.cancelled,
    ToolCardPhase.succeeded || ToolCardPhase.failed => t.chat.tool.called,
  };
  return ToolCardStrings(verb: verb, target: state.toolName);
}
