import 'dart:async';

import 'package:anselm/core/contract/entities/document.dart';
import 'package:anselm/core/contract/entities/skill.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/router/navigation.dart';
import 'package:anselm/core/entity/mention_source.dart';
import 'package:anselm/core/settings/settings_prefs.dart';
import 'package:anselm/features/library/model/doc_outline.dart';
import 'package:anselm/features/library/state/doc_group_collapse.dart';
import 'package:anselm/features/library/ui/an_document_editor.dart';
import 'package:super_text_layout/super_text_layout.dart' show BlinkController;
import 'package:anselm/core/ui/an_button.dart';
import 'package:anselm/core/ui/an_sidebar_list.dart'
    show AnRowDropZone, AnSidebarList;
import 'package:anselm/core/ui/an_state.dart';
import 'package:anselm/core/ui/icons.dart';
import 'package:anselm/features/library/data/library_fixtures.dart';
import 'package:anselm/features/library/data/library_repository.dart';
import 'package:anselm/features/library/state/library_state.dart';
import 'package:anselm/features/library/ui/library_ocean.dart';
import 'package:anselm/features/library/ui/library_rail.dart';
import 'package:anselm/features/library/ui/library_rail_model.dart';
import 'package:anselm/features/library/ui/library_inspector.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/router_harness.dart';

final _t = DateTime.utc(2026, 7, 5);

DocumentNode _doc(
  String id,
  String? parent,
  String name,
  int pos, {
  String content = '',
}) => DocumentNode(
  id: id,
  parentId: parent,
  name: name,
  position: pos,
  content: content,
  createdAt: _t,
  updatedAt: _t,
);

Skill _skill(String name) => Skill(
  name: name,
  description: 'x',
  context: 'inline',
  body: '# $name',
  updatedAt: _t,
);

const _labels = LibraryRailLabels(
  documents: 'Documents',
  skills: 'Skills',
  untitled: 'Untitled',
  newLabel: 'New',
  filter: 'Filter',
);

FixtureLibraryRepository _repo() => FixtureLibraryRepository(
  documents: [
    _doc('doc_a', null, 'Getting Started', 0, content: '# Hello\n\nbody text'),
    _doc('doc_b', 'doc_a', 'Setup', 0),
    _doc('doc_c', 'doc_a', 'Concepts', 1),
    _doc('doc_d', null, 'Playbooks', 1),
  ],
  skills: [_skill('commit-helper'), _skill('triage')],
);

/// Selection is route-derived now, so rail hosts ride a real test router (the SAME instance is
/// routerConfig AND the goRouterProvider override — context.go and selectedDocProvider share one truth).
/// 选区由路由派生:rail 宿主挂真测试路由(同实例既是 routerConfig 又是 goRouterProvider override)。
Widget _host(
  FixtureLibraryRepository repo,
  Widget child, {
  String initialLocation = '/',
}) {
  final router = buildTestRouter(
    initialLocation: initialLocation,
    page: Scaffold(body: SizedBox(width: 320, height: 640, child: child)),
  );
  return ProviderScope(
    overrides: [
      libraryRepositoryProvider.overrideWithValue(repo),
      goRouterProvider.overrideWithValue(router),
      // The draft/live editors watch mentionSourceProvider (the @ picker seam) — give it a fake. @ 数据缝。
      mentionSourceProvider.overrideWithValue(_FakeMentions()),
    ],
    child: TranslationProvider(
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        theme: AnTheme.light(),
        routerConfig: router,
      ),
    ),
  );
}

