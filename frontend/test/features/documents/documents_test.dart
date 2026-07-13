import 'dart:async';

import 'package:anselm/core/contract/entities/document.dart';
import 'package:anselm/core/contract/entities/skill.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/router/navigation.dart';
import 'package:anselm/core/entity/mention_source.dart';
import 'package:anselm/features/documents/ui/an_document_editor.dart';
import 'package:super_text_layout/super_text_layout.dart' show BlinkController;
import 'package:anselm/core/ui/an_sidebar_list.dart' show AnRowDropZone;
import 'package:anselm/features/documents/data/document_fixtures.dart';
import 'package:anselm/features/documents/data/document_repository.dart';
import 'package:anselm/features/documents/state/document_state.dart';
import 'package:anselm/features/documents/ui/document_ocean.dart';
import 'package:anselm/features/documents/ui/document_rail.dart';
import 'package:anselm/features/documents/ui/document_rail_model.dart';
import 'package:anselm/features/documents/ui/documents_inspector.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/router_harness.dart';

final _t = DateTime.utc(2026, 7, 5);

DocumentNode _doc(String id, String? parent, String name, int pos, {String content = ''}) => DocumentNode(
    id: id, parentId: parent, name: name, position: pos, content: content, createdAt: _t, updatedAt: _t);

Skill _skill(String name) => Skill(name: name, description: 'x', context: 'inline', body: '# $name', updatedAt: _t);

const _labels = DocRailLabels(
    documents: 'Documents', skills: 'Skills', untitled: 'Untitled', newLabel: 'New', filter: 'Filter');

