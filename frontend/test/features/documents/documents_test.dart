import 'dart:async';

import 'package:anselm/core/contract/entities/document.dart';
import 'package:anselm/core/contract/entities/skill.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/router/navigation.dart';
import 'package:anselm/core/entity/mention_source.dart';
import 'package:anselm/core/ui/an_doc_editor.dart';
import 'package:anselm/core/ui/an_mention_picker.dart';
import 'package:anselm/core/ui/an_sidebar_list.dart' show AnRowDropZone;
import 'package:anselm/core/ui/entity_ref_codec.dart';
import 'package:anselm/features/documents/data/document_fixtures.dart';
import 'package:anselm/features/documents/data/document_repository.dart';
import 'package:anselm/features/documents/state/document_state.dart';
import 'package:anselm/features/documents/ui/document_ocean.dart';
import 'package:anselm/features/documents/ui/document_rail.dart';
import 'package:anselm/features/documents/ui/document_rail_model.dart';
import 'package:anselm/features/documents/ui/documents_inspector.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
// super_editor_test carries the caret/IME robot (placeCaretInParagraph / typeImeText) + the inspector.
import 'package:super_editor/super_editor.dart' show TextComponent;
import 'package:super_editor/super_editor_test.dart';
import 'package:super_text_layout/super_text_layout.dart' show BlinkController;

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
      await tester.tap(find.text('New'));
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

    testWidgets('a selected document opens in the editable AnDocEditor', (tester) async {
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
      await tester.pump();
      await tester.pump();
      // The doc opens in the Notion editor (super_editor renders text via its own layout, not a plain
      // Text, so assert the editor is mounted + the title bar shows the doc name). 文档进可编辑器。
      expect(find.byType(AnDocEditor), findsOneWidget);
      expect(find.text('Getting Started'), findsOneWidget); // the title bar (doc name)
    });

    testWidgets('a selected skill opens editable; a body edit PUTs keeping the frontmatter', (tester) async {
      BlinkController.indeterminateAnimationsEnabled = false;
      addTearDown(() => BlinkController.indeterminateAnimationsEnabled = true);
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
      await tester.pump();
      await tester.pump();
      expect(find.byType(AnDocEditor), findsOneWidget); // the skill body is editable now. skill 正文可编。

      // Type into the body, wait past the 600ms save debounce: the PUT must carry the body edit AND the
      // untouched frontmatter (read-modify-write — the inspector is a second writer). 编辑落 PUT、frontmatter 不丢。
      final nodeId = SuperEditorInspector.findDocument()!.first.id;
      final len = SuperEditorInspector.findTextInComponent(nodeId).length;
      await tester.placeCaretInParagraph(nodeId, len);
      await tester.typeImeText('!');
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();

      final after = await repo.getSkill('commit-helper');
      expect(after.body, contains('!'));
      expect(after.description, 'x'); // untouched frontmatter fields survive. 未动的 frontmatter 字段存活。
      expect(after.context, 'inline');
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
      expect(find.text('Backlinks'), findsOneWidget);
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
      expect(find.text('Backlinks'), findsOneWidget);
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

  group('AnDocEditor @ mentions', () {
    // Drives the real super_editor IME + caret so the @ typeahead runs end-to-end: type `@sy`, the
    // caret-anchored panel opens with the name-filtered candidate, a pick commits `@sync_inventory` into
    // the serialized markdown and closes the panel. 真驱动 IME/光标,@ 预输入端到端:打 @sy→面板→选→落 markdown。
    // super_editor's caret blink is an indefinite Ticker, which forces Flutter into a perpetual-frame mode
    // so pumpAndSettle (used inside placeCaretInParagraph) never settles. This is super_editor's own test
    // knob to switch it off. 光标闪烁是永久 Ticker→逼永久帧→pumpAndSettle 永不静;这是 super_editor 官方测试开关。
    void disableCaretBlink() {
      BlinkController.indeterminateAnimationsEnabled = false;
      addTearDown(() => BlinkController.indeterminateAnimationsEnabled = true);
    }

    testWidgets('typing @ opens the picker; a pick commits the mention + closes it', (tester) async {
      disableCaretBlink();
      String? lastMd;
      await tester.pumpWidget(TranslationProvider(
        child: MaterialApp(
          theme: AnTheme.light(),
          home: Scaffold(
            body: SizedBox(
              width: 720,
              height: 600,
              child: AnDocEditor(
                initialMarkdown: 'Draft: ',
                autofocus: true,
                mentionSource: _FakeMentions(),
                onChanged: (m) => lastMd = m,
              ),
            ),
          ),
        ),
      ));
      await tester.pump();

      // Place the caret at the end of the single "Draft: " paragraph, then type the @ trigger + query.
      final paragraphId = SuperEditorInspector.findDocument()!.first.id;
      await tester.placeCaretInParagraph(paragraphId, 'Draft: '.length);
      await tester.typeImeText('@sy');
      await tester.pumpAndSettle();

      // The panel is up, filtered to the name-matching candidate (report_writer doesn't match "sy").
      expect(find.byType(AnMentionPanel), findsOneWidget);
      expect(find.text('sync_inventory'), findsOneWidget);
      expect(find.text('report_writer'), findsNothing);

      await tester.tap(find.text('sync_inventory'));
      await tester.pumpAndSettle();

      // Picked → panel closed; the mention serializes to the backend `[[id]]` wikilink (the display name is
      // dropped, the bare id survives — what pkg/wikilink reads to build link edges). 选中→关、落 `[[id]]` 线缆形。
      expect(find.byType(AnMentionPanel), findsNothing);
      expect(lastMd, contains('[[$_fnId]]'));
      expect(lastMd, isNot(contains('@'))); // the `@` trigger is gone — the chip is the bare name. 无 @。
    });

    // The window-bottom FLIP — the real-machine walkthrough caught the panel hanging below a caret near the
    // window bottom, pushing the menu off-screen. With more space above than below, the panel must flip
    // ABOVE the trigger line and stay fully inside the window. 窗口底部翻转回归:下方装不下即翻上方、整板在屏内。
    testWidgets('the @ panel flips above a caret near the window bottom (never off-screen)', (tester) async {
      disableCaretBlink();
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(720, 300);
      addTearDown(tester.view.reset);
      final filler = List.generate(8, (i) => 'Paragraph $i').join('\n\n');
      await tester.pumpWidget(TranslationProvider(
        child: MaterialApp(
          theme: AnTheme.light(),
          home: Scaffold(
            body: AnDocEditor(
              initialMarkdown: '$filler\n\nDraft: ',
              autofocus: true,
              mentionSource: _FakeMentions(),
            ),
          ),
        ),
      ));
      await tester.pump();

      final lastId = SuperEditorInspector.findDocument()!.last.id;
      await tester.placeCaretInParagraph(lastId, 'Draft: '.length);
      await tester.typeImeText('@sy');
      await tester.pumpAndSettle();

      expect(find.byType(AnMentionPanel), findsOneWidget);
      final panel = tester.getRect(find.byType(AnMentionPanel));
      // The trigger lives in the LAST paragraph (super_editor text isn't visible to text finders).
      // 触发行=末段组件(super_editor 文本对 text finder 不可见)。
      final caretLine = tester.getRect(find.byType(TextComponent).last);
      expect(panel.bottom, lessThanOrEqualTo(caretLine.top + 1),
          reason: 'panel must sit ABOVE the trigger line when below-space runs out');
      expect(panel.top, greaterThanOrEqualTo(0), reason: 'panel must stay fully on-screen');
    });

    // The wikilink round-trip: a document loaded with the EXPANDED editor form (what document_ocean produces
    // from stored `[[id]]` + resolved names) must serialize back to the bare `[[id]]` wire form on edit.
    // wikilink 往返:载入编辑内展开形(document_ocean 由 `[[id]]`+名产)→编辑→存回裸 `[[id]]`。
    testWidgets('a loaded [name](anselm-entity:id) link round-trips back to [[id]] on save', (tester) async {
      disableCaretBlink();
      String? lastMd;
      const expanded = 'Owner [sync_inventory]($kEntityRefScheme:$_fnId) ships it';
      await tester.pumpWidget(TranslationProvider(
        child: MaterialApp(
          theme: AnTheme.light(),
          home: Scaffold(
            body: SizedBox(
              width: 720,
              height: 600,
              child: AnDocEditor(
                initialMarkdown: expanded,
                autofocus: true,
                mentionSource: _FakeMentions(),
                onChanged: (m) => lastMd = m,
              ),
            ),
          ),
        ),
      ));
      await tester.pump();

      // Edit (type a space at the end) to fire onChanged, then assert the link collapsed to `[[id]]`.
      final nodeId = SuperEditorInspector.findDocument()!.first.id;
      final end = SuperEditorInspector.findTextInComponent(nodeId).length;
      await tester.placeCaretInParagraph(nodeId, end);
      await tester.typeImeText('!');
      await tester.pumpAndSettle();

      expect(lastMd, contains('[[$_fnId]]'));
      expect(lastMd, isNot(contains(kEntityRefScheme))); // the in-editor link scheme never persists. 链接 scheme 不落盘。
    });

    testWidgets('Escape dismisses the picker without inserting', (tester) async {
      disableCaretBlink();
      await tester.pumpWidget(TranslationProvider(
        child: MaterialApp(
          theme: AnTheme.light(),
          home: Scaffold(
            body: SizedBox(
              width: 720,
              height: 600,
              child: AnDocEditor(initialMarkdown: 'Draft: ', autofocus: true, mentionSource: _FakeMentions()),
            ),
          ),
        ),
      ));
      await tester.pump();
      final paragraphId = SuperEditorInspector.findDocument()!.first.id;
      await tester.placeCaretInParagraph(paragraphId, 'Draft: '.length);
      await tester.typeImeText('@sy');
      await tester.pumpAndSettle();
      expect(find.byType(AnMentionPanel), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(AnMentionPanel), findsNothing);
    });

    // The `/` slash block menu — type `/head`, the same shared popover opens filtered to the heading
    // options, and picking Heading 1 submits (deletes `/head`) + converts the block → markdown `# `.
    // `/` 块菜单:打 /head→同一 popover 过滤到标题→选 H1→删 /head + 变块→markdown 起始 `# `。
    testWidgets('typing / opens the block menu; a pick converts the block', (tester) async {
      disableCaretBlink();
      String? lastMd;
      await tester.pumpWidget(TranslationProvider(
        child: MaterialApp(
          theme: AnTheme.light(),
          home: Scaffold(
            body: SizedBox(
              width: 720,
              height: 600,
              child: AnDocEditor(
                initialMarkdown: 'Draft ',
                autofocus: true,
                slashLabels: _slashTestLabels,
                onChanged: (m) => lastMd = m,
              ),
            ),
          ),
        ),
      ));
      await tester.pump();

      final paragraphId = SuperEditorInspector.findDocument()!.first.id;
      await tester.placeCaretInParagraph(paragraphId, 'Draft '.length);
      await tester.typeImeText('/head');
      await tester.pumpAndSettle();

      // Panel up, filtered to the heading options ("Bulleted list" doesn't match "head").
      expect(find.byType(AnMentionPanel), findsOneWidget);
      expect(find.text('Heading 1'), findsOneWidget);
      expect(find.text('Bulleted list'), findsNothing);

      await tester.tap(find.text('Heading 1'));
      await tester.pumpAndSettle();

      // Picked → panel closed, the `/head` text is gone and the block is now a header. 选中→关、块变标题。
      expect(find.byType(AnMentionPanel), findsNothing);
      expect(lastMd, startsWith('# '));
      expect(lastMd, contains('Draft'));
      expect(lastMd, isNot(contains('/head')));
    });

    testWidgets('/ then Bulleted list converts to a list item', (tester) async {
      disableCaretBlink();
      String? lastMd;
      await tester.pumpWidget(TranslationProvider(
        child: MaterialApp(
          theme: AnTheme.light(),
          home: Scaffold(
            body: SizedBox(
              width: 720,
              height: 600,
              child: AnDocEditor(
                initialMarkdown: 'Milk ',
                autofocus: true,
                slashLabels: _slashTestLabels,
                onChanged: (m) => lastMd = m,
              ),
            ),
          ),
        ),
      ));
      await tester.pump();
      final paragraphId = SuperEditorInspector.findDocument()!.first.id;
      await tester.placeCaretInParagraph(paragraphId, 'Milk '.length);
      await tester.typeImeText('/bul');
      await tester.pumpAndSettle();
      expect(find.text('Bulleted list'), findsOneWidget);
      await tester.tap(find.text('Bulleted list'));
      await tester.pumpAndSettle();
      // Unordered list item → super_editor markdown emits a `*` bullet. 无序列表项(super_editor 用 `*`)。
      expect(lastMd, contains('* Milk'));
      expect(lastMd, isNot(contains('/bul')));
    });

    // The remaining block families — code fence / horizontal rule / GitHub task — all round-trip through
    // the markdown serializer. 其余块族(代码栏/分隔线/待办)全经 markdown 序列化往返。
    Future<String?> slashPick(WidgetTester tester,
        {required String seed, required String query, required String pick}) async {
      String? lastMd;
      await tester.pumpWidget(TranslationProvider(
        child: MaterialApp(
          theme: AnTheme.light(),
          home: Scaffold(
            body: SizedBox(
              width: 720,
              height: 600,
              child: AnDocEditor(
                initialMarkdown: seed,
                autofocus: true,
                slashLabels: _slashTestLabels,
                onChanged: (m) => lastMd = m,
              ),
            ),
          ),
        ),
      ));
      await tester.pump();
      final paragraphId = SuperEditorInspector.findDocument()!.first.id;
      await tester.placeCaretInParagraph(paragraphId, seed.length);
      await tester.typeImeText(query);
      await tester.pumpAndSettle();
      await tester.tap(find.text(pick));
      await tester.pumpAndSettle();
      return lastMd;
    }

    testWidgets('/ Code block converts and serializes to a fenced block', (tester) async {
      disableCaretBlink();
      final md = await slashPick(tester, seed: 'Snippet ', query: '/cod', pick: 'Code block');
      expect(md, contains('```'));
      expect(md, contains('Snippet'));
    });

    testWidgets('/ Divider replaces the block with a rule and typing continues below', (tester) async {
      disableCaretBlink();
      final md = await slashPick(tester, seed: 'Above ', query: '/div', pick: 'Divider');
      expect(md, contains('---'));
      // The caret re-seated into the fresh paragraph after the rule — typing lands there. 光标已落 HR 后新段。
      await tester.typeImeText('below');
      await tester.pumpAndSettle();
      final doc = SuperEditorInspector.findDocument()!;
      expect(SuperEditorInspector.findTextInComponent(doc.last.id).toPlainText(), 'below');
    });

    testWidgets('/ To-do converts to a GitHub task line', (tester) async {
      disableCaretBlink();
      final md = await slashPick(tester, seed: 'Ship ', query: '/to', pick: 'To-do');
      expect(md, contains('- [ ] Ship'));
    });

    // The fence LANGUAGE survives an edit — super_editor's built-in parser drops it (```python would
    // save back as bare ```); the custom converter/serializer pair keeps it on node metadata.
    // 围栏语言在编辑后存活——上游解析器丢弃(```python 存回裸 ```);自定义 converter/serializer 经 metadata 保真。
    testWidgets('a fenced code block round-trips its language tag', (tester) async {
      disableCaretBlink();
      String? lastMd;
      await tester.pumpWidget(TranslationProvider(
        child: MaterialApp(
          theme: AnTheme.light(),
          home: Scaffold(
            body: SizedBox(
              width: 720,
              height: 600,
              child: AnDocEditor(
                initialMarkdown: '```python\nprint(1)\n```',
                autofocus: true,
                onChanged: (m) => lastMd = m,
              ),
            ),
          ),
        ),
      ));
      await tester.pump();
      final nodeId = SuperEditorInspector.findDocument()!.first.id;
      await tester.placeCaretInParagraph(nodeId, 0);
      await tester.typeImeText('# ');
      await tester.pumpAndSettle();
      expect(lastMd, contains('```python')); // the language tag survived the edit 语言标存活
      expect(lastMd, contains('print(1)# ')); // …and the typed chars landed inside the block 输入落块内
    });

    // Chip integrity — a picked mention behaves as ONE token: the caret continues AFTER it, and a
    // backspace at its edge deletes the whole chip. chip 完整性:光标续在其后;缘上退格整删。
    testWidgets('a picked mention seats the caret after the chip; typing continues outside', (tester) async {
      disableCaretBlink();
      String? lastMd;
      await tester.pumpWidget(TranslationProvider(
        child: MaterialApp(
          theme: AnTheme.light(),
          home: Scaffold(
            body: SizedBox(
              width: 720,
              height: 600,
              child: AnDocEditor(
                initialMarkdown: 'Draft: ',
                autofocus: true,
                mentionSource: _FakeMentions(),
                onChanged: (m) => lastMd = m,
              ),
            ),
          ),
        ),
      ));
      await tester.pump();
      final paragraphId = SuperEditorInspector.findDocument()!.first.id;
      await tester.placeCaretInParagraph(paragraphId, 'Draft: '.length);
      await tester.typeImeText('@sy');
      await tester.pumpAndSettle();
      await tester.tap(find.text('sync_inventory'));
      await tester.pumpAndSettle();
      await tester.typeImeText('x');
      await tester.pumpAndSettle();
      // 'x' landed after the chip + its trailing space — never inside the link span. x 落在 chip+空格后。
      expect(lastMd, contains('[[$_fnId]] x'));
    });

    testWidgets('backspace at the chip edge deletes the whole chip', (tester) async {
      disableCaretBlink();
      String? lastMd;
      const expanded = 'Owner [sync_inventory]($kEntityRefScheme:$_fnId) ships';
      await tester.pumpWidget(TranslationProvider(
        child: MaterialApp(
          theme: AnTheme.light(),
          home: Scaffold(
            body: SizedBox(
              width: 720,
              height: 600,
              child: AnDocEditor(
                initialMarkdown: expanded,
                autofocus: true,
                mentionSource: _FakeMentions(),
                onChanged: (m) => lastMd = m,
              ),
            ),
          ),
        ),
      ));
      await tester.pump();
      final nodeId = SuperEditorInspector.findDocument()!.first.id;
      // Caret right at the chip's trailing edge ('Owner sync_inventory|'). 光标贴 chip 尾缘。
      await tester.placeCaretInParagraph(nodeId, 'Owner sync_inventory'.length);
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pumpAndSettle();
      expect(lastMd, isNot(contains(_fnId))); // the WHOLE chip died as one token 整体删除
      expect(lastMd, contains('Owner'));
      expect(lastMd, contains('ships'));
    });
  });
}

const _slashTestLabels = SlashMenuLabels(
  text: 'Text',
  h1: 'Heading 1',
  h2: 'Heading 2',
  h3: 'Heading 3',
  bulleted: 'Bulleted list',
  numbered: 'Numbered list',
  quote: 'Quote',
  code: 'Code block',
  divider: 'Divider',
  todo: 'To-do',
);

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
