import 'package:anselm/core/contract/entities/document.dart';
import 'package:anselm/core/contract/entities/skill.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/entity/mention_source.dart';
import 'package:anselm/core/notice/notice_center.dart';
import 'package:anselm/core/router/navigation.dart';
import 'package:anselm/features/library/data/library_fixtures.dart';
import 'package:anselm/features/library/data/library_repository.dart';
import 'package:anselm/features/library/state/library_state.dart';
import 'package:anselm/features/library/ui/library_ocean.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:super_text_layout/super_text_layout.dart' show BlinkController;

// WRK-083 L17 — a page that no longer exists must not keep being presented.
//
// The ocean used to keep a deleted page fully alive on screen: title, editable body, live properties —
// and every keystroke 404'd on autosave behind a bare 「操作失败」. Real machine: delete the open page out
// of band, keep typing, watch the words go nowhere.
//
// The mechanism EXISTED for the one path the user drives themselves — the rail's own delete calls
// `_clearIfSelected` — but nothing reconciled the paths that matter most here: an agent's
// `delete_document`, another view, a 410 recovery. And it is blind, even from the rail, to the deletion
// of an ANCESTOR: `Delete` soft-deletes the whole subtree but publishes ONE `deleted` frame naming only
// the root, so an open child dies with no event that mentions it. That is why the fix reconciles against
// the TREE rather than against a delete event — a row that left the tree is gone, however it went.
//
// Three cells: the verdict, the ancestor case (which the rail's own path also misses), and the one
// dangerous false positive — evicting a page that was merely never seen yet.
//
// WRK-083 L17——已不存在的页面不该继续被呈现。
//
// 海洋原本让被删的页面在屏幕上完好如初:标题、可编辑正文、活属性——而每一次键入的自动保存都 404,背后只有一句光秃秃的
// 「操作失败」。真机:带外删掉打开着的页,继续打字,看着字消失在无处。
//
// 机制**本来就有**,但只接了用户自己驱动的那一条路(rail 删除调 `_clearIfSelected`);最要紧的几条从没走到它——agent 的
// `delete_document`、另一个视图、410 恢复。而且**连 rail 自己**也看不见**祖先**被删:`Delete` 软删整棵子树却只发一条
// 只点根名字的 `deleted` 帧,打开着的子页无声而亡。故修复与**树**对账、不与删除事件对账——行离开了树就是没了,不论怎么没的。
//
// 三格:判决本身、祖先那一格(rail 自己那条路同样漏)、以及唯一危险的误判方向——把一个只是「还没见过」的页面踢掉。

DocumentNode _doc(String id, String? parent, String name, int pos) =>
    DocumentNode(
      id: id,
      parentId: parent,
      name: name,
      description: '',
      content: '',
      tags: const [],
      position: pos,
      path: '/$name',
      sizeBytes: 0,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    );

FixtureLibraryRepository _repo() => FixtureLibraryRepository(
  documents: [
    _doc('doc_a', null, 'Getting Started', 0),
    _doc('doc_b', 'doc_a', 'Setup', 0),
    _doc('doc_d', null, 'Playbooks', 1),
  ],
  skills: const [],
);

Skill _skill(String name) => Skill(
  name: name,
  description: 'A test skill',
  context: 'inline',
  body: '# $name',
  updatedAt: DateTime.utc(2026, 1, 1),
);

class _FakeMentions implements MentionSource {
  @override
  Future<Map<String, String>> resolveNames(List<String> ids) async => const {};
  @override
  Future<List<MentionCandidate>> search(String query) async => const [];
}

