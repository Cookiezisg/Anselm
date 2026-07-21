import 'package:anselm/core/contract/mcp.dart';
import 'package:anselm/core/contract/model_capability.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/settings/settings_prefs.dart';
import 'package:anselm/core/ui/an_card.dart';
import 'package:anselm/core/ui/brand_registry.dart';
import 'package:anselm/features/settings/data/settings_repository.dart';
import 'package:anselm/features/settings/ui/panels/mcp_forms.dart';
import 'package:anselm/features/settings/ui/panels/mcp_panel.dart';
import 'package:anselm/features/settings/ui/panels/models_keys_panel.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// P3 重构 batteries (0719): the reusable three-stage model picker (credential → model specs →
// generic knobs → the exact apply payload), the vendor-grid add flow's baseUrl gate, the brand
// registry's token mapping (io.github.* must NOT read as the GitHub brand), and the marketplace's
// browse-first default (whole registry listed, search only filters).
// P3 电池:三段模型面板(凭证→模型规格→通用 knobs→应用载荷)/添加流 baseUrl 门/品牌注册表词元
// 映射(io.github.* 不得认成 GitHub)/市场默认全列(搜索只过滤)。

const _caps = <ModelCapability>[
  ModelCapability(
    apiKeyId: 'aki_1',
    keyName: 'Main key',
    provider: 'deepseek',
    modelId: 'deepseek-chat',
    displayName: 'DeepSeek Chat',
    contextWindow: 128000,
    vision: true,
  ),
  ModelCapability(
    apiKeyId: 'aki_1',
    keyName: 'Main key',
    provider: 'deepseek',
    modelId: 'deepseek-reasoner',
    displayName: 'DeepSeek Reasoner',
    contextWindow: 128000,
    knobs: [
      ModelKnob(
        key: 'reasoning_effort',
        label: 'Reasoning effort',
        type: 'enum',
        values: ['low', 'medium', 'high'],
        defaultValue: 'medium',
      ),
      ModelKnob(
        key: 'logprobs',
        label: 'Logprobs',
        type: 'bool',
        defaultValue: 'false',
      ),
    ],
  ),
  ModelCapability(
    apiKeyId: 'aki_2',
    keyName: 'Second key',
    provider: 'openai',
    modelId: 'gpt-x',
    displayName: 'GPT X',
  ),
];

Widget _host(Widget child) => ProviderScope(
  child: TranslationProvider(
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AnTheme.light(),
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  ),
);

