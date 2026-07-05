import 'package:anselm/core/contract/entities/document.dart';
import 'package:anselm/core/contract/entities/skill.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/entity/mention_source.dart';
import 'package:anselm/core/ui/an_doc_editor.dart';
import 'package:anselm/core/ui/an_mention_picker.dart';
import 'package:anselm/features/documents/data/document_fixtures.dart';
import 'package:anselm/features/documents/data/document_repository.dart';
import 'package:anselm/features/documents/state/document_state.dart';
import 'package:anselm/features/documents/ui/document_ocean.dart';
import 'package:anselm/features/documents/ui/document_rail.dart';
import 'package:anselm/features/documents/ui/document_rail_model.dart';
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

      // Picked → panel closed, mention committed into the markdown. 选中→面板关、mention 落 markdown。
      expect(find.byType(AnMentionPanel), findsNothing);
      expect(lastMd, contains('@sync_inventory'));
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

/// The @ picker's data seam for the editor tests — two entities, name-substring filtered (mirrors the
/// server-side `?search`). editor 测试的 @ 数据缝:两实体、名子串过滤(镜像服务端 ?search)。
class _FakeMentions implements MentionSource {
  @override
  Future<List<MentionCandidate>> search(String query) async {
    const all = [
      MentionCandidate(type: 'function', id: 'fn_1', name: 'sync_inventory', description: 'sync stock'),
      MentionCandidate(type: 'agent', id: 'ag_1', name: 'report_writer', description: 'writes reports'),
    ];
    final q = query.toLowerCase();
    return [for (final c in all) if (q.isEmpty || c.name.toLowerCase().contains(q)) c];
  }
}

class _PinnedSelection extends SelectedDocController {
  _PinnedSelection(this._seed);
  final DocSelection _seed;
  @override
  DocSelection? build() => _seed;
}