void main() {
  setUpAll(() => BlinkController.indeterminateAnimationsEnabled = false);

  final t = AppLocaleUtils.parse('en').buildSync();

  /// A persistent shell (both routes share ONE constant-key page) so `context.go('/')` does NOT remount
  /// the ocean — the eviction must be observable as a SELECTION change, not as a lucky teardown.
  /// 持久壳(两 route 共用同一常量 key 页),使 `context.go('/')` 不重挂海洋——撤离必须以**选区**变化被观察到,
  /// 而不是靠一次侥幸的卸载。
  Future<WidgetRef> pumpOcean(
    WidgetTester tester,
    FixtureLibraryRepository repo, {
    required String at,
  }) async {
    late WidgetRef ref;
    final host = Consumer(
      builder: (_, r, _) {
        ref = r;
        return const Scaffold(
          body: SizedBox(width: 720, height: 640, child: LibraryOcean()),
        );
      },
    );
    final router = GoRouter(
      initialLocation: at,
      routes: [
        for (final path in ['/', '/library/:id', '/library/skill/:name'])
          GoRoute(
            path: path,
            pageBuilder: (_, _) =>
                NoTransitionPage(key: const ValueKey('shell'), child: host),
          ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          libraryRepositoryProvider.overrideWithValue(repo),
          goRouterProvider.overrideWithValue(router),
          mentionSourceProvider.overrideWithValue(_FakeMentions()),
        ],
        child: TranslationProvider(
          child: MaterialApp.router(
            theme: AnTheme.light(),
            routerConfig: router,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return ref;
  }

  group('L17 一个已被删除的页面不该继续呈现', () {
    testWidgets('删掉打开着的那一页 → 离开它并明说', (tester) async {
      final repo = _repo();
      final ref = await pumpOcean(tester, repo, at: '/library/doc_d');
      expect(ref.read(selectedDocProvider)?.id, 'doc_d');

      // Deleted by SOMEONE ELSE (agent / another view): the row leaves the tree and no local call clears
      // anything. 被**别人**删掉(agent/另一视图):行离开树,本地没有任何调用去清选区。
      await repo.deleteDocument('doc_d');
      ref.invalidate(documentTreeProvider);
      await tester.pumpAndSettle();

      expect(
        ref.read(selectedDocProvider),
        isNull,
        reason: 'the ocean must not keep presenting a page that is gone (L17)',
      );
      expect(
        ref.read(noticeCenterProvider).current?.message.text,
        t.library.docGone,
        reason:
            'being returned home mid-sentence without a word is its own mystery (L17)',
      );
    });

    testWidgets('删掉祖先 → 打开着的子页同样离开(rail 自己那条路也漏的一格)', (tester) async {
      final repo = _repo();
      // doc_b lives under doc_a. 子页 doc_b 挂在 doc_a 下。
      final ref = await pumpOcean(tester, repo, at: '/library/doc_b');
      expect(ref.read(selectedDocProvider)?.id, 'doc_b');

      // Delete the PARENT. The backend soft-deletes the subtree but names only the root, so nothing
      // anywhere ever says the word "doc_b" — only the tree knows it is gone.
      // 删**父页**。后端软删整棵子树却只点根的名字,故任何地方都不会说出 "doc_b" 四个字——只有树知道它没了。
      await repo.deleteDocument('doc_a');
      ref.invalidate(documentTreeProvider);
      await tester.pumpAndSettle();

      expect(
        ref.read(selectedDocProvider),
        isNull,
        reason:
            'an open child dies with its ancestor and no event names it — only the tree knows (L17)',
      );
    });

    testWidgets('树里从没见过的页 → 绝不被踢走(误判方向)', (tester) async {
      // The window right after a create: the page exists server-side but this client's (debounced) tree
      // refetch has not landed, so the row is legitimately absent. Evicting on absence ALONE would throw
      // the writer out of the page they just made — worse than the bug being fixed. Hence «seen, then
      // gone», and hence this cell: an id never seen in the tree gets no verdict at all.
      // 创建之后那个窗口:页面在服务端存在,但这个客户端(防抖的)树重取还没落地,故行合法缺席。**光凭**缺席就撤离,会把
      // 作者从他刚新建的页面里踢出去——比被修的 bug 更严重。故判据是「见过、又不见了」,故有本格:树里从没见过的 id
      // 根本不下判决。
      final repo = _repo();
      final ref = await pumpOcean(tester, repo, at: '/library/doc_unseen');
      expect(ref.read(selectedDocProvider)?.id, 'doc_unseen');

      // A tree turnover that still does not contain it changes nothing. 树换代后仍不含它,也什么都不该变。
      ref.invalidate(documentTreeProvider);
      await tester.pumpAndSettle();

      expect(
        ref.read(selectedDocProvider)?.id,
        'doc_unseen',
        reason:
            'never seen in the tree = newly created, NOT deleted — evicting here would throw the writer '
            'out of the page they just made (L17)',
      );
      expect(
        ref.read(noticeCenterProvider).current?.message.text,
        isNot(t.library.docGone),
        reason: 'and it must not claim the page was deleted (L17)',
      );
    });
  });

  group('skill 删除后不该继续呈现', () {
    testWidgets('删掉打开着的 skill → 离开它并明说', (tester) async {
      final repo = FixtureLibraryRepository(
        documents: const [],
        skills: [_skill('skill_a')],
      );
      final ref = await pumpOcean(tester, repo, at: '/library/skill/skill_a');
      expect(ref.read(selectedDocProvider), (isSkill: true, id: 'skill_a'));

      // Delete out of band (another view / agent), then let the list reconcile against its source of truth.
      await repo.deleteSkill('skill_a');
      ref.invalidate(skillListProvider);
      await tester.pumpAndSettle();

      expect(
        ref.read(selectedDocProvider),
        isNull,
        reason: 'the ocean must not keep presenting a skill that is gone',
      );
      expect(
        ref.read(noticeCenterProvider).current?.message.text,
        t.library.skillGone,
      );
    });

    testWidgets('列表里从没见过的 skill → 绝不被踢走', (tester) async {
      final repo = FixtureLibraryRepository(
        documents: const [],
        skills: const [],
      );
      final ref = await pumpOcean(
        tester,
        repo,
        at: '/library/skill/skill_unseen',
      );

      ref.invalidate(skillListProvider);
      await tester.pumpAndSettle();

      expect(
        ref.read(selectedDocProvider),
        (isSkill: true, id: 'skill_unseen'),
        reason: 'a deep link is not proof that the skill was deleted',
      );
      expect(
        ref.read(noticeCenterProvider).current?.message.text,
        isNot(t.library.skillGone),
      );
    });
  });
}
