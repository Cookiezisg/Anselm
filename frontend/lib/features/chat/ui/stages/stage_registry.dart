import 'agent_stage.dart';
import 'approval_stage.dart';
import 'control_stage.dart';
import 'handler_stage.dart';
import 'document_stage.dart';
import 'function_stage.dart';
import 'skill_memory_mcp_stage.dart';
import 'stage_scene.dart';
import 'subagent_stage.dart';
import 'trigger_stage.dart';
import 'workflow_stage.dart';

/// kind → bespoke stage body (WRK-061 §7). Absent = the generic stage (the designed fallback, not a
/// stub) — the map fills W2→W5 until all 13 kinds are bespoke. kind→量身舞台体;缺=通用舞台兜底,
/// W2→W5 逐批补满 13 座。
final Map<String, StageBodyBuilder> stageBodies = {
  'function': (context, scene) => FunctionStageBody(scene: scene),
  'document': (context, scene) => DocumentStageBody(scene: scene),
  'workflow': (context, scene) => WorkflowStageBody(scene: scene),
  'control': (context, scene) => ControlStageBody(scene: scene),
  'approval': (context, scene) => ApprovalStageBody(scene: scene),
  'trigger': (context, scene) => TriggerStageBody(scene: scene),
  'subagent': (context, scene) => SubagentStageBody(scene: scene),
  'handler': (context, scene) => HandlerStageBody(scene: scene),
  'agent': (context, scene) => AgentStageBody(scene: scene),
  'skill': (context, scene) => SkillStageBody(scene: scene),
  'memory': (context, scene) => MemoryStageBody(scene: scene),
  'mcp': (context, scene) => McpStageBody(scene: scene),
};
