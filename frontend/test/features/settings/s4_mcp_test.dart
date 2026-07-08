import 'package:anselm/core/contract/mcp.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/settings/settings_prefs.dart';
import 'package:anselm/features/settings/data/settings_repository.dart';
import 'package:anselm/features/settings/state/mcp_providers.dart';
import 'package:anselm/features/settings/state/settings_detail_provider.dart';
import 'package:anselm/features/settings/ui/panels/mcp_panel.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// S4b batteries: roster stats + five-state dots, manual add (stdio, honest failed face), the
// marketplace search + installed mark, the :plan-driven install form (isSecret masked / required
// starred), import (overwrite off skips same names), and detail tabs.
// MCP 电池:名册统计+五态点/手动添加(failed 诚实)/市场搜索+已装标/:plan 表单/导入跳同名/详情三 tab。

Widget _host(FixtureSettingsRepository repo) => ProviderScope(
      overrides: [
        settingsPrefsProvider.overrideWithValue(SettingsPrefs.inMemory()),
        settingsRepositoryProvider.overrideWithValue(repo),
      ],
      child: TranslationProvider(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AnTheme.light(),
          home: const Scaffold(body: SingleChildScrollView(child: McpPanel())),
        ),
      ),
    );

void main() {
  setUpAll(() => LocaleSettings.setLocaleRaw('zh-CN'));

  testWidgets('roster: stats bar counts ready/failed; five-state dot mapping', (tester) async {
    final repo = FixtureSettingsRepository()
      ..mcpServers.addAll(const [
        McpServerStatus(id: 'mcp_1', name: 'context7', status: 'ready'),
        McpServerStatus(id: 'mcp_2', name: 'broken', status: 'failed', lastError: 'boom'),
        McpServerStatus(id: 'mcp_3', name: 'flaky', status: 'degraded'),
      ]);
    await tester.pumpWidget(_host(repo));
    await tester.pumpAndSettle();
    final t = Translations.of(tester.element(find.byType(McpPanel)));
    expect(find.text(t.settings.mcp.statBar(n: 3, ready: 1, failed: 1)), findsOneWidget);
    expect(find.text('context7'), findsOneWidget);
    expect(mcpDot('ready'), isNotNull);
    expect(mcpDot('disconnected'), isNull, reason: '未连接=无点');
  });

  testWidgets('manual add (stdio) lands; an unreachable server shows the honest failed face',
      (tester) async {
    final repo = FixtureSettingsRepository()..nextMcpStatus = 'failed';
    await tester.pumpWidget(_host(repo));
    await tester.pumpAndSettle();
    final t = Translations.of(tester.element(find.byType(McpPanel)));

    await tester.tap(find.text(t.settings.mcp.manualAdd));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'myserver');
    await tester.enterText(find.byType(TextField).at(1), 'npx');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text(t.settings.mcp.add));
    await tester.tap(find.text(t.settings.mcp.add));
    await tester.pumpAndSettle();

    expect(repo.mcpServers.single.name, 'myserver');
    expect(repo.mcpServers.single.status, 'failed');
    expect(find.text('myserver'), findsOneWidget, reason: '失败也落名册(诚实)');
  });

  testWidgets('marketplace: client-side search + installed mark; :plan form stars required',
      (tester) async {
    final repo = FixtureSettingsRepository()
      ..mcpRegistry.addAll(const [
        McpRegistryEntry(name: 'io.github.upstash/context7', description: 'library docs'),
        McpRegistryEntry(name: 'io.github.x/weather', description: 'forecasts'),
      ])
      ..mcpServers.add(const McpServerStatus(id: 'mcp_1', name: 'context7', status: 'ready'))
      ..mcpPlan = const McpRegistryPlan(transport: 'stdio', runtime: 'node', envVars: [
        McpEnvVar(name: 'API_KEY', isSecret: true, required: true),
        McpEnvVar(name: 'ZONE', description: 'optional zone'),
      ]);
    await tester.pumpWidget(_host(repo));
    await tester.pumpAndSettle();
    final panelEl = tester.element(find.byType(McpPanel));
    final container = ProviderScope.containerOf(panelEl, listen: false);
    final t = Translations.of(panelEl);

    await tester.tap(find.text(t.settings.mcp.browse));
    await tester.pumpAndSettle();
    expect(find.text('context7'), findsWidgets);
    expect(find.text(t.settings.mcp.installed), findsOneWidget, reason: '短名比对已装标');

    await tester.enterText(find.byType(TextField).first, 'weather');
    await tester.pumpAndSettle();
    expect(find.text('context7'), findsNothing, reason: '本地搜索');

    container.read(settingsDetailProvider.notifier).push('mcpInstall', id: 'io.github.x/weather');
    await tester.pumpAndSettle();
    expect(find.text('API_KEY'), findsOneWidget);
    expect(find.textContaining(t.settings.mcp.requiredMark), findsOneWidget, reason: '必填星标');
    expect(find.text('optional zone'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(0), 'sk-x');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text(t.settings.mcp.install));
    await tester.tap(find.text(t.settings.mcp.install));
    await tester.pumpAndSettle();
    expect(repo.mcpServers.any((s) => s.name == 'weather'), isTrue, reason: '安装落短名行');
  });

  testWidgets('import skips same names when overwrite is off', (tester) async {
    final repo = FixtureSettingsRepository()
      ..mcpServers.add(const McpServerStatus(id: 'mcp_1', name: 'dup', status: 'ready'));
    await tester.pumpWidget(_host(repo));
    await tester.pumpAndSettle();
    final panelEl = tester.element(find.byType(McpPanel));
    final container = ProviderScope.containerOf(panelEl, listen: false);

    final r = await container.read(mcpServersProvider.notifier).importJson(
        '{"mcpServers":{"dup":{"command":"npx"},"fresh":{"command":"npx"}}}');
    expect(r.imported, ['fresh']);
    expect(r.skipped, ['dup'], reason: 'overwrite=false 跳同名');
  });

  testWidgets('detail: status card + three tabs; failed server leads with the error',
      (tester) async {
    final repo = FixtureSettingsRepository()
      ..mcpServers.add(const McpServerStatus(
          id: 'mcp_1',
          name: 'broken',
          status: 'failed',
          lastError: 'spawn npx ENOENT',
          consecutiveFailures: 3,
          tools: [McpToolDef(name: 'do-thing', description: 'does the thing')]));
    await tester.pumpWidget(_host(repo));
    await tester.pumpAndSettle();
    final panelEl = tester.element(find.byType(McpPanel));
    final container = ProviderScope.containerOf(panelEl, listen: false);
    final t = Translations.of(panelEl);

    container.read(settingsDetailProvider.notifier).push('mcpServer', id: 'broken');
    await tester.pumpAndSettle();
    expect(find.textContaining('spawn npx ENOENT'), findsOneWidget, reason: '错误置顶');
    expect(find.text('do-thing'), findsOneWidget, reason: '工具 tab 默认开');

    await tester.tap(find.text(t.settings.mcp.tabStderr));
    await tester.pumpAndSettle();
    expect(find.text(t.settings.mcp.noStderr), findsOneWidget);
  });
}
