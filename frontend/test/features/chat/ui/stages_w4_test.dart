import 'package:anselm/core/contract/todo.dart';
import 'package:anselm/core/contract/conversation.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/sse/frame.dart';
import 'package:anselm/core/ui/ui.dart';
import 'package:anselm/features/chat/data/chat_fixtures.dart';
import 'package:anselm/features/chat/data/chat_providers.dart';
import 'package:anselm/features/chat/model/stage_director.dart';
import 'package:anselm/features/chat/state/stage_director_provider.dart';
import 'package:anselm/features/chat/state/stage_expansion.dart';
import 'package:anselm/features/chat/ui/stage_panel.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// W4 execution family: the RUNDOWN (whole-list todo frames → ring + three-state rows + subagent
// boards), the SUBAGENT stage (nested trajectory → current action + compact tail; close settles with
// tokens + stopReason), the ENSEMBLE (≥2 live delegates → cards; tapping a peer pins it), and R-10's
// poll lifecycle (trigger_workflow's 202 close NEVER curtains). W4 执行族电池。

const _conv = 'cv_1';
const _scope = StreamScope(kind: 'conversation', id: _conv);

FixtureChatRepository _repo() => FixtureChatRepository(
  conversations: [
    Conversation(
      id: _conv,
      title: 'w4',
      createdAt: DateTime.utc(2026, 7, 8),
      updatedAt: DateTime.utc(2026, 7, 8),
      lastMessageAt: DateTime.utc(2026, 7, 8),
    ),
  ],
);

Widget _host(FixtureChatRepository repo) => ProviderScope(
  overrides: [chatRepositoryProvider.overrideWithValue(repo)],
  child: TranslationProvider(
    child: MaterialApp(
      theme: AnTheme.light(),
      home: Scaffold(
        body: SizedBox(
          width: 400,
          height: 760,
          child: StagePanel(conversationId: _conv),
        ),
      ),
    ),
  ),
);

StreamEnvelope _open(
  String id,
  String tool, {
  String? parent,
  String type = 'tool_call',
  Map<String, dynamic>? extra,
}) => StreamEnvelope(
  seq: 1,
  scope: _scope,
  id: id,
  frame: FrameOpen(
    parentId: parent,
    node: StreamNode(type: type, content: {'name': tool, ...?extra}),
  ),
);
StreamEnvelope _delta(String id, String chunk) => StreamEnvelope(
  seq: 0,
  scope: _scope,
  id: id,
  frame: FrameDelta(chunk: chunk),
);
StreamEnvelope _close(
  String id, {
  String status = 'completed',
  Map<String, dynamic>? content,
}) => StreamEnvelope(
  seq: 2,
  scope: _scope,
  id: id,
  frame: FrameClose(
    status: status,
    result: content == null
        ? null
        : StreamNode(type: 'tool_call', content: content),
  ),
);

