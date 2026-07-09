import 'package:anselm/core/contract/conversation.dart';
import 'package:anselm/core/contract/entities/agent.dart';
import 'package:anselm/core/contract/entities/handler.dart';
import 'package:anselm/core/contract/entities/values.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/sse/frame.dart';
import 'package:anselm/features/chat/data/chat_fixtures.dart';
import 'package:anselm/features/chat/data/chat_providers.dart';
import 'package:anselm/features/chat/ui/stage_panel.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// W5 long-tail stages (13/13 bespoke): HANDLER (method rack — the W0 path-aware channel keeps同名
// bodies apart), AGENT (R-9 progressive disclosure: untouched slots keep the 40% old truth), SKILL
// (amber allowedTools + $ placeholders), MEMORY (the slip), MCP (masked env keys + the tool shelf).
// W5 长尾五座电池。

const _conv = 'cv_1';
const _scope = StreamScope(kind: 'conversation', id: _conv);

FixtureChatRepository _repo() => FixtureChatRepository(conversations: [
      Conversation(
        id: _conv,
        title: 'w5',
        createdAt: DateTime.utc(2026, 7, 8),
        updatedAt: DateTime.utc(2026, 7, 8),
        lastMessageAt: DateTime.utc(2026, 7, 8),
      ),
    ]);

Widget _host(FixtureChatRepository repo) => ProviderScope(
      overrides: [chatRepositoryProvider.overrideWithValue(repo)],
      child: TranslationProvider(
        child: MaterialApp(
          theme: AnTheme.light(),
          home: Scaffold(
            body: SizedBox(width: 400, height: 760, child: StagePanel(conversationId: _conv)),
          ),
        ),
      ),
    );

StreamEnvelope _open(String id, String tool) => StreamEnvelope(
    seq: 1, scope: _scope, id: id,
    frame: FrameOpen(node: StreamNode(type: 'tool_call', content: {'name': tool})));
StreamEnvelope _delta(String id, String chunk) =>
    StreamEnvelope(seq: 0, scope: _scope, id: id, frame: FrameDelta(chunk: chunk));
StreamEnvelope _close(String id, String args) => StreamEnvelope(
    seq: 2, scope: _scope, id: id,
    frame: FrameClose(status: 'completed', result: StreamNode(type: 'tool_call', content: {
      'name': '', 'arguments': args,
    })));

