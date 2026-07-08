import '../../../core/contract/api_key.dart';
import '../../../core/contract/model_capability.dart';
import 'settings_repository.dart';

/// The zero-backend settings fixture `make demo` mounts: a managed free-tier row with live quota +
/// one BYOK key, so the models-and-keys panel and the chat model picker both have something honest
/// to show. Capabilities are core-level (S-15) so they ship as a separate list the demo assembly
/// overrides [modelCapabilitiesProvider] with.
///
/// make demo 挂的零后端 settings fixture:一条受管免费档(带配额)+一条 BYOK,模型密钥面板与 chat 模型
/// 选择器都有诚实数据。能力目录在 core(S-15),故单独出一份列表由 demo 装配 override。
SettingsRepository demoSettingsRepository() {
  final at = DateTime.utc(2026, 7, 1, 9);
  return FixtureSettingsRepository()
    ..keys.addAll([
      ApiKey(
          id: 'aki_demo_managed0',
          provider: 'anselm',
          displayName: 'Anselm Free',
          testStatus: 'ok',
          createdAt: at,
          updatedAt: at),
      ApiKey(
          id: 'aki_demo_byok0000',
          provider: 'deepseek',
          displayName: 'DeepSeek (personal)',
          testStatus: 'ok',
          createdAt: at,
          updatedAt: at),
    ])
    ..quota = const FreetierQuota(
        limit: 5000, used: 1730, remaining: 3270, resetAt: '2026-08-01T00:00:00Z', available: true);
}

/// The demo (key, model) catalog — what `GET /model-capabilities` would aggregate from the rows
/// above. demo 能力目录——上面两行 key 聚合出的模型选项。
const demoModelCapabilities = <ModelCapability>[
  ModelCapability(
      apiKeyId: 'aki_demo_managed0',
      keyName: 'Anselm Free',
      provider: 'anselm',
      modelId: 'deepseek-chat',
      displayName: 'DeepSeek Chat'),
  ModelCapability(
      apiKeyId: 'aki_demo_managed0',
      keyName: 'Anselm Free',
      provider: 'anselm',
      modelId: 'deepseek-reasoner',
      displayName: 'DeepSeek Reasoner'),
  ModelCapability(
      apiKeyId: 'aki_demo_byok0000',
      keyName: 'DeepSeek (personal)',
      provider: 'deepseek',
      modelId: 'deepseek-chat',
      displayName: 'DeepSeek Chat'),
];
