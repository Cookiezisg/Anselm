import 'package:anselm/core/contract/entities/handler.dart';
import 'package:anselm/core/contract/entities/function.dart';
import 'package:anselm/core/contract/entities/values.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/graph/node_ref.dart';
import 'package:anselm/core/ui/an_dropdown.dart';
import 'package:anselm/features/entities/data/entity_fixtures.dart';
import 'package:anselm/features/entities/data/entity_providers.dart';
import 'package:anselm/features/entities/ui/detail/node_ref_picker.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// WRK-055 stage 2a — the hierarchical NodeRefPicker: family → target → member dependent dropdowns,
// driven by invoking each dropdown's onChanged (the arena-free way to exercise the logic).

final _t = DateTime.utc(2026, 7, 4);

FixtureEntityRepository _repo() => FixtureEntityRepository(
  runDelay: Duration.zero,
  functions: [
    FunctionEntity(
      id: 'fn_test',
      name: 'run tests',
      createdAt: _t,
      updatedAt: _t,
    ),
    FunctionEntity(id: 'fn_other', name: 'other', createdAt: _t, updatedAt: _t),
  ],
  handlers: [
    HandlerEntity(
      id: 'hd_db',
      name: 'db',
      createdAt: _t,
      updatedAt: _t,
      activeVersionId: 'hdv_1',
      activeVersion: HandlerVersion(
        id: 'hdv_1',
        handlerId: 'hd_db',
        version: 1,
        createdAt: _t,
        updatedAt: _t,
        methods: const [
          MethodSpec(name: 'query'),
          MethodSpec(name: 'insert'),
        ],
      ),
    ),
  ],
  mcpServers: const [(id: 'github', name: 'github', meta: 'connected')],
  mcpTools: const {
    'github': [
      (id: 'create_issue', name: 'create_issue', meta: 'Open an issue'),
      (id: 'list_prs', name: 'list_prs', meta: null),
    ],
  },
  triggers: const [(id: 'trg_cron', name: 'nightly', meta: null)],
);

