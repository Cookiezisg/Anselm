/// The story dataset's Settings seam — one `FixtureSettingsRepository` seeded so every Settings page
/// reads like a real, well-used install of the Product Team workspace: a managed tier that has burned
/// a quarter of its quota, four BYOK keys (one whose last probe FAILED, which is the same failed-test
/// the notification ledger reports), six scenario defaults spread over three keys, a half-used voice
/// slot, two mounted MCP servers, a pinned team memory, installed runtimes and honest storage numbers.
/// Every visible phrase goes through [StoryLocale.t]; identifiers, model ids, paths and package names
/// stay English — that mirrors real usage in both languages.
///
/// story 数据集的 Settings 数据缝——一份 `FixtureSettingsRepository`，种得让每个设置页都像产品团队
/// workspace 里一个用了很久的真实安装：受管档已烧掉四分之一配额，四把 BYOK key（其中一把最近一次
/// 探测失败，与通知账本里那条「key 测试失败」是同一件事），六个场景默认分布在三把 key 上，克隆音色用了
/// 一半，两台 MCP 已挂载，一条 pin 住的团队约定，已装运行时和诚实的存储数字。所有可见文案经
/// [StoryLocale.t]；标识符、模型 id、路径、包名两种语言都保持英文，与真实使用一致。
library;

import '../../core/contract/api_key.dart';
import '../../core/contract/mcp.dart';
import '../../core/contract/memory.dart';
import '../../core/contract/model_capability.dart';
import '../../core/contract/network.dart';
import '../../core/contract/retention.dart';
import '../../core/contract/sandbox.dart';
import '../../core/contract/workspace.dart';
import '../../features/settings/data/settings_demo_fixture.dart';
import '../../features/settings/data/settings_repository.dart';
import 'story_bible.dart';
import 'story_locale.dart';

// ───────────────────────── Key ids ─────────────────────────
// Shared with [storyModelCapabilities] so the picker's (key, model) rows resolve to these key rows.
// 与 [storyModelCapabilities] 共用，选择器的 (key, model) 行才能落到这些 key 行上。

const akiManaged = 'aki_5f2c8e1a9d3b7406';
const akiOpenAi = 'aki_9b4d2f7a1c6e8305';
const akiGemini = 'aki_3e7a1c9d5b2f8604';
const akiDeepSeek = 'aki_7c1e5a3b9d4f2806';
const akiBrave = 'aki_2d8f4b6a1e9c3507';

const storyPersonalWorkspaceId = 'ws_7a3e9c1d5b2f8604';
String storyPersonalWorkspaceName(StoryLocale l) => l.t('Personal', '个人');

/// The install's data directory — a realistic macOS path, because the Storage page prints it verbatim
/// and «/tmp/anselm-fixture» would give the screenshot away. 安装数据目录——真实 macOS 路径，
/// Storage 页原样打印，`/tmp/anselm-fixture` 会穿帮。
const storyDataDir = '/Users/you/Library/Application Support/Anselm';

