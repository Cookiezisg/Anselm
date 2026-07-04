// Dev screenshot harness for the frameless WorkflowEditorPage (WRK-055 R3) — NOT part of the gate.
// Run: flutter test test/dev/capture_workflow_editor.dart
// Renders the editor headlessly at a desktop size with a branchy graph, a node selected (so the right
// island shows the node editor) → test/dev/out/workflow_editor.png. Verifies: frameless top chrome
// (floating pills, no bar), the OS-lights zone reserved on the left, the collapsible right island, the
// canvas zoom cluster moved bottom-left.
//
// 无边框编辑器开发截图夹具(非门禁)。桌面尺寸无头渲富图 + 选中节点(右岛出节点编辑器)→ workflow_editor.png。
// 核对:无边框顶 chrome(浮动药丸、非条)、左侧红绿灯位预留、可收右岛、缩放条落左下。
import 'dart:io';
import 'dart:ui' as ui;

import 'package:anselm/core/contract/entities/workflow.dart';
import 'package:anselm/core/contract/entities/function.dart';
import 'package:anselm/core/contract/entities/handler.dart';
import 'package:anselm/core/contract/entities/agent.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/features/entities/data/entity_providers.dart';
import 'package:anselm/features/entities/data/entity_fixtures.dart';
import 'package:anselm/features/entities/state/detail/workflow_editor_provider.dart';
import 'package:anselm/features/entities/state/selected_entity.dart';
import 'package:anselm/features/entities/data/entity_kind.dart' show EntityKind;
import 'package:anselm/core/contract/entities/values.dart' show MethodSpec;
import 'package:anselm/features/entities/ui/detail/workflow_editor_page.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _load(String family, String path) async {
  final f = File(path);
  if (!f.existsSync()) return;
  final b = f.readAsBytesSync();
  final loader = FontLoader(family)
    ..addFont(Future.value(ByteData.view(b.buffer, b.offsetInBytes, b.length)));
  await loader.load();
}

final _t = DateTime.utc(2026, 7, 4);
const _graph =
    '{"nodes":['
    '{"id":"on_pr_merged","kind":"trigger","ref":"trg_pr"},'
    '{"id":"run_tests","kind":"action","ref":"fn_test"},'
    '{"id":"branch_result","kind":"control","ref":"ctl_gate"},'
    '{"id":"approve_rollback","kind":"approval","ref":"apf_ok"},'
    '{"id":"do_rollback","kind":"action","ref":"fn_rollback"}],'
    '"edges":['
    '{"id":"e1","from":"on_pr_merged","to":"run_tests"},'
    '{"id":"e2","from":"run_tests","to":"branch_result"},'
    '{"id":"e3","from":"branch_result","fromPort":"fail","to":"approve_rollback"},'
    '{"id":"e4","from":"approve_rollback","fromPort":"yes","to":"do_rollback"},'
    '{"id":"e5","from":"branch_result","fromPort":"retry","to":"run_tests"}]}';

FixtureEntityRepository _repo() => FixtureEntityRepository(
      runDelay: Duration.zero,
      workflows: [
        WorkflowEntity(
          id: 'wf_1',
          name: 'ci-guard',
          createdAt: _t,
          updatedAt: _t,
          activeVersionId: 'wf_1_v1',
          activeVersion: WorkflowVersion(
              id: 'wf_1_v1', workflowId: 'wf_1', version: 3, graph: _graph, createdAt: _t, updatedAt: _t),
        ),
      ],
      // Candidates for the hierarchical ref picker. ref 分层选择器的候选。
      functions: [
        FunctionEntity(id: 'fn_test', name: 'run tests', createdAt: _t, updatedAt: _t),
        FunctionEntity(id: 'fn_lint', name: 'lint', createdAt: _t, updatedAt: _t),
      ],
      handlers: [
        HandlerEntity(
          id: 'hd_db',
          name: 'postgres',
          createdAt: _t,
          updatedAt: _t,
          activeVersionId: 'hdv_1',
          activeVersion: HandlerVersion(
            id: 'hdv_1',
            handlerId: 'hd_db',
            version: 1,
            createdAt: _t,
            updatedAt: _t,
            methods: const [MethodSpec(name: 'query'), MethodSpec(name: 'insert')],
          ),
        ),
      ],
      agents: [AgentEntity(id: 'ag_triage', name: 'triage', createdAt: _t, updatedAt: _t)],
      mcpServers: const [(id: 'github', name: 'github', meta: 'connected')],
      mcpTools: const {
        'github': [
          (id: 'create_issue', name: 'create_issue', meta: 'Open an issue'),
          (id: 'list_prs', name: 'list_prs', meta: 'List pull requests'),
        ],
      },
    );

