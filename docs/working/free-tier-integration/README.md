---
id: WRK-032
type: working
status: active
owner: @weilin
created: 2026-06-20
reviewed: 2026-06-20
review-due: 2026-09-18
audience: [human, ai]
landed-into:
---

# Anselm 免费档网关 —— 后端集成实施计划（START HERE）

> **本文 = 把已上线的免费网关接进 Anselm 后端作为「内置 provider/model」的代码级实施计划。** 自包含、可据以施工。
>
> **前序**：建网关本身的蓝图见 [`../../archive/free-tier-gateway/README.md`](../../archive/free-tier-gateway/README.md)（WRK-030，已落地为生产网关 `api.anselm.host`）。其 §9「客户端集成」是本文的设计种子；**本文是 §9 的代码级落地细化 + 据当前 `backend/` 逐 seam 核验的加固版**。
>
> **方法论**：本文据 ① 对当前 `backend/` 逐 seam 静态核验（带 `file:line`）+ ② 蓝图 §9 的 5 视角评审结论 + ③ 一轮 11-agent workflow 研究 + ④ 对抗式准确性核验（14 论断、11 ACCURATE、3 必修正）合并而成。
>
> **产品前置决策（已与 @weilin 确认 2026-06-20）**：**免费档是全功能 agentic provider** —— 网关 `tools`/`tool_choice` + 流式 `tool_call` 透传已由 @weilin 快修并**对生产端实测确认**（2026-06-20：非流 `finish_reason:tool_calls` + 流式 11 帧 `tool_calls` 拼出 `get_weather{"city":"Tokyo"}`）。故 Anselm 这边**三个用途（dialogue/utility/agent）一并接入、不留 flag**，loop 无条件挂工具即可。

---

## 0. 结论先行

- **方案**：免费档 = 后端 boot 时在每个 workspace **自动维护一条「受管 api_key 行」**（provider=`anselm`、base_url=网关、key=install token、植入合成 TestResponse 直接置 `test_status=ok`）。`gwk_` token 骑现有 `api_keys` 表的加密 Bearer 路径 → **零新表、零改解析链**。
- **为什么低成本**：唯一解析缝 `modelclient.Resolve`（`app/modelclient/modelclient.go:39`）**provider-名驱动、从不 special-case 名字**；token 作为加密字符串复用 `api_keys.key_encrypted` + AES-256-GCM 机器绑定加密。
- **工作量**：~2.5–3 天，**一次做到位、无质量欠债**（弃用「MVP/增量」分法——配额可见/错误分语义/坏-token 自愈都并入本次，详见 §10）。
- **三个决策全部已定**（§11）：① 隐私同意+零配置在场 ② 注册独立 `anselm` provider ③ tools 透传实测确认→agent 默认一并接入。

---

## 1. 现状架构（配 API + 选 model 怎么转）

### 1.1 三个并行注册表（最重要的结构事实）

整套由**三个以小写 provider 字符串为键的注册表**支撑，必须锁步：

| 注册表 | 文件 | 职责 |
|---|---|---|
| Provider 目录 `providers` map | `app/apikey/providers.go:45-63` | displayName / 默认 baseURL / 探针方式（`TestMethod`） |
| LLM wire 注册表 `providerRegistry` | `infra/llm/provider.go:106-120` | Request→HTTP + ParseStream + DescribeModels（各家方言） |
| 静态 model specs（如 `deepseekSpecs`） | `infra/llm/deepseek.go:459` | ctx window / knobs / vision |

加 provider 要改**前两张 map**；加 model 要补**第三张 specs**。`infra/llm` 的 `lookupProvider` 对**未注册 name 静默 fallback 到 openai 方言**（`provider.go:134`）——会注入 openai 专有 knobs，与网关白名单打架。**故新 provider 必须两张 map 都登记，不能只加一处。**

### 1.2 配 key（"配 API"半）

