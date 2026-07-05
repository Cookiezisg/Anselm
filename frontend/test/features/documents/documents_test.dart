import 'package:anselm/core/contract/entities/document.dart';
import 'package:anselm/core/contract/entities/skill.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/ui/an_doc_editor.dart';
import 'package:anselm/features/documents/data/document_fixtures.dart';
import 'package:anselm/features/documents/data/document_repository.dart';
import 'package:anselm/features/documents/state/document_state.dart';
import 'package:anselm/features/documents/ui/document_ocean.dart';
import 'package:anselm/features/documents/ui/document_rail.dart';
import 'package:anselm/features/documents/ui/document_rail_model.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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
}

class _PinnedSelection extends SelectedDocController {
  _PinnedSelection(this._seed);
  final DocSelection _seed;
  @override
  DocSelection? build() => _seed;
}
