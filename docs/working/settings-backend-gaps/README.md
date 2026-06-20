---
id: WRK-033
type: working
status: active
owner: @weilin
created: 2026-06-20
reviewed: 2026-06-20
review-due: 2026-09-18
audience: [human, ai]
landed-into:
---

# 设置 UI 需要、但后端现在没有的 —— 后端补缺清单（交接用）

> 来源：对整个设置面的代码级深读（workspace / apikey+model / skill+search / sandbox+limits / MCP / free-tier，全部带 `文件:行` 锚点）。
> 用法：这是**给后端实现者的待办清单**，不是设计。每条给【缺什么 · 设置为啥要 · 大致补什么 · 代码锚点】。按 P0/P1/P2 优先级分档——P0 不补，设置页会明显残缺或误导用户。
> 范围：只列「设置 UI 想要、后端缺」的。**刻意不可配的**（运行时版本钉死/下载源固定 = ADR 0001；加密绑机器指纹）不在此列——那是设计决定、别动。

---

## P0 —— 不补，设置页就残缺/误导

### G1. 免费档配额可见（无法显示剩余额度）
- **缺什么**：网关 `Install` 响应已带 `{monthlyQuota, resetAt}`，但 `InstallResult.MonthlyQuota/ResetAt` **被领取后随即丢弃**——provisioner 只读 `res.Token`，不落库、不经任何 HTTP 端点暴露；`CapabilityView` 无配额字段；无 `GET /quota`。
- **设置为啥要**：免费档卡片要显「本月剩余 X / 5000，7-01 重置」。现在用户只能发消息撞到 `LLM_QUOTA_EXHAUSTED`(429) 被动感知耗尽，无主动 gauge。
- **大致补**：① 客户端直连网关 `GET /v1/quota`（网关侧已就绪，返 `{limit,used,remaining,resetAt,available}`）—— 最省，无需后端改；或 ② provisioner 落库 quota + 加一个只读 `GET /api/v1/freetier/quota` 透出。二选一。
- **锚点**：`infra/llm/install.go`（`InstallResult` 含 MonthlyQuota/ResetAt 但被丢）· `app/freetier/freetier.go`（provisioner 只用 res.Token）· 网关 `api.anselm.host/v1/quota` 已可调。

### G2. 装机 / 下载进度（大包装机 UI 零反馈）
- **缺什么**：sandbox runtime（dotnet ~226MB）、搜索 embedder（EmbeddingGemma ~600MB）首装时 **POST 阻塞直到装完，UI 全程无反馈**。`directInstaller` 内部有 `ProgressFunc`（`direct.go:495-499`）但**未经 SSE 透出**。MCP 市场直装同理（进度只在经 chat 装时走 messages 流）。
- **设置为啥要**：装一个运行时/嵌入模型动辄几分钟几百 MB，没进度条用户会以为卡死。
- **大致补**：把 `ProgressFunc` 接到 **notifications 流**（如 `sandbox.install_progress {kind, version, bytesDone, bytesTotal}`），或给一条装机进度端点。MCP 市场直装也接同一通道。
- **锚点**：`infra/sandbox/direct.go:495-499`（ProgressFunc）· `app/sandbox`（EnsureRuntime 同步阻塞）· `infra/search/engine/engine.go`（embedder 下载，status 只布尔 downloading 无 %）· MCP `app/mcp/install.go`（install_mcp_server 经 chat 才有进度）。

### G3. 清除三场景默认模型（无端点）
- **缺什么**：默认搜索 key 有 `DELETE /workspaces/{id}/default-search`，但**默认模型没有对称的 clear**。能力层 `SetDefault` 接受 nil-ref 能清（`workspace.go:284`），但 HTTP `setDefaultModelRequest` 永远构造非 nil ref，空 body → `MODEL_REF_INVALID`(400)。
- **设置为啥要**：用户想把某场景默认「取消/回未配」时无路可走。
- **大致补**：`DELETE /api/v1/workspaces/{id}/default-models/{scenario}` → 调 `SetDefaultFor(scenario, nil)`。
- **锚点**：`app/workspace/workspace.go:271-291`（SetDefault 已支持 nil）· `transport/.../workspaces.go:175-188`（HTTP 层永构造非 nil）。