- HTTP：`POST/GET/PATCH/DELETE /api/v1/api-keys` + `POST .../{id}:test` + `GET /api/v1/providers`（**豁免 RequireWorkspace**，供 onboarding，`handlers/apikey.go:37-40`）。
- `Create {provider, key, baseUrl, apiFormat}` → `validateCreate`（`app/apikey/apikey.go:118-133`）：**`key` 必填、无 per-provider 豁免**（受管行接入要绕过此处，见 §3）。
- 加密：`encryptor.Encrypt` AES-256-GCM，**主密钥由机器指纹派生**（`infra/crypto/aesgcm.go:46-50`，指纹来自 `fingerprint.go:23` 的 per-machine ID）。**密文机器绑定**——换机不可解。
- 表 `api_keys`（`infra/store/apikey/apikey.go:25-45`）：`key_encrypted TEXT NOT NULL` / `test_response TEXT`（free-form）/ `test_status` / `base_url` / `workspace_id NOT NULL`（D2）。约束：`idx_api_keys_ws_displayname` UNIQUE（仅活跃行）；**无 `(workspace_id, provider)` UNIQUE**（同 provider 可多 key、去重靠 app）。
- `ProviderMeta`（`providers.go:36-43`）只有 `Name/DisplayName/DefaultBaseURL/BaseURLRequired/TestMethod/Category`——**无 AuthScheme/Capabilities/key-可选 flag**。**baseURL per-row 可覆盖**（`resolveBaseURL`，`apikey.go:296-304`）。

### 1.3 选 model（"选 model"半）

- **无硬编码全局 model 表。** model 目录**每 workspace 从已配 key 的探针存档派生**：
  `:test 存 raw /models body → CapabilityService.List() 读 test_status==ok 的 key → DescribeModels(provider, TestResponse) → describeFromSpecs(staticSpecs, raw) → []ModelInfo`。
- 🔴 **死状态陷阱（§9.2 评审 high）**：`CapabilityService.List`（`app/model/capability.go`）产出 model **不只看 `test_status==ok`，还要 `DescribeModels` 能从 `TestResponse` 解析出 model id，且 id 命中静态 specs 前缀**（`describeFromSpecs` 跳过无匹配 id，`models_common.go:89-108`）。→ **受管行必须植入合成 `TestResponse`**，否则「ok 但选择器里没模型」。
- 能力布尔只有 `Vision`+`NativeDocs`（`infra/llm/provider.go:143-151`）；reasoning 经 `Knob`（非布尔）。`deepseek-v4-flash` **已在 `deepseekSpecs`**（`deepseek.go:459`：1M ctx / 384K out / 无 vision / knobs=`dsKnobs()`）。
- `model.ModelRef`（`domain/model/model.go:24`）= 选择值 `{APIKeyID, ModelID, Options}`——**provider 经 api_key 隐式携带**。

### 1.4 调用解析缝（网关插入点）

唯一入口 `modelclientapp.Resolve`（`app/modelclient/modelclient.go:39`），**provider-中立、从不 special-case provider 名**：
1. `modeldomain.Resolve` → `ModelRef`（override-then-default；无默认 → `MODEL_NOT_CONFIGURED`，`model.go:85`）。
2. `keys.ResolveCredentialsByID` → 解密 `Credentials{Provider, Key, BaseURL, APIFormat}`（`apikey.go:241`，**每次调用解密无缓存**）。
3. `factory.Build` → `(Client, baseURL)`（`factory.go:46`）。
4. `BuildRequest` 各家方言；DeepSeek 硬编码 `BaseURL+"/chat/completions"` + Bearer（`deepseek.go`）→ **`gwk_` token 走现有 Bearer 路径零改**。

**关键 gating 事实**：`loop.go:152-153` **无条件挂工具**（`req.Tools = ToLLMDefs(host.Tools())`，无 `SupportsTools` gate，架构显式信任 provider 兑现）。→ 配合「网关已透传 tools」的前置决策，免费档**自动获得 agentic 能力**，无需加能力轴。

---

## 2. 推荐方案：C-混合 + 蓝图 §9 加固

**把 `gwk_` token 当一条「受管 api_key 行」自动开通进现有 `api_keys` 表，embed deepseek 方言，boot/建 workspace 时自动 install + 植入合成 TestResponse —— 零新表、零配置。**

- **否决 A**（手敲 token 配 custom 端点）：无 in-app install、无品牌、无默认 wiring，不满足零配置愿景。
- **否决 B 的「专门全局 token 表」进首版**：为「一机一 token」建整张表违反复用优先原则（设计原则 #8）。
- **`anselm.go` 用 embed `deepseekProvider`** 覆盖 `Name/DefaultBaseURL/DescribeModels` 三方法（~15 行），继承 `BuildRequest/ParseStream` + `reasoning_content` round-trip 全套。**不直接复用 deepseek 名**的理由：`deepseekProvider.DefaultBaseURL()` 硬编码 `api.deepseek.com`（删 base 即打到 deepseek 真站，对内置 provider 太脆）；provenance 标 "deepseek" 失真；`dsKnobs()` 在网关是死 UI 钮。**（注：此点与蓝图 §9.1「v1 复用 deepseek 名最省改」分歧 → 见 §11 开放决策②。）**