SettingsRepository storySettingsRepository(StoryLocale l) {
  final repo = FixtureSettingsRepository(
    workspace: Workspace(
      id: storyWorkspaceId,
      name: storyWorkspaceName(l),
      avatarColor: '#5B7CFA',
      language: l.languageTag,
      // Six scenario defaults over three keys: chat + every generation scenario ride the managed
      // tier, the cheap utility calls go to DeepSeek, and the agent scenario uses gpt-4.1 — a spread
      // that reads as deliberate routing, not one key copied six times.
      // 六个场景默认跨三把 key：对话和全部生成场景走受管档，便宜的 utility 调用走 DeepSeek，agent
      // 场景用 gpt-4.1——读起来是有意的路由，而不是一把 key 抄六遍。
      defaultDialogue: const ModelRef(
        apiKeyId: akiManaged,
        modelId: 'anselm-auto',
      ),
      defaultUtility: const ModelRef(
        apiKeyId: akiDeepSeek,
        modelId: 'deepseek-chat',
      ),
      defaultAgent: const ModelRef(apiKeyId: akiOpenAi, modelId: 'gpt-4.1'),
      defaultImage: const ModelRef(
        apiKeyId: akiManaged,
        modelId: 'anselm-auto',
      ),
      defaultSpeech: const ModelRef(
        apiKeyId: akiManaged,
        modelId: 'anselm-auto',
      ),
      defaultVideo: const ModelRef(
        apiKeyId: akiManaged,
        modelId: 'anselm-auto',
      ),
      defaultSearchKeyId: akiBrave,
      webFetchMode: 'local',
      lastUsedAt: ago(minutes: 3),
      createdAt: ago(days: 94),
      updatedAt: ago(hours: 2),
    ),
  );

  // ── Models & keys 模型与密钥 ──
  // The fixture's provider catalog has no gemini row; add one so the failed key's provider resolves
  // in the add/edit sheet. Base URL mirrors the backend's geminiDefaultBaseURL.
  // fixture 的 provider 目录没有 gemini 行；补一行，失败 key 的 provider 在新增/编辑面板里才能解析。
  // 地址镜像后端 geminiDefaultBaseURL。
  repo.providers = [
    ...repo.providers,
    const ProviderMeta(
      name: 'gemini',
      displayName: 'Google Gemini',
      defaultBaseUrl: 'https://generativelanguage.googleapis.com/v1beta',
      dialect: 'gemini',
    ),
  ];
  repo.keys.addAll([
    ApiKey(
      id: akiManaged,
      provider: 'anselm',
      displayName: 'Anselm Free',
      testStatus: 'ok',
      lastTestedAt: ago(days: 1, hours: 4),
      createdAt: ago(days: 94),
      updatedAt: ago(days: 1, hours: 4),
    ),
    ApiKey(
      id: akiOpenAi,
      provider: 'openai',
      displayName: l.t('OpenAI (team)', 'OpenAI（团队）'),
      keyMasked: 'sk-proj-…4Qx2',
      baseUrl: 'https://api.openai.com/v1',
      testStatus: 'ok',
      lastTestedAt: ago(days: 2, hours: 6),
      createdAt: ago(days: 61),
      updatedAt: ago(days: 2, hours: 6),
    ),
    // The failed probe the notification ledger points at: the key was rotated on Google's side and
    // the last test came back 401. 通知账本指向的那次探测失败：key 在 Google 侧被轮换，最近一次测试 401。
    ApiKey(
      id: akiGemini,
      provider: 'gemini',
      displayName: l.t('Gemini (trial)', 'Gemini（试用）'),
      keyMasked: 'AIza…f9Kd',
      testStatus: 'failed',
      testError: l.t(
        'API key not valid. Please pass a valid API key. (401)',
        'API key 无效，请传入有效的 key。(401)',
      ),
      lastTestedAt: ago(hours: 5),
      createdAt: ago(days: 12),
      updatedAt: ago(hours: 5),
    ),
    ApiKey(
      id: akiDeepSeek,
      provider: 'deepseek',
      displayName: l.t('DeepSeek (utility)', 'DeepSeek（工具调用）'),
      keyMasked: 'sk-…c81e',
      testStatus: 'ok',
      lastTestedAt: ago(days: 3),
      createdAt: ago(days: 47),
      updatedAt: ago(days: 3),
    ),
    ApiKey(
      id: akiBrave,
      provider: 'brave',
      displayName: 'Brave Search',
      keyMasked: 'BSA…p7Lm',
      testStatus: 'ok',
      lastTestedAt: ago(days: 3),
      createdAt: ago(days: 40),
      updatedAt: ago(days: 3),
    ),
  ]);
  repo.quota = const FreetierQuota(
    limit: 5000,
    used: 1240,
    remaining: 3760,
    resetAt: '2026-10-01T00:00:00Z',
    available: true,
  );
  repo.fixtureVoices = VoiceInventory(
    items: [
      ClonedVoice(
        id: 'vce_4d8b2f6a1c9e3705',
        name: l.t('Studio narrator', '录音室旁白'),
        provider: 'anselm',
        createdAt: ago(days: 18).toUtc().toIso8601String(),
      ),
    ],
    capacity: 2,
    remaining: 1,
  );

  // ── MCP ──
  repo.mcpServers.addAll([
    McpServerStatus(
      id: 'mcp_8a1c3e5b7d2f4609',
      name: 'github',
      status: 'ready',
      connectedAt: ago(hours: 9),
      totalCalls: 318,
      totalFailures: 4,
      tools: [
        McpToolDef(
          serverName: 'github',
          name: 'list_commits',
          description: l.t('List commits on a branch', '列出分支上的提交'),
        ),
        McpToolDef(
          serverName: 'github',
          name: 'list_pull_requests',
          description: l.t('List pull requests with filters', '按条件列出 PR'),
        ),
        McpToolDef(
          serverName: 'github',
          name: 'get_pull_request',
          description: l.t(
            'Fetch one pull request with its diff',
            '读取单个 PR 及其 diff',
          ),
        ),
        McpToolDef(
          serverName: 'github',
          name: 'list_issues',
          description: l.t('List issues in a repository', '列出仓库 issue'),
        ),
        McpToolDef(
          serverName: 'github',
          name: 'create_issue_comment',
          description: l.t('Comment on an issue or PR', '在 issue 或 PR 下评论'),
        ),
        McpToolDef(
          serverName: 'github',
          name: 'search_code',
          description: l.t('Search code across repositories', '跨仓库搜索代码'),
        ),
      ],
    ),
    // Mounted but degraded: the panel shows the warning dot plus the active error text, which is the
    // «mounted with a warning» state the screenshot wants. 已挂载但降级：面板显示等待色点与当前错误文本，
    // 即截图要的「挂载但有警告」态。
    McpServerStatus(
      id: 'mcp_2f6b9d1a4c8e3507',
      name: 'filesystem',
      status: 'degraded',
      connectedAt: ago(hours: 9),
      consecutiveFailures: 1,
      totalCalls: 57,
      totalFailures: 3,
      lastError: l.t(
        'allowed root $storyGoneDir no longer exists',
        '允许目录 $storyGoneDir 已不存在',
      ),
      lastErrorAt: ago(minutes: 40),
      tools: [
        McpToolDef(
          serverName: 'filesystem',
          name: 'read_file',
          description: l.t('Read a file under an allowed root', '读取允许目录下的文件'),
        ),
        McpToolDef(
          serverName: 'filesystem',
          name: 'write_file',
          description: l.t('Write a file under an allowed root', '写入允许目录下的文件'),
        ),
        McpToolDef(
          serverName: 'filesystem',
          name: 'list_directory',
          description: l.t('List a directory', '列出目录'),
        ),
      ],
    ),
  ]);
  repo.mcpCalls.addAll([
    McpCall(
      id: 'mcc_1a9e3c5b7d2f4608',
      serverId: 'mcp_8a1c3e5b7d2f4609',
      tool: 'list_commits',
      status: 'ok',
      triggeredBy: 'workflow',
      elapsedMs: 842,
      startedAt: ago(days: 1, hours: 2),
      createdAt: ago(days: 1, hours: 2),
    ),
    McpCall(
      id: 'mcc_5c3a7e9b1d4f2608',
      serverId: 'mcp_8a1c3e5b7d2f4609',
      tool: 'list_pull_requests',
      status: 'ok',
      triggeredBy: 'agent',
      elapsedMs: 611,
      startedAt: ago(hours: 3),
      createdAt: ago(hours: 3),
    ),
    McpCall(
      id: 'mcc_9e1c3a5b7d2f4608',
      serverId: 'mcp_2f6b9d1a4c8e3507',
      tool: 'list_directory',
      status: 'failed',
      triggeredBy: 'chat',
      errorMessage: l.t(
        'allowed root $storyGoneDir no longer exists',
        '允许目录 $storyGoneDir 已不存在',
      ),
      elapsedMs: 12,
      startedAt: ago(minutes: 40),
      createdAt: ago(minutes: 40),
    ),
  ]);
  repo.mcpRegistry.addAll([
    McpRegistryEntry(
      name: 'io.github.modelcontextprotocol/postgres',
      description: l.t(
        'Query a Postgres database read-only',
        '只读查询 Postgres 数据库',
      ),
    ),
    McpRegistryEntry(
      name: 'io.github.upstash/context7',
      description: l.t(
        'Versioned library docs for coding agents',
        '给编码 agent 用的带版本库文档',
      ),
    ),
    McpRegistryEntry(
      name: 'io.github.modelcontextprotocol/slack',
      description: l.t('Post and read Slack messages', '读写 Slack 消息'),
      prerequisite: 'SLACK_BOT_TOKEN',
    ),
  ]);

  // ── Memory 记忆 ──
  repo.memories.addAll([
    Memory(
      name: 'team-conventions',
      description: l.t(
        'PR titles use conventional commits; every feature PR links its working doc',
        'PR 标题走 conventional commits；每个功能 PR 链接对应的 working 文档',
      ),
      pinned: true,
      source: 'user',
      updatedAt: ago(days: 20),
    ),
    Memory(
      name: 'release-cadence',
      description: l.t(
        'Ship every other Tuesday; freeze the Friday before; release notes drafted by $agReleaseNotesName',
        '隔周二发版；前一个周五冻结；版本说明由 $agReleaseNotesName 起草',
      ),
      source: 'user',
      updatedAt: ago(days: 6),
    ),
    Memory(
      name: 'repo-layout',
      description: l.t(
        '$storyRepoDir: Go backend under backend/, Flutter client under frontend/, docs are the contract source',
        '$storyRepoDir：Go 后端在 backend/，Flutter 客户端在 frontend/，docs 是契约事实源',
      ),
      source: 'ai',
      updatedAt: ago(days: 9),
    ),
    Memory(
      name: 'flaky-test-history',
      description: l.t(
        'parse_invoice_pdf tests are timezone-sensitive; run with TZ=UTC before calling them flaky',
        'parse_invoice_pdf 的测试对时区敏感；判定不稳定前先用 TZ=UTC 跑一遍',
      ),
      source: 'ai',
      updatedAt: ago(days: 1, hours: 3),
    ),
  ]);

  // ── Sandbox 沙箱 ──
  repo.runtimes.addAll([
    SandboxRuntime(
      id: 'srt_6b2d8f4a1c9e3507',
      kind: 'python',
      version: '3.12.4',
      sizeBytes: 142 * 1024 * 1024,
      installedAt: ago(days: 88),
    ),
    SandboxRuntime(
      id: 'srt_3d9f1b7a5c2e8604',
      kind: 'node',
      version: '22.6.0',
      sizeBytes: 104 * 1024 * 1024,
      installedAt: ago(days: 72),
    ),
  ]);
  repo.envsByOwner['function'] = [
    SandboxEnv(
      id: 'senv_1c9e5b3a7d2f4806',
      ownerKind: 'function',
      ownerId: fnParseInvoice,
      ownerName: fnParseInvoiceName,
      runtimeId: 'srt_6b2d8f4a1c9e3507',
      deps: const ['pdfplumber', 'pydantic', 'python-dateutil'],
      sizeBytes: 64 * 1024 * 1024,
      status: 'ready',
      lastUsedAt: ago(hours: 2),
    ),
    SandboxEnv(
      id: 'senv_8d2f4a6c9e1b3507',
      ownerKind: 'function',
      ownerId: fnFetchGithub,
      ownerName: fnFetchGithubName,
      runtimeId: 'srt_3d9f1b7a5c2e8604',
      deps: const ['octokit', 'zod'],
      sizeBytes: 38 * 1024 * 1024,
      status: 'ready',
      lastUsedAt: ago(days: 1, hours: 2),
    ),
    SandboxEnv(
      id: 'senv_5a3c7e9b1d4f2608',
      ownerKind: 'function',
      ownerId: fnResizeImage,
      ownerName: fnResizeImageName,
      runtimeId: 'srt_6b2d8f4a1c9e3507',
      deps: const ['pillow'],
      sizeBytes: 21 * 1024 * 1024,
      status: 'ready',
      lastUsedAt: ago(days: 4),
    ),
  ];
  // Runtimes + envs + pip/npm caches; the disk row must not be smaller than the rows it sums.
  // 运行时 + env + pip/npm 缓存；磁盘行不能比它汇总的各行还小。
  repo.fixtureDisk = 412 * 1024 * 1024;

  // ── Storage & logs 存储与日志 ──
  repo.fixtureDataDir = storyDataDir;
  repo.fixtureDbBytes = 38 * 1024 * 1024;
  repo.fixtureDeadBytes = 6 * 1024 * 1024;
  repo.fixtureAttachmentBytes = 412 * 1024 * 1024;
  repo.fixtureAttachmentDeadBytes = 27 * 1024 * 1024;
  repo.fixtureRetention = const RetentionConfig(runRetentionDays: 90);

  // ── Network 网络 ──
  // Proxy off = every field empty; the page shows the three inputs blank with web fetch on `local`
  // (set on the workspace row above). 代理关 = 三个字段全空；页上三个输入框留白，web fetch 为 local。
  repo.fixtureNetwork = const NetworkConfig();

  // ── Workspaces & about 工作区与关于 ──
  repo.extraWorkspaces.add(
    Workspace(
      id: storyPersonalWorkspaceId,
      name: storyPersonalWorkspaceName(l),
      avatarColor: '#4CAF7D',
      language: l.languageTag,
      lastUsedAt: ago(days: 2),
      createdAt: ago(days: 70),
      updatedAt: ago(days: 2),
    ),
  );
  repo.stats = const WorkspaceStats(
    conversations: 8,
    functions: 4,
    handlers: 2,
    agents: 3,
    workflows: 4,
    documents: 8,
    runningFlowruns: 1,
    generatingConversations: 1,
    blobBytes: 412 * 1024 * 1024,
  );
  repo.version = '0.2.0';

  return repo;
}

