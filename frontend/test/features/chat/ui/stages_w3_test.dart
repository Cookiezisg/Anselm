import 'package:anselm/core/contract/conversation.dart';
import 'package:anselm/core/contract/entities/control.dart';
import 'package:anselm/core/contract/entities/trigger.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/sse/frame.dart';
import 'package:anselm/core/ui/ui.dart';
import 'package:anselm/features/chat/data/chat_fixtures.dart';
import 'package:anselm/features/chat/data/chat_providers.dart';
import 'package:anselm/features/chat/ui/stage_panel.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// W3 graph-and-discriminant stages over the full assembly: WORKFLOW (ops → canvas + counts + the
// latest-discriminant drawer), CONTROL (rungs slide in as branches close: port w400 / when CEL / emit
// grid / 透传 ghost / the catch-all 否则 badge + the 40% old ladder on edit), APPROVAL ({{ }} amber
// capsules + timeout prose + the unsent seal), TRIGGER (radar while waiting → the kind face → R-16
// settle facts from GET only). W3 四舞台集成电池。

const _conv = 'cv_1';
const _scope = StreamScope(kind: 'conversation', id: _conv);

FixtureChatRepository _repo() => FixtureChatRepository(conversations: [
      Conversation(
        id: _conv,
        title: 'w3',
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
Future<void> _stageAndSettleFrames(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 600));
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  setUpAll(() => LocaleSettings.setLocaleRaw('zh-CN'));

  testWidgets('WORKFLOW create: closed ops build the canvas + counts + the discriminant drawer',
      (tester) async {
    final repo = _repo();
    await tester.pumpWidget(_host(repo));
    await tester.pump();
    repo.emitFrame(_conv, _open('tc', 'create_workflow'));
    repo.emitFrame(
        _conv,
        _delta('tc',
            '{"name":"rollup","ops":[{"op":"add_node","node":{"id":"pull","kind":"action","ref":"fn_pull"}},'
            '{"op":"add_node","node":{"id":"sum","kind":"action","ref":"fn_sum","input":{"rows":"pull.result","limit":"input.cap"}}},'
            '{"op":"add_edge","edge":{"id":"e1","from":"pull","to":"sum"}},{"op":"add_no'));
    await _stageAndSettleFrames(tester);

    expect(find.byType(AnGraphCanvas), findsOneWidget);
    expect(find.textContaining('节点 2'), findsOneWidget); // only CLOSED ops count 只数闭合
    expect(find.textContaining('边 1'), findsOneWidget);
    expect(find.textContaining('最新判别式'), findsOneWidget);
    expect(find.byType(AnCelGrow), findsNWidgets(2)); // rows + limit 两条 CEL
    expect(find.text('pull.result'), findsOneWidget); // the reference capsule 引用药囊
  });

  testWidgets('CONTROL: rungs from closed branches — when CEL, emit grid, 透传 ghost, 否则 catch-all',
      (tester) async {
    final repo = _repo();
    repo.controls['ct_1'] = ControlLogic(
      id: 'ct_1',
      name: 'router',
      activeVersion: ControlVersion(
        id: 'cv_1',
        controlId: 'ct_1',
        version: 2,
        branches: const [Branch(port: 'legacy', when: 'input.total < 10')],
        createdAt: DateTime.utc(2026, 7, 1),
        updatedAt: DateTime.utc(2026, 7, 1),
      ),
      createdAt: DateTime.utc(2026, 7, 1),
      updatedAt: DateTime.utc(2026, 7, 1),
    );
    await tester.pumpWidget(_host(repo));
    await tester.pump();
    repo.emitFrame(_conv, _open('tc', 'edit_control'));
    repo.emitFrame(
        _conv,
        _delta('tc',
            '{"controlId":"ct_1","branches":['
            '{"port":"big","when":"input.total > 100","emit":{"tier":"input.total * 2"}},'
            '{"port":"small","when":"input.total > 0","emit":{}},'
            '{"port":"fallback","when":"true","emit":{}}],"inp'));
    await _stageAndSettleFrames(tester);

    expect(find.textContaining('改之前的梯'), findsOneWidget); // 40% old ladder 旧梯垫底
    expect(find.text('big'), findsOneWidget);
    expect(find.text('input.total'), findsWidgets); // reference capsules 引用药囊
    expect(find.textContaining('透传'), findsNWidgets(2)); // both empty emits ghost 两级空 emit 皆幽灵
    expect(find.text('否则'), findsOneWidget); // when:"true" badge, not code 兜底徽非代码
    expect(find.text('true'), findsNothing);
  });

  testWidgets('APPROVAL: {{ }} amber capsules + timeout prose + the unsent seal; settle = the preview',
      (tester) async {
    final repo = _repo();
    await tester.pumpWidget(_host(repo));
    await tester.pump();
    repo.emitFrame(_conv, _open('tc', 'create_approval'));
    repo.emitFrame(
        _conv,
        _delta('tc',
            '{"name":"big-spend","timeout":"30d","timeoutBehavior":"reject","allowReason":true,'
            '"template":"请审批 {{ input.amount }} 的支出,申请人 {{ input.who }}。'));
    await _stageAndSettleFrames(tester);

    expect(find.textContaining('预览 · 尚未寄出'), findsOneWidget);
    expect(find.text('input.amount'), findsOneWidget); // amber capsule 琥珀药囊
    expect(find.textContaining('30d 后自动拒绝'), findsOneWidget); // humane timeout 人话
    expect(find.textContaining('审批者可附理由'), findsOneWidget);
  });

  testWidgets('TRIGGER: radar while kind is unknown → the cron face; R-16 settle facts come from GET',
      (tester) async {
    final repo = _repo();
    repo.triggers['tg_1'] = TriggerEntity(
      id: 'tg_1',
      name: 'daily',
      kind: TriggerSource.cron,
      listening: true,
      refCount: 2,
      nextFireAt: DateTime.now().add(const Duration(hours: 2)),
      createdAt: DateTime.utc(2026, 7, 1),
      updatedAt: DateTime.utc(2026, 7, 1),
    );
    await tester.pumpWidget(_host(repo));
    await tester.pump();
    repo.emitFrame(_conv, _open('tc', 'create_trigger'));
    repo.emitFrame(_conv, _delta('tc', '{"name":"daily",'));
    await _stageAndSettleFrames(tester);
    expect(find.byType(AnRadarSweep), findsWidgets); // honest waiting 诚实等待

    repo.emitFrame(_conv, _delta('tc', '"kind":"cron","config":{"expression":"0 9 * * *"},'));
    await tester.pump(const Duration(milliseconds: 60));
    await tester.pump(const Duration(milliseconds: 60));
    expect(find.textContaining('0 9 * * *'), findsOneWidget); // the cron face 钟面

    repo.emitFrame(
        _conv,
        StreamEnvelope(
            seq: 2, scope: _scope, id: 'tc',
            frame: const FrameClose(status: 'completed', result: StreamNode(type: 'tool_call', content: {
              'name': 'create_trigger',
              'arguments': '{"name":"daily","kind":"cron","config":{"expression":"0 9 * * *"}}',
            }))));
    // The result carries the id → the settle reconciles via GET. 回执带 id→GET 对账。
    repo.emitFrame(
        _conv,
        const StreamEnvelope(
            seq: 3, scope: _scope, id: 'tr',
            frame: FrameOpen(parentId: 'tc', node: StreamNode(type: 'tool_result', content: {'content': '{"id":"tg_1","listening":false}'}))));
    repo.emitFrame(
        _conv,
        const StreamEnvelope(
            seq: 4, scope: _scope, id: 'tr',
            frame: FrameClose(status: 'completed', result: StreamNode(type: 'tool_result', content: {'content': '{"id":"tg_1","listening":false}'}))));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 200));

    // R-16: listening/refCount render the GET truth (listening:true, ref 2), NOT the frame's false.
    // R-16:渲 GET 真相(listening:true/ref 2),非帧里的 false。
    expect(find.text('监听中'), findsOneWidget);
    expect(find.textContaining('被 2 条 workflow 引用'), findsOneWidget);
    expect(find.textContaining('下次点火'), findsOneWidget);
  });
}