---

## 3. 端到端改动清单（按依赖序、分层）

### 阶段 0 — infra/llm（wire 层，无上游依赖）

| # | 文件 | 改动 |
|---|---|---|
| 0.1 | `infra/llm/llm.go`（sentinel 块 `:29-35`） | 加 **独立 sentinel** `ErrQuotaExhausted = errorspkg.New(KindRateLimited, "LLM_QUOTA_EXHAUSTED", …)`。🔴 **必须是独立 sentinel、绝不 alias 成 `ErrRateLimited`**：`isRetryable` 按 `errors.Is(sentinel)` 身份分派（`:263-281`），`ErrRateLimited` 是**可重试**的；alias 会让 402 被 `Generate` 盲重试 3×。加测试断言「Generate 不重试 ErrQuotaExhausted」。 |
| 0.2 | `infra/llm/transport.go`（`classifyHTTPError` switch `:138`） | 加 `case http.StatusPaymentRequired → ErrQuotaExhausted`。现状 402 落 default→`ErrProviderError`（502+可重试，错）。429 已映射 `ErrRateLimited`（可重试，配额窗口短可接受）。 |
| 0.3 | `infra/llm/deepseek.go`（`dsChunkError` `:395`） | 🔴 **真 wire 改（非纯读）**：`dsChunkError` **当前只有 `Message`、无 `Code` 字段**。加 `Code string json:"code"`，共享 emit 路径读 `code=="BUDGET_EXHAUSTED"` → `EventError` 包 `ErrQuotaExhausted`。因 anselm.go embed 继承 ParseStream，此改落 deepseek.go 共享路径（deepseek 也受益、无害）+ 配 deepseek 回归测试。 |
| 0.4 | `infra/llm/anselm.go`（新建） | embed `deepseekProvider`，**必须覆盖 `DescribeModels`** 用 `anselmSpecs`（knobs=nil，否则 picker 显示死 thinking/reasoning 钮）+ `Name()="anselm"` + `DefaultBaseURL()="https://api.anselm.host/v1"`。定义 `anselmSpecs = []modelSpec{{"deepseek-v4-flash", 1_000_000, 384_000, nil, false, false}}`。 |
| 0.5 | `infra/llm/install.go`（新建） | `InstallClient`：`POST {BaseURL}/install {fingerprint,client}` → `{token,monthlyQuota,resetAt}`，非 200 经嵌套 `{error:{code,message}}` 映射。~50 行。 |
| 0.6 | `infra/llm/provider.go`（`buildProviderRegistry` `:106`） | 加 `"anselm": newAnselmProvider()`。不加则 fallback openai 方言 → DescribeModels 按 openaiSpecs 解析 → **丢弃 deepseek-v4-flash** → model 消失。**强制**。 |
| 0.7 | `infra/llm/anselm_test.go` + deepseek 回归 | 断言 `Bearer gwk_…` + `reasoning_content`-先于-`content` + 嵌套 error code → `ErrQuotaExhausted`（**非重试**）+ install httptest。 |

### 阶段 1 — app/apikey（目录 + 受管创建路径）

| # | 文件 | 改动 |
|---|---|---|
| 1.1 | `app/apikey/providers.go`（`:57` 后） | 加 `"anselm": {DisplayName:"Anselm Free (DeepSeek)", DefaultBaseURL:"https://api.anselm.host/v1", TestMethod:GetModels, Category:LLM}`。🔴 **`/v1` 必须在 DefaultBaseURL**（探针追加 `/models`、wire 追加 `/chat/completions`）。 |
| 1.2 | `app/apikey/apikey.go`（新 `CreateManaged` 路径） | 🔴 **新增受管创建路径**：绕过 `validateCreate` 的 key-必填、**直接置 `test_status=ok` + 植入合成 `test_response={"object":"list","data":[{"id":"deepseek-v4-flash","object":"model"}]}`、跳过 live 探针**。这同时**消除「探针 402/429 翻 key 脑裂」风险**（根本不跑探针）。token 仍走既有 encrypt-on-create。 |
| 1.3 | `app/apikey/apikey.go`（`Update` 守卫） | 🔴 **不可编辑**：`Update` 现不咨询任何 scanner（§9.2）。加前置守卫——`provider=="anselm"` 的行拒绝编辑（`API_KEY_IMMUTABLE`）。**不可删**已由 `RefScanner` 兜（受管 ModelRef 引用 → `Delete` 返 `API_KEY_IN_USE`）。**无需新列**：受管性以 `provider=="anselm"` 隐式判定。 |