FixtureDocumentsRepository _repo() => FixtureDocumentsRepository(
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
Widget _host(FixtureDocumentsRepository repo, Widget child, {String initialLocation = '/'}) {
  final router = buildTestRouter(
    initialLocation: initialLocation,
    page: Scaffold(body: SizedBox(width: 320, height: 640, child: child)),
  );
  return ProviderScope(
    overrides: [
      documentsRepositoryProvider.overrideWithValue(repo),
      goRouterProvider.overrideWithValue(router),
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

  group('buildDocumentsRailModel', () {
    test('assembles the nested document tree by parentId + a flat skill section', () {
      final model = buildDocumentsRailModel(
        [
          _doc('doc_a', null, 'Getting Started', 0),
          _doc('doc_b', 'doc_a', 'Setup', 1),
          _doc('doc_c', 'doc_a', 'Concepts', 0), // lower position → sorts first
          _doc('doc_d', null, 'Playbooks', 1),
        ],
        [_skill('commit-helper')],
        _labels,
      );
      final types = model.groups.single.types;
      expect(types.map((t) => t.label), ['Documents', 'Skills']);
      final docRows = types[0].rows;
      expect(docRows.map((r) => r.id), ['doc_a', 'doc_d']); // two roots, position-ordered
      // doc_a's children sort by position: Concepts(0) before Setup(1). 子按 position 排。
      expect(docRows[0].children.map((r) => r.label), ['Concepts', 'Setup']);
      expect(docRows[0].hasChildren, isTrue);
      // Skills flat, id namespaced. skill 扁平、id 加前缀。
      expect(types[1].rows.single.id, 'skill:commit-helper');
    });

    test('unnamed document falls back to the untitled label', () {
      final model = buildDocumentsRailModel([_doc('doc_x', null, '', 0)], const [], _labels);
      expect(model.groups.single.types[0].rows.single.label, 'Untitled');
    });

    test('docSelectionForRowId disambiguates skills by prefix', () {
      expect(docSelectionForRowId('doc_a'), (isSkill: false, id: 'doc_a'));
      expect(docSelectionForRowId('skill:triage'), (isSkill: true, id: 'triage'));
    });
  });

  group('DocumentRail', () {
    testWidgets('renders the document tree + skills', (tester) async {
      await tester.pumpWidget(_host(_repo(), const DocumentRail()));
      await tester.pump();
      await tester.pump();
      expect(find.text('Getting Started'), findsOneWidget);
      expect(find.text('Playbooks'), findsOneWidget);
      expect(find.text('commit-helper'), findsOneWidget);
    });

    testWidgets('selecting a document drives selectedDocProvider', (tester) async {
      late WidgetRef ref;
      await tester.pumpWidget(_host(
        _repo(),
        Consumer(builder: (_, r, _) {
          ref = r;
          return const DocumentRail();
        }),
      ));
      await tester.pump();
      await tester.pump();
      expect(ref.read(selectedDocProvider), isNull);
      await tester.tap(find.text('Getting Started'));
      await tester.pump();
      expect(ref.read(selectedDocProvider), (isSkill: false, id: 'doc_a'));
    });

    testWidgets('the New row creates a root page and selects it', (tester) async {
      final repo = _repo();
      late WidgetRef ref;
      await tester.pumpWidget(_host(
        repo,
        Consumer(builder: (_, r, _) {
          ref = r;
          return const DocumentRail();
        }),
      ));
      await tester.pump();
      await tester.pump();
      final before = (await repo.getTree()).length;
      await tester.tap(find.text('New page')); // the New row label (B9: unified to "New <thing>") 新建行标签
      await tester.pumpAndSettle();
      final tree = await repo.getTree();
      // A new root page was created and became the selection (dropping into inline-rename). 新根页建成+选中。
      expect(tree.length, before + 1);
      final sel = ref.read(selectedDocProvider);
      expect(sel, isNotNull);
      expect(sel!.isSkill, isFalse);
      expect(tree.any((d) => d.id == sel.id && d.parentId == null), isTrue);
    });
  });

  group('DocumentOcean', () {
    testWidgets('no selection → the pick empty state', (tester) async {
      await tester.pumpWidget(_host(_repo(), const DocumentOcean()));
      await tester.pump();
      expect(find.text(t.documents.pickTitle), findsOneWidget);
    });

    testWidgets('a selected document opens in the native editor with its content + meta', (tester) async {
      final repo = _repo();
      await tester.pumpWidget(ProviderScope(
        overrides: [
          documentsRepositoryProvider.overrideWithValue(repo),
          selectedDocProvider.overrideWith(() => _PinnedSelection((isSkill: false, id: 'doc_a'))),
          mentionSourceProvider.overrideWithValue(_FakeMentions()),
        ],
        child: TranslationProvider(
          child: MaterialApp(
            theme: AnTheme.light(),
            home: const Scaffold(body: DocumentOcean()),
          ),
        ),
      ));
      await tester.pumpAndSettle(); // resolve the async mention-name batch, then mount the editor 解析提及名后挂载
      // The native editor mounts with the doc's props (its header is Flutter now). 原生编辑器带 doc props 挂载。
      final editor = tester.widget<AnDocumentEditor>(find.byType(AnDocumentEditor));
      expect(editor.name, 'Getting Started');
      expect(editor.crumb, t.documents.documents);
      expect(editor.initialMarkdown, contains('# Hello'));
      expect(editor.nameEditable, isTrue);
      expect(editor.mentionSource, isNotNull);
    });

    testWidgets('a selected skill opens read-only-name with its body', (tester) async {
      final repo = _repo();
      await tester.pumpWidget(ProviderScope(
        overrides: [
          documentsRepositoryProvider.overrideWithValue(repo),
          selectedDocProvider.overrideWith(() => _PinnedSelection((isSkill: true, id: 'commit-helper'))),
          mentionSourceProvider.overrideWithValue(_FakeMentions()),
        ],
        child: TranslationProvider(
          child: MaterialApp(theme: AnTheme.light(), home: const Scaffold(body: DocumentOcean())),
        ),
      ));
      await tester.pumpAndSettle();
      final editor = tester.widget<AnDocumentEditor>(find.byType(AnDocumentEditor));
      expect(editor.name, 'commit-helper');
      expect(editor.crumb, t.documents.skills);
      expect(editor.nameEditable, isFalse); // the skill name IS its identity — not renamable. 名即身份。
      expect(editor.initialMarkdown, contains('commit-helper')); // the skill body '# commit-helper'
      expect(editor.mentionSource, isNull); // no @ mentions on skills. skill 不接 @。
    });

    testWidgets('an edit within the autosave window is FLUSHED on unmount — no data loss (P5, C-001 area)',
        (tester) async {
      final repo = _repo();
      await tester.pumpWidget(ProviderScope(
        overrides: [
          documentsRepositoryProvider.overrideWithValue(repo),
          selectedDocProvider.overrideWith(() => _PinnedSelection((isSkill: false, id: 'doc_a'))),
          mentionSourceProvider.overrideWithValue(_FakeMentions()),
        ],
        child: TranslationProvider(
          child: MaterialApp(theme: AnTheme.light(), home: const Scaffold(body: DocumentOcean())),
        ),
      ));
      await tester.pumpAndSettle();
      // Simulate a content edit (drives DocumentOcean._onChanged → schedules the 600ms autosave). The
      // editor's onChangedMarkdown IS the ocean's _onChanged. 模拟正文编辑→排 600ms 自动保存。
      tester.widget<AnDocumentEditor>(find.byType(AnDocumentEditor)).onChangedMarkdown(
          '# Edited\n\nthe last line, typed just before switching away');
      // Unmount BEFORE the 600ms autosave fires — the old bug CANCELLED the pending save here, dropping
      // the edit. The fix FLUSHES it in dispose. 600ms 内卸载(旧 bug 在此丢存,修复在 dispose flush)。
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(); // let the flushed async save complete 让 flush 的异步存完成
      final saved = await repo.getDocument('doc_a');
      expect(saved.content, '# Edited\n\nthe last line, typed just before switching away',
          reason: 'dispose must FLUSH the pending autosave — the last edit must persist, not be dropped');
    });
  });

  group('planDocMove', () {
    // Seed shape: doc_a(root,0){doc_b(0), doc_c(1)} · doc_d(root,1). 种子:两根、doc_a 携两子。
    List<DocumentNode> tree() => [
          _doc('doc_a', null, 'Getting Started', 0),
          _doc('doc_b', 'doc_a', 'Setup', 0),
          _doc('doc_c', 'doc_a', 'Concepts', 1),
          _doc('doc_d', null, 'Playbooks', 1),
        ];

    test('inside → nest under the target, position omitted (backend appends)', () {
      expect(planDocMove(tree(), 'doc_d', 'doc_a', AnRowDropZone.inside),
          (parentId: 'doc_a', position: null));
    });

    test('above/below → the target parent + index among siblings EXCLUDING the dragged node', () {
      expect(planDocMove(tree(), 'doc_d', 'doc_b', AnRowDropZone.above), (parentId: 'doc_a', position: 0));
      expect(planDocMove(tree(), 'doc_d', 'doc_b', AnRowDropZone.below), (parentId: 'doc_a', position: 1));
      expect(planDocMove(tree(), 'doc_d', 'doc_c', AnRowDropZone.below), (parentId: 'doc_a', position: 2));
    });

    test('same-parent reorder excludes the dragged node from the index space', () {
      // Root siblings excluding doc_a = [doc_d] → dropping doc_a below doc_d = position 1. 剔除自身后计序。
      expect(planDocMove(tree(), 'doc_a', 'doc_d', AnRowDropZone.below), (parentId: null, position: 1));
      expect(planDocMove(tree(), 'doc_d', 'doc_a', AnRowDropZone.above), (parentId: null, position: 0));
    });

    test('cycles are refused: into or beside the dragged node\'s own subtree', () {
      expect(planDocMove(tree(), 'doc_a', 'doc_b', AnRowDropZone.inside), isNull);
      expect(planDocMove(tree(), 'doc_a', 'doc_b', AnRowDropZone.below), isNull);
    });

    test('self, unknown ids and skill rows are refused', () {
      expect(planDocMove(tree(), 'doc_a', 'doc_a', AnRowDropZone.inside), isNull);
      expect(planDocMove(tree(), 'doc_a', 'nope', AnRowDropZone.inside), isNull);
      expect(planDocMove(tree(), 'skill:triage', 'doc_a', AnRowDropZone.inside), isNull);
      expect(planDocMove(tree(), 'doc_a', 'skill:triage', AnRowDropZone.inside), isNull);
    });

    test('a malformed parent loop in the data is refused, not spun on', () {
      final looped = [
        _doc('doc_x', 'doc_y', 'X', 0),
        _doc('doc_y', 'doc_x', 'Y', 0),
        _doc('doc_z', null, 'Z', 0),
      ];
      expect(planDocMove(looped, 'doc_z', 'doc_x', AnRowDropZone.above), isNull);
    });
  });

  group('DocumentRail drag-reorder', () {
    // A real pointer drag: grab the source row, nudge to arm the drag recognizer, glide to the target
    // offset, release. 真手势:按住源行→微移触发识别→滑到目标点→松手。
    Future<void> drag(WidgetTester tester, String fromLabel, Offset to) async {
      final g = await tester.startGesture(tester.getCenter(find.text(fromLabel)));
      await tester.pump(const Duration(milliseconds: 20));
      await g.moveBy(const Offset(0, 6));
      await tester.pump(const Duration(milliseconds: 20));
      await g.moveTo(to);
      await tester.pump(const Duration(milliseconds: 20));
      await g.up();
      await tester.pumpAndSettle();
    }

    testWidgets('dropping on a row\'s middle nests the page under it', (tester) async {
      final repo = _repo();
      await tester.pumpWidget(_host(repo, const DocumentRail()));
      await tester.pump();
      await tester.pump();
      // 'Playbooks' (root) onto the CENTER of 'Getting Started' → inside → reparent. 中段=嵌入。
      await drag(tester, 'Playbooks', tester.getCenter(find.text('Getting Started')));
      expect((await repo.getDocument('doc_d')).parentId, 'doc_a');
    });

    testWidgets('dropping on a row\'s top edge reorders above it', (tester) async {
      final repo = _repo();
      await tester.pumpWidget(_host(repo, const DocumentRail()));
      await tester.pump();
      await tester.pump();
      // 'Playbooks' onto the TOP QUARTER of 'Getting Started' → above → root position 0. 上缘=前插。
      await drag(tester, 'Playbooks', tester.getCenter(find.text('Getting Started')) - const Offset(0, 12));
      final moved = await repo.getDocument('doc_d');
      expect(moved.parentId, isNull);
      expect(moved.position, 0);
      expect((await repo.getDocument('doc_a')).position, 1); // shifted sibling 让位兄弟顺移
    });

    testWidgets('dropping a page into its own subtree is refused (cycle)', (tester) async {
      final repo = _repo();
      await tester.pumpWidget(_host(repo, const DocumentRail()));
      await tester.pump();
      await tester.pump();
      await drag(tester, 'Getting Started', tester.getCenter(find.text('Setup')));
      // Nothing moved. 未动。
      expect((await repo.getDocument('doc_a')).parentId, isNull);
      expect((await repo.getDocument('doc_b')).parentId, 'doc_a');
    });

    testWidgets('dragging a branch\'s first child onto its parent\'s bottom edge is an identity move', (tester) async {
      final repo = _repo();
      await tester.pumpWidget(_host(repo, const DocumentRail()));
      await tester.pump();
      await tester.pump();
      // 'Setup' IS doc_a's first child; below-on-open-branch normalizes to "above first child" = itself —
      // the primitive must emit nothing (adversarial-review regression). 首子拖到父行下缘=恒等移动,不派发。
      await drag(tester, 'Setup', tester.getCenter(find.text('Getting Started')) + const Offset(0, 12));
      final b = await repo.getDocument('doc_b');
      expect(b.parentId, 'doc_a');
      expect(b.position, 0);
    });

    testWidgets('drag is disabled while the filter query is active', (tester) async {
      final repo = _repo();
      await tester.pumpWidget(_host(repo, const DocumentRail()));
      await tester.pump();
      await tester.pump();
      // The query force-expands + hides rows — indicators/position math would lie, so rows must not drag
      // (adversarial-review regression). 过滤时强展开+藏行,指示会撒谎——行必须不可拖。
      await tester.enterText(find.byType(EditableText).first, 'o'); // matches several rows 命中若干行
      await tester.pump();
      await drag(tester, 'Playbooks', tester.getCenter(find.text('Getting Started')));
      expect((await repo.getDocument('doc_d')).parentId, isNull); // unchanged 未动
    });
  });

  group('SSE-driven refresh', () {
    testWidgets('a document.* signal refetches the tree (debounced, burst-collapsed); skill signals do not',
        (tester) async {
      final repo = _SignallingRepo();
      final container = ProviderContainer(overrides: [documentsRepositoryProvider.overrideWithValue(repo)]);
      addTearDown(container.dispose);
      final sub = container.listen(documentTreeProvider, (_, _) {});
      addTearDown(sub.close);
      await container.read(documentTreeProvider.future);
      expect(repo.treeFetches, 1);

      // A burst of document signals (the typing-save echo shape) collapses into ONE refetch. 突发合一。
      repo.emit('document');
      repo.emit('document');
      await tester.pump(const Duration(milliseconds: 500)); // past the 400ms debounce 过去抖
      await container.read(documentTreeProvider.future);
      expect(repo.treeFetches, 2);

      // A skill signal must NOT refetch the tree. skill 信号不动树。
      repo.emit('skill');
      await tester.pump(const Duration(milliseconds: 500));
      await container.read(documentTreeProvider.future);
      expect(repo.treeFetches, 2);
    });

    testWidgets('a skill.* signal refetches the skill list', (tester) async {
      final repo = _SignallingRepo();
      final container = ProviderContainer(overrides: [documentsRepositoryProvider.overrideWithValue(repo)]);
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
  });

  group('DocumentsInspector', () {
    Widget host(FixtureDocumentsRepository repo, DocSelection sel) => ProviderScope(
          overrides: [
            documentsRepositoryProvider.overrideWithValue(repo),
            selectedDocProvider.overrideWith(() => _PinnedSelection(sel)),
          ],
          child: TranslationProvider(
            child: MaterialApp(
              theme: AnTheme.light(),
              home: const Scaffold(body: SizedBox(width: 320, height: 640, child: DocumentsInspector())),
            ),
          ),
        );

    testWidgets('a page panel keeps only outline / file meta / backlinks (no property form)', (tester) async {
      final repo = _repo();
      await tester.pumpWidget(host(repo, (isSkill: false, id: 'doc_a')));
      await tester.pumpAndSettle();
      // File meta + backlinks stay; the page's OWN properties (name/description/tags) edit in the
      // CENTER under the big title now. 文件 meta+反链留;页自身属性(名/描述/标签)已归中心大标题下。
      expect(find.text('Modified'), findsOneWidget);
      expect(find.text('BACKLINKS'), findsOneWidget); // AnGroupLabel 大写脸(批6 A-081)
      expect(find.text('Name'), findsNothing);
      expect(find.text('Tags'), findsNothing);
      expect(find.byType(EditableText), findsNothing); // nothing edits on this panel anymore 本岛无输入
    });

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

    testWidgets('backlinks list the linking pages; a tap navigates to the linker', (tester) async {
      // doc_d's body wikilinks doc_a → doc_a's panel lists 'Playbooks' as a backlink. doc_d 链 doc_a。
      final repo = FixtureDocumentsRepository(
        documents: [
          _doc('doc_a', null, 'Getting Started', 0),
          _doc('doc_d', null, 'Playbooks', 1, content: 'see [[doc_a]] first'),
        ],
        skills: const [],
      );
      final router = buildTestRouter(page: const Scaffold(body: SizedBox(width: 320, height: 640, child: DocumentsInspector())));
      await tester.pumpWidget(ProviderScope(
        overrides: [
          documentsRepositoryProvider.overrideWithValue(repo),
          goRouterProvider.overrideWithValue(router),
          selectedDocProvider.overrideWith(() => _PinnedSelection((isSkill: false, id: 'doc_a'))),
        ],
        child: TranslationProvider(
          child: MaterialApp.router(theme: AnTheme.light(), routerConfig: router),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('BACKLINKS'), findsOneWidget); // AnGroupLabel 大写脸(批6 A-081)
      expect(find.text('Playbooks'), findsOneWidget);

      await tester.tap(find.text('Playbooks'));
      await tester.pumpAndSettle();
      expect(router.routerDelegate.currentConfiguration.uri.path, '/documents/doc_d'); // navigated 导航到链接方
    });

    testWidgets('editing a skill CONFIG field PUTs the whole frontmatter, keeping body + description',
        (tester) async {
      // A FORK skill so the agent field (the island's only text input) shows — identity/description
      // edit in the center now. fork skill 才有 agent 输入(本岛唯一文本框);身份/描述已归中心。
      final repo = FixtureDocumentsRepository(documents: const [], skills: [
        Skill(
          name: 'commit-helper',
          description: 'x',
          context: 'fork',
          body: '# commit-helper',
          frontmatter: const Frontmatter(name: 'commit-helper', context: 'fork', agent: 'coder'),
          updatedAt: _t,
        ),
      ]);
      final before = await repo.getSkill('commit-helper');
      await tester.pumpWidget(host(repo, (isSkill: true, id: 'commit-helper')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(EditableText).first, 'reviewer');
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
      final after = await repo.getSkill('commit-helper');
      expect(after.frontmatter.agent, 'reviewer');
      expect(after.body, before.body); // the untouched body survives the full-replace PUT. body 不被抹。
      expect(after.description, before.description); // …and so does the center-owned description. 描述不被抹。
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
      MentionCandidate(type: 'function', id: _fnId, name: 'sync_inventory', description: 'sync stock'),
      MentionCandidate(type: 'agent', id: _agId, name: 'report_writer', description: 'writes reports'),
    ];
    final q = query.toLowerCase();
    return [for (final c in all) if (q.isEmpty || c.name.toLowerCase().contains(q)) c];
  }

  @override
  Future<Map<String, String>> resolveNames(List<String> ids) async =>
      {for (final id in ids) if (id == _fnId) id: 'sync_inventory' else if (id == _agId) id: 'report_writer'};
}

class _PinnedSelection extends SelectedDocController {
  _PinnedSelection(this._seed);
  final DocSelection _seed;
  @override
  DocSelection? build() => _seed;
}

/// A fixture whose lifecycle stream the test drives by hand, counting refetches. 手动驱动信号流的 fixture,计数重取。
class _SignallingRepo extends FixtureDocumentsRepository {
  _SignallingRepo()
      : super(documents: [
          DocumentNode(id: 'doc_a', name: 'A', createdAt: _t, updatedAt: _t),
        ], skills: [
          _skill('triage'),
        ]);

  final _signals = StreamController<String>.broadcast();
  int treeFetches = 0;
  int skillFetches = 0;

  void emit(String domain) => _signals.add(domain);

  @override
  Stream<String> lifecycleSignals() => _signals.stream;

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
}