### G4. `API_KEY_IN_USE` 不告诉「谁在引用」
- **缺什么**：删 key 撞引用返 422 `API_KEY_IN_USE`，但 `RefScanner` 接口只回 `bool`，错误**无 details 列出引用方**（哪个 scenario / 哪个 agent）。
- **设置为啥要**：用户删 key 被拦,不知道去哪解引用(改哪个默认/哪个 agent)，只能盲找。
- **大致补**：`RefScanner` 回引用方描述（`[]string` 或 `{kind,name}`），`API_KEY_IN_USE` 错误 `details.references` 带上。
- **锚点**：`app/apikey/apikey.go:32-34`（RefScanner 只回 bool）· `:245-256`（Delete 守）· 两 scanner `app/workspace/workspace.go:324-342` + `app/agent/crud.go:156-177`。

---

## P1 —— 补了明显更好（避免漂移 / 减少误操作）

### G5. 元数据端点（前端被迫复刻 Go 常量 = 契约漂移）
- **缺什么**：这些只在 Go 注释/常量里、**不经 API 暴露**：limits 各字段的合法范围/默认值/单位/影响；可装 runtime 版本（pin map：python 3.11/3.12/3.13、node 22…）；knob 默认值。前端要渲染「合法范围/默认多少/装哪个版本」只能自己硬编一份 → 后端改了就漂。
- **大致补**：① `GET /api/v1/limits/schema`（每字段 default/min/max/unit/desc）② `GET /api/v1/sandbox/runtimes/available`（pin map 可装版本）。
- **锚点**：`pkg/limits/limits.go:25-104`（schema+Default 全在 Go）· `infra/sandbox/direct.go:222-375`（版本 pin map）。

### G6. limits「恢复默认」（无端点）
- **缺什么**：要回默认得 PATCH 每个字段回默认值（前端硬编默认 → 会和 `Default()` 漂），或删 settings.json（前端做不到）。
- **大致补**：`POST /api/v1/limits:reset`（整体或单段）→ 调 `Default()`。
- **锚点**：`app/settings/settings.go:87-104`（PatchLimits）· `pkg/limits/limits.go:172`（Default）。

### G7. key 旋转后模型静默消失（无自动重探 / 无信号）
- **缺什么**：`PATCH api-keys/{id}` 带新 `key` = 旋转 → 探测档案重置成 `pending` → capabilities 不采纳 pending → **该 key 的模型从选择器消失**，但**不自动 `:test`**、无信号提示。
- **大致补**：旋转 key 时自动触发一次探活，或响应带「需重新 :test」信号让前端补。
- **锚点**：`app/apikey/apikey.go:194-240`（Update 重置档案为 pending，不触发 Test）。

### G8. Ollama 连接测试端点（status=ready 不代表真连通）
- **缺什么**：选 ollama / 填 baseUrl 后，`engine.status` 恒 `ready`（只要工厂造出适配器），**即使 Ollama 守护没跑**——实际 Embed 才失败。无「保存前测试连接」端点。
- **大致补**：`POST /api/v1/search/settings:test-ollama`（探一次 `/api/tags`）返连通性。
- **锚点**：`app/search/semantic.go:443-491`（ollama 无 StatusReporter 恒 ready）· `infra/search/engine/engine.go:367-417`（ollama 适配器）。

### G9. custom `apiFormat` 无白名单校验（静默走错方言）
- **缺什么**：custom provider 的 `apiFormat` 只显式认 `"anthropic-compatible"`，**其余任意串静默落 OpenAI-compat 默认**，无 `ErrAPIFormatInvalid`。用户填错值不报错、悄悄走错方言。
- **大致补**：白名单校验（`openai-compatible` / `anthropic-compatible` 二选一）+ 报错码。
- **锚点**：`domain/apikey/apikey.go:58`（只一个常量）· `infra/llm/provider.go:128-136`（其余落默认分支）。