### 阶段 2 — app/freetier（新 provisioner 包）

| # | 文件 | 改动 |
|---|---|---|
| 2.1 | `app/freetier/freetier.go`（新建，别名 `freetierapp`） | `Provisioner.EnsureForWorkspace(wsCtx)` 幂等单元（详见 §4）。依赖既有端口 `apikeyapp.Service`（CreateManaged/List）、`workspaceapp.Service`（Pick/SetDefault）、`llminfra.InstallClient`、`cryptoinfra.MachineFingerprint`。 |
| 2.2 | `app/freetier/freetier_test.go` | 幂等（二次 no-op）、仅未设设默认、指纹缺失优雅降级、Create 唯一冲突当幂等 no-op。 |

### 阶段 3 — bootstrap（装配 + 两钩子）

| # | 文件 | 改动 |
|---|---|---|
| 3.1 | `bootstrap/build_services.go`（`keys` 后 `:133` 附近） | 构造 `freetier := freetierapp.NewProvisioner(keys, ws, llminfra.NewInstallClient(), cryptoinfra.MachineFingerprint, log)`。🔴 **`apikeyapp.NewService` 是 4 参 `(repo, enc, tester, log)` 且 nil log panic**（`apikey.go:50-55`）——任何 NewService 触点传全 4 参。 |
| 3.2 | `bootstrap/build.go`（`forEachWorkspace` `:269`） | 在 `handler.Boot`/`mcp.Boot` 旁加 `freetier.EnsureForWorkspace(wsCtx)`（闭包已是 per-ws `Detached(wsID)` ctx，`:309`）。best-effort log（失败只降级免费档不挂 boot）。**回填既存 workspace + 自愈上次失败 install。** |
| 3.3 | `app/workspace/workspace.go`（`Create` 内 `repo.Save` 后 `:109`） | 🔴 **首装唯一承载路径**：fresh data dir 零 workspace → Boot 循环不 provision 任何东西。加 nil-tolerant `OnCreated` 回调（仿 `SetReaper` `:54` 在 build 后注入，破环），`Create` 成功后用 `Detached(w.ID)` 调它接到 `freetier.EnsureForWorkspace`。**必须 best-effort**——freetier 失败绝不能让 `Workspace.Create` 失败（否则 onboarding 挂）。 |

**DB 迁移：无。** token 复用 `key_encrypted`、合成 /models body 复用 `test_response`、受管性以 `provider=="anselm"` 隐式判定，无新表/列/ID 前缀（`aki_` 复用）。

**前端契约：无需改 Dart DTO。** `anselm` provider/model 经既有 `GET /providers` + `GET /model-capabilities` 暴露，DTO 对 provider 字符串/model id/错误码均 open + `unknown` 兜底。

---

## 4. `gwk_` token 生命周期 + Provisioner

**放哪**：作为普通 `api_keys` 行（provider `anselm`），**不进 settings.json（明文）、不进新表**。白享 AES-256-GCM 机器绑定加密 + masking + RefScanner 删除保护。

**`EnsureForWorkspace(wsCtx)`（幂等）**：
1. **去重**：`keys.List(wsCtx, {Provider:"anselm"})` 非空即已配 → 跳步 4 设默认。（无 `(ws,provider)` UNIQUE，去重在 app。）
2. **指纹（隐私）**：`fp,err := MachineFingerprint()`。🔴 **发 `sha256(fp)` hex、绝不发裸序列号**。`err==ErrNoFingerprint`（in-memory/测试）→ log + 返 nil（best-effort，镜像 encryptor 回退纪律）。
3. **install**：`InstallClient.Install(wsCtx, sha256(fp), "anselm-desktop/<ver>")`。任何错 → log + 返 nil。
4. **持久化**：`keys.CreateManaged(wsCtx, {Provider:"anselm", DisplayName:"Anselm Free (DeepSeek)", Key:token, BaseURL:".../v1", TestStatus:ok, TestResponse:合成/models body})`。🔴 **DisplayName 唯一冲突当幂等 no-op**（`idx_api_keys_ws_displayname` UNIQUE）。
5. **设默认（仅未设时）**：见 §7 —— **此步与隐私同意耦合，是开放决策①**。

