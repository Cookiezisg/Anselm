import 'package:anselm/core/contract/conversation.dart';
import 'package:anselm/core/contract/touchpoint.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/settings/app_prefs_providers.dart';
import 'package:anselm/core/settings/settings_prefs.dart';
import 'package:anselm/core/sse/frame.dart';
import 'package:anselm/features/chat/data/chat_fixtures.dart';
import 'package:anselm/features/chat/data/chat_providers.dart';
import 'package:anselm/features/chat/model/stage_director.dart';
import 'package:anselm/features/chat/state/stage_director_provider.dart';
import 'package:anselm/features/chat/ui/stage_panel.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// W7 polish batteries: the R-10 retirement end-to-end (a poll stage settles on the durable
// run_terminal entities signal, matched by flowrunId), the persisted follow three-notch, and the
// curtain-call landing wash on the settled subject's Cast row.
// W7 收官电池:R-10 退役端到端(poll 舞台按 flowrunId 匹配 durable run_terminal 落定)、跟随三档持久化、
// 谢幕落账洗亮。

const _conv = 'cv_1';
const _scope = StreamScope(kind: 'conversation', id: _conv);

FixtureChatRepository _repo() => FixtureChatRepository(conversations: [
      Conversation(
        id: _conv,
        title: 'w7',
        createdAt: DateTime.utc(2026, 7, 8),
        updatedAt: DateTime.utc(2026, 7, 8),
        lastMessageAt: DateTime.utc(2026, 7, 8),
      ),
    ]);

Widget _host(FixtureChatRepository repo, {SettingsPrefs? prefs}) => ProviderScope(
      overrides: [
        chatRepositoryProvider.overrideWithValue(repo),
        if (prefs != null) settingsPrefsProvider.overrideWithValue(prefs),
      ],
      child: TranslationProvider(
        child: MaterialApp(
          theme: AnTheme.light(),
          home: Scaffold(
            body: SizedBox(width: 400, height: 760, child: StagePanel(conversationId: _conv)),
          ),
        ),
      ),
    );

