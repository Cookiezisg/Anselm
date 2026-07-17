import 'package:anselm/core/contract/conversation.dart';
import 'package:anselm/core/contract/touchpoint.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/sse/frame.dart';
import 'package:anselm/core/ui/ui.dart';
import 'package:anselm/features/chat/data/chat_fixtures.dart';
import 'package:anselm/features/chat/data/chat_providers.dart';
import 'package:anselm/features/chat/state/touchpoint_ledger.dart';
import 'package:anselm/features/chat/ui/stage_panel.dart';
import 'package:anselm/features/chat/ui/stages/function_stage.dart';
import 'package:anselm/features/chat/ui/stages/handler_stage.dart';
import 'package:anselm/features/chat/ui/stages/scene_from_truth.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// WRK-070 §A#1 — the「假想框律」geometry locks. A REAL frame (AnCodeEditor …) fills the body width at X=0
// and never indents twice; ICON-led rows share ONE gutter (icon 对 icon, 文字对文字); BARE text lives in
// the imaginary frame (X=8, the AnKv-key line). Each test pins one of these so a future re-indent regresses
// loudly. 假想框律几何锁:真框满宽贴 X=0、icon 沟对齐、裸文字归假想框(X=8,KV 键线)。

const _conv = 'cv_1';
const _scope = StreamScope(kind: 'conversation', id: _conv);