void main() {
  // The document editor is now the native super_editor AnDocumentEditor (E9). Disable the caret blink
  // ticker so pumpAndSettle doesn't hang on it. Editor behavior is covered by test/core/editor/*.
  // 编辑器=原生 super_editor;关光标 ticker 免 pumpAndSettle 挂;编辑器行为由 core/editor 测覆盖。
  setUp(() => BlinkController.indeterminateAnimationsEnabled = false);
  tearDown(() => BlinkController.indeterminateAnimationsEnabled = true);

  group('buildLibraryRailModel', () {
    test(
      'assembles the nested document tree by parentId + a flat skill section',
      () {
        final model = buildLibraryRailModel(
          [
            _doc('doc_a', null, 'Getting Started', 0),
            _doc('doc_b', 'doc_a', 'Setup', 1),
            _doc(
              'doc_c',
              'doc_a',
              'Concepts',
              0,
            ), // lower position → sorts first
            _doc('doc_d', null, 'Playbooks', 1),
          ],
          [_skill('commit-helper')],
          _labels,
        );
        final types = model.groups.single.types;
        expect(types.map((t) => t.label), ['Documents', 'Skills']);
        final docRows = types[0].rows;
        expect(docRows.map((r) => r.id), [
          'doc_a',
          'doc_d',
        ]); // two roots, position-ordered
        // doc_a's children sort by position: Concepts(0) before Setup(1). 子按 position 排。
        expect(docRows[0].children.map((r) => r.label), ['Concepts', 'Setup']);
        expect(docRows[0].hasChildren, isTrue);
        // Skills flat, id namespaced. skill 扁平、id 加前缀。
        expect(types[1].rows.single.id, 'skill:commit-helper');
      },
    );

    test('unnamed document falls back to the untitled label', () {
      final model = buildLibraryRailModel(
        [_doc('doc_x', null, '', 0)],
        const [],
        _labels,
      );
      expect(model.groups.single.types[0].rows.single.label, 'Untitled');
    });

    test(
      'B4: the row icon tells an empty page (file) from a written one (fileText/doc) via hasContent',
      () {
        final model = buildLibraryRailModel(
          [
            DocumentNode(
              id: 'doc_empty',
              name: 'Empty',
              createdAt: _t,
              updatedAt: _t,
            ), // hasContent defaults false
            DocumentNode(
              id: 'doc_full',
              name: 'Written',
              hasContent: true,
              createdAt: _t,
              updatedAt: _t,
            ),
          ],
          const [],
          _labels,
        );
        final rows = model.groups.single.types[0].rows;
        expect(
          rows.firstWhere((r) => r.id == 'doc_empty').icon,
          AnIcons.file,
          reason: '空页=空白页 icon',
        );
        expect(
          rows.firstWhere((r) => r.id == 'doc_full').icon,
          AnIcons.doc,
          reason: '已写=fileText icon',
        );
      },
    );

    test('docSelectionForRowId disambiguates skills by prefix', () {
      expect(docSelectionForRowId('doc_a'), (isSkill: false, id: 'doc_a'));
      expect(docSelectionForRowId('skill:triage'), (
        isSkill: true,
        id: 'triage',
      ));
    });
  });

  group('LibraryRail', () {
    testWidgets('renders the document tree + skills', (tester) async {
      await tester.pumpWidget(_host(_repo(), const LibraryRail()));
      await tester.pump();
      await tester.pump();
      expect(find.text('Getting Started'), findsOneWidget);
      expect(find.text('Playbooks'), findsOneWidget);
      expect(find.text('commit-helper'), findsOneWidget);
    });

    testWidgets('selecting a document drives selectedDocProvider', (
      tester,
    ) async {
      late WidgetRef ref;
      await tester.pumpWidget(
        _host(
          _repo(),
          Consumer(
            builder: (_, r, _) {
              ref = r;
              return const LibraryRail();
            },
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(ref.read(selectedDocProvider), isNull);
      await tester.tap(find.text('Getting Started'));
      await tester.pump();
      expect(ref.read(selectedDocProvider), (isSkill: false, id: 'doc_a'));
    });

    testWidgets(
      'empty library → the collapsed shape: New page + Documents / Skills heads, no tombstone',
      (tester) async {
        await tester.pumpWidget(
          _host(
            FixtureLibraryRepository(documents: const [], skills: const []),
            const LibraryRail(),
          ),
        );
        await tester.pump();
        await tester.pump();
        // 用户 0718 拍板: an empty library = the FULL rail with rows removed — New page + both section heads
        // render, no «Nothing here yet» tombstone. 空态=满态收起:New page + 双组头恒在、无墓碑。
        expect(find.byType(AnSidebarList), findsOneWidget);
        expect(
          find.byType(AnState),
          findsNothing,
        ); // the old empty tombstone is retired 墓碑退役
        expect(find.text('New page'), findsOneWidget);
        expect(
          find.text(t.library.documents),
          findsOneWidget,
        ); // Documents head
        expect(find.text(t.library.skills), findsOneWidget); // Skills head
      },
    );

    testWidgets(
      'B2 active: the New row creates a root page immediately, selects it, and flags the title '
      'for one-shot autofocus (no inline-rename)',
      (tester) async {
        final repo = _repo();
        late WidgetRef ref;
        await tester.pumpWidget(
          _host(
            repo,
            Consumer(
              builder: (_, r, _) {
                ref = r;
                return const LibraryRail();
              },
            ),
          ),
        );
        await tester.pump();
        await tester.pump();
        final before = (await repo.getTree()).length;
        await tester.tap(
          find.text('New page'),
        ); // the New row label (B9: unified to "New <thing>") 新建行标签
        await tester.pumpAndSettle();
        final tree = await repo.getTree();
        // A new root page was created + became the selection; the active-create path DOESN'T inline-rename —
        // it flags the fresh doc's TITLE for a one-shot autofocus (focus lands on the title in the ocean).
        // 新根页建成+选中;主动新建不进行内改名,而是标记新 doc 标题一次性聚焦(焦点落海洋标题)。
        expect(tree.length, before + 1);
        final sel = ref.read(selectedDocProvider);
        expect(sel, isNotNull);
        expect(sel!.isSkill, isFalse);
        expect(tree.any((d) => d.id == sel.id && d.parentId == null), isTrue);
        expect(
          ref.read(focusNewDocTitleProvider),
          sel.id,
          reason: '主动新建把新 doc 标记为标题聚焦意图',
        );
      },
    );

    testWidgets(
      'B3: a page row\'s + action creates a CHILD under that page (parent = that row)',
      (tester) async {
        final repo = _CountingDocsRepo(
          documents: [
            _doc('doc_a', null, 'Getting Started', 0, content: '# Hello'),
          ],
          skills: const [],
        );
        await tester.pumpWidget(_host(repo, const LibraryRail()));
        await tester.pump();
        await tester.pump();
        // The row's `[+]` action is an AnButton carrying the newSubpage a11y label (hover-revealed by AnRow;
        // its reachability is AnRow's shared concern — here we assert the WIRING: + → create-child).
        // 行 `[+]`=带 newSubpage 标签的 AnButton;可达性归 AnRow(共用),此处断言接线:+ → 建子文档。
        final plus = tester
            .widgetList<AnButton>(
              find.byWidgetPredicate(
                (w) => w is AnButton && w.semanticLabel == t.a11y.newSubpage,
              ),
            )
            .toList();
        expect(
          plus,
          hasLength(1),
          reason: 'exactly one page row → one + action',
        );
        plus.single.onPressed!();
        await tester.pumpAndSettle();
        expect(repo.createCount, 1);
        expect(
          repo.lastCreatedParent,
          'doc_a',
          reason: 'B3:行内 + 建的是该行的子文档(parent=该行)',
        );
      },
    );
  });

  group('LibraryOcean', () {
    testWidgets(
      'B2 passive: no selection → a DRAFT editor (empty, uncreated — NOT a pick tombstone)',
      (tester) async {
        final repo = _CountingDocsRepo(documents: const [], skills: const []);
        await tester.pumpWidget(_host(repo, const LibraryOcean()));
        await tester.pumpAndSettle();
        // The center is a real editor with an EMPTY title/body (the header shows its grey guides); nothing is
        // created until the first edit. 中心=空标题/正文的真编辑器(头显灰引导);首次编辑前不建。
        final editor = tester.widget<AnDocumentEditor>(
          find.byType(AnDocumentEditor),
        );
        expect(editor.name, '');
        expect(editor.initialMarkdown, '');
        // A root draft's parent path is just «Documents» (面包屑律:路径到上一级、绝不含自己). 根草稿父路径=Documents。
        expect(editor.crumbs.single.label, t.library.documents);
        expect(
          repo.createCount,
          0,
          reason: 'draft landing must not POST until the first edit',
        );
      },
    );

    testWidgets(
      'B2 passive: the first body edit POSTs the create, navigates, and 转正 WITHOUT a remount',
      (tester) async {
        final repo = _CountingDocsRepo(documents: const [], skills: const []);
        late WidgetRef ref;
        // A PERSISTENT-shell harness: both `/` and `/documents/:id` return ONE page with a constant key, so
        // the URL flip does NOT remount the subtree (mirrors the app's constant-key shell — the per-route
        // `_host` would remount and mask the seam). 持久壳:两 route 共用常量 key 页,URL 翻转不重挂子树(镜像 app 常量壳)。
        final host = Consumer(
          builder: (_, r, _) {
            ref = r;
            return const Scaffold(
              body: SizedBox(width: 720, height: 640, child: LibraryOcean()),
            );
          },
        );
        final router = GoRouter(
          initialLocation: '/',
          routes: [
            GoRoute(
              path: '/',
              pageBuilder: (_, _) =>
                  NoTransitionPage(key: const ValueKey('shell'), child: host),
            ),
            GoRoute(
              path: '/library/:id',
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
        // Capture the editor STATE before the edit — a seamless 转正 must keep the SAME State (no remount,
        // no cursor/content loss, B6). 记录编辑前 State——无缝转正须保持同一 State(不重挂、光标/内容不丢)。
        final stateBefore = tester.state<AnDocumentEditorState>(
          find.byType(AnDocumentEditor),
        );
        tester
            .widget<AnDocumentEditor>(find.byType(AnDocumentEditor))
            .onChangedMarkdown('# Hi\n\nfirst line');
        await tester.pumpAndSettle();
        expect(repo.createCount, 1, reason: 'first edit POSTs the create once');
        final sel = ref.read(selectedDocProvider);
        expect(
          sel?.id,
          repo.lastCreatedId,
          reason: 'navigated to the new id (route 转正)',
        );
        expect(
          ref.read(adoptedDraftDocProvider),
          repo.lastCreatedId,
          reason: 'the ocean adopted the new id',
        );
        final stateAfter = tester.state<AnDocumentEditorState>(
          find.byType(AnDocumentEditor),
        );
        expect(
          identical(stateBefore, stateAfter),
          isTrue,
          reason:
              'the create must NOT remount the editor — same State element (seamless 转正)',
        );
        // Clean up the pending autosave debounce timer. 收尾去抖计时器。
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      },
    );

    testWidgets(
      'B2 passive: writing NOTHING then leaving creates nothing (什么都不留)',
      (tester) async {
        final repo = _CountingDocsRepo(documents: const [], skills: const []);
        await tester.pumpWidget(_host(repo, const LibraryOcean()));
        await tester.pumpAndSettle();
        // Leave without any edit. 未编辑即离开。
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        expect(
          repo.createCount,
          0,
          reason: 'an untouched draft leaves nothing behind',
        );
      },
    );

    testWidgets(
      'B2 active: an open doc flagged for title-autofocus mounts the editor with autofocusName',
      (tester) async {
        final repo = _repo();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              libraryRepositoryProvider.overrideWithValue(repo),
              selectedDocProvider.overrideWith(
                () => _PinnedSelection((isSkill: false, id: 'doc_a')),
              ),
              mentionSourceProvider.overrideWithValue(_FakeMentions()),
              // Pre-flag doc_a for the one-shot title autofocus (the active-create hand-off). 预标记标题聚焦。
              focusNewDocTitleProvider.overrideWith(
                () => _PinnedFocus('doc_a'),
              ),
            ],
            child: TranslationProvider(
              child: MaterialApp(
                theme: AnTheme.light(),
                home: const Scaffold(body: LibraryOcean()),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final editor = tester.widget<AnDocumentEditor>(
          find.byType(AnDocumentEditor),
        );
        expect(
          editor.autofocusName,
          isTrue,
          reason: '被标记的 doc 挂载时标题进编辑态(焦点落标题)',
        );
      },
    );

    testWidgets(
      'a selected document opens in the native editor with its content + meta',
      (tester) async {
        final repo = _repo();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              libraryRepositoryProvider.overrideWithValue(repo),
              selectedDocProvider.overrideWith(
                () => _PinnedSelection((isSkill: false, id: 'doc_a')),
              ),
              mentionSourceProvider.overrideWithValue(_FakeMentions()),
            ],
            child: TranslationProvider(
              child: MaterialApp(
                theme: AnTheme.light(),
                home: const Scaffold(body: LibraryOcean()),
              ),
            ),
          ),
        );
        await tester
            .pumpAndSettle(); // resolve the async mention-name batch, then mount the editor 解析提及名后挂载
        // The native editor mounts with the doc's props (its header is Flutter now). 原生编辑器带 doc props 挂载。
        final editor = tester.widget<AnDocumentEditor>(
          find.byType(AnDocumentEditor),
        );
        expect(editor.name, 'Getting Started');
        // The crumb path starts at «Documents» and NEVER includes the doc's own name. 面包屑首段=Documents,绝不含自己。
        expect(editor.crumbs.first.label, t.library.documents);
        expect(
          editor.crumbs.map((c) => c.label),
          isNot(contains('Getting Started')),
        );
        expect(editor.initialMarkdown, contains('# Hello'));
        expect(editor.nameEditable, isTrue);
        expect(editor.mentionSource, isNotNull);
      },
    );

    testWidgets('a selected skill opens read-only-name with its body', (
      tester,
    ) async {
      final repo = _repo();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            libraryRepositoryProvider.overrideWithValue(repo),
            selectedDocProvider.overrideWith(
              () => _PinnedSelection((isSkill: true, id: 'commit-helper')),
            ),
            selectedSkillFileProvider.overrideWith(_PinnedSkillFile.new),
            mentionSourceProvider.overrideWithValue(_FakeMentions()),
          ],
          child: TranslationProvider(
            child: MaterialApp(
              theme: AnTheme.light(),
              home: const Scaffold(body: LibraryOcean()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final editor = tester.widget<AnDocumentEditor>(
        find.byType(AnDocumentEditor),
      );
      expect(editor.name, 'commit-helper');
      // A skill's parent path is «Documents / Skills» — the skills collection, never the skill name.
      // skill 父路径=Documents / Skills(集合,绝不含 skill 名)。
      expect(editor.crumbs.map((c) => c.label), [
        t.library.documents,
        t.library.skills,
      ]);
      expect(
        editor.nameEditable,
        isFalse,
      ); // the skill name IS its identity — not renamable. 名即身份。
      expect(
        editor.initialMarkdown,
        contains('commit-helper'),
      ); // the skill body '# commit-helper'
      expect(
        editor.mentionSource,
        isNull,
      ); // no @ mentions on skills. skill 不接 @。
    });

    testWidgets(
      'an edit within the autosave window is FLUSHED on unmount — no data loss (P5, C-001 area)',
      (tester) async {
        final repo = _repo();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              libraryRepositoryProvider.overrideWithValue(repo),
              selectedDocProvider.overrideWith(
                () => _PinnedSelection((isSkill: false, id: 'doc_a')),
              ),
              mentionSourceProvider.overrideWithValue(_FakeMentions()),
            ],
            child: TranslationProvider(
              child: MaterialApp(
                theme: AnTheme.light(),
                home: const Scaffold(body: LibraryOcean()),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        // Simulate a content edit (drives LibraryOcean._onChanged → schedules the 600ms autosave). The
        // editor's onChangedMarkdown IS the ocean's _onChanged. 模拟正文编辑→排 600ms 自动保存。
        tester
            .widget<AnDocumentEditor>(find.byType(AnDocumentEditor))
            .onChangedMarkdown(
              '# Edited\n\nthe last line, typed just before switching away',
            );
        // Unmount BEFORE the 600ms autosave fires — the old bug CANCELLED the pending save here, dropping
        // the edit. The fix FLUSHES it in dispose. 600ms 内卸载(旧 bug 在此丢存,修复在 dispose flush)。
        await tester.pumpWidget(const SizedBox.shrink());
        await tester
            .pump(); // let the flushed async save complete 让 flush 的异步存完成
        final saved = await repo.getDocument('doc_a');
        expect(
          saved.content,
          '# Edited\n\nthe last line, typed just before switching away',
          reason:
              'dispose must FLUSH the pending autosave — the last edit must persist, not be dropped',
        );
      },
    );
  });

  // B5 empty-field guides (the AnDocHeader primitive contract) live in test/core/ui/an_doc_header_test.dart.
  // The B2 draft/live editors WIRE those guides via AnDocumentEditor (covered above). B5 引导原语契约在
  // an_doc_header_test.dart;B2 草稿/实文档编辑器经 AnDocumentEditor 接线(上面已覆盖)。

  group('planDocMove', () {
    // Seed shape: doc_a(root,0){doc_b(0), doc_c(1)} · doc_d(root,1). 种子:两根、doc_a 携两子。
    List<DocumentNode> tree() => [
      _doc('doc_a', null, 'Getting Started', 0),
      _doc('doc_b', 'doc_a', 'Setup', 0),
      _doc('doc_c', 'doc_a', 'Concepts', 1),
      _doc('doc_d', null, 'Playbooks', 1),
    ];

    test(
      'inside → nest under the target, position omitted (backend appends)',
      () {
        expect(planDocMove(tree(), 'doc_d', 'doc_a', AnRowDropZone.inside), (
          parentId: 'doc_a',
          position: null,
        ));
      },
    );

    test(
      'above/below → the target parent + index among siblings EXCLUDING the dragged node',
      () {
        expect(planDocMove(tree(), 'doc_d', 'doc_b', AnRowDropZone.above), (
          parentId: 'doc_a',
          position: 0,
        ));
        expect(planDocMove(tree(), 'doc_d', 'doc_b', AnRowDropZone.below), (
          parentId: 'doc_a',
          position: 1,
        ));
        expect(planDocMove(tree(), 'doc_d', 'doc_c', AnRowDropZone.below), (
          parentId: 'doc_a',
          position: 2,
        ));
      },
    );

    test(
      'same-parent reorder excludes the dragged node from the index space',
      () {
        // Root siblings excluding doc_a = [doc_d] → dropping doc_a below doc_d = position 1. 剔除自身后计序。
        expect(planDocMove(tree(), 'doc_a', 'doc_d', AnRowDropZone.below), (
          parentId: null,
          position: 1,
        ));
        expect(planDocMove(tree(), 'doc_d', 'doc_a', AnRowDropZone.above), (
          parentId: null,
          position: 0,
        ));
      },
    );

    test(
      'cycles are refused: into or beside the dragged node\'s own subtree',
      () {
        expect(
          planDocMove(tree(), 'doc_a', 'doc_b', AnRowDropZone.inside),
          isNull,
        );
        expect(
          planDocMove(tree(), 'doc_a', 'doc_b', AnRowDropZone.below),
          isNull,
        );
      },
    );

    test('self, unknown ids and skill rows are refused', () {
      expect(
        planDocMove(tree(), 'doc_a', 'doc_a', AnRowDropZone.inside),
        isNull,
      );
      expect(
        planDocMove(tree(), 'doc_a', 'nope', AnRowDropZone.inside),
        isNull,
      );
      expect(
        planDocMove(tree(), 'skill:triage', 'doc_a', AnRowDropZone.inside),
        isNull,
      );
      expect(
        planDocMove(tree(), 'doc_a', 'skill:triage', AnRowDropZone.inside),
        isNull,
      );
    });

    test('a malformed parent loop in the data is refused, not spun on', () {
      final looped = [
        _doc('doc_x', 'doc_y', 'X', 0),
        _doc('doc_y', 'doc_x', 'Y', 0),
        _doc('doc_z', null, 'Z', 0),
      ];
      expect(
        planDocMove(looped, 'doc_z', 'doc_x', AnRowDropZone.above),
        isNull,
      );
    });
  });

  group('LibraryRail drag-reorder', () {
    // A real pointer drag: grab the source row, nudge to arm the drag recognizer, glide to the target
    // offset, release. 真手势:按住源行→微移触发识别→滑到目标点→松手。
    Future<void> drag(WidgetTester tester, String fromLabel, Offset to) async {
      final g = await tester.startGesture(
        tester.getCenter(find.text(fromLabel)),
      );
      await tester.pump(const Duration(milliseconds: 20));
      await g.moveBy(const Offset(0, 6));
      await tester.pump(const Duration(milliseconds: 20));
      await g.moveTo(to);
      await tester.pump(const Duration(milliseconds: 20));
      await g.up();
      await tester.pumpAndSettle();
    }

    testWidgets('dropping on a row\'s middle nests the page under it', (
      tester,
    ) async {
      final repo = _repo();
      await tester.pumpWidget(_host(repo, const LibraryRail()));
      await tester.pump();
      await tester.pump();
      // 'Playbooks' (root) onto the CENTER of 'Getting Started' → inside → reparent. 中段=嵌入。
      await drag(
        tester,
        'Playbooks',
        tester.getCenter(find.text('Getting Started')),
      );
      expect((await repo.getDocument('doc_d')).parentId, 'doc_a');
    });

    testWidgets('dropping on a row\'s top edge reorders above it', (
      tester,
    ) async {
      final repo = _repo();
      await tester.pumpWidget(_host(repo, const LibraryRail()));
      await tester.pump();
      await tester.pump();
      // 'Playbooks' onto the TOP QUARTER of 'Getting Started' → above → root position 0. 上缘=前插。
      await drag(
        tester,
        'Playbooks',
        tester.getCenter(find.text('Getting Started')) - const Offset(0, 12),
      );
      final moved = await repo.getDocument('doc_d');
      expect(moved.parentId, isNull);
      expect(moved.position, 0);
      expect(
        (await repo.getDocument('doc_a')).position,
        1,
      ); // shifted sibling 让位兄弟顺移
    });

    testWidgets('dropping a page into its own subtree is refused (cycle)', (
      tester,
    ) async {
      final repo = _repo();
      await tester.pumpWidget(_host(repo, const LibraryRail()));
      await tester.pump();
      await tester.pump();
      await drag(
        tester,
        'Getting Started',
        tester.getCenter(find.text('Setup')),
      );
      // Nothing moved. 未动。
      expect((await repo.getDocument('doc_a')).parentId, isNull);
      expect((await repo.getDocument('doc_b')).parentId, 'doc_a');
    });

    testWidgets(
      'dragging a branch\'s first child onto its parent\'s bottom edge is an identity move',
      (tester) async {
        final repo = _repo();
        await tester.pumpWidget(_host(repo, const LibraryRail()));
        await tester.pump();
        await tester.pump();
        // 'Setup' IS doc_a's first child; below-on-open-branch normalizes to "above first child" = itself —
        // the primitive must emit nothing (adversarial-review regression). 首子拖到父行下缘=恒等移动,不派发。
        await drag(
          tester,
          'Setup',
          tester.getCenter(find.text('Getting Started')) + const Offset(0, 12),
        );
        final b = await repo.getDocument('doc_b');
        expect(b.parentId, 'doc_a');
        expect(b.position, 0);
      },
    );

    testWidgets('drag is disabled while the filter query is active', (
      tester,
    ) async {
      final repo = _repo();
      await tester.pumpWidget(_host(repo, const LibraryRail()));
      await tester.pump();
      await tester.pump();
      // The query force-expands + hides rows — indicators/position math would lie, so rows must not drag
      // (adversarial-review regression). 过滤时强展开+藏行,指示会撒谎——行必须不可拖。
      await tester.enterText(
        find.byType(EditableText).first,
        'o',
      ); // matches several rows 命中若干行
      await tester.pump();
      await drag(
        tester,
        'Playbooks',
        tester.getCenter(find.text('Getting Started')),
      );
      expect(
        (await repo.getDocument('doc_d')).parentId,
        isNull,
      ); // unchanged 未动
    });
  });

  group('SSE-driven refresh', () {
    testWidgets(
      'a document.* signal refetches the tree (debounced, burst-collapsed); skill signals do not',
      (tester) async {
        final repo = _SignallingRepo();
        final container = ProviderContainer(
          overrides: [libraryRepositoryProvider.overrideWithValue(repo)],
        );
        addTearDown(container.dispose);
        final sub = container.listen(documentTreeProvider, (_, _) {});
        addTearDown(sub.close);
        await container.read(documentTreeProvider.future);
        expect(repo.treeFetches, 1);

        // A burst of document signals (the typing-save echo shape) collapses into ONE refetch. 突发合一。
        repo.emit('document');
        repo.emit('document');
        await tester.pump(
          const Duration(milliseconds: 500),
        ); // past the 400ms debounce 过去抖
        await container.read(documentTreeProvider.future);
        expect(repo.treeFetches, 2);

        // A skill signal must NOT refetch the tree. skill 信号不动树。
        repo.emit('skill');
        await tester.pump(const Duration(milliseconds: 500));
        await container.read(documentTreeProvider.future);
        expect(repo.treeFetches, 2);
      },
    );

    testWidgets('a skill.* signal refetches the skill list', (tester) async {
      final repo = _SignallingRepo();
      final container = ProviderContainer(
        overrides: [libraryRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);
      final sub = container.listen(skillListProvider, (_, _) {});
      addTearDown(sub.close);
      await container.read(skillListProvider.future);
      expect(repo.skillFetches, 1);
      repo.emit('skill');
      await tester.pump(const Duration(milliseconds: 500));
      await container.read(skillListProvider.future);
      expect(repo.skillFetches, 2);
    });

    testWidgets(
      'document.updated for a HELD row patches one row in place — no tree refetch (S4)',
      (tester) async {
        final repo = _SignallingRepo();
        final container = ProviderContainer(
          overrides: [libraryRepositoryProvider.overrideWithValue(repo)],
        );
        addTearDown(container.dispose);
        final sub = container.listen(documentTreeProvider, (_, _) {});
        addTearDown(sub.close);
        await container.read(documentTreeProvider.future);
        expect(repo.treeFetches, 1);

        // Mutate behind the provider's back (an autosave from another surface), then echo it.
        // 背后改行(别的表面自动存),再回声信号。
        await repo.updateDocument('doc_a', {'name': 'A2', 'content': 'body!'});
        repo.emit('document', action: 'updated', id: 'doc_a');
        await tester.pump(const Duration(milliseconds: 500));

        final rows = container.read(documentTreeProvider).value!;
        final a = rows.firstWhere((n) => n.id == 'doc_a');
        expect(a.name, 'A2'); // the row is fresh 行已新
        expect(
          a.content,
          isEmpty,
        ); // tree projection kept (metadata-only) 树投影保持
        expect(a.hasContent, isTrue); // derived from the fetched body 由取回正文推
        expect(repo.docGets, 1); // ONE single-row GET 单行一取
        expect(repo.treeFetches, 1); // and NO full refetch 无整取
      },
    );

    testWidgets(
      'document.updated for an UNHELD id falls back to the structural refetch',
      (tester) async {
        final repo = _SignallingRepo();
        final container = ProviderContainer(
          overrides: [libraryRepositoryProvider.overrideWithValue(repo)],
        );
        addTearDown(container.dispose);
        final sub = container.listen(documentTreeProvider, (_, _) {});
        addTearDown(sub.close);
        await container.read(documentTreeProvider.future);

        repo.emit('document', action: 'updated', id: 'doc_ghost');
        await tester.pump(const Duration(milliseconds: 500));
        await container.read(documentTreeProvider.future);
        expect(
          repo.treeFetches,
          2,
        ); // unknown row → the tree is re-pulled 未持有→整取
        expect(repo.docGets, 0);
      },
    );

    testWidgets('skill.updated for a held row patches in place (S4)', (
      tester,
    ) async {
      final repo = _SignallingRepo();
      final container = ProviderContainer(
        overrides: [libraryRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);
      final sub = container.listen(skillListProvider, (_, _) {});
      addTearDown(sub.close);
      await container.read(skillListProvider.future);
      expect(repo.skillFetches, 1);

      repo.emit('skill', action: 'updated', id: 'triage');
      await tester.pump(const Duration(milliseconds: 500));

      final rows = container.read(skillListProvider).value!;
      expect(rows.single.body, isEmpty); // list projection kept 列表投影保持
      expect(repo.skillGets, 1);
      expect(repo.skillFetches, 1); // no full refetch 无整取
    });
  });

  group('LibraryInspector', () {
    Widget host(FixtureLibraryRepository repo, DocSelection sel) =>
        ProviderScope(
          overrides: [
            libraryRepositoryProvider.overrideWithValue(repo),
            selectedDocProvider.overrideWith(() => _PinnedSelection(sel)),
          ],
          child: TranslationProvider(
            child: MaterialApp(
              theme: AnTheme.light(),
              home: const Scaffold(
                body: SizedBox(
                  width: 320,
                  height: 640,
                  child: LibraryInspector(),
                ),
              ),
            ),
          ),
        );

    testWidgets(
      'a page panel keeps only outline / file meta / backlinks (no property form)',
      (tester) async {
        final repo = _repo();
        await tester.pumpWidget(host(repo, (isSkill: false, id: 'doc_a')));
        await tester.pumpAndSettle();
        // File meta + backlinks stay; the page's OWN properties (name/description/tags) edit in the
        // CENTER under the big title now. 文件 meta+反链留;页自身属性(名/描述/标签)已归中心大标题下。
        expect(find.text('Modified'), findsOneWidget);
        expect(
          find.text('Backlinks'),
          findsOneWidget,
        ); // AnRow 组头文法(三段式文法 §3,批2)
        expect(find.text('Name'), findsNothing);
        expect(find.text('Tags'), findsNothing);
        expect(
          find.byType(EditableText),
          findsNothing,
        ); // nothing edits on this panel anymore 本岛无输入
      },
    );

    testWidgets('a skill shows its frontmatter fields', (tester) async {
      final repo = _repo();
      await tester.pumpWidget(host(repo, (isSkill: true, id: 'commit-helper')));
      await tester.pumpAndSettle();
      expect(find.text('Context'), findsOneWidget);
      expect(find.text('Allowed tools'), findsOneWidget);
      expect(find.text('User-invocable'), findsOneWidget);
      // The name is read-only (slug identity) — shown, not an input. name 只读展示。
      expect(find.text('commit-helper'), findsWidgets);
    });

    testWidgets(
      'backlinks list the linking pages; a tap navigates to the linker',
      (tester) async {
        // doc_d's body wikilinks doc_a → doc_a's panel lists 'Playbooks' as a backlink. doc_d 链 doc_a。
        final repo = FixtureLibraryRepository(
          documents: [
            _doc('doc_a', null, 'Getting Started', 0),
            _doc('doc_d', null, 'Playbooks', 1, content: 'see [[doc_a]] first'),
          ],
          skills: const [],
        );
        final router = buildTestRouter(
          page: const Scaffold(
            body: SizedBox(width: 320, height: 640, child: LibraryInspector()),
          ),
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              libraryRepositoryProvider.overrideWithValue(repo),
              goRouterProvider.overrideWithValue(router),
              selectedDocProvider.overrideWith(
                () => _PinnedSelection((isSkill: false, id: 'doc_a')),
              ),
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
        expect(
          find.text('Backlinks'),
          findsOneWidget,
        ); // AnRow 组头文法(三段式文法 §3,批2)
        expect(find.text('Playbooks'), findsOneWidget);

        await tester.tap(find.text('Playbooks'));
        await tester.pumpAndSettle();
        expect(
          router.routerDelegate.currentConfiguration.uri.path,
          '/library/doc_d',
        ); // navigated 导航到链接方
      },
    );

    testWidgets(
      'editing a skill CONFIG field PUTs the whole frontmatter, keeping body + description',
      (tester) async {
        // A FORK skill so the agent field (the island's only text input) shows — identity/description
        // edit in the center now. fork skill 才有 agent 输入(本岛唯一文本框);身份/描述已归中心。
        final repo = FixtureLibraryRepository(
          documents: const [],
          skills: [
            Skill(
              name: 'commit-helper',
              description: 'x',
              context: 'fork',
              body: '# commit-helper',
              frontmatter: const Frontmatter(
                name: 'commit-helper',
                context: 'fork',
                agent: 'coder',
              ),
              updatedAt: _t,
            ),
          ],
        );
        final before = await repo.getSkill('commit-helper');
        await tester.pumpWidget(
          host(repo, (isSkill: true, id: 'commit-helper')),
        );
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(EditableText).first, 'reviewer');
        await tester.pump(const Duration(milliseconds: 600));
        await tester.pumpAndSettle();
        final after = await repo.getSkill('commit-helper');
        expect(after.frontmatter.agent, 'reviewer');
        expect(
          after.body,
          before.body,
        ); // the untouched body survives the full-replace PUT. body 不被抹。
        expect(
          after.description,
          before.description,
        ); // …and so does the center-owned description. 描述不被抹。
      },
    );
  });

  // The three-segment grammar (三段式文法 §1–§3, batch 2, 用户 0719): one identity head + a §2 glance strip
  // + §3 collapsible groups replacing the three orphan mini-titles. 一头三组替三孤儿标题。
  group('LibraryInspector · 三段式文法', () {
    Widget host(
      FixtureLibraryRepository repo,
      DocSelection sel, {
      List<DocOutlineEntry> outline = const [],
      SettingsPrefs? prefs,
    }) => ProviderScope(
      overrides: [
        libraryRepositoryProvider.overrideWithValue(repo),
        selectedDocProvider.overrideWith(() => _PinnedSelection(sel)),
        if (outline.isNotEmpty)
          docOutlineProvider.overrideWith(() => _PinnedOutline(outline)),
        if (prefs != null) settingsPrefsProvider.overrideWithValue(prefs),
      ],
      child: TranslationProvider(
        child: MaterialApp(
          theme: AnTheme.light(),
          home: const Scaffold(
            body: SizedBox(width: 320, height: 640, child: LibraryInspector()),
          ),
        ),
      ),
    );

    FixtureLibraryRepository linkedRepo() => FixtureLibraryRepository(
      documents: [
        _doc(
          'doc_a',
          null,
          'Getting Started',
          0,
          content: 'a page with a fair number of words here',
        ),
        _doc('doc_link', null, 'Playbooks', 1, content: 'see [[doc_a]] first'),
      ],
      skills: const [],
    );

    testWidgets('one head + three group heads (counts), no orphan uppercase titles', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          linkedRepo(),
          (isSkill: false, id: 'doc_a'),
          outline: const [(level: 1, text: 'Alpha'), (level: 2, text: 'Beta')],
        ),
      );
      await tester.pumpAndSettle();
      // §1 head = the doc's NAME (identity), never a generic panel title. 身份头=页名。
      expect(find.text('Getting Started'), findsWidgets);
      // §3 group heads speak the AnRow language (normal case + count), NOT the retired orphan AnGroupLabel
      // (uppercase). 组头 = AnRow 文法(非退役的孤儿大写标题)。
      expect(find.text('Outline'), findsOneWidget);
      expect(find.text('Properties'), findsOneWidget);
      expect(find.text('Backlinks'), findsOneWidget);
      expect(find.text('OUTLINE'), findsNothing);
      expect(find.text('BACKLINKS'), findsNothing);
      // Group bodies default-EXPANDED → their (untouched) content is present. 默认展开,组内内容原样在。
      expect(find.text('Modified'), findsOneWidget); // properties KV
      expect(find.text('Alpha'), findsOneWidget); // outline row
      expect(find.text('Playbooks'), findsOneWidget); // backlink row
    });

    testWidgets(
      '§2 glance: three segments (chars · backlinks · edited) when all carry signal',
      (tester) async {
        await tester.pumpWidget(
          host(linkedRepo(), (isSkill: false, id: 'doc_a')),
        );
        await tester.pumpAndSettle();
        expect(find.textContaining('chars'), findsOneWidget); // word/char count
        expect(
          find.textContaining('backlinks'),
          findsOneWidget,
        ); // lower-case → the glance, not the «Backlinks» head
        expect(
          find.textContaining('Edited'),
          findsOneWidget,
        ); // relative last-edited
      },
    );

    testWidgets('§2 glance: a no-backlinks page drops the 反链 segment (零人话律)', (
      tester,
    ) async {
      final repo = FixtureLibraryRepository(
        documents: [
          _doc(
            'doc_solo',
            null,
            'Solo',
            0,
            content: 'just some words, nobody links here',
          ),
        ],
        skills: const [],
      );
      await tester.pumpWidget(host(repo, (isSkill: false, id: 'doc_solo')));
      await tester.pumpAndSettle();
      expect(find.textContaining('chars'), findsOneWidget);
      expect(find.textContaining('Edited'), findsOneWidget);
      expect(
        find.textContaining('backlinks'),
        findsNothing,
      ); // omitted — zero backlinks 无信号段不渲
    });

    testWidgets(
      '§2 glance: absent entirely with no selection (all-empty → no band)',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              libraryRepositoryProvider.overrideWithValue(_repo()),
              selectedDocProvider.overrideWith(
                () => _PinnedSelection(null),
              ), // nothing open 空选
            ],
            child: TranslationProvider(
              child: MaterialApp(
                theme: AnTheme.light(),
                home: const Scaffold(
                  body: SizedBox(
                    width: 320,
                    height: 640,
                    child: LibraryInspector(),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.text('Nothing selected'),
          findsOneWidget,
        ); // the inset empty state 空态
        expect(find.textContaining('Edited'), findsNothing);
        expect(find.textContaining('chars'), findsNothing);
      },
    );

    testWidgets(
      'group fold: tapping a head collapses its body; re-tap restores it',
      (tester) async {
        await tester.pumpWidget(
          host(linkedRepo(), (isSkill: false, id: 'doc_a')),
        );
        await tester.pumpAndSettle();
        expect(
          find.text('Modified'),
          findsOneWidget,
        ); // Properties open by default
        await tester.tap(find.text('Properties'));
        await tester.pumpAndSettle();
        expect(find.text('Modified'), findsNothing); // collapsed → body gone
        await tester.tap(find.text('Properties'));
        await tester.pumpAndSettle();
        expect(find.text('Modified'), findsOneWidget); // re-expanded
      },
    );

    testWidgets(
      'a skill: head + Outline/Properties groups, no Backlinks; glance drops 反链',
      (tester) async {
        final repo = FixtureLibraryRepository(
          documents: const [],
          skills: [
            Skill(
              name: 'commit-helper',
              description: 'x',
              context: 'inline',
              body: '# commit-helper\n\nsome body words',
              updatedAt: _t,
            ),
          ],
        );
        await tester.pumpWidget(
          host(
            repo,
            (isSkill: true, id: 'commit-helper'),
            outline: const [(level: 1, text: 'commit-helper')],
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.text('commit-helper'),
          findsWidgets,
        ); // §1 head = slug identity
        expect(find.text('Outline'), findsOneWidget);
        expect(find.text('Properties'), findsOneWidget);
        expect(
          find.text('Backlinks'),
          findsNothing,
        ); // a skill has no backlinks group 无反链组
        // The frontmatter form is the Properties body (kept mounted, default open). frontmatter 表单=属性组体。
        expect(find.text('Context'), findsOneWidget);
        // WRK-076 F3: the skill glance is now «N files · M bindings · edited» — a single-file,
        // zero-binding skill keeps only the edited segment (zero-speech law).
        // skill 速览带现为「N 文件 · M 绑定 · 编辑」——单文件零绑定只剩编辑段(零人话律)。
        expect(find.textContaining('chars'), findsNothing);
        expect(find.textContaining('files'), findsNothing); // files>1 才显
        expect(find.textContaining('Edited'), findsOneWidget);
        expect(
          find.textContaining('backlinks'),
          findsNothing,
        ); // §2 零人话律: no 反链 segment
      },
    );

    testWidgets(
      'outline row tap fires the jump intent (existing linkage intact)',
      (tester) async {
        final container = ProviderContainer(
          overrides: [
            libraryRepositoryProvider.overrideWithValue(linkedRepo()),
            selectedDocProvider.overrideWith(
              () => _PinnedSelection((isSkill: false, id: 'doc_a')),
            ),
            docOutlineProvider.overrideWith(
              () => _PinnedOutline(const [(level: 1, text: 'Alpha')]),
            ),
          ],
        );
        addTearDown(container.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: TranslationProvider(
              child: MaterialApp(
                theme: AnTheme.light(),
                home: const Scaffold(
                  body: SizedBox(
                    width: 320,
                    height: 640,
                    child: LibraryInspector(),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(container.read(outlineJumpProvider), isNull);
        await tester.tap(find.text('Alpha'));
        await tester.pump();
        expect(
          container.read(outlineJumpProvider)?.index,
          0,
        ); // jumped to heading 0 大纲联动不破坏
      },
    );
  });

  // The group-fold axis persists per-group via the declared `an.right.collapsed.` family. 折叠态持久化。
  group('docGroupCollapseProvider', () {
    test(
      'default = all expanded; toggle persists; a fresh controller restores',
      () {
        final prefs = SettingsPrefs.inMemory();
        final c1 = ProviderContainer(
          overrides: [settingsPrefsProvider.overrideWithValue(prefs)],
        );
        addTearDown(c1.dispose);
        expect(
          c1.read(docGroupCollapseProvider),
          isEmpty,
        ); // nothing collapsed by default
        c1.read(docGroupCollapseProvider.notifier).toggle(kDocGroupProps);
        expect(
          c1.read(docGroupCollapseProvider).contains(kDocGroupProps),
          isTrue,
        );
        // Persisted to the declared family → a fresh controller over the SAME prefs restores the fold.
        // 落盘到声明族 → 新控制器同 prefs 恢复折叠。
        final c2 = ProviderContainer(
          overrides: [settingsPrefsProvider.overrideWithValue(prefs)],
        );
        addTearDown(c2.dispose);
        expect(
          c2.read(docGroupCollapseProvider).contains(kDocGroupProps),
          isTrue,
        );
      },
    );

    test('expandAll / collapseAll walk every group key', () {
      final prefs = SettingsPrefs.inMemory();
      final c = ProviderContainer(
        overrides: [settingsPrefsProvider.overrideWithValue(prefs)],
      );
      addTearDown(c.dispose);
      c.read(docGroupCollapseProvider.notifier).collapseAll();
      expect(c.read(docGroupCollapseProvider), kDocGroups.toSet());
      c.read(docGroupCollapseProvider.notifier).expandAll();
      expect(c.read(docGroupCollapseProvider), isEmpty);
    });
  });
}

const _fnId = 'fn_0123456789abcdef';
const _agId = 'ag_fedcba9876543210';

/// The @ picker's data seam for the editor tests — two entities (strict `<prefix>_<16hex>` ids so the
/// wikilink codec round-trips), name-substring filtered (mirrors the server-side `?search`). @ 数据缝。
class _FakeMentions implements MentionSource {
  @override
  Future<List<MentionCandidate>> search(String query) async {
    const all = [
      MentionCandidate(
        type: 'function',
        id: _fnId,
        name: 'sync_inventory',
        description: 'sync stock',
      ),
      MentionCandidate(
        type: 'agent',
        id: _agId,
        name: 'report_writer',
        description: 'writes reports',
      ),
    ];
    final q = query.toLowerCase();
    return [
      for (final c in all)
        if (q.isEmpty || c.name.toLowerCase().contains(q)) c,
    ];
  }

  @override
  Future<Map<String, String>> resolveNames(List<String> ids) async => {
    for (final id in ids)
      if (id == _fnId)
        id: 'sync_inventory'
      else if (id == _agId)
        id: 'report_writer',
  };
}

class _PinnedSelection extends SelectedDocController {
  _PinnedSelection(this._seed);
  final DocSelection? _seed;
  @override
  DocSelection? build() => _seed;
}

/// Seeds [docOutlineProvider] (normally fed by the editor view, absent in an inspector-only test) so the
/// Outline group renders. 播种大纲(编辑视图喂,纯检查器测缺席),使大纲组渲染。
class _PinnedOutline extends DocOutlineController {
  _PinnedOutline(this._seed);
  final List<DocOutlineEntry> _seed;
  @override
  List<DocOutlineEntry> build() => _seed;
}

/// Pins [focusNewDocTitleProvider] to a seed so a title-autofocus flag can be tested without the rail's
/// create flow. 钉住标题聚焦标记,免走 rail 创建流程即可测。
class _PinnedFocus extends FocusNewDocTitle {
  _PinnedFocus(this._seed);
  final String? _seed;
  @override
  String? build() => _seed;
}

/// A fixture that counts create calls + records the last created id/parent — the B2/B3 create batteries.
/// 计数创建 + 记最后创建 id/parent 的 fixture(B2/B3 创建电池)。
class _CountingDocsRepo extends FixtureLibraryRepository {
  _CountingDocsRepo({super.documents, super.skills});

  int createCount = 0;
  String? lastCreatedId;
  String? lastCreatedParent;

  @override
  Future<DocumentNode> createDocument({
    required String name,
    String? parentId,
    String content = '',
    String description = '',
    List<String> tags = const [],
  }) async {
    createCount++;
    lastCreatedParent = parentId;
    final node = await super.createDocument(
      name: name,
      parentId: parentId,
      content: content,
      description: description,
      tags: tags,
    );
    lastCreatedId = node.id;
    return node;
  }
}

/// A fixture whose lifecycle stream the test drives by hand, counting refetches. 手动驱动信号流的 fixture,计数重取。
class _SignallingRepo extends FixtureLibraryRepository {
  _SignallingRepo()
    : super(
        documents: [
          DocumentNode(id: 'doc_a', name: 'A', createdAt: _t, updatedAt: _t),
        ],
        skills: [_skill('triage')],
      );

  final _signals = StreamController<LibrarySignal>.broadcast();
  int treeFetches = 0;
  int skillFetches = 0;
  int docGets = 0;
  int skillGets = 0;

  // Default action `created` = the structural tier (full refetch), matching the old string-only
  // signal semantics; `updated` + a held id exercises the in-place patch tier (S4).
  // 默认 created=结构档(整取),与旧字符串信号同义;updated+已持有 id 走就地补档(S4)。
  void emit(String domain, {String action = 'created', String id = ''}) =>
      _signals.add((domain: domain, action: action, id: id));

  @override
  Stream<LibrarySignal> lifecycleSignals() => _signals.stream;

  @override
  Future<List<DocumentNode>> getTree() {
    treeFetches++;
    return super.getTree();
  }

  @override
  Future<List<Skill>> listSkills() {
    skillFetches++;
    return super.listSkills();
  }

  @override
  Future<DocumentNode> getDocument(String id) {
    docGets++;
    return super.getDocument(id);
  }

  @override
  Future<Skill> getSkill(String name) {
    skillGets++;
    return super.getSkill(name);
  }
}

/// Pins the skill-file selection to null (manifest view) — widget tests carry no real router.
/// 把 skill 文件选区钉为 null(清单视图)——widget 测试无真 router。
class _PinnedSkillFile extends SelectedSkillFileController {
  @override
  String? build() => null;
}