void main() {
  setUpAll(() => LocaleSettings.setLocaleRaw('zh-CN'));

  testWidgets(
    'RUNDOWN: whole-list todo frames render the ring + three-state rows + subagent boards',
    (tester) async {
      final repo = _repo();
      await tester.pumpWidget(_host(repo));
      await tester.pump();
      repo.emitTodos(
        const ConversationTodos(
          conversationId: _conv,
          todos: [
            TodoEntry(content: '扫描日志', status: 'completed'),
            TodoEntry(
              content: '定位根因',
              activeForm: '正在定位根因…',
              status: 'in_progress',
            ),
            TodoEntry(content: '写修复方案', status: 'pending'),
          ],
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      // The todo pins as row zero — a progress-ring lead + done/total, collapsed by default (WRK-064).
      // todo 置顶为第 0 行(进度环 lead + done/total),默认收起。
      expect(find.byType(AnTaskRing), findsOneWidget);
      expect(find.text('1/3'), findsOneWidget);
      // Expand it to reveal the checklist. 展开见清单。
      await tester.tap(find.text(t.chat.stage.tasks));
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        find.text('正在定位根因…'),
        findsOneWidget,
      ); // activeForm fronts in_progress 进行时文案
      expect(find.text('扫描日志'), findsOneWidget); // struck completed 划线完成
      expect(find.text('写修复方案'), findsOneWidget);

      // A subagent board joins with its micro-title; the whole-list REPLACES (no merge). 子清单+整表替换。
      repo.emitTodos(
        const ConversationTodos(
          conversationId: _conv,
          subagentId: 'sub_1',
          todos: [TodoEntry(content: '子任务甲', status: 'pending')],
        ),
      );
      repo.emitTodos(
        const ConversationTodos(
          conversationId: _conv,
          todos: [
            TodoEntry(content: '扫描日志', status: 'completed'),
            TodoEntry(content: '定位根因', status: 'completed'),
            TodoEntry(
              content: '写修复方案',
              activeForm: '正在写修复方案…',
              status: 'in_progress',
            ),
          ],
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        find.text('2/4'),
        findsOneWidget,
      ); // 2 done of 4 total (3 main + 1 sub) 合计
      expect(
        find.textContaining('sub_1'),
        findsOneWidget,
      ); // the board micro-title 子清单微标题
      expect(find.text('正在定位根因…'), findsNothing); // replaced wholesale 整表替换无残留
    },
  );

  testWidgets(
    'SUBAGENT solo: trajectory tail + current action; close settles tokens + stopReason',
    (tester) async {
      final repo = _repo();
      await tester.pumpWidget(_host(repo));
      await tester.pump();
      repo.emitFrame(_conv, _open('sa1', 'Subagent'));
      repo.emitFrame(
        _conv,
        _delta('sa1', '{"description":"审计执行日志","prompt":"..."}'),
      );
      // The nested E3 trajectory: a message wrapper carrying reasoning + a tool_call. 嵌套轨迹。
      repo.emitFrame(
        _conv,
        _open(
          'm1',
          '',
          parent: 'sa1',
          type: 'message',
          extra: {'role': 'assistant'},
        ),
      );
      repo.emitFrame(_conv, _open('r1', '', parent: 'm1', type: 'reasoning'));
      repo.emitFrame(_conv, _delta('r1', '先拉最近十条失败记录'));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('审计执行日志'), findsOneWidget); // the task name 任务名
      expect(
        find.text('先拉最近十条失败记录'),
        findsWidgets,
      ); // current action / tail 当前动作+尾行

      repo.emitFrame(
        _conv,
        _close(
          'sa1',
          content: {
            'name': 'Subagent',
            'status': 'completed',
            'stopReason': 'max_tokens',
            'tokens': {'in': 1200, 'out': 800},
            'arguments': '{"description":"审计执行日志"}',
          },
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.textContaining('1200'), findsOneWidget); // tokens roll 结算
      expect(
        find.textContaining('max_tokens'),
        findsOneWidget,
      ); // honest stopReason 止因如实
    },
  );

  testWidgets(
    'G1: two live delegates, BOTH rows expanded — one card each, no in-body ensemble (N×N regression)',
    (tester) async {
      final repo = _repo();
      await tester.pumpWidget(_host(repo));
      await tester.pump();
      repo.emitFrame(_conv, _open('sa1', 'Subagent'));
      repo.emitFrame(_conv, _delta('sa1', '{"description":"分身甲"}'));
      await tester.pump(const Duration(milliseconds: 600));
      repo.emitFrame(_conv, _open('sa2', 'Subagent'));
      repo.emitFrame(_conv, _delta('sa2', '{"description":"分身乙"}'));
      await tester.pump(
        const Duration(milliseconds: 600),
      ); // sa2 debounce → channels 入频道
      await tester.pump(const Duration(milliseconds: 400));

      // Two accordion rows: the staged subject's opened automatically; open the channel's BY HAND.
      // This is the very state the retired ensemble left untested — both bodies mounted at once was
      // exactly where the old peers loop double-rendered (self-inclusion + N×N).
      // 两行:主角行已自动展开,手动展开频道行——「双行同展」正是旧群像从未被测过、且一测即爆的状态。
      expect(find.text('Subagent'), findsNWidgets(2));
      await tester.tap(find.text('Subagent').last);
      await tester.pump(const Duration(milliseconds: 400));

      // Panel-wide uniqueness: each delegate appears EXACTLY once; the ensemble title is retired.
      // 全面板唯一性:每席恰一张卡;群像标题退役。
      expect(find.text('分身甲'), findsOneWidget);
      expect(find.text('分身乙'), findsOneWidget);
      expect(find.textContaining('并行群像'), findsNothing);
    },
  );

  testWidgets(
    'G2: engaging a stage body claims the row — the curtain leaves it open and the pipeline stays alive',
    (tester) async {
      final repo = _repo();
      await tester.pumpWidget(_host(repo));
      await tester.pump();
      repo.emitFrame(_conv, _open('b1', 'create_function'));
      await tester.pump(
        const Duration(milliseconds: 600),
      ); // staged + auto-opened 登台+自动展开

      final el = tester.element(find.byType(StagePanel));
      final container = ProviderScope.containerOf(el, listen: false);
      expect(
        container.read(stageExpansionProvider(_conv)).contains('block:b1'),
        isTrue,
      );

      // Tap inside the live body — the G2 row claim. Pre-G2 this pinned the whole DIRECTOR: the
      // follow pipeline froze for the rest of the conversation with no exit. 体内点击=认领本行;
      // 旧行为钉死整个导演器、全会话流水线冻结且无出口。
      await tester.tap(find.byType(AnHonestyRibbon));
      await tester.pump();

      // The wire truth: the tool_call close only ends ARG streaming; the director settles on the
      // tool_result close (the real execution terminal). 线缆真相:参流关≠执行终态,导演器认 result 关。
      repo.emitFrame(_conv, _close('b1'));
      repo.emitFrame(_conv, _open('r1', '', parent: 'b1', type: 'tool_result'));
      repo.emitFrame(_conv, _close('r1'));
      await tester.pump(
        const Duration(milliseconds: 2000),
      ); // breath + curtain 停拍+谢幕

      // The curtain fired (subject gone) but the CLAIMED row stays open. 谢幕发生,认领行不收。
      expect(container.read(stageDirectorProvider(_conv)).subject, isNull);
      expect(
        container.read(stageExpansionProvider(_conv)).contains('block:b1'),
        isTrue,
      );

      // And the pipeline is alive: the next tool auto-stages + auto-opens ITS row. 流水线存活。
      repo.emitFrame(_conv, _open('b2', 'create_document'));
      await tester.pump(const Duration(milliseconds: 600));
      final stage = container.read(stageDirectorProvider(_conv));
      expect(stage.subject?.blockId, 'b2');
      expect(stage.phase, StagePhase.following);
      expect(
        container.read(stageExpansionProvider(_conv)).contains('block:b2'),
        isTrue,
      );
    },
  );

  test(
    'R-10 poll: trigger_workflow\'s 202 close NEVER curtains (holds until displaced/dismissed)',
    () {
      final d = StageDirector();
      final t0 = DateTime.utc(2026, 7, 8, 12);
      d.onToolOpen('b1', 'trigger_workflow', t0);
      d.advance(t0.add(const Duration(milliseconds: 500)));
      expect(d.state.stageOpen, isTrue);
      d.onToolClose(
        'b1',
        t0.add(const Duration(seconds: 2)),
      ); // the 202 enqueue receipt 入队回执
      d.advance(
        t0.add(const Duration(seconds: 30)),
      ); // any amount of breathing room 任意久
      expect(
        d.state.stageOpen,
        isTrue,
      ); // still on stage — the run is NOT over 仍在台上
      expect(d.state.phase, StagePhase.following);
      d.onDismiss(t0.add(const Duration(seconds: 31)));
      expect(d.state.phase, StagePhase.idle);
    },
  );
}
