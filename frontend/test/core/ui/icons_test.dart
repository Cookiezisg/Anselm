import 'package:anselm/core/ui/icons.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

// The semantic registry is the single icon source — a wrong/missing binding must degrade to the
// visible fallback, never crash. 语义注册表是图标单源:错/缺绑定降级成可见 fallback、绝不崩。
void main() {
  test('byKey resolves domain keys + falls back on unknown', () {
    expect(AnIcons.byKey('agent'), AnIcons.agent);
    // Same Lucide glyph as the raw icon, rendered at the thin weight family. 同字形、细字重族。
    expect(AnIcons.byKey('agent').codePoint, LucideIcons.bot.codePoint);
    expect(AnIcons.byKey('workflow').codePoint, LucideIcons.workflow.codePoint);
    expect(AnIcons.byKey('conversation'), AnIcons.chat); // alias to chat
    expect(AnIcons.byKey('definitely-not-a-key'), AnIcons.fallback);
  });

  test('entityKindGlyph: the shared named lookup (case-insensitive, degrades)', () {
    expect(AnIcons.entityKindGlyph('function'), AnIcons.function);
    expect(AnIcons.entityKindGlyph('Workflow'), AnIcons.workflow); // case-insensitive
    expect(AnIcons.entityKindGlyph('document'), AnIcons.doc); // contract wire vocab, not demo alias
    expect(AnIcons.entityKindGlyph('mcp'), AnIcons.mcp);
    expect(AnIcons.entityKindGlyph('nope'), AnIcons.fallback);
  });

  test('node: the 5 graph kinds + fallback', () {
    expect(AnIcons.node('trigger'), AnIcons.trigger);
    expect(AnIcons.node('approval'), AnIcons.approval);
    expect(AnIcons.node('bogus'), AnIcons.fallback);
  });

  // The full chat tool registry (WRK-057 census §6: 13 resident + 103 lazy). Every real backend
  // tool must land an INTENTIONAL glyph — the wrench default is reserved for genuinely unknown
  // names, so any registry tool resolving to it is a missing binding (the "逐条钉死" guarantee).
  // 全量 chat 工具注册表:每个真实后端工具必须有意图字形,扳手默认只留给真未知名——注册表工具落到
  // 扳手 = 漏配。新增后端工具漏配即此测试红。
  const registry = <String>[
    // resident (13)
    'Read', 'Write', 'Edit', 'LS', 'Glob', 'Grep', 'Bash', 'BashOutput', 'KillShell',
    'ask_user', 'todo_write', 'todo_read', 'search_tools',
    // function (10)
    'search_function', 'get_function', 'create_function', 'edit_function', 'revert_function',
    'delete_function', 'update_function_meta', 'run_function', 'search_function_executions',
    'get_function_execution',
    // handler (12)
    'search_handler', 'get_handler', 'create_handler', 'edit_handler', 'revert_handler',
    'delete_handler', 'call_handler', 'update_handler_config', 'update_handler_meta',
    'restart_handler', 'search_handler_calls', 'get_handler_call',
    // agent (10)
    'search_agent', 'get_agent', 'create_agent', 'edit_agent', 'revert_agent', 'delete_agent',
    'update_agent_meta', 'invoke_agent', 'search_agent_executions', 'get_agent_execution',
    // control (6)
    'search_control', 'get_control', 'create_control', 'edit_control', 'revert_control',
    'delete_control',
    // approval (6)
    'search_approval', 'get_approval', 'create_approval', 'edit_approval', 'revert_approval',
    'delete_approval',
    // workflow (17)
    'search_workflow', 'get_workflow', 'create_workflow', 'edit_workflow', 'revert_workflow',
    'delete_workflow', 'capability_check_workflow', 'trigger_workflow', 'stage_workflow',
    'activate_workflow', 'deactivate_workflow', 'kill_workflow', 'get_flowrun', 'search_flowruns',
    'replay_flowrun', 'list_approval_inbox', 'decide_approval',
    // trigger (9)
    'search_triggers', 'get_trigger', 'create_trigger', 'edit_trigger', 'delete_trigger',
    'fire_trigger', 'search_activations', 'get_activation', 'search_firings',
    // document (7)
    'search_documents', 'list_documents', 'read_document', 'create_document', 'edit_document',
    'move_document', 'delete_document',
    // attachment (2)
    'list_attachments', 'read_attachment',
    // memory (3)
    'read_memory', 'write_memory', 'forget_memory',
    // model (1)
    'get_model_config',
    // mcp (6)
    'list_mcp_marketplace', 'install_mcp_server', 'uninstall_mcp_server', 'reconnect_mcp',
    'search_mcp_calls', 'get_mcp_call',
    // skill (5)
    'activate_skill', 'get_skill', 'create_skill', 'edit_skill', 'delete_skill',
    // blocks (1)
    'search_blocks',
    // conversation (3)
    'search_conversations', 'list_conversations', 'manage_conversation',
    // relation (1)
    'get_relations',
    // web (2)
    'WebFetch', 'WebSearch',
    // subagent (2)
    'Subagent', 'get_subagent_trace',
  ];

  test('every registry tool lands an intentional glyph (none falls to the wrench default)', () {
    expect(registry.length, 116, reason: '13 resident + 103 lazy = 116 (census §6)');
    final generic = registry.where((t) => AnIcons.toolIcon(t) == AnIcons.tool).toList();
    expect(generic, isEmpty,
        reason: 'these tools have no intentional glyph — add a binding (exact table or rule): $generic');
  });

  test('dynamic MCP tools + genuinely unknown names', () {
    expect(AnIcons.toolIcon('mcp__github__create_issue'), AnIcons.mcp);
    expect(AnIcons.toolIcon('frobnicate_the_gizmo'), AnIcons.tool); // real unknown → wrench
  });

  test('toolIcon: builds/get show the ENTITY, delete/revert/search show the ACTION', () {
    // builds + get → entity glyph
    expect(AnIcons.toolIcon('create_function'), AnIcons.function);
    expect(AnIcons.toolIcon('edit_workflow'), AnIcons.workflow);
    expect(AnIcons.toolIcon('get_agent'), AnIcons.agent);
    expect(AnIcons.toolIcon('create_control'), AnIcons.control);
    expect(AnIcons.toolIcon('get_skill'), AnIcons.skill);
    expect(AnIcons.toolIcon('create_trigger'), AnIcons.trigger);
    // delete → tombstone, revert → history, search/list → search, update → edit
    expect(AnIcons.toolIcon('delete_agent'), AnIcons.trash);
    expect(AnIcons.toolIcon('revert_function'), AnIcons.history);
    expect(AnIcons.toolIcon('search_workflow'), AnIcons.search);
    expect(AnIcons.toolIcon('update_handler_config'), AnIcons.edit);
    expect(AnIcons.toolIcon('update_function_meta'), AnIcons.edit);
  });

  test('toolIcon: run-log archives read as history (not captured by the entity suffix)', () {
    expect(AnIcons.toolIcon('get_function_execution'), AnIcons.history);
    expect(AnIcons.toolIcon('search_handler_calls'), AnIcons.history);
    expect(AnIcons.toolIcon('get_flowrun'), AnIcons.history);
    expect(AnIcons.toolIcon('search_firings'), AnIcons.history);
    expect(AnIcons.toolIcon('get_activation'), AnIcons.history);
    expect(AnIcons.toolIcon('get_mcp_call'), AnIcons.history);
  });

  test('toolIcon: irregular families get their bespoke glyph', () {
    expect(AnIcons.toolIcon('Read'), AnIcons.doc);
    expect(AnIcons.toolIcon('Edit'), AnIcons.diff);
    expect(AnIcons.toolIcon('LS'), AnIcons.folder);
    expect(AnIcons.toolIcon('Bash'), AnIcons.terminal);
    expect(AnIcons.toolIcon('KillShell'), AnIcons.ban);
    expect(AnIcons.toolIcon('call_handler'), AnIcons.handler); // exec verb, not history
    expect(AnIcons.toolIcon('WebFetch'), AnIcons.download);
    expect(AnIcons.toolIcon('WebSearch'), AnIcons.web);
    expect(AnIcons.toolIcon('ask_user'), AnIcons.ask);
    expect(AnIcons.toolIcon('decide_approval'), AnIcons.gavel);
    expect(AnIcons.toolIcon('list_approval_inbox'), AnIcons.inbox);
    expect(AnIcons.toolIcon('write_memory'), AnIcons.memory);
    expect(AnIcons.toolIcon('forget_memory'), AnIcons.trash);
    expect(AnIcons.toolIcon('todo_write'), AnIcons.todo);
    expect(AnIcons.toolIcon('get_relations'), AnIcons.relations);
    expect(AnIcons.toolIcon('get_model_config'), AnIcons.model);
    expect(AnIcons.toolIcon('list_mcp_marketplace'), AnIcons.store);
    expect(AnIcons.toolIcon('uninstall_mcp_server'), AnIcons.unplug);
    expect(AnIcons.toolIcon('reconnect_mcp'), AnIcons.refresh);
    expect(AnIcons.toolIcon('restart_handler'), AnIcons.refresh);
    expect(AnIcons.toolIcon('stage_workflow'), AnIcons.layers);
    expect(AnIcons.toolIcon('deactivate_workflow'), AnIcons.pause);
    expect(AnIcons.toolIcon('kill_workflow'), AnIcons.ban);
    expect(AnIcons.toolIcon('capability_check_workflow'), AnIcons.capability);
    expect(AnIcons.toolIcon('move_document'), AnIcons.move);
    expect(AnIcons.toolIcon('Subagent'), AnIcons.subagent);
    expect(AnIcons.toolIcon('get_subagent_trace'), AnIcons.history);
    expect(AnIcons.toolIcon('run_function'), AnIcons.run);
    expect(AnIcons.toolIcon('invoke_agent'), AnIcons.agent);
    expect(AnIcons.toolIcon('manage_conversation'), AnIcons.chat);
  });
}
