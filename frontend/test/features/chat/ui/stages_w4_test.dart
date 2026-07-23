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
import 'package:flutter/gestures.dart';
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

      // Row head + card header share ONE title derivation (G3/A2-23) — the same label in both, by
      // design. 行头与卡头单源同名(G3):同一标签恰两处。
      expect(find.text('审计执行日志'), findsNWidgets(2));
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
      // A1-4 regression lock (G4): the ARG-stream close is NOT the execution terminal — the card
      // keeps its live face (no ✓, no settle line) while the delegate still runs. 参流关≠执行终态:
      // 分身还在跑,卡不许提前换 ✓ 结算脸。
      expect(find.byIcon(AnIcons.check), findsNothing);
      expect(find.textContaining('1200'), findsNothing);

      repo.emitFrame(
        _conv,
        _open('r_sa1', '', parent: 'sa1', type: 'tool_result'),
      );
      repo.emitFrame(_conv, _close('r_sa1'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.textContaining('1200'), findsOneWidget); // tokens roll 结算
      expect(
        find.textContaining('max_tokens'),
        findsOneWidget,
      ); // honest stopReason 止因如实
    },
  );

  testWidgets('G4: a cancelled delegate never wears the green check (A3-5)', (
    tester,
  ) async {
    final repo = _repo();
    await tester.pumpWidget(_host(repo));
    await tester.pump();
    repo.emitFrame(_conv, _open('sa1', 'Subagent'));
    repo.emitFrame(_conv, _delta('sa1', '{"description":"取消演习"}'));
    await tester.pump(const Duration(milliseconds: 600));
    repo.emitFrame(_conv, _close('sa1', status: 'cancelled'));
    await tester.pump(const Duration(milliseconds: 100));
    // The settle mark speaks the terminal: cancelled = the neutral glyph, NEVER the ok check.
    // 结算记号如实:取消=中性记号,绝非成功绿勾。
    expect(find.byIcon(AnIcons.check), findsNothing);
    expect(
      find.descendant(
        of: find.byType(AnWindow),
        matching: find.byIcon(AnIcons.close),
      ),
      findsOneWidget,
    );
  });

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

      // Two accordion rows now TITLED BY TASK (G3 single-source naming): the subject's row is auto-
      // opened (head + its own card = 2), the channel's is collapsed (head only = 1) — the ensemble
      // no longer leaks a peer card into the subject's body. 行头即任务名:主角行头+卡=2,频道行头=1。
      expect(find.text('分身甲'), findsNWidgets(2));
      expect(find.text('分身乙'), findsOneWidget);
      await tester.tap(find.text('分身乙'));
      await tester.pump(const Duration(milliseconds: 400));

      // BOTH bodies mounted — the state the retired ensemble left untested. Each delegate appears
      // exactly TWICE (its own head + its own card), never a third copy from a peers loop (the N×N
      // regression), and the ensemble title is gone for good. 双行同展:每席恰「头+卡」两处、无第三张。
      expect(find.text('分身甲'), findsNWidgets(2));
      expect(find.text('分身乙'), findsNWidgets(2));
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

  testWidgets(
    'G3: a failed activity wears the red truth and the clear exit actually removes it',
    (tester) async {
      final repo = _repo();
      await tester.pumpWidget(_host(repo));
      await tester.pump();
      repo.emitFrame(_conv, _open('b1', 'create_agent'));
      await tester.pump(const Duration(milliseconds: 600));
      repo.emitFrame(_conv, _close('b1', status: 'error'));
      await tester.pump();

      // The row says «失败», never «进行中» (the old head aliased «director holds a view» to Live).
      // 行头如实「失败」,绝不再渲「进行中」。
      expect(find.text(t.chat.stage.rowFailed), findsOneWidget);
      expect(find.text(t.chat.stage.live), findsNothing);

      // The exit exists and works — a failed activity is no longer a permanent squatter. The action
      // is hover-revealed (idle layer IgnorePointer'd), so drive a REAL mouse: traditional highlight
      // strategy + hover the row + down/up with the SAME pointer (a tester.tap touch carries no
      // hover). 出口存在且有效:真鼠标配方——传统高亮策略+悬停行+同一指针 down/up。
      final clear = find.descendant(
        of: find.byType(AnRow),
        matching: find.byIcon(AnIcons.close),
      );
      expect(clear, findsOneWidget);
      WidgetsBinding.instance.focusManager.highlightStrategy =
          FocusHighlightStrategy.alwaysTraditional;
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(() => mouse.removePointer());
      await mouse.moveTo(tester.getCenter(find.byType(AnRow).first));
      await tester.pump();
      final p = tester.getCenter(clear);
      await mouse.moveTo(p);
      await tester.pump();
      await mouse.down(p);
      await mouse.up();
      await tester.pump();
      final el = tester.element(find.byType(StagePanel));
      final container = ProviderScope.containerOf(el, listen: false);
      final stage = container.read(stageDirectorProvider(_conv));
      expect(stage.subject, isNull);
      expect(stage.channels, isEmpty);
      expect(find.text(t.chat.stage.rowFailed), findsNothing);
    },
  );

  testWidgets(
    'G3: the settle breath reads «settling» (green), the poll hold reads «running» (blue) — never a fake Live',
    (tester) async {
      final repo = _repo();
      await tester.pumpWidget(_host(repo));
      await tester.pump();

      // toolClose lifecycle: ok close → the 1.8s breath is «settling». 停拍=「正在落定」。
      repo.emitFrame(_conv, _open('b1', 'create_function'));
      await tester.pump(const Duration(milliseconds: 600));
      repo.emitFrame(_conv, _close('b1'));
      repo.emitFrame(_conv, _open('r1', '', parent: 'b1', type: 'tool_result'));
      repo.emitFrame(_conv, _close('r1'));
      await tester.pump(const Duration(milliseconds: 200)); // inside the breath
      expect(find.text(t.chat.stage.rowSettling), findsOneWidget);
      expect(find.text(t.chat.stage.live), findsNothing);
      await tester.pump(const Duration(milliseconds: 2000)); // curtain 谢幕

      // poll lifecycle: the 202 receipt closed but the flowrun still runs → «running». poll=「运行中」。
      repo.emitFrame(_conv, _open('b2', 'trigger_workflow'));
      await tester.pump(const Duration(milliseconds: 600));
      repo.emitFrame(_conv, _close('b2'));
      repo.emitFrame(_conv, _open('r2', '', parent: 'b2', type: 'tool_result'));
      repo.emitFrame(_conv, _close('r2'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text(t.chat.stage.rowRunning), findsOneWidget);
      expect(find.text(t.chat.stage.live), findsNothing);
    },
  );

  testWidgets(
    'G7: a user-opened CHANNEL row survives its own itemId resolving (key migration for every view)',
    (tester) async {
      final repo = _repo();
      await tester.pumpWidget(_host(repo));
      await tester.pump();
      repo.emitFrame(_conv, _open('b0', 'create_function'));
      await tester.pump(const Duration(milliseconds: 600)); // b0 = subject
      repo.emitFrame(_conv, _open('b1', 'run_function'));
      await tester.pump(const Duration(milliseconds: 100)); // b1 = channel row
      await tester.tap(find.text('run_function')); // user opens it 用户手动展开
      await tester.pump();

      final el = tester.element(find.byType(StagePanel));
      final container = ProviderScope.containerOf(el, listen: false);
      expect(
        container.read(stageExpansionProvider(_conv)).contains('block:b1'),
        isTrue,
      );

      // The args close resolves the target id → the key migrates instead of the row snapping shut
      // in the user's face (the old migration ran for the SUBJECT only). 参流关解出 id→键迁移,
      // 行不再当面合上(旧迁移只管 subject)。
      repo.emitFrame(
        _conv,
        _close('b1', content: {'arguments': '{"functionId":"fn_9"}'}),
      );
      await tester.pump();
      final exp = container.read(stageExpansionProvider(_conv));
      expect(exp.contains('function:fn_9'), isTrue);
      expect(exp.contains('block:b1'), isFalse);
      await tester.pump(const Duration(seconds: 4)); // drain deadlines 排干闹钟
    },
  );

  testWidgets(
    'G7: a handoff A→B collapses A\'s auto-opened row (per-activity curtain, not subject-null only)',
    (tester) async {
      final repo = _repo();
      await tester.pumpWidget(_host(repo));
      await tester.pump();
      repo.emitFrame(_conv, _open('b1', 'create_function'));
      await tester.pump(const Duration(milliseconds: 600)); // auto-opened
      repo.emitFrame(_conv, _close('b1'));
      repo.emitFrame(_conv, _open('r1', '', parent: 'b1', type: 'tool_result'));
      repo.emitFrame(_conv, _close('r1')); // settled → breath 落定停拍
      repo.emitFrame(_conv, _open('b2', 'create_document'));
      await tester.pump(
        const Duration(milliseconds: 700),
      ); // b2 preempts the breath (handoff) 接场

      final el = tester.element(find.byType(StagePanel));
      final container = ProviderScope.containerOf(el, listen: false);
      final exp = container.read(stageExpansionProvider(_conv));
      // The old «subject became null» trigger missed every handoff — A's row stayed open forever
      // and the island became a wall of open stages. 旧触发只认 subject 归零,接场全漏收。
      expect(exp.contains('block:b1'), isFalse);
      expect(exp.contains('block:b2'), isTrue);
    },
  );

  testWidgets(
    'G7: auto-open never CLAIMS a row the user already opened — the curtain leaves it alone',
    (tester) async {
      final repo = _repo();
      await tester.pumpWidget(_host(repo));
      await tester.pump();
      repo.emitFrame(_conv, _open('b1', 'create_function'));
      await tester.pump(
        const Duration(milliseconds: 100),
      ); // debouncing → already a channel row 防抖中已有频道行
      await tester.tap(find.text('create_function')); // USER opens it 用户先开
      await tester.pump();
      await tester.pump(
        const Duration(milliseconds: 500),
      ); // staged — sees the row open, must NOT claim it 登台见已开,不认领

      repo.emitFrame(_conv, _close('b1'));
      repo.emitFrame(_conv, _open('r1', '', parent: 'b1', type: 'tool_result'));
      repo.emitFrame(_conv, _close('r1'));
      await tester.pump(
        const Duration(milliseconds: 2200),
      ); // breath + curtain 停拍+谢幕

      final el = tester.element(find.byType(StagePanel));
      final container = ProviderScope.containerOf(el, listen: false);
      // The user's row survives the curtain (the old claim put it on the collapse list, A2-8).
      // 用户的行躲过谢幕(旧认领会把它列进收起清单)。
      expect(
        container.read(stageExpansionProvider(_conv)).contains('block:b1'),
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
      d.onClearActivity('b1', t0.add(const Duration(seconds: 31)));
      expect(d.state.phase, StagePhase.idle);
    },
  );
}