void main() {
  setUpAll(() => LocaleSettings.setLocaleRaw('zh-CN'));

  group('ModelPickerPanel 三段面板', () {
    testWidgets(
      'credential → model (specs in meta) → knobs prefilled → apply payload',
      (tester) async {
        String? gotKey;
        String? gotModel;
        Map<String, String>? gotOptions;
        await tester.pumpWidget(
          _host(
            ModelPickerPanel(
              caps: _caps,
              onApply: (k, m, o) {
                gotKey = k;
                gotModel = m;
                gotOptions = o;
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Stage ①: both credentials listed; no models yet. 两把凭证在列,未选前无模型段。
        expect(find.text('Main key'), findsOneWidget);
        expect(find.text('Second key'), findsOneWidget);
        expect(find.text('DeepSeek Reasoner'), findsNothing);

        await tester.tap(find.text('Main key'));
        await tester.pumpAndSettle();
        // Stage ②: that key's models with capability specs (128K · 视觉). 该 key 的模型+规格。
        expect(find.text('DeepSeek Chat'), findsOneWidget);
        expect(find.textContaining('128K'), findsWidgets);
        expect(
          find.textContaining(t.settings.keys.visionBadge),
          findsOneWidget,
          reason: '视觉徽',
        );

        await tester.tap(find.text('DeepSeek Reasoner'));
        await tester.pumpAndSettle();
        // Stage ③: knobs render generically, default prefilled. knobs 通用渲染,default 预填。
        expect(find.text('Reasoning effort'), findsOneWidget);
        expect(find.text('medium'), findsOneWidget, reason: 'enum 预填 default');
        expect(find.text('Logprobs'), findsOneWidget, reason: 'bool knob 开关行');

        // Change the enum then apply — only non-default knobs ride the payload. 改 enum 应用,载荷
        // 只带偏离 default 的 knob。
        await tester.tap(find.text('medium'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('high').last);
        await tester.pumpAndSettle();
        await tester.tap(find.text(t.settings.keys.pickerApply));
        await tester.pumpAndSettle();
        expect(gotKey, 'aki_1');
        expect(gotModel, 'deepseek-reasoner');
        expect(gotOptions, {
          'reasoning_effort': 'high',
        }, reason: 'default 值不进 options');
      },
    );

    testWidgets('switching credential resets the model stage', (tester) async {
      await tester.pumpWidget(
        _host(ModelPickerPanel(caps: _caps, onApply: (_, _, _) {})),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Main key'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('DeepSeek Chat'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Second key'));
      await tester.pumpAndSettle();
      expect(find.text('GPT X'), findsOneWidget, reason: '换凭证换模型列表');
      expect(find.text('DeepSeek Chat'), findsNothing);
      // Apply is disarmed until a model under the NEW key is picked. 未选新模型不可应用。
      expect(
        tester.widget<Text>(find.text(t.settings.keys.pickerApply)).style,
        isNotNull,
      );
    });

    testWidgets(
      'zero capabilities → guidance + the add-key jump (no dead dropdown)',
      (tester) async {
        var jumped = false;
        await tester.pumpWidget(
          _host(
            ModelPickerPanel(
              caps: const [],
              onApply: (_, _, _) {},
              onAddKey: () => jumped = true,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.text(t.settings.keys.noCapsGuide),
          findsOneWidget,
          reason: '零可用引导',
        );
        await tester.tap(find.text(t.settings.keys.addKey));
        expect(jumped, isTrue);
      },
    );
  });

  group('KeyForm 添加流 baseUrl 门', () {
    Widget host(FixtureSettingsRepository repo) => ProviderScope(
      overrides: [
        settingsPrefsProvider.overrideWithValue(SettingsPrefs.inMemory()),
        settingsRepositoryProvider.overrideWithValue(repo),
      ],
      child: TranslationProvider(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AnTheme.light(),
          home: const Scaffold(body: SingleChildScrollView(child: KeyForm())),
        ),
      ),
    );

    testWidgets(
      'ollama: save stays disarmed until the required base URL is filled',
      (tester) async {
        final repo = FixtureSettingsRepository();
        await tester.pumpWidget(host(repo));
        await tester.pumpAndSettle();
        // Grid → pick the self-hosted vendor. 网格选自托管厂。
        await tester.tap(find.text('Ollama'));
        await tester.pumpAndSettle();
        expect(
          find.text(t.settings.keys.baseUrlRequiredHint),
          findsOneWidget,
          reason: '必填注记',
        );

        final inputs = find.byType(TextField);
        await tester.enterText(inputs.at(0), 'local'); // displayName
        await tester.enterText(inputs.at(1), 'sk-anything'); // secret
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text(t.settings.keys.saveKey));
        await tester.tap(find.text(t.settings.keys.saveKey));
        await tester.pumpAndSettle();
        expect(repo.keys, isEmpty, reason: 'baseUrl 缺,保存不放行');

        await tester.enterText(inputs.at(2), 'http://localhost:11434');
        await tester.pumpAndSettle();
        await tester.tap(find.text(t.settings.keys.saveKey));
        await tester.pumpAndSettle();
        expect(repo.keys, hasLength(1), reason: '补 baseUrl 后保存放行');
      },
    );
  });

  group('brand_registry 品牌词元映射', () {
    test('io.github.* namespaces never read as the GitHub brand', () {
      expect(mcpBrandFor('io.github.getsentry/sentry-mcp'), 'sentry');
      expect(mcpBrandFor('io.github.github/github-mcp-server'), 'github');
      expect(mcpBrandFor('io.github.upstash/context7'), 'upstash');
      expect(
        mcpBrandFor('io.github.hashicorp/terraform-mcp-server'),
        'terraform',
      );
    });

    test('reverse-DNS orgs resolve by their brand segment', () {
      expect(mcpBrandFor('com.figma.mcp/mcp'), 'figma');
      expect(mcpBrandFor('com.supabase/mcp'), 'supabase');
      expect(mcpBrandFor('makenotion/notion-mcp-server'), 'notion');
      expect(mcpBrandFor('doist/todoist-ai'), 'todoist');
      expect(mcpBrandFor('io.github.pgEdge/postgres-mcp'), 'postgresql');
    });

    test('unmapped entries fall back to null (the letter plate)', () {
      expect(mcpBrandFor('microsoft/playwright-mcp'), isNull);
      expect(mcpBrandFor('firecrawl/firecrawl-mcp-server'), isNull);
      expect(mcpBrandFor('oraios/serena'), isNull);
    });

    test('every registered slug has a vendored asset name', () {
      for (final slug in kBrandAssets) {
        expect(
          slug,
          matches(RegExp(r'^[a-z0-9]+$')),
          reason: 'slug=资产文件名,$slug',
        );
      }
    });
  });

  group('MCP 双列卡', () {
    Widget host(FixtureSettingsRepository repo, Widget child) => ProviderScope(
      overrides: [
        settingsPrefsProvider.overrideWithValue(SettingsPrefs.inMemory()),
        settingsRepositoryProvider.overrideWithValue(repo),
      ],
      child: TranslationProvider(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AnTheme.light(),
          home: Scaffold(body: SingleChildScrollView(child: child)),
        ),
      ),
    );

    testWidgets(
      'installed roster renders brand cards; zero tool/call counts stay silent',
      (tester) async {
        final repo = FixtureSettingsRepository()
          ..mcpServers.addAll([
            McpServerStatus(
              id: 'mcp_1',
              name: 'github',
              status: 'ready',
              totalCalls: 42,
              tools: const [
                McpToolDef(
                  serverName: 'github',
                  name: 'search',
                  description: '',
                ),
              ],
            ),
            const McpServerStatus(
              id: 'mcp_2',
              name: 'flaky',
              status: 'failed',
              lastError: 'connect refused',
            ),
          ]);
        await tester.pumpWidget(host(repo, const McpPanel()));
        await tester.pumpAndSettle();
        expect(find.byType(AnCard), findsNWidgets(2), reason: '双列卡,一台一卡');
        expect(find.text('github'), findsOneWidget);
        expect(
          find.text('connect refused'),
          findsOneWidget,
          reason: '失败卡诚实错误句',
        );
        // The failed server has 0 tools + 0 calls — neither segment renders. 零计数不显。
        expect(find.textContaining(t.settings.mcp.tools(n: 0)), findsNothing);
        expect(find.textContaining(t.settings.mcp.calls(n: 0)), findsNothing);
      },
    );

    testWidgets(
      'marketplace lists the WHOLE registry by default; search only filters',
      (tester) async {
        final repo = FixtureSettingsRepository()
          ..mcpRegistry.addAll(const [
            McpRegistryEntry(
              name: 'io.github.getsentry/sentry-mcp',
              description: 'Errors',
            ),
            McpRegistryEntry(
              name: 'com.supabase/mcp',
              description: 'Postgres platform',
              prerequisite: 'account',
            ),
            McpRegistryEntry(
              name: 'oraios/serena',
              description: 'Coding agent toolkit',
            ),
          ]);
        await tester.pumpWidget(host(repo, const McpMarket()));
        await tester.pumpAndSettle();
        // Browse-first: every entry is a card BEFORE any query. 默认全列。
        expect(find.byType(AnCard), findsNWidgets(3));
        expect(find.text('sentry-mcp'), findsOneWidget);
        expect(
          find.text(t.settings.mcp.prerequisite),
          findsOneWidget,
          reason: '前置徽在卡上',
        );

        await tester.enterText(find.byType(TextField), 'supabase');
        await tester.pumpAndSettle();
        expect(find.byType(AnCard), findsOneWidget, reason: '搜索即过滤');
        expect(find.text('mcp'), findsOneWidget);
      },
    );
  });
}