**`ModelID` 钉死 `"deepseek-v4-flash"`**：网关 coerce model 字段，但 provenance（message + `agent_executions.ModelID`）记 workspace 默认存的 id，钉死避免误导。

**失效重领**：token per-machine；配额耗尽是「有效但暂无额度」**非失效** → `402→ErrQuotaExhausted`，**绝不触发 `MarkInvalidByID`**（loop 本就不调，仅 `web/search.go:220` 调；新 402 路径**不加**该调用）。配额按月 `resetAt` 自恢复。真失效（401/403）→ MVP 需手动处理（见下 RefScanner 注意）。换机：AES 机器绑定解密失败 → 重 provision mint 新 token。

🔴 **RefScanner 锁死注意**：受管 key 一旦成默认，删它返 `API_KEY_IN_USE`（`apikey.go:177`）。坏-token 兜底「手动删行重领」**走不通**——必须**先解默认再删**。MVP 文档化此序列；first-class 增量加「401 时标记 + Boot 重 mint」。

---

## 5. 能力 / 错误映射 / 配额可见性

### 能力（embed 自动对齐）
- `anselmSpecs` vision=false/nativeDocs=false → `contentCaps`（`bootstrap/model_info.go:55`）honored；附件降级为文本（与网关丢 vision 对齐）。
- knobs=nil → picker 不给死钮（**embed 必须覆盖 DescribeModels**，否则带 `dsKnobs()`）。
- ctx=1M → `WindowResolver`（`model_info.go:71`）喂 contextmgr 压缩预算。
- **tools**：网关已透传（前置决策）→ loop 无条件挂工具即可，免费档全 agentic。验收必须确认 tool_call round-trip（§9）。

### 错误映射（402/429 → 平台错误体）
| 出口 | 行为 |
|---|---|
| 402 pre-stream | `classifyHTTPError` → `ErrQuotaExhausted`（非重试 + HTTP 429 Envelope） |
| 402 in-stream `{error:{code}}` | `dsChunkError.Code=="BUDGET_EXHAUSTED"` → `EventError` 包 `ErrQuotaExhausted`；wire code 仍 `LLM_STREAM_ERROR`（`loop.go:181`）但 errMsg 带配额原因 |
| 429 族 | 已 → `ErrRateLimited`（可重试，窗口短可接受） |
| **绝不误禁** | 新 402 路径**不加** `MarkInvalidByID` |

> 🔴 §9.5 更细的「按 `error.code` 分语义 + 仅 `INVALID_TOKEN` 重领、`ACCOUNT_BANNED` 不重领」是 first-class 增量；MVP 用 402→ErrQuotaExhausted 通用映射够用。拦截点：受管行走标准 `Stream→doRequest→classifyHTTPError`，现架构无「按 key 受管」钩子 → 增量时按 `base_url==网关` 判定 + 解析网关 body。

### 配额可见性（走 GET /v1/quota，非响应头）
🔴 **响应头路径在现架构不成立（§9.4 critical）**：`StreamEvent` 不承载 HTTP 响应头，透出要跨 4 层改 + 撞 E 系列「三流永不再加」。
- **MVP**：install 返回的 `{monthlyQuota,resetAt}` 可经 `CapabilityView` 小扩展只读暴露；用户经 402/429 错误路径感知耗尽。
- **增量 I2**：客户端调 `GET /v1/quota`（首屏 + 发消息后异步刷新），不实时但简单。**不进 MVP**。

---

## 6. 写码前必修正汇总（critic + §9）