void main() {
  setUpAll(() async {
    await _load('Inter', 'assets/fonts/InterVariable.ttf');
    await _load('MiSans', 'assets/fonts/MiSansVF.ttf');
    await _load('JetBrains Mono', 'assets/fonts/JetBrainsMono.ttf');
    final cache = '${Platform.environment['HOME']}/.pub-cache/hosted/pub.dev';
    await _load('packages/lucide_icons_flutter/Lucide300',
        '$cache/lucide_icons_flutter-3.1.14+2/assets/build_font/LucideVariable-w300.ttf');
  });

  testWidgets('capture frameless workflow editor', (tester) async {
    LocaleSettings.setLocaleRaw('zh-CN');
    const key = ValueKey('cap');
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1400, 900);
    addTearDown(tester.view.reset);

    final repo = _repo();
    await tester.pumpWidget(RepaintBoundary(
      key: key,
      child: ProviderScope(
        overrides: [entityRepositoryProvider.overrideWithValue(repo)],
        child: TranslationProvider(
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AnTheme.light(),
            home: const WorkflowEditorPage(workflowId: 'wf_1'),
          ),
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 80)); // editor loads + fit
    // Select a node so the right island shows the node editor. 选中节点让右岛出节点编辑器。
    const ref = EntityRef(EntityKind.workflow, 'wf_1');
    final container = ProviderScope.containerOf(tester.element(find.byType(WorkflowEditorPage)));
    final notifier = container.read(workflowEditorProvider(ref).notifier);
    // Select an ACTION node and route its ref through a handler → the hierarchical picker shows the full
    // family(处理器) → target(postgres) → member(query) drill-down; the edit also lights the live chrome
    // (enabled floating save + unsaved + discard). 选 action 节点、ref 走 handler → 选择器展示完整
    // 族(处理器)→目标(postgres)→成员(query)下钻;编辑也点亮 chrome。
    notifier.selectNode('run_tests');
    notifier.setNodeRef('run_tests', 'mcp:github/create_issue'); // MCP: family → server → tool 三级
    await tester.pump(const Duration(milliseconds: 80));
    await tester.pump(const Duration(milliseconds: 150)); // let the ref-candidate providers resolve → names 显示名字

    late final Uint8List bytes;
    await tester.runAsync(() async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
      final image = await boundary.toImage(pixelRatio: 2.0);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      bytes = png!.buffer.asUint8List();
      image.dispose();
    });
    final dir = Directory('test/dev/out')..createSync(recursive: true);
    File('${dir.path}/workflow_editor.png').writeAsBytesSync(bytes);
  });

  testWidgets('capture editor empty inspector (nothing selected)', (tester) async {
    LocaleSettings.setLocaleRaw('zh-CN');
    const key = ValueKey('cap');
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1400, 900);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(RepaintBoundary(
      key: key,
      child: ProviderScope(
        overrides: [entityRepositoryProvider.overrideWithValue(_repo())],
        child: TranslationProvider(
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AnTheme.light(),
            home: const WorkflowEditorPage(workflowId: 'wf_1'),
          ),
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 80)); // nothing selected → empty state
    late final Uint8List bytes;
    await tester.runAsync(() async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
      final image = await boundary.toImage(pixelRatio: 2.0);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      bytes = png!.buffer.asUint8List();
      image.dispose();
    });
    final dir = Directory('test/dev/out')..createSync(recursive: true);
    File('${dir.path}/workflow_editor_empty.png').writeAsBytesSync(bytes);
  });
}