Future<void> _stageFrames(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 600));
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  setUpAll(() => LocaleSettings.setLocaleRaw('zh-CN'));

  testWidgets('HANDLER: the rack keeps同名 method bodies apart (W0 path channel) + settle states',
      (tester) async {
    final repo = _repo();
    repo.handlers['hd_1'] = HandlerEntity(
      id: 'hd_1',
      name: 'notifier',
      configState: 'ready',
      runtimeState: 'running',
      createdAt: DateTime.utc(2026, 7, 1),
      updatedAt: DateTime.utc(2026, 7, 1),
    );
    await tester.pumpWidget(_host(repo));
    await tester.pump();
    repo.emitFrame(_conv, _open('tc', 'edit_handler'));
    repo.emitFrame(
        _conv,
        _delta('tc',
            '{"handlerId":"hd_1","ops":['
            '{"op":"add_method","method":{"name":"send","streaming":true,"timeout":30,"body":"def send(self):\\n    push()\\n"}},'
            '{"op":"add_method","method":{"name":"drain","body":"def drain(self):\\n    fl'));
    await _stageFrames(tester);

    expect(find.text('send'), findsOneWidget); // spine 1 书脊一
    expect(find.text('~'), findsOneWidget); // streaming wave 波浪
    expect(find.textContaining('⏱ 30'), findsOneWidget);
    expect(find.text('    push()'), findsOneWidget); // method 1's CLOSED body 一号方法已闭 body
    // Method 2's body is still streaming: its whole line is unreleased and NOT bleeding into spine 1.
    // 二号 body 仍在流:未完行按住,且绝不串进一号书脊。
    expect(find.textContaining('fl'), findsNothing);

    const finalArgs =
        '{"handlerId":"hd_1","ops":[{"op":"add_method","method":{"name":"send","streaming":true,"timeout":30,"body":"def send(self):\\n    push()\\n"}},{"op":"add_method","method":{"name":"drain","body":"def drain(self):\\n    flush()\\n"}}]}';
    repo.emitFrame(_conv, _close('tc', finalArgs));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text(t.chat.stage.cfgReady), findsOneWidget); // configState from the truth 配置态
    expect(find.text(t.chat.stage.rtRunning), findsOneWidget); // runtimeState heartbeat 运行态
  });

  testWidgets('AGENT R-9: touching only tools keeps the OLD prompt as the 40% stratum', (tester) async {
    final repo = _repo();
    repo.agents['ag_1'] = AgentEntity(
      id: 'ag_1',
      name: 'auditor',
      activeVersion: AgentVersion(
        id: 'av_2',
        agentId: 'ag_1',
        version: 2,
        prompt: '你是审计员,先看日志再下结论。',
        tools: const [ToolRef(ref: 'fn_pull', name: 'pull_invoices')],
        createdAt: DateTime.utc(2026, 7, 1),
        updatedAt: DateTime.utc(2026, 7, 1),
      ),
      createdAt: DateTime.utc(2026, 7, 1),
      updatedAt: DateTime.utc(2026, 7, 1),
    );
    await tester.pumpWidget(_host(repo));
    await tester.pump();
    repo.emitFrame(_conv, _open('tc', 'edit_agent'));
    repo.emitFrame(
        _conv,
        _delta('tc', '{"agentId":"ag_1","tools":[{"ref":"fn_sum","name":"sum_rollup"}],"kno'));
    await _stageFrames(tester);

    expect(find.textContaining('你是审计员'), findsOneWidget); // untouched prompt = old stratum 旧地层
    expect(find.textContaining('v2'), findsOneWidget);
    expect(find.text('sum_rollup'), findsOneWidget); // the fresh belt chip 新腰带扣
  });

  testWidgets('SKILL: amber allowedTools + \$ placeholder slots + the human-only seal', (tester) async {
    final repo = _repo();
    await tester.pumpWidget(_host(repo));
    await tester.pump();
    repo.emitFrame(_conv, _open('tc', 'create_skill'));
    repo.emitFrame(
        _conv,
        _delta('tc',
            '{"name":"deploy-runbook","context":"fork","allowedTools":["Bash","run_function"],'
            '"disableModelInvocation":true,"body":"Run \$ARGUMENTS against \${STAGE} then report \$1.'));
    await _stageFrames(tester);

    expect(find.text('deploy-runbook'), findsWidgets); // the mono slug 铭牌
    expect(find.text('Bash'), findsOneWidget); // amber pill 琥珀药丸
    expect(find.text('仅人可唤'), findsOneWidget);
    expect(find.text(r'$ARGUMENTS'), findsOneWidget); // placeholder slot 占位槽
    expect(find.text(r'${STAGE}'), findsOneWidget);
  });

  testWidgets('MEMORY: the slip carries the slug corner + growing content', (tester) async {
    final repo = _repo();
    await tester.pumpWidget(_host(repo));
    await tester.pump();
    repo.emitFrame(_conv, _open('tc', 'write_memory'));
    repo.emitFrame(
        _conv,
        _delta('tc', '{"name":"retry-policy","content":"重试统一走指数退避,超限抛 SyncError。'));
    await _stageFrames(tester);

    expect(find.text('retry-policy'), findsWidgets); // slug corner 笺角
    expect(find.textContaining('指数退避'), findsOneWidget);
  });

  testWidgets('MCP: env KEYS masked •••• while live; the settle shelf counts discovered tools',
      (tester) async {
    final repo = _repo();
    await tester.pumpWidget(_host(repo));
    await tester.pump();
    repo.emitFrame(_conv, _open('tc', 'install_mcp_server'));
    repo.emitFrame(
        _conv,
        _delta('tc', '{"name":"github","env":{"GITHUB_TOKEN":"ghp_secret123"},"transport":"st'));
    await _stageFrames(tester);

    expect(find.text('GITHUB_TOKEN ••••'), findsOneWidget); // key visible, value NEVER 键显值恒掩
    expect(find.textContaining('ghp_secret123'), findsNothing);

    repo.emitFrame(
        _conv,
        StreamEnvelope(
            seq: 2, scope: _scope, id: 'tc',
            frame: const FrameClose(status: 'completed', result: StreamNode(type: 'tool_call', content: {
              'name': 'install_mcp_server',
              'arguments': '{"name":"github","env":{"GITHUB_TOKEN":"x"}}',
            }))));
    repo.emitFrame(
        _conv,
        const StreamEnvelope(
            seq: 3, scope: _scope, id: 'tr',
            frame: FrameOpen(parentId: 'tc', node: StreamNode(type: 'tool_result', content: {
              'content': '{"id":"mcp_1","tools":[{"name":"create_issue"},{"name":"list_repos"}]}',
            }))));
    repo.emitFrame(
        _conv,
        const StreamEnvelope(
            seq: 4, scope: _scope, id: 'tr',
            frame: FrameClose(status: 'completed', result: StreamNode(type: 'tool_result', content: {
              'content': '{"id":"mcp_1","tools":[{"name":"create_issue"},{"name":"list_repos"}]}',
            }))));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('个工具已发现'), findsOneWidget);
    expect(find.text('create_issue'), findsOneWidget); // the shelf 货架
    expect(find.text('list_repos'), findsOneWidget);
  });
}