1. 🔴 `ErrQuotaExhausted` **独立 sentinel**，绝不 alias `ErrRateLimited`（否则盲重试 3×）；加「不重试」测试。
2. 🔴 `apikeyapp.NewService` **4 参**（含 mandatory log，nil panic）。
3. 🔴 in-stream 配额检测要**给 `dsChunkError` 加 `Code` 字段**（当前仅 Message）+ 改 deepseek 共享 emit 路径；embed **必须覆盖 DescribeModels**（非仅 Name/BaseURL）。
4. 🔴 受管行**植入合成 TestResponse + 直接 ok + 跳过 live 探针**（§9.2）——否则死状态，且消除探针脑裂。
5. 🔴 **不可编辑**需新 `Update` 守卫（§9.2，按 provider=="anselm"）；**不可删** RefScanner 已兜，但坏-token「删行重领」需先解默认（§4）。
6. 🔴 首装**全靠 `Workspace.Create` 钩子**（Boot 循环对空 data dir 不 provision），且必须 best-effort 不挂 Create。
7. 🔴 DisplayName 唯一冲突当幂等 no-op；指纹缺失优雅降级返 nil。

---

## 7. 隐私 + 默认档（产品决策，必须定死）

🔴 **§9.6 评审 high**：Anselm 主打本地优先/隐私，免费档把 prompt 经作者服务器 + 过作者 DeepSeek 账号。**蓝图定论：免费档默认关闭 + 首用走显式同意 modal**（文案直言「内容会经我们的代理与第三方模型，免费档不享本地隐私保证」），自有 key 是首选叙事（更快/不限额）。

**与「零配置自动设默认」的张力 + 推荐调和**（= 开放决策①）：
- **provision 受管行 = 自动**（boot/建 ws 即静默建好那条 api_key 行，零配置「在场」）。
- **设为默认 / 首次实际调用 = 一次性同意门控**：受管行建好但**不自动设 default model**；首次用户主动选免费档（或点「启用免费档」）弹同意 modal → 同意后才 `SetDefault`。
- 这样「零配置在场」与「隐私显式同意」两全：用户装完即看到免费档可选，但 prompt 出本地前有一次知情同意。
- 仅未设时设（保护用户已选 model）；设后 RefScanner 自动护删。

---

## 8. 文档同步清单（落地同提交，CLAUDE.md §9 触发表）

| 文档 | 改动 |
|---|---|
| `references/backend/database.md` | `api_keys` 加 `anselm` provider 词汇；明示受管 token 存为普通行、合成 TestResponse 存 `test_response`、无新表/列/前缀。 |
| `references/backend/error-codes.md` | 新增 `LLM_QUOTA_EXHAUSTED`（Kind RateLimited→429）、`API_KEY_IMMUTABLE`；标注 402/429 **绝不触发 `MarkInvalidByID`**。 |
| `references/backend/api.md` | `anselm` 出现在 `GET /providers`；provisioning 是内部 boot 步、非 HTTP 端点（`POST /v1/install` 是后端→网关出站调用）。 |
| `references/backend/domains/apikey.md` | `anselm` 内置 provider + 受管创建路径（合成 TestResponse + 直接 ok + 跳探针）+ 不可编辑守卫 + RefScanner 不可删 + 用户解默认才能删。 |
| `references/backend/domains/model.md` | `anselm`/`deepseek-v4-flash` 零配置语义 + 能力（无 vision/docs/knobs、tools 经网关透传）+ 隐私同意门控默认。 |
| `references/backend/events.md` | **无改**（配额耗尽骑既有 `LLM_STREAM_ERROR`；GET /v1/quota 是客户端拉取非 SSE）。 |
| `references/frontend/contract.md` + 域 | 隐私同意 modal + 免费档可选项 + （增量）配额 gauge 的 DTO。 |
| `decisions/000X-free-tier-integration.md`（**新 ADR**） | 复用 apikey store + embed deepseek 方言；否决专门 token 表；受管行=合成 TestResponse；402 非重试配额 sentinel；隐私同意门控；agentic（依赖网关透传 tools）。 |
| `concepts/architecture.md` | **整体重述**「providers/keys」节，记录首个「用户视角 keyless 的内置受管 provider」seam（非追加）。 |

---

## 9. 风险 + 验收

