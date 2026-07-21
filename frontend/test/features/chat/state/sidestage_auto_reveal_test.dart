import 'package:anselm/core/settings/app_prefs_providers.dart';
import 'package:anselm/core/settings/follow_mode.dart';
import 'package:anselm/core/shell/oceans.dart';
import 'package:anselm/core/shell/right_panel.dart';
import 'package:anselm/core/sse/frame.dart';
import 'package:anselm/features/chat/data/chat_fixtures.dart';
import 'package:anselm/features/chat/data/chat_providers.dart';
import 'package:anselm/features/chat/state/sidestage_activity_provider.dart';
import 'package:anselm/features/chat/state/sidestage_auto_reveal.dart';
import 'package:anselm/features/chat/state/stage_director_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 缺口A (用户 0719 改判) — the sidestage AUTO-REVEAL: under a following FollowMode a conversation's FIRST staged
// activity auto-opens the chat right island (which defaults collapsed). `never` never opens; a manual close is
// respected for the rest of the session. The director already gates STAGING by mode, so the reveal rides that
// gate (watches stageOpen false→true). 首个登台自动开(默认收起的)岛;never 不开;手动关过不弹。

const _conv = 'cv_1';
const _scope = StreamScope(kind: 'conversation', id: _conv);

StreamEnvelope _open(String id, String tool) => StreamEnvelope(
  seq: 1,
  scope: _scope,
  id: id,
  frame: FrameOpen(
    node: StreamNode(type: 'tool_call', content: {'name': tool}),
  ),
);

// A container on the CHAT ocean (whose right-island bucket defaults COLLAPSED), the reveal watcher mounted so
// its two listeners run whether the island is open or closed. chat 海洋容器(桶默认收起) + 挂载揭示监听。
({ProviderContainer c, FixtureChatRepository repo}) _harness({
  FollowMode mode = FollowMode.always,
  bool preMarkedClosed = false,
}) {
  final repo = FixtureChatRepository();
  final c = ProviderContainer(
    overrides: [chatRepositoryProvider.overrideWithValue(repo)],
  );
  addTearDown(c.dispose);
  c.read(selectedOceanProvider.notifier).select(OceanKind.chat);
  if (mode != FollowMode.always) c.read(followModeProvider.notifier).set(mode);
  if (preMarkedClosed) {
    c.read(sidestageManualCloseProvider.notifier).mark(_conv);
  }
  c.listen(
    sidestageAutoRevealProvider(_conv),
    (_, _) {},
  ); // mount the reveal (+ its director / right-panel deps)
  c.listen(
    sidestageActivityProvider(_conv),
    (_, _) {},
  ); // keep the activity flag warm (manual-close gate reads it)
  return (c: c, repo: repo);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'always: the first staged activity opens the default-collapsed chat island',
    (tester) async {
      final h = _harness();
      await tester.pump();
      expect(
        h.c.read(rightPanelCollapsedProvider),
        isTrue,
        reason: 'chat bucket defaults collapsed',
      );

      h.repo.emitFrame(
        _conv,
        _open('b1', 'create_function'),
      ); // stage-worthy, stays open
      await tester.pump(
        const Duration(milliseconds: 600),
      ); // past the 500ms entrance debounce → staged
      await tester.pump();
      expect(h.c.read(stageDirectorProvider(_conv)).stageOpen, isTrue);
      expect(
        h.c.read(rightPanelCollapsedProvider),
        isFalse,
        reason: '缺口A: first activity auto-opened the island',
      );
    },
  );

  testWidgets(
    'cold start catch-up: an already-staged first activity opens when the shell watcher mounts',
    (tester) async {
      final repo = FixtureChatRepository();
      final c = ProviderContainer(
        overrides: [chatRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(c.dispose);
      c.read(selectedOceanProvider.notifier).select(OceanKind.chat);
      // Reproduce the startup race: replay reaches the director before AppShell mounts its reveal watcher.
      // 复现冷启动竞态：回放先抵导演器，AppShell 的揭示监听后挂。
      c.listen(stageDirectorProvider(_conv), (_, _) {});
      await tester.pump();
      repo.emitFrame(_conv, _open('b1', 'create_function'));
      await tester.pump(const Duration(milliseconds: 600));
      expect(c.read(stageDirectorProvider(_conv)).stageOpen, isTrue);
      expect(c.read(rightPanelCollapsedProvider), isTrue);

      c.listen(sidestageAutoRevealProvider(_conv), (_, _) {});
      await tester.pump();
      expect(
        c.read(rightPanelCollapsedProvider),
        isFalse,
        reason:
            'the listener reconciles an already-true stageOpen instead of missing the first entrance',
      );
    },
  );

  testWidgets('never: a staged activity never opens the island', (
    tester,
  ) async {
    final h = _harness(mode: FollowMode.never);
    await tester.pump();

    h.repo.emitFrame(_conv, _open('b1', 'create_function'));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();
    // never gates STAGING itself (the director never stages), so the island stays collapsed. 从不档:不登台不开岛。
    expect(h.c.read(stageDirectorProvider(_conv)).stageOpen, isFalse);
    expect(h.c.read(rightPanelCollapsedProvider), isTrue);
  });

  testWidgets(
    'respects a manual close: a pre-marked conversation stays collapsed even when it stages',
    (tester) async {
      final h = _harness(preMarkedClosed: true);
      await tester.pump();

      h.repo.emitFrame(_conv, _open('b1', 'create_function'));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump();
      expect(
        h.c.read(stageDirectorProvider(_conv)).stageOpen,
        isTrue,
        reason: 'it DID stage',
      );
      expect(
        h.c.read(rightPanelCollapsedProvider),
        isTrue,
        reason: '缺口A: the manual close this session is respected — no auto-pop',
      );
    },
  );

  testWidgets(
    'records a manual close when the user collapses a visible sidestage',
    (tester) async {
      final h = _harness();
      await tester.pump();

      h.repo.emitFrame(_conv, _open('b1', 'create_function'));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump();
      expect(
        h.c.read(rightPanelCollapsedProvider),
        isFalse,
      ); // auto-opened, panel now visible
      expect(
        h.c.read(sidestageManualCloseProvider).contains(_conv),
        isFalse,
      ); // not yet marked

      // The user closes the visible panel (✕ / toggle) → recorded so it never auto-pops again this session.
      // 用户关掉可见面板→记为手动关,本会话不再自动弹。
      h.c.read(rightPanelCollapsedProvider.notifier).set(true);
      await tester.pump();
      expect(h.c.read(sidestageManualCloseProvider).contains(_conv), isTrue);
    },
  );
}