void main() {
  // A controlled host that holds the ref and rebuilds the picker on change — mirrors how the inspector
  // feeds node.ref down and writes setNodeRef back. 受控 host:持 ref、变更即重建(镜像检查器喂 node.ref / 回写)。
  Future<String Function()> pumpPicker(
    WidgetTester tester, {
    required NodeKind kind,
    required String initial,
  }) async {
    var ref = initial;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [entityRepositoryProvider.overrideWithValue(_repo())],
        child: TranslationProvider(
          child: MaterialApp(
            theme: AnTheme.light(),
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) => NodeRefPicker(
                  kind: kind,
                  refString: ref,
                  onChanged: (v) => setState(() => ref = v),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 30)); // providers resolve
    return () => ref;
  }

  testWidgets('action node: family dropdown + target dropdown render', (
    tester,
  ) async {
    await pumpPicker(tester, kind: NodeKind.action, initial: 'fn_test');
    // family (RefFamily) + target (String) dropdowns present; no member (function has none). 族+目标,无成员。
    expect(find.byType(AnDropdown<RefFamily>), findsOneWidget);
    expect(find.byType(AnDropdown<String>), findsOneWidget);
  });

  testWidgets(
    'switch family → target clears; pick handler → member appears; pick method → hd.method',
    (tester) async {
      final refOf = await pumpPicker(
        tester,
        kind: NodeKind.action,
        initial: 'fn_test',
      );

      // 1) switch family to handler → the family dropdown MUST hold handler (regression: it used to
      // collapse to '' and revert to function), ref = the family placeholder. 切到 handler:族下拉须真为
      // handler(回归:曾塌成 '' 回退 function),ref = 族占位。
      tester
          .widget<AnDropdown<RefFamily>>(find.byType(AnDropdown<RefFamily>))
          .onChanged!(RefFamily.handler);
      await tester.pump(const Duration(milliseconds: 30));
      expect(refOf(), 'hd_new');
      expect(
        tester
            .widget<AnDropdown<RefFamily>>(find.byType(AnDropdown<RefFamily>))
            .value,
        RefFamily.handler,
      );
      // still just family + target (no member until a target is picked). 仍只有族+目标。
      expect(find.byType(AnDropdown<String>), findsOneWidget);

      // 2) pick a handler target → ref = hd_db, member dropdown appears. 选 handler → 出成员。
      tester
          .widget<AnDropdown<String>>(find.byType(AnDropdown<String>))
          .onChanged!('hd_db');
      await tester.pump(const Duration(milliseconds: 30));
      expect(refOf(), 'hd_db');
      expect(
        find.byType(AnDropdown<String>),
        findsNWidgets(2),
      ); // target + member

      // 3) pick a method (the 2nd String dropdown = member) → ref = hd_db.query. 选方法 → hd_db.query。
      tester
          .widget<AnDropdown<String>>(find.byType(AnDropdown<String>).at(1))
          .onChanged!('query');
      await tester.pump(const Duration(milliseconds: 30));
      expect(refOf(), 'hd_db.query');
    },
  );

  testWidgets(
    'mcp: pick server then tool → mcp:server/tool (second level drills in)',
    (tester) async {
      final refOf = await pumpPicker(
        tester,
        kind: NodeKind.action,
        initial: 'mcp:',
      );
      // family parsed as mcp; no server yet → target only, no member. 族=mcp,未选 server → 仅目标。
      expect(find.byType(AnDropdown<String>), findsOneWidget);
      // pick a server → ref = mcp:github, tool dropdown appears. 选 server → 出工具下拉。
      tester
          .widget<AnDropdown<String>>(find.byType(AnDropdown<String>))
          .onChanged!('github');
      await tester.pump(const Duration(milliseconds: 30));
      expect(refOf(), 'mcp:github');
      expect(find.byType(AnDropdown<String>), findsNWidgets(2));
      // pick a tool → ref = mcp:github/create_issue. 选工具 → mcp:github/create_issue。
      tester
          .widget<AnDropdown<String>>(find.byType(AnDropdown<String>).at(1))
          .onChanged!('create_issue');
      await tester.pump(const Duration(milliseconds: 30));
      expect(refOf(), 'mcp:github/create_issue');
    },
  );

  // Regression (stage-2 review, HIGH): reach the mcp family via the family DROPDOWN starting from a
  // plain function ref — the transition that used to revert to function.
  testWidgets(
    'reach mcp via the family dropdown (from a function ref) → mcp:server',
    (tester) async {
      final refOf = await pumpPicker(
        tester,
        kind: NodeKind.action,
        initial: 'fn_test',
      );
      tester
          .widget<AnDropdown<RefFamily>>(find.byType(AnDropdown<RefFamily>))
          .onChanged!(RefFamily.mcp);
      await tester.pump(const Duration(milliseconds: 30));
      expect(refOf(), 'mcp:');
      expect(
        tester
            .widget<AnDropdown<RefFamily>>(find.byType(AnDropdown<RefFamily>))
            .value,
        RefFamily.mcp,
      );
      // the target dropdown now lists mcp servers → pick one. 目标下拉列 mcp 服务器 → 选。
      tester
          .widget<AnDropdown<String>>(find.byType(AnDropdown<String>))
          .onChanged!('github');
      await tester.pump(const Duration(milliseconds: 30));
      expect(refOf(), 'mcp:github');
    },
  );

  testWidgets('agent node: a single target dropdown, no family chooser', (
    tester,
  ) async {
    await pumpPicker(tester, kind: NodeKind.agent, initial: 'ag_new');
    expect(
      find.byType(AnDropdown<RefFamily>),
      findsNothing,
    ); // single family → no chooser
    expect(find.byType(AnDropdown<String>), findsOneWidget);
  });

  testWidgets('trigger node: single target dropdown lists triggers', (
    tester,
  ) async {
    final refOf = await pumpPicker(
      tester,
      kind: NodeKind.trigger,
      initial: 'trg_new',
    );
    expect(find.byType(AnDropdown<RefFamily>), findsNothing);
    tester
        .widget<AnDropdown<String>>(find.byType(AnDropdown<String>))
        .onChanged!('trg_cron');
    await tester.pump(const Duration(milliseconds: 30));
    expect(refOf(), 'trg_cron');
  });
}
