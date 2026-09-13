import 'package:anselm/core/contract/conversation.dart';
import 'package:anselm/core/contract/interaction.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/entity/mention_source.dart';
import 'package:anselm/core/ui/ui.dart';
import 'package:anselm/core/sse/frame.dart';
import 'package:anselm/features/chat/data/chat_fixtures.dart';
import 'package:anselm/features/chat/data/chat_providers.dart';
import 'package:anselm/features/chat/ui/chat_toc.dart';
import 'package:anselm/features/chat/ui/stage_panel.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// The leftover-clearing batteries (W7 追加): [[id]] pills resolve real names through the ONE
// MentionSource seam, a delegate's streaming tool progress rolls an inline terminal, and pending
// gates ride the 场次条's first page top (the fixture mirrors the broker rule).
// 清账电池:[[id]] 药丸经唯一 MentionSource 缝解真名、分身工具 progress 内联终端滚动、待决人闸骑场次条首页顶。

const _conv = 'cv_1';
const _scope = StreamScope(kind: 'conversation', id: _conv);

class _StubMentions extends MentionSource {
  @override
  Future<List<MentionCandidate>> search(String query) async => const [];

  @override
  Future<Map<String, String>> resolveNames(List<String> ids) async => {
    for (final id in ids)
      if (id == 'fn_1') id: 'sync_inventory',
  };
}

FixtureChatRepository _repo() => FixtureChatRepository(
  conversations: [
    Conversation(
      id: _conv,
      title: 'w7l',
      createdAt: DateTime.utc(2026, 7, 8),
      updatedAt: DateTime.utc(2026, 7, 8),
      lastMessageAt: DateTime.utc(2026, 7, 8),
    ),
  ],
);

Widget _host(FixtureChatRepository repo, Widget child) => ProviderScope(
  overrides: [
    chatRepositoryProvider.overrideWithValue(repo),
    mentionSourceProvider.overrideWithValue(_StubMentions()),
  ],
  child: TranslationProvider(
    child: MaterialApp(
      theme: AnTheme.light(),
      home: Scaffold(body: SizedBox(width: 400, height: 760, child: child)),
    ),
  ),
);

void main() {
  setUpAll(() => LocaleSettings.setLocaleRaw('zh-CN'));

  testWidgets(
    '[[id]] pills resolve display names through the MentionSource seam',
    (tester) async {
      final repo = _repo();
      await tester.pumpWidget(_host(repo, StagePanel(conversationId: _conv)));
      await tester.pump();
      repo.emitFrame(
        _conv,
        const StreamEnvelope(
          seq: 1,
          scope: _scope,
          id: 'tc',
          frame: FrameOpen(
            node: StreamNode(
              type: 'tool_call',
              content: {'name': 'create_document'},
            ),
          ),
        ),
      );
      repo.emitFrame(
        _conv,
        const StreamEnvelope(
          seq: 0,
          scope: _scope,
          id: 'tc',
          frame: FrameDelta(
            chunk:
                '{"name":"notes.md","content":"排查记录,详见 [[fn_1]] 与 [[doc_x]]。',
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('sync_inventory'), findsOneWidget); // resolved 解出真名
      expect(
        find.text('doc_x'),
        findsOneWidget,
      ); // unresolved falls back to the id 解不出回落 id
    },
  );

  testWidgets(
    '场次条: pending gates ride the first page top (fixture mirrors the broker rule)',
    (tester) async {
      final repo = _repo();
      repo.interactions[_conv] = const [
        Interaction(
          toolCallId: 'tc_gate',
          kind: InteractionKind.danger,
          tool: 'delete_function',
          resolved: false,
        ),
      ];
      await tester.pumpWidget(
        _host(repo, Center(child: TranscriptToc(conversationId: _conv))),
      );
      await tester.pump();
      await tester.tap(find.byType(AnButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        find.text(t.chat.toc.gates),
        findsOneWidget,
      ); // the amber section 琥珀节
      expect(find.text('delete_function'), findsOneWidget);
    },
  );
}
