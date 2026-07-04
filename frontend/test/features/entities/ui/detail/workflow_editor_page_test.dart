import 'package:anselm/core/contract/entities/workflow.dart';
import 'package:anselm/core/ui/an_dropdown.dart';
import 'package:anselm/core/ui/an_graph_canvas.dart';
import 'package:anselm/features/entities/data/entity_fixtures.dart';
import 'package:anselm/features/entities/data/entity_kind.dart';
import 'package:anselm/features/entities/data/entity_providers.dart';
import 'package:anselm/features/entities/ui/detail/workflow_editor_page.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:flutter/material.dart';
import 'package:anselm/features/entities/state/detail/workflow_editor_provider.dart';
import 'package:anselm/features/entities/state/selected_entity.dart';
import 'package:anselm/features/entities/data/entity_kind.dart' show EntityKind;
import 'package:anselm/core/contract/entities/values.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// WRK-055 W5 gate (widget) — the graph editor page: renders the toolbar + edit-mode canvas +
// inspector; selecting a node shows its editor; editing enables save; save persists a new version.

final _t = DateTime.utc(2026, 6, 27);
const _graph =
    '{"nodes":[{"id":"start","kind":"trigger","ref":"tr_x"},{"id":"work","kind":"action","ref":"fn_1"}],"edges":[{"id":"e1","from":"start","to":"work"}]}';

FixtureEntityRepository _repo() => FixtureEntityRepository(
      runDelay: Duration.zero,
      workflows: [
        WorkflowEntity(
          id: 'wf_1',
          name: 'pipe',
          createdAt: _t,
          updatedAt: _t,
          activeVersionId: 'wf_1_v1',
          activeVersion: WorkflowVersion(
              id: 'wf_1_v1', workflowId: 'wf_1', version: 1, graph: _graph, createdAt: _t, updatedAt: _t),
        ),
      ],
    );

Widget _host(FixtureEntityRepository repo) => ProviderScope(
      overrides: [entityRepositoryProvider.overrideWithValue(repo)],
      child: TranslationProvider(
        child: MaterialApp(
          theme: AnTheme.light(),
          home: const WorkflowEditorPage(workflowId: 'wf_1'),
        ),
      ),
    );

void main() {
  final e = t.entities.detail.editor;

  // The editor is a full-desktop page; give the test a realistic wide surface (the toolbar has many
  // buttons). 编辑器是桌面整页;给测试真实宽面(工具条按钮多)。
  void wide(WidgetTester tester) {
    tester.view.physicalSize = const Size(1400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  testWidgets('renders toolbar + edit-mode canvas + inspector empty state', (tester) async {
    wide(tester);
    await tester.pumpWidget(_host(_repo()));
    await tester.pump(const Duration(milliseconds: 60)); // editor loads
    expect(find.text(e.addNode), findsOneWidget);
    expect(find.text(e.autoLayout), findsOneWidget);
    expect(find.text(e.save), findsOneWidget);
    final canvas = tester.widget<AnGraphCanvas>(find.byType(AnGraphCanvas));
    expect(canvas.editable, isTrue);
    expect(find.text(e.inspectorEmpty), findsOneWidget);
  });

  testWidgets('selecting a node reveals its editor (kind dropdown + ref + delete)', (tester) async {
    wide(tester);
    await tester.pumpWidget(_host(_repo()));
    await tester.pump(const Duration(milliseconds: 60));
    await tester.tap(find.text('work'));
    await tester.pump();
    expect(find.byType(AnDropdown<NodeKind>), findsOneWidget); // kind dropdown
    expect(find.text('fn_1'), findsWidgets); // ref value
    expect(find.text(e.deleteNode), findsOneWidget);
  });

  testWidgets('an edit enables save; tapping it persists a new version', (tester) async {
    wide(tester);
    final repo = _repo();
    await tester.pumpWidget(_host(repo));
    await tester.pump(const Duration(milliseconds: 60));
    const ref = EntityRef(EntityKind.workflow, 'wf_1');
    final container = ProviderScope.containerOf(tester.element(find.byType(WorkflowEditorPage)));
    final saveBtn = find.text(e.save);
    expect(saveBtn, findsOneWidget);
    // Not dirty → the save CTA is inert (tapping persists nothing, still v1). 未改前保存惰性、点无效。
    await tester.tap(saveBtn);
    await tester.pumpAndSettle();
    expect((await repo.getWorkflow('wf_1')).activeVersion!.version, 1);
    container.read(workflowEditorProvider(ref).notifier).setNodeRef('work', 'fn_renamed');
    await tester.pump();
    // Now dirty → tapping the save CTA persists a new version. 已改 → 点保存落新版本。
    await tester.tap(saveBtn);
    await tester.pumpAndSettle();
    final wf = await repo.getWorkflow('wf_1');
    expect(wf.activeVersion!.version, 2);
    // The saved version carries the renamed ref. 新版本带改名。
    expect(wf.activeVersion!.graph.contains('fn_renamed'), isTrue);
  });

  testWidgets('add-node menu inserts a node', (tester) async {
    wide(tester);
    await tester.pumpWidget(_host(_repo()));
    await tester.pump(const Duration(milliseconds: 60));
    await tester.tap(find.text(e.addNode));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120)); // menu opens
    await tester.tap(find.text(t.graph.kind.action).last);
    await tester.pump();
    // A new 'task' node appears on the canvas. 画布多出 task 节点。
    expect(find.text('task'), findsWidgets);
  });
}
