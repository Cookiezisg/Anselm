import '../../../core/contract/api_key.dart';
import '../../../core/contract/mcp.dart';
import '../../../core/contract/memory.dart';
import '../../../core/contract/model_capability.dart';
import '../../../core/contract/sandbox.dart';
import '../../../core/contract/workspace.dart';
import 'settings_repository.dart';

/// The zero-backend settings fixture `make demo` mounts: a managed free-tier row with live quota +
/// one BYOK key, so the models-and-keys panel and the chat model picker both have something honest
/// to show; plus seeded memories, MCP servers and sandbox runtimes/envs so every settings panel shows
/// populated state instead of an empty placeholder (D-032/033/034). Capabilities are core-level (S-15)
/// so they ship as a separate list the demo assembly overrides [modelCapabilitiesProvider] with.
///
/// make demo 挂的零后端 settings fixture:受管免费档+BYOK+配额,加记忆/MCP server/沙箱运行时·env 种子,
/// 使每个设置面板都显有数据态而非空占位(D-032/033/034)。能力目录在 core(S-15),单独出列表由装配 override。
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
        limit: 5000, used: 1730, remaining: 3270, resetAt: '2026-08-01T00:00:00Z', available: true)
    // D-034 memory panel — a pinned (gold) row + a user note + an AI-authored note. 记忆面:pin/user/ai 各态。
    ..memories.addAll([
      Memory(name: 'coding-style', description: '缩进两空格 · 函数优先 · 早返回', pinned: true, source: 'user', updatedAt: at),
      Memory(name: 'user-timezone', description: 'SGT (UTC+8)', source: 'user', updatedAt: at),
      Memory(name: 'retry-policy', description: '指数退避,最多 3 次;超限抛 SyncError', source: 'ai', updatedAt: at),
    ])
    // D-032 MCP panel — a ready server (with a tool), a failed server, a registry entry. MCP:就绪/失败/市场。
    ..mcpServers.addAll([
      McpServerStatus(id: 'mcp_ctx7', name: 'context7', status: 'ready', connectedAt: at, totalCalls: 42, tools: const [
        McpToolDef(serverName: 'context7', name: 'resolve-library-id', description: 'Resolve a package to its docs id'),
        McpToolDef(serverName: 'context7', name: 'get-library-docs', description: 'Fetch versioned library docs'),
      ]),
      McpServerStatus(
          id: 'mcp_gh',
          name: 'github',
          status: 'failed',
          consecutiveFailures: 3,
          totalCalls: 12,
          totalFailures: 3,
          lastError: 'connection refused (is the server running?)',
          lastErrorAt: at),
    ])
    ..mcpRegistry.addAll(const [
      McpRegistryEntry(name: 'filesystem', description: 'Local filesystem access (read/write within a root)'),
      McpRegistryEntry(name: 'postgres', description: 'Query a Postgres database read-only'),
    ])
    // D-033 sandbox panel — an installed runtime + a ready env under a function owner. 沙箱:已装运行时+就绪 env。
    ..runtimes.addAll([
      SandboxRuntime(id: 'srt_py311', kind: 'python', version: '3.11.9', sizeBytes: 128 * 1024 * 1024, installedAt: at),
      SandboxRuntime(id: 'srt_node20', kind: 'node', version: '20.11.0', sizeBytes: 96 * 1024 * 1024, installedAt: at),
    ])
    ..envsByOwner['function'] = [
      SandboxEnv(
          id: 'senv_sync0',
          ownerKind: 'function',
          ownerId: 'fn_1a2b3c4d5e6f7a8b',
          ownerName: 'sync_inventory',
          runtimeId: 'srt_py311',
          deps: const ['httpx', 'pydantic'],
          sizeBytes: 18 * 1024 * 1024,
          status: 'ready',
          lastUsedAt: at),
    ]
    // Workspaces panel — a second (deletable) row beside the active one, plus honest inventory
    // numbers for the danger zone. 工作区面:当前之外再种一行(可删),危险区有真数字可陈。
    ..extraWorkspaces.add(Workspace(
        id: 'ws_demo_side0000',
        name: 'Side Projects',
        avatarColor: '#4CAF7D',
        language: 'zh-CN',
        createdAt: at,
        updatedAt: at))
    ..stats = const WorkspaceStats(
        conversations: 12,
        functions: 4,
        handlers: 2,
        agents: 3,
        workflows: 2,
        documents: 9,
        blobBytes: 22 * 1024 * 1024);
}

/// The demo (key, model) catalog — what `GET /model-capabilities` would aggregate from the rows
/// above, capability specs + native knobs included so the three-stage picker has something honest
/// to render. demo 能力目录——上面两行 key 聚合出的模型选项,带能力规格与原生 knobs,三段选择面板
/// 有真东西可渲。
const demoModelCapabilities = <ModelCapability>[
  ModelCapability(
      apiKeyId: 'aki_demo_managed0',
      keyName: 'Anselm Free',
      provider: 'anselm',
      modelId: 'deepseek-chat',
      displayName: 'DeepSeek Chat',
      contextWindow: 128000,
      maxOutput: 8192),
  ModelCapability(
      apiKeyId: 'aki_demo_managed0',
      keyName: 'Anselm Free',
      provider: 'anselm',
      modelId: 'deepseek-reasoner',
      displayName: 'DeepSeek Reasoner',
      contextWindow: 128000,
      maxOutput: 65536,
      knobs: [
        ModelKnob(
            key: 'reasoning_effort',
            label: 'Reasoning effort',
            type: 'enum',
            values: ['low', 'medium', 'high'],
            defaultValue: 'medium'),
      ]),
  ModelCapability(
      apiKeyId: 'aki_demo_byok0000',
      keyName: 'DeepSeek (personal)',
      provider: 'deepseek',
      modelId: 'deepseek-chat',
      displayName: 'DeepSeek Chat',
      contextWindow: 128000,
      maxOutput: 8192,
      vision: false),
];