### 风险
| 风险 | 等级 | 缓解 |
|---|---|---|
| **跨 repo 依赖**：网关未透传 tools → 免费档 agent 静默退化 | 高 | 验收门：evals 跑一个 tool_call 经网关 round-trip；网关侧工作未完成前 agent 默认不指向免费档。 |
| 误禁有效 token（402 触发 MarkInvalidByID） | 高（若未守） | 测试断言 402 路径不调 `MarkInvalidByID`。 |
| 指纹降级 error boot | 高（若未守） | `EnsureForWorkspace` ErrNoFingerprint 返 nil；测试覆盖。 |
| 隐私（发裸序列号） | 高（若未守） | 强制 `sha256(fp)`；测试断言出站 body 是哈希。 |
| 首装钩子失败挂 Create | 高（若未守） | OnCreated best-effort，错误不冒泡 Create。 |
| 死状态（无合成 TestResponse） | 中 | §9.2 受管创建路径强制植入；testend 断言 picker 出现 model。 |

### 验收
- **`make verify`**：`anselm_test.go`（wire+install+402 非重试）+ `freetier_test.go`（幂等+仅未设设默认+指纹降级+唯一冲突 no-op）+ deepseek 回归（dsChunkError.Code）+ `make docs` 全绿。
- **`make testend`（llmmock 零 token）**：fresh data dir → 建首个 workspace → 断言 `GET /api-keys?provider=anselm` 一行 + `GET /model-capabilities` 含 `deepseek-v4-flash` + 同意后 `dialogue/utility` 默认已设。install 用 testend stub。
- **`make evals`（EVALS=1）**：对真 `api.anselm.host` 跑 chat turn 断言 `reasoning_content` 渲染 + **一个 tool_call round-trip**（验跨 repo 依赖）+ 配额耗尽 → `ErrQuotaExhausted`。
- **手测**：新装 → 无 paste-key → 同意后首条消息得 DeepSeek 回复 + reasoning 折叠块 + 挂一个 tool 验真能调用。

---

## 10. 交付范围（一次做到位，无质量欠债）

> 弃用「MVP/增量」分法（易误读为半成品）。按「本次完整范围 / 不做的投机项 / 另一层」三段。

**本次完整范围（~2.5–3 天）— 一个完整、生产级、agentic 的免费档**
- 阶段 0–3 全 + 受管创建路径（合成 TestResponse + 跳 live 探针）+ 不可编辑守卫 + RefScanner 不可删 + 隐私同意门控（§7）。
- **三个用途全接**（dialogue + utility + **agent**）—— tools 透传已实测确认，无 flag/gating。
- **配额可见（后端）**：暴露 `{monthlyQuota,resetAt}` 只读视图（原 I2 后端部分并入）。
- **错误分语义**（原 I3 并入）：402 BUDGET（非重试、不误禁）vs 401/403 真失效，区分呈现。
- **坏-token 自愈**（原 I4 并入）：401/403 标记 + Boot 重 mint，免「手动解默认+删行」疮疤。
- 文档全套 + ADR + testend + evals（**含 tool_call round-trip 断言**，锁住 agentic 不回退）。
- **交付**：新装即见、同意后 chat+reasoning+**tools/agent** 通、配额可见+耗尽诚实报错、token 状态自愈。

**不做（现在做即过度设计）**
- **`SupportsTools` 能力轴**（原 I5）：免费档本就 agentic、无当前消费者；为不存在的「非工具 model」写抽象 = 过度设计。将来真引入再加。

**另一层（前端任务，不在本后端计划）**
- 配额 gauge UI + 隐私同意 modal 的前端实现（后端已备好数据 + 门控接口）。

---

## 11. 决策（全部已定 2026-06-20）

1. ✅ **隐私同意 + 零配置在场**（§7）：自动 provision 受管行（零配置「在场」）+ 设默认/首用走一次性同意 modal（prompt 出本地前知情同意）。@weilin 确认。
2. ✅ **注册独立 `anselm` provider**（embed deepseek，~15 行，provenance 真实、base_url 不脆），非复用 deepseek 名。@weilin 确认。
3. ✅ **跨 repo 时序 — 已解除**：网关 tools 透传由 @weilin 快修，**对生产端实测确认**（2026-06-20：非流 `finish_reason:tool_calls` + 流式 11 帧 `tool_calls` 拼出 `get_weather{"city":"Tokyo"}`）。故 agent 默认**一并接入、不留 flag**；evals 加 tool_call round-trip 断言锁住不回退。

> **落地后**：本文结论提取进 `concepts/architecture.md` + `references/backend/domains/{apikey,model}.md` + 新 ADR，填本文 `landed-into:`，移 `archive/`（§7 working 文档纪律）。