---

## P2 —— 锦上添花 / 未来（设置页可先不做或先 mock）

### G10. 数据：导出 / 备份 / 全量重置（基本全缺）
- 只支持「停 app 手动拷 dataDir」+ 单 workspace 级联删（`DELETE /workspaces/{id}`）。**无「导出全部」「重置应用」端点**（roadmap 未排期）。跨机迁移后三类密文（API keys / handler config / MCP env）须重填（机器指纹派生密钥）。
- 补：导出/导入/重置端点（大工程）。锚点：`data-migration.md`。

### G11. 数据目录展示端点（无 GET）
- `ANSELM_DATA_DIR` 只在 boot 读环境变量，**无运行时 GET**。设置想显「数据存储位置 + 打开目录」需后端补只读端点（或 sidecar 启动参数侧告知）。

### G12. 技能（Skill）几个缺口
- **无启停开关**（`user-invocable` 字段**存而未消费**；`disable-model-invocation` 只藏 LLM 概览、人工仍可激活）· **无 rename**（改名要前端「删+建」）· **无导入/导出端点**（SKILL.md 上传/打包，frontmatter 镜像 Anthropic 本是为无缝导入但无 HTTP 面）· **坏文件无诊断端点**（手改坏的 SKILL.md 列表里静默少一条）· `model`/`effort` frontmatter 存而不用。
- 锚点：`app/skill/*` · `handlers/skill.go` · `domain/skill/skill.go`。

### G13. 搜索几个缺口
- 无引擎下载进度 %（只布尔 downloading）· 无 reindex 进度/完成事件（fire-and-forget）· 无 per-workspace embedder 覆盖（机器级单套）· 无检索调参面（RRF/topK/floor 全硬编码常量）· 无「一键重嵌所有 workspace」（换 model 后其它 ws 靠惰性自愈）。

### G14. 沙箱几个缺口
- 无磁盘/数量配额上限（无「最大总占用/最大 env 数」可配）· 无 GC 自动化配置（`olderThanDays` 不持久化、无定时）· 无「列出可装版本」端点（同 G5）· 无聚合 env 视图（要按 5 个 ownerKind 各查一次）· disk-usage 不分项（只一个 totalBytes，不拆 runtime/env/per-kind）· 无 docker 状态独立端点（只在装 docker runtime 失败时才探报）。

### G15. 模型目录外 id 静默丢弃
- 贫端点 provider（openai/deepseek/anthropic…）`/models` 返的 id 若不在本版静态 spec 表 → `describeFromSpecs` 跳过 → **不出现在 capabilities**（虽然底层 `Request.ModelID` 直接用仍能调通）。前端无「手动输入 model id」通道时这些新模型对用户不可见。
- 补：capabilities 带「目录外原始 id」或前端给手动输入通道。锚点：`infra/llm/models_common.go:94`。

### G16. 工作区小缺口
- 无重名「建议名」（重名直接 409）· avatar_color 无服务端调色板枚举（纯前端约束）· 无工作区图标/emoji（只有颜色）· 无对称的「当前工作区」服务端查询（纯客户端态）。

---

## 给实现者的优先级建议（一句话）

- **先做 P0 四条**（G1 配额 / G2 装机进度 / G3 清默认 / G4 谁引用）——它们直接决定「模型与 Key」「免费档」「运行时」三页能不能做得不残。
- **G1 配额优先走「客户端直连网关 /v1/quota」**（网关已就绪、后端零改），是最快解。
- **P1 元数据端点（G5）**优先级也高——不补的话前端要复刻一堆 Go 常量、后端一改就漂，是长期债。
- P2 大多可先 UI mock 或不做，按产品节奏排。
