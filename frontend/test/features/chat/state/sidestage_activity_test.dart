import 'package:anselm/core/contract/conversation.dart';
import 'package:anselm/core/contract/todo.dart';
import 'package:anselm/core/contract/touchpoint.dart';
import 'package:anselm/core/sse/frame.dart';
import 'package:anselm/features/chat/data/chat_demo_fixture.dart';
import 'package:anselm/features/chat/data/chat_fixtures.dart';
import 'package:anselm/features/chat/data/chat_providers.dart';
import 'package:anselm/features/chat/model/conversation_transcript.dart';
import 'package:anselm/features/chat/model/stage_director.dart';
import 'package:anselm/features/chat/state/sidestage_activity_provider.dart';
import 'package:anselm/features/chat/state/touchpoint_ledger.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Chat right island ON-DEMAND EXISTENCE (用户 0718-19): the sidestage earns a right island + its
// panel-right toggle ONLY when it has content — an empty conversation's button would be a door onto a
// tombstone. The activity flag mirrors the sidestage's OWN non-empty check (ledger / stage / todo /
// settled-subagent), and deliberately EXCLUDES a bare human gate (ask_user renders inline, not here).
// 有 activity 才有右岛;判定源=侧幕自己的数据源、逐条镜像非空判断;裸人闸排除(内联渲染)。

final _now = DateTime.utc(2026, 7, 19, 12);

Touchpoint _tp(String id) => Touchpoint(
      id: id,
      conversationId: 'cv',
      itemKind: 'function',
      itemId: 'fn_1',
      verb: TouchpointVerb.edited,
      count: 1,
      firstAt: _now,
      lastAt: _now,
    );

const _view = StageActivityView(
    blockId: 'b1', toolName: 'run_function', kind: 'function', live: true, failed: false, unread: 0);

const _scope = StreamScope(kind: 'conversation', id: 'cv');
StreamEnvelope _open(String id, String tool) => StreamEnvelope(
    seq: 1,
    scope: _scope,
    id: id,
    frame: FrameOpen(node: StreamNode(type: 'tool_call', content: {'name': tool})));

class _Probe extends ConsumerWidget {
  const _Probe(this.cv);
  final String cv;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Text(
        ref.watch(sidestageActivityProvider(cv)) ? 'YES' : 'NO',
        textDirection: TextDirection.ltr,
      );
}

Widget _host(FixtureChatRepository repo, String cv) => ProviderScope(
      overrides: [chatRepositoryProvider.overrideWithValue(repo)],
      child: _Probe(cv),
    );

FixtureChatRepository _repo() => FixtureChatRepository(conversations: [
      Conversation(
        id: 'cv',
        title: 'demand',
        createdAt: _now,
        updatedAt: _now,
        lastMessageAt: _now,
      ),
    ]);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('sidestageHasContent (pure)', () {
    const empty = TouchpointLedgerState(hydrated: true);
    final tx = ConversationTranscript('cv');

    bool call({
      TouchpointLedgerState? ledger,
      StageState? stage,
      Map<String, ConversationTodos>? rundown,
    }) =>
        sidestageHasContent(
          ledger: ledger ?? empty,
          stage: stage ?? const StageState(phase: StagePhase.idle),
          rundown: rundown ?? const {},
          transcript: tx,
        );

    test('all empty → false (no content → no door)', () => expect(call(), isFalse));

    test('a ledger entity → true', () {
      final entity = CastEntity(kind: 'function', key: 'fn_1', byVerb: {TouchpointVerb.edited: _tp('tp1')});
      expect(call(ledger: TouchpointLedgerState(entities: [entity], hydrated: true)), isTrue);
    });

    test('a FAILED ledger fetch → true (the error+retry face is content, not blank)',
        () => expect(call(ledger: const TouchpointLedgerState(failed: true)), isTrue));

    test('a live/held stage subject → true',
        () => expect(call(stage: const StageState(phase: StagePhase.following, subject: _view)), isTrue));

    test('a live channel → true',
        () => expect(call(stage: const StageState(phase: StagePhase.idle, channels: [_view])), isTrue));

    test('a pinned todo board → true', () {
      expect(
          call(rundown: const {
            '': ConversationTodos(conversationId: 'cv', todos: [TodoEntry(content: 'x')]),
          }),
          isTrue);
    });

    test('an empty todo board → false (no todos)', () {
      expect(call(rundown: const {'': ConversationTodos(conversationId: 'cv')}), isFalse);
    });

    test('a BARE human gate → FALSE (ask_user renders inline, never in the sidestage)',
        () => expect(call(stage: const StageState(phase: StagePhase.idle, gateWaiting: true)), isFalse));
  });

  testWidgets('a fresh conversation has NO activity; a touchpoint arrival flips it to YES', (tester) async {
    final repo = _repo();
    await tester.pumpWidget(_host(repo, 'cv'));
    await tester.pump(); // build
    await tester.pump(const Duration(milliseconds: 50)); // ledger + stream hydrate (empty)
    expect(find.text('NO'), findsOneWidget);

    repo.touch(_tp('tp1')); // a durable touchpoint signal (a tool touched fn_1)
    await tester.pump();
    await tester.pump();
    expect(find.text('YES'), findsOneWidget);
  });

  testWidgets('a stage-worthy tool_call flips it to YES after the entrance debounce', (tester) async {
    final repo = _repo();
    await tester.pumpWidget(_host(repo, 'cv'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('NO'), findsOneWidget);

    repo.emitFrame('cv', _open('tc', 'create_function')); // stage-worthy, stays open
    await tester.pump(const Duration(milliseconds: 600)); // past the 500ms entrance debounce → staged
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('YES'), findsOneWidget);
  });

  testWidgets('a plain Q&A conversation (no tools) stays NO', (tester) async {
    // The demo's plain recents have messages but no touchpoints/tools → no sidestage content. 纯问答无活动。
    final repo = demoChatRepository();
    // A seeded plain conversation id (Q&A, no tool calls). 纯问答对话。
    await tester.pumpWidget(_host(repo, 'cv_p01'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    expect(find.text('NO'), findsOneWidget);
  });

  testWidgets('the big rebuild conversation (cv_sync, seeded touchpoints) is YES', (tester) async {
    final repo = demoChatRepository();
    await tester.pumpWidget(_host(repo, 'cv_sync'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120)); // ledger hydrate resolves
    expect(find.text('YES'), findsOneWidget);
  });
}