FixtureChatRepository _repo() => FixtureChatRepository(conversations: [
      Conversation(
        id: _conv,
        title: 'align',
        createdAt: DateTime.utc(2026, 7, 17),
        updatedAt: DateTime.utc(2026, 7, 17),
        lastMessageAt: DateTime.utc(2026, 7, 17),
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

StreamEnvelope _open(String id, String tool, {String? parent, String type = 'tool_call', Map<String, dynamic>? extra}) =>
    StreamEnvelope(
        seq: 1, scope: _scope, id: id,
        frame: FrameOpen(parentId: parent, node: StreamNode(type: type, content: {'name': tool, ...?extra})));
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

Future<void> _settleFrames(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 200));
  await tester.pump(const Duration(milliseconds: 200));
}

void main() {
  setUpAll(() => LocaleSettings.setLocaleRaw('zh-CN'));

  testWidgets('HANDLER: the settled code window is FLUSH with the body left — no s12 re-indent (真框满宽)',
      (tester) async {
    final repo = _repo();
    await tester.pumpWidget(_host(repo));
    await tester.pump();
    const args = '{"ops":[{"op":"set_init","initBody":"def init(self):\\n    pass\\n"}]}';
    repo.emitFrame(_conv, _open('tc', 'create_handler'));
    repo.emitFrame(_conv, _delta('tc', args));
    await _stageFrames(tester);
    repo.emitFrame(_conv, _close('tc', args));
    await _settleFrames(tester);

    expect(find.byType(HandlerStageBody), findsOneWidget);
    final bodyLeft = tester.getTopLeft(find.byType(HandlerStageBody)).dx;
    final codeLeft = tester.getTopLeft(find.byType(AnCodeEditor).first).dx;
    // The imaginary-frame law: a real frame (AnCodeEditor) fills the body width at X=0. The old
    // EdgeInsets.only(left: s12) pushed it 12px right of the body left. 真框满宽贴 X=0(旧 s12 退格已删)。
    expect(codeLeft, moreOrLessEquals(bodyLeft, epsilon: 0.5),
        reason: 'handler code window flush with the body left (was +s12)');
  });

  testWidgets('FUNCTION: the settled code window is FLUSH too — the reference摆法 handler now matches',
      (tester) async {
    final repo = _repo();
    await tester.pumpWidget(_host(repo));
    await tester.pump();
    const args =
        '{"ops":[{"op":"set_code","code":"def sync():\\n    return 1\\n"}]}';
    repo.emitFrame(_conv, _open('tc', 'create_function'));
    repo.emitFrame(_conv, _delta('tc', args));
    await _stageFrames(tester);
    repo.emitFrame(_conv, _close('tc', args));
    await _settleFrames(tester);

    expect(find.byType(FunctionStageBody), findsOneWidget);
    final bodyLeft = tester.getTopLeft(find.byType(FunctionStageBody)).dx;
    final codeLeft = tester.getTopLeft(find.byType(AnCodeEditor).first).dx;
    // Function was already flush — it is the摆法 handler was fixed to match. 两座同原语同摆法。
    expect(codeLeft, moreOrLessEquals(bodyLeft, epsilon: 0.5),
        reason: 'function code window flush with the body left (the reference)');
  });

  testWidgets('MCP: the tool-row text starts on the SAME column as the nameplate name (icon 沟文法)',
      (tester) async {
    final repo = _repo();
    await tester.pumpWidget(_host(repo));
    await tester.pump();
    repo.emitFrame(_conv, _open('tc', 'install_mcp_server'));
    repo.emitFrame(_conv, _delta('tc', '{"name":"github","env":{"GITHUB_TOKEN":"x"}}'));
    await _stageFrames(tester);
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
    await _settleFrames(tester);

    // Nameplate name (iconSm glyph) and a tool name (iconXs glyph) BOTH sit in the fixed iconSm gutter +
    // AnGap.inline, so their text lands on ONE column whatever the glyph size. 沟格统一→文字同列。
    // ('github' also names the accordion row header above — the nameplate is the LAST one, in the body.)
    final nameLeft = tester.getTopLeft(find.text('github').last).dx;
    final toolLeft = tester.getTopLeft(find.text('create_issue')).dx;
    expect(toolLeft, moreOrLessEquals(nameLeft, epsilon: 0.5),
        reason: 'mcp tool text starts on the nameplate name column (icon 沟文法)');
  });

  testWidgets('SUBAGENT: a tail row glyph is vertically CENTRED on its text first line (±3px)',
      (tester) async {
    final repo = _repo();
    await tester.pumpWidget(_host(repo));
    await tester.pump();
    repo.emitFrame(_conv, _open('sa1', 'Subagent'));
    repo.emitFrame(_conv, _delta('sa1', '{"description":"审计执行日志"}'));
    // A nested trajectory: a reasoning block (the tail row we measure) + a later tool_call (the current
    // action, so the reasoning line only appears in the tail — never twice). 嵌套轨迹:reasoning 只现于尾行。
    repo.emitFrame(_conv, _open('m1', '', parent: 'sa1', type: 'message', extra: {'role': 'assistant'}));
    repo.emitFrame(_conv, _open('r1', '', parent: 'm1', type: 'reasoning'));
    repo.emitFrame(_conv, _delta('r1', '先拉最近十条失败记录'));
    repo.emitFrame(_conv, _open('t1', 'Bash', parent: 'm1', type: 'tool_call'));
    await _stageFrames(tester);

    final icon = tester.getRect(find.byIcon(AnIcons.reasoning));
    final text = tester.getRect(find.text('先拉最近十条失败记录'));
    // CrossAxisAlignment.center in the gutter row → the glyph centres on the (single) text line; the old
    // CrossAxisAlignment.start hung the iconXs above the text. 沟行 center→字形与首行同心(旧 start 吊高)。
    expect((icon.center.dy - text.center.dy).abs(), lessThanOrEqualTo(3),
        reason: 'subagent tail glyph centres on its text first line (±3px)');
  });

  testWidgets('SETTLED tombstone: the red line starts on the AnKv-key line (X=8, 假想框律)',
      (tester) async {
    final now = DateTime.utc(2026, 7, 17, 12);
    final entity = CastEntity(kind: 'function', key: 'fn_gone', byVerb: {
      TouchpointVerb.deleted: Touchpoint(
        id: 'tp_1',
        conversationId: _conv,
        itemKind: 'function',
        itemId: 'fn_gone',
        verb: TouchpointVerb.deleted,
        count: 1,
        firstAt: now,
        lastAt: now,
      ),
    });
    await tester.pumpWidget(ProviderScope(
      child: TranslationProvider(
        child: MaterialApp(
          theme: AnTheme.light(),
          home: Scaffold(
            body: SizedBox(
              width: 360,
              child: SettledBody(conversationId: _conv, entity: entity, tombstoned: true),
            ),
          ),
        ),
      ),
    ));
    await tester.pump();

    // The AnKv key ('id') sits in the family h:s8 inset; the tombstone (bare text) now wears the imaginary
    // frame's own s8, so both left edges land on ONE line — the red line no longer顶格. KV 键与墓碑同起点。
    final keyLeft = tester.getTopLeft(find.text('id')).dx;
    final tombLeft = tester.getTopLeft(find.text(t.feedback.cast.tombstone)).dx;
    expect(tombLeft, moreOrLessEquals(keyLeft, epsilon: 0.5),
        reason: 'tombstone line aligns with the AnKv key (X=8), not顶格 at X=0');
  });
}