void main() {
  setUpAll(() => LocaleSettings.setLocaleRaw('zh-CN'));

  testWidgets('R-10 retires end-to-end: the held 202 stage settles when ITS flowrun terminal '
      'arrives (wrong flowrunId ignored)', (tester) async {
    final repo = _repo();
    await tester.pumpWidget(_host(repo));
    await tester.pump();

    repo.emitFrame(_conv, const StreamEnvelope(
        seq: 1, scope: _scope, id: 'tc',
        frame: FrameOpen(node: StreamNode(type: 'tool_call', content: {'name': 'trigger_workflow'}))));
    repo.emitFrame(_conv, const StreamEnvelope(
        seq: 0, scope: _scope, id: 'tc',
        frame: FrameDelta(chunk: '{"workflowId":"wf_9","payload":{}}')));
    await tester.pump(const Duration(milliseconds: 600));
    // The enqueue receipt carries the flowrunId the terminal must match. 回执携 flowrunId。
    repo.emitFrame(_conv, const StreamEnvelope(
        seq: 2, scope: _scope, id: 'tr',
        frame: FrameOpen(parentId: 'tc', node: StreamNode(type: 'tool_result', content: {
          'content': '{"flowrunId":"fr_1","status":"running"}',
        }))));
    repo.emitFrame(_conv, const StreamEnvelope(
        seq: 3, scope: _scope, id: 'tc',
        frame: FrameClose(status: 'completed', result: StreamNode(type: 'tool_call', content: {
          'name': 'trigger_workflow',
          'arguments': '{"workflowId":"wf_9","payload":{}}',
        }))));
    await tester.pump(const Duration(seconds: 5));

    final el = tester.element(find.byType(StagePanel));
    final container = ProviderScope.containerOf(el, listen: false);
    expect(container.read(stageDirectorProvider(_conv)).stageOpen, isTrue,
        reason: 'the 202 close never curtains (R-10) 202 不谢幕');

    // A DIFFERENT run's terminal must not settle this stage. 别的 run 终态不落定本台。
    repo.emitWorkflowFrame('wf_9', const StreamEnvelope(
        seq: 10, scope: StreamScope(kind: 'workflow', id: 'wf_9'), id: 's1',
        frame: FrameSignal(node: StreamNode(type: 'run_terminal', content: {
          'flowrunId': 'fr_other', 'status': 'completed',
        }))));
    await tester.pump(const Duration(seconds: 3));
    expect(container.read(stageDirectorProvider(_conv)).stageOpen, isTrue);

    // Node ticks roll the LIVE RUN SCROLL: mono node rows + the taken port badge; a foreign
    // run's tick never shows (ticks NEVER guess). 节点 tick 滚活运行卷;外 run 的 tick 绝不显。
    repo.emitWorkflowFrame('wf_9', const StreamEnvelope(
        seq: 0, scope: StreamScope(kind: 'workflow', id: 'wf_9'), id: 't1',
        frame: FrameSignal(node: StreamNode(type: 'run', content: {
          'flowrunId': 'fr_1', 'nodeId': 'pull', 'iteration': 0, 'status': 'completed',
        }))));
    repo.emitWorkflowFrame('wf_9', const StreamEnvelope(
        seq: 0, scope: StreamScope(kind: 'workflow', id: 'wf_9'), id: 't2',
        frame: FrameSignal(node: StreamNode(type: 'run', content: {
          'flowrunId': 'fr_1', 'nodeId': 'gate', 'iteration': 0, 'status': 'completed', 'port': 'pass',
        }))));
    repo.emitWorkflowFrame('wf_9', const StreamEnvelope(
        seq: 0, scope: StreamScope(kind: 'workflow', id: 'wf_9'), id: 't3',
        frame: FrameSignal(node: StreamNode(type: 'run', content: {
          'flowrunId': 'fr_other', 'nodeId': 'ghost', 'iteration': 0, 'status': 'completed',
        }))));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('pull'), findsOneWidget);
    expect(find.text('gate'), findsOneWidget);
    expect(find.text('→ pass'), findsOneWidget); // the taken branch, live 选中分支实时可见
    expect(find.text('ghost'), findsNothing); // ticks never guess 绝不猜

    // OUR terminal settles it: breath then curtain. 我们的终态:停拍→谢幕。
    repo.emitWorkflowFrame('wf_9', const StreamEnvelope(
        seq: 11, scope: StreamScope(kind: 'workflow', id: 'wf_9'), id: 's2',
        frame: FrameSignal(node: StreamNode(type: 'run_terminal', content: {
          'flowrunId': 'fr_1', 'status': 'completed',
        }))));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text(t.chat.stage.run.done), findsOneWidget); // the honest closing line 收卷行
    await tester.pump(const Duration(milliseconds: 1900)); // settleBreath 停拍
    await tester.pump(const Duration(milliseconds: 400)); // curtain 谢幕
    expect(container.read(stageDirectorProvider(_conv)).stageOpen, isFalse,
        reason: 'the run truly ended — the hold retires 驻留退役');
  });

  testWidgets('the follow three-notch persists (restore + write-through)', (tester) async {
    final prefs = SettingsPrefs.inMemory({'an.stage.follow': 'never'});
    final repo = _repo();
    await tester.pumpWidget(_host(repo, prefs: prefs));
    await tester.pump();
    final el = tester.element(find.byType(StagePanel));
    final container = ProviderScope.containerOf(el, listen: false);
    await tester.pump(const Duration(milliseconds: 50));
    expect(container.read(followModeProvider), FollowMode.never,
        reason: 'restored from an.stage.follow 持久恢复');

    container.read(followModeProvider.notifier).set(FollowMode.firstPerConversation);
    await tester.pump(const Duration(milliseconds: 50));
    expect(prefs.getString(SettingsKeys.chatAutoStage), 'firstPerConversation');
  });

  testWidgets('a clean settle keeps the touchpoint row in place (no curtain removal, WRK-064)',
      (tester) async {
    final repo = _repo();
    final at = DateTime.now().toUtc();
    repo.touchpoints[_conv] = [
      Touchpoint(
          id: 'tp_1', conversationId: _conv, itemKind: 'document', itemId: 'weekly.md',
          itemName: 'weekly.md', verb: TouchpointVerb.created, lastActor: TouchpointActor.assistant,
          count: 1, firstAt: at, lastAt: at),
    ];
    await tester.pumpWidget(_host(repo));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    repo.emitFrame(_conv, const StreamEnvelope(
        seq: 1, scope: _scope, id: 'tc',
        frame: FrameOpen(node: StreamNode(type: 'tool_call', content: {'name': 'create_document'}))));
    repo.emitFrame(_conv, const StreamEnvelope(
        seq: 0, scope: _scope, id: 'tc',
        frame: FrameDelta(chunk: '{"name":"weekly.md","content":"# 周报"}')));
    await tester.pump(const Duration(milliseconds: 600));
    repo.emitFrame(_conv, const StreamEnvelope(
        seq: 2, scope: _scope, id: 'tc',
        frame: FrameClose(status: 'completed', result: StreamNode(type: 'tool_call', content: {
          'name': 'create_document',
          'arguments': '{"name":"weekly.md","content":"# 周报"}',
          'entityName': 'weekly.md',
        }))));
    await tester.pump(const Duration(milliseconds: 1900)); // breath 停拍
    await tester.pump(const Duration(milliseconds: 400)); // the director dismisses the subject 导演器谢幕
    await tester.pump(const Duration(milliseconds: 50));

    // The accordion keeps the settled row — the ledger touchpoint persists, nothing auto-collapses or
    // removes it (§8-3 手风琴心智=同屏可见). 手风琴保留落定行(行头名 + 展开摘要 id,都是 weekly.md)。
    expect(find.text('weekly.md'), findsWidgets);
  });
}
