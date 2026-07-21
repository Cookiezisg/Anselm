import 'package:anselm/core/contract/conversation.dart';
import 'package:anselm/core/contract/entities/document.dart';
import 'package:anselm/core/contract/entities/function.dart';
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

// W2 flagship stages over the full assembly (registry + truth providers + fixture): the FUNCTION stage
// (edit → R-5 old-truth stratum + neutral op ticker + whole-line live window → settle editor + honest
// +n/−m diff badge) and the DOCUMENT stage (edit → prefix fast-forward against the baseline → spine +
// divergence label → settle whole-replace badge; R-9 metadata-only edit never fakes a prose curtain).
// W2 双旗舰集成电池:function(R-5 地层/中性 ticker/活窗→落定编辑器+真 diff 徽)+document(基线前缀快进/
// 书脊/分叉标→落定全量替换徽;R-9 无 content 键不开散文幕)。

const _conv = 'cv_1';
const _scope = StreamScope(kind: 'conversation', id: _conv);

FixtureChatRepository _repo() => FixtureChatRepository(
  conversations: [
    Conversation(
      id: _conv,
      title: 'w2',
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
          width: 380,
          height: 720,
          child: StagePanel(conversationId: _conv),
        ),
      ),
    ),
  ),
);

StreamEnvelope _open(String id, String tool) => StreamEnvelope(
  seq: 1,
  scope: _scope,
  id: id,
  frame: FrameOpen(
    node: StreamNode(type: 'tool_call', content: {'name': tool}),
  ),
);
StreamEnvelope _delta(String id, String chunk) => StreamEnvelope(
  seq: 0,
  scope: _scope,
  id: id,
  frame: FrameDelta(chunk: chunk),
);
StreamEnvelope _close(String id, String args, {String? entityName}) =>
    StreamEnvelope(
      seq: 2,
      scope: _scope,
      id: id,
      frame: FrameClose(
        status: 'completed',
        result: StreamNode(
          type: 'tool_call',
          content: {'name': '', 'arguments': args, 'entityName': ?entityName},
        ),
      ),
    );
StreamEnvelope _resultOpen(String id, String parent) => StreamEnvelope(
  seq: 3,
  scope: _scope,
  id: id,
  frame: FrameOpen(
    parentId: parent,
    node: const StreamNode(type: 'tool_result', content: {'content': ''}),
  ),
);
StreamEnvelope _resultClose(String id) => StreamEnvelope(
  seq: 4,
  scope: _scope,
  id: id,
  frame: const FrameClose(
    status: 'completed',
    result: StreamNode(type: 'tool_result', content: {'content': 'ok'}),
  ),
);

