import 'package:anselm/core/contract/entities/skill.dart';
import 'package:anselm/core/entity/mention_source.dart';
import 'package:anselm/features/documents/data/document_fixtures.dart';
import 'package:anselm/features/documents/data/document_repository.dart';
import 'package:anselm/features/documents/ui/skill_tool_picker.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _fnId = 'fn_deadbeef00000001';
final _t = DateTime.utc(2026, 1, 1);

// A fake @-mention source: one function + one handler + one agent (agent must NOT surface in the
// picker's fn/hd groups). 假 @ 候选源:函数+处理器+agent(agent 绝不进选择器 fn/hd 组)。
class _FakeMentions implements MentionSource {
  @override
  Future<List<MentionCandidate>> search(String query) async => const [
    MentionCandidate(
      type: 'function',
      id: _fnId,
      name: 'sync_inventory',
      description: 'sync stock',
    ),
    MentionCandidate(
      type: 'handler',
      id: 'hd_00000000000000aa',
      name: 'on_order',
      description: 'order webhook',
    ),
    MentionCandidate(
      type: 'agent',
      id: 'ag_00000000000000bb',
      name: 'report_writer',
      description: 'writes reports',
    ),
  ];

  @override
  Future<Map<String, String>> resolveNames(List<String> ids) async => const {};
}

Skill _skill(String name, {List<String> allowedTools = const []}) => Skill(
  name: name,
  description: 'x',
  context: 'inline',
  body: '# $name',
  frontmatter: Frontmatter(allowedTools: allowedTools),
  updatedAt: _t,
);

Widget _host(FixtureDocumentsRepository repo, Widget child) => ProviderScope(
  overrides: [
    documentsRepositoryProvider.overrideWithValue(repo),
    mentionSourceProvider.overrideWithValue(_FakeMentions()),
  ],
  child: TranslationProvider(
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AnTheme.light(),
      home: Scaffold(body: SizedBox(width: 380, height: 720, child: child)),
    ),
  ),
);

void main() {
  group('pure helpers', () {
    test('mcpAuthToolName builds the double-underscore call name', () {
      expect(
        mcpAuthToolName('github', 'create_issue'),
        'mcp__github__create_issue',
      );
    });

    test('skillToolPillLabel resolves entity ids, passes literals through', () {
      final idToName = {'fn_x': 'sync_inventory'};
      expect(skillToolPillLabel('fn_x', idToName), 'sync_inventory');
      expect(skillToolPillLabel('Read', idToName), 'Read');
      expect(skillToolPillLabel('Bash(git:*)', idToName), 'Bash(git:*)');
      expect(skillToolPillLabel('fn_unknown', idToName), 'fn_unknown');
    });

    test('firstRemovedToolIndex is position-based (dup labels safe)', () {
      expect(firstRemovedToolIndex(['a', 'b', 'c'], ['a', 'c']), 1); // middle
      expect(firstRemovedToolIndex(['a', 'b', 'c'], ['a', 'b']), 2); // last
      expect(firstRemovedToolIndex(['a', 'b', 'c'], ['b', 'c']), 0); // first
      expect(firstRemovedToolIndex(['a', 'b'], ['a', 'b']), -1); // none
      expect(
        firstRemovedToolIndex(['dup', 'dup'], ['dup']),
        1,
      ); // dup: 2nd removed
    });
  });

  group('SkillToolsField', () {
    testWidgets('pills show resolved entity names; literals verbatim', (
      tester,
    ) async {
      final repo = FixtureDocumentsRepository(
        documents: const [],
        skills: [
          _skill('ts', allowedTools: [_fnId]),
        ],
      );
      await tester.pumpWidget(
        _host(
          repo,
          SkillToolsField(
            skillName: 'ts',
            values: const ['Read', _fnId],
            onChanged: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      // fn_ id resolves to the bound entity name (the fixture's equip edge names it 'demo-function');
      // Read shows verbatim. fn_ 显示 equip 边给的名、Read 原文。
      expect(find.text('demo-function'), findsOneWidget);
      expect(find.text('Read'), findsOneWidget);
      expect(find.text(_fnId), findsNothing);
    });

    testWidgets('removing a pill fires onChanged minus that value', (
      tester,
    ) async {
      List<String>? got;
      final repo = FixtureDocumentsRepository(
        documents: const [],
        skills: [_skill('ts')],
      );
      await tester.pumpWidget(
        _host(
          repo,
          SkillToolsField(
            skillName: 'ts',
            values: const ['Read', 'Bash'],
            onChanged: (v) => got = v,
          ),
        ),
      );
      final semantics = tester.ensureSemantics();
      // Each pill carries a remove-× with semantics label "Remove {label}". 每药丸带移除 ×。
      final removeRead = find.bySemanticsLabel('Remove Read');
      expect(removeRead, findsOneWidget);
      await tester.tap(removeRead);
      await tester.pumpAndSettle();
      expect(got, ['Bash']);
      semantics.dispose();
    });

    testWidgets('picker adds a builtin by name and a function by id', (
      tester,
    ) async {
      final picks = <List<String>>[];
      final repo = FixtureDocumentsRepository(
        documents: const [],
        skills: [_skill('ts')],
      );
      await tester.pumpWidget(
        _host(
          repo,
          SkillToolsField(
            skillName: 'ts',
            values: const [],
            onChanged: picks.add,
          ),
        ),
      );
      await tester.pumpAndSettle();
      // Open the picker.
      await tester.tap(find.text(t.documents.props.addTool));
      await tester.pumpAndSettle();
      // A builtin (fixture catalog has Read) → stored as its name.
      await tester.tap(find.text('Read').last);
      await tester.pumpAndSettle();
      expect(picks.last, ['Read']);
      // A function candidate → stored as its id (not its name). Scroll it into view first (it sits
      // below the builtin group). 函数候选→存 id;先滚入视口(在内置组下方)。
      await tester.ensureVisible(find.text('sync_inventory'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('sync_inventory'));
      await tester.pumpAndSettle();
      expect(picks.last, ['Read', _fnId]);
    });

    testWidgets('free-text submit adds a scope literal verbatim', (
      tester,
    ) async {
      final picks = <List<String>>[];
      final repo = FixtureDocumentsRepository(
        documents: const [],
        skills: [_skill('ts')],
      );
      await tester.pumpWidget(
        _host(
          repo,
          SkillToolsField(
            skillName: 'ts',
            values: const [],
            onChanged: picks.add,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(t.documents.props.addTool));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(EditableText).first, 'Bash(git:*)');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(picks.last, ['Bash(git:*)']);
    });
  });
}