/// The story (key, model) catalog: every model the scenario defaults above point at, resolved to the
/// story key ids. Built from [demoModelCapabilities] so capability specs stay in one place, with the
/// key ids rebound and the OpenAI + Gemini rows added. Gemini is listed even though its key failed its
/// last probe — the catalog is what the backend last aggregated, and a stale row is the honest state.
/// story 能力目录：上面场景默认指向的每个模型，落到 story 的 key id 上。基于 [demoModelCapabilities]
/// 生成，能力规格只维护一处，改绑 key id 并补 OpenAI 与 Gemini 行。Gemini 的 key 最近探测失败仍列出——
/// 目录是后端上次聚合的结果，陈旧行才是诚实状态。
final List<ModelCapability> storyModelCapabilities = [
  for (final cap in demoModelCapabilities)
    switch (cap.provider) {
      'anselm' => cap.copyWith(apiKeyId: akiManaged, keyName: 'Anselm Free'),
      'deepseek' => cap.copyWith(
        apiKeyId: akiDeepSeek,
        keyName: 'DeepSeek (utility)',
      ),
      _ => cap,
    },
  const ModelCapability(
    apiKeyId: akiOpenAi,
    keyName: 'OpenAI (team)',
    provider: 'openai',
    modelId: 'gpt-4.1',
    displayName: 'GPT-4.1',
    contextWindow: 1047576,
    maxOutput: 32768,
    textInputLimit: 1047576,
    multimodalInputLimit: 262144,
    vision: true,
    nativeDocs: true,
    maxMediaParts: 10,
    maxMediaBytes: 20 * 1024 * 1024,
  ),
  const ModelCapability(
    apiKeyId: akiOpenAi,
    keyName: 'OpenAI (team)',
    provider: 'openai',
    modelId: 'gpt-4.1-mini',
    displayName: 'GPT-4.1 mini',
    contextWindow: 1047576,
    maxOutput: 32768,
    textInputLimit: 1047576,
    multimodalInputLimit: 262144,
    vision: true,
    maxMediaParts: 10,
    maxMediaBytes: 20 * 1024 * 1024,
  ),
  const ModelCapability(
    apiKeyId: akiGemini,
    keyName: 'Gemini (trial)',
    provider: 'gemini',
    modelId: 'gemini-2.5-flash',
    displayName: 'Gemini 2.5 Flash',
    contextWindow: 1048576,
    maxOutput: 65536,
    textInputLimit: 1048576,
    multimodalInputLimit: 1048576,
    vision: true,
    video: true,
    audio: true,
    nativeDocs: true,
    maxMediaParts: 16,
    maxMediaBytes: 20 * 1024 * 1024,
    knobs: [
      ModelKnob(
        key: 'thinking',
        label: 'Thinking',
        type: 'enum',
        values: ['off', 'low', 'high'],
        defaultValue: 'low',
      ),
    ],
  ),
];
