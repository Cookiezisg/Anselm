import 'package:anselm/core/contract/entities/document.dart';
import 'package:anselm/core/contract/entities/skill.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/entity/mention_source.dart';
import 'package:anselm/core/ui/an_doc_editor.dart';
import 'package:anselm/core/ui/an_mention_picker.dart';
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
import 'package:super_editor/super_editor_test.dart';
import 'package:super_text_layout/super_text_layout.dart' show BlinkController;

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

Widget _host(FixtureDocumentsRepository repo, Widget child) => ProviderScope(
      overrides: [documentsRepositoryProvider.overrideWithValue(repo)],
      child: TranslationProvider(
        child: MaterialApp(
          theme: AnTheme.light(),
          home: Scaffold(body: SizedBox(width: 320, height: 640, child: child)),
        ),
      ),
    );

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

    testWidgets('a page shows its properties; editing the name PATCHes', (tester) async {
      final repo = _repo();
      await tester.pumpWidget(host(repo, (isSkill: false, id: 'doc_a')));
      await tester.pumpAndSettle();
      expect(find.text('Name'), findsOneWidget);
      expect(find.text('Tags'), findsOneWidget);
      expect(find.text('Modified'), findsOneWidget); // read-only meta 只读 meta
      // The name field is the first text input; a debounced edit PATCHes through the repository. 改名去抖 PATCH。
      await tester.enterText(find.byType(EditableText).first, 'Renamed page');
      await tester.pump(const Duration(milliseconds: 600)); // past the 500ms debounce 过去抖
      await tester.pumpAndSettle();
      expect((await repo.getDocument('doc_a')).name, 'Renamed page');
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

    testWidgets('editing a skill description PUTs the whole frontmatter, keeping the body', (tester) async {
      final repo = _repo();
      final bodyBefore = (await repo.getSkill('commit-helper')).body;
      await tester.pumpWidget(host(repo, (isSkill: true, id: 'commit-helper')));
      await tester.pumpAndSettle();
      // The description field is the first (only) text input in the skill form. description=首个输入。
      await tester.enterText(find.byType(EditableText).first, 'Reworded skill');
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
      final after = await repo.getSkill('commit-helper');
      expect(after.description, 'Reworded skill');
      expect(after.body, bodyBefore); // the untouched body survives the full-replace PUT. body 不被全覆盖抹掉。
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