void main() {
  setUpAll(() => LocaleSettings.setLocaleRaw('zh-CN'));

  testWidgets(
    'FUNCTION edit: R-5 stratum + neutral op ticker + whole-line window → settle editor + real diff badge',
    (tester) async {
      final repo = _repo();
      repo.functions['fn_1'] = FunctionEntity(
        id: 'fn_1',
        name: 'sync_inventory',
        activeVersion: FunctionVersion(
          id: 'fv_3',
          functionId: 'fn_1',
          version: 3,
          code: 'def sync():\n    return 1\n',
          createdAt: DateTime.utc(2026, 7, 1),
          updatedAt: DateTime.utc(2026, 7, 1),
        ),
        createdAt: DateTime.utc(2026, 7, 1),
        updatedAt: DateTime.utc(2026, 7, 1),
      );
      await tester.pumpWidget(_host(repo));
      await tester.pump();

      repo.emitFrame(_conv, _open('tc', 'edit_function'));
      repo.emitFrame(
        _conv,
        _delta(
          'tc',
          '{"functionId":"fn_1","ops":[{"op":"set_meta","description":"retry"},{"op":"set_code","code":"def sync():\\n    for a in range(3):\\n        run(a',
        ),
      );
      await tester.pump(const Duration(milliseconds: 600)); // stage entrance 登台
      await tester.pump(
        const Duration(milliseconds: 400),
      ); // truth fetch + reveal 真相+揭示
      await tester.pump(const Duration(milliseconds: 200)); // line fades 行淡入

      expect(find.byType(AnLayerDiff), findsOneWidget); // R-5 stratum 地层
      expect(find.textContaining('v3'), findsOneWidget); // provenance tag 出处签
      expect(find.text('set_meta'), findsOneWidget); // neutral ticker 中性芯片
      // 批2: the live face IS the editor (one shell, two faces) — full content incl. the streaming
      // tail is shown honestly (the old whole-line hold was retired with AnLiveCodeWindow).
      // 批2:live 脸即编辑器(两脸一壳)——含流式尾行的全量内容诚实可见(整行按住随旧窗退役)。
      final liveEditor = tester.widget<AnCodeEditor>(find.byType(AnCodeEditor));
      expect(liveEditor.live, isTrue);
      expect(
        find.textContaining('for a in range(3):'),
        findsOneWidget,
      ); // content present 内容在场

      const finalArgs =
          '{"functionId":"fn_1","ops":[{"op":"set_meta","description":"retry"},{"op":"set_code","code":"def sync():\\n    for a in range(3):\\n        run(a)\\n    return 3\\n"}]}';
      repo.emitFrame(
        _conv,
        _close('tc', finalArgs, entityName: 'sync_inventory'),
      );
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));

      expect(
        find.byType(AnLayerDiff),
        findsNothing,
      ); // the diff badge takes over 地层退场
      expect(
        find.byType(AnCodeEditor),
        findsOneWidget,
      ); // highlighted settle 高亮落定
      // Real diff vs the fetched before: shared def+trailing lines, −1 old return, +3 new lines —
      // now leading stats on the ONE bar (批5 A-043,AnStatBar 渲 rich text). 真 diff 计数进当家条。
      expect(find.textContaining('+3', findRichText: true), findsOneWidget);
      expect(find.textContaining('−1', findRichText: true), findsOneWidget);
    },
  );

  testWidgets(
    'DOCUMENT edit: prefix fast-forward against the baseline → divergence label + spine; settle badge',
    (tester) async {
      final repo = _repo();
      repo.documents['doc_1'] = DocumentNode(
        id: 'doc_1',
        name: 'runbook',
        content: '# Runbook\n\nstep one\n',
        path: '/ops/runbook',
        sizeBytes: 21,
        createdAt: DateTime.utc(2026, 7, 1),
        updatedAt: DateTime.utc(2026, 7, 1),
      );
      await tester.pumpWidget(_host(repo));
      await tester.pump();

      repo.emitFrame(_conv, _open('tc', 'edit_document'));
      repo.emitFrame(
        _conv,
        _delta('tc', '{"id":"doc_1","content":"# Runbook\\n\\nstep'),
      );
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 400));

      // Still inside the common prefix → fast-forwarding. 仍在公共前缀内→快进中。
      expect(find.text(t.chat.stage.fastForwarding), findsOneWidget);
      expect(find.byType(AnMinimapSpine), findsOneWidget);

      // Diverge: the new text departs from the baseline. 分叉。
      repo.emitFrame(_conv, _delta('tc', ' ONE (revised)\\nstep two\\n'));
      await tester.pump(const Duration(milliseconds: 50)); // coalescer notify 帧
      await tester.pump(const Duration(milliseconds: 50)); // rebuild 帧
      expect(
        find.textContaining('已快进'),
        findsOneWidget,
      ); // prefixKept label 前缀标

      repo.emitFrame(
        _conv,
        _close(
          'tc',
          '{"id":"doc_1","content":"# Runbook\\n\\nstep ONE (revised)\\nstep two\\n"}',
          entityName: 'runbook',
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));

      expect(
        find.textContaining('全量替换'),
        findsOneWidget,
      ); // the honest badge 诚实徽
    },
  );

  testWidgets(
    'DOCUMENT R-9: an edit whose args never open `content` never fakes a prose curtain',
    (tester) async {
      final repo = _repo();
      repo.documents['doc_1'] = DocumentNode(
        id: 'doc_1',
        name: 'runbook',
        content: '# Runbook\n',
        createdAt: DateTime.utc(2026, 7, 1),
        updatedAt: DateTime.utc(2026, 7, 1),
      );
      await tester.pumpWidget(_host(repo));
      await tester.pump();

      repo.emitFrame(_conv, _open('tc', 'edit_document'));
      repo.emitFrame(_conv, _delta('tc', '{"id":"doc_1","name":"runbook-v2"}'));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 300));
      repo.emitFrame(
        _conv,
        _close(
          'tc',
          '{"id":"doc_1","name":"runbook-v2"}',
          entityName: 'runbook-v2',
        ),
      );
      repo.emitFrame(_conv, _resultOpen('tr', 'tc'));
      repo.emitFrame(_conv, _resultClose('tr'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.text(t.chat.stage.proseUntouched),
        findsOneWidget,
      ); // metadata-only 元数据小卡
      expect(
        find.textContaining('全量替换'),
        findsNothing,
      ); // no fake replace badge 不伪造替换徽
    },
  );
}
