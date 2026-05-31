---
id: DOC-115
type: reference
status: active
owner: @weilin
created: 2026-04-22
reviewed: 2026-05-31
review-due: 2026-06-30
audience: [human, ai]
---
# model domain — 详细设计文档

**所属 Phase**：Phase 2（基础对话能力，第 2 个 domain）
**状态**：✅ 已实现（2026-04-25 初版；2026-05-28 model selection redesign：3 scenarios + APIKeyID；2026-05-30 thinking + capability）
**职责**：为每个"场景"（scenario）记录用户选定的 `(apiKeyID, modelID)`；给 chat / workflow / subagent 提供"我该用谁"的策略层（provider 由 apiKey 隐含）；管理用户的 per-model 能力 override（`model_cap_overrides` 表）
**依赖**：
- `infra/db`（GORM 底层）+ `pkg/reqctx`（userID ctx 读取）
- **不依赖** `domain/crypto`（无敏感数据）
- **依赖** `apikeydomain.KeyProvider.ResolveCredentialsByID`：F1 校验 `Upsert` 收到的 `apiKeyId` 存在 + 跨用户隔离（2026-05-28 redesign 后；不再校验"provider 是否有 key"）

**被依赖**：`chat.Service` / 未来的 `workflow` LLM 节点 / `knowledge` embedding 层，**全部通过 `modeldomain.ModelPicker` 接口**

**关联文档**：
- [`../backend-design.md`](../backend-design.md) — 总规范（设计原则 #5 端到端推演先行 + #6 反校验剧场）
- [`../service-contract-documents/api-design.md`](../service-contract-documents/api-design.md) — API 索引
- [`../service-contract-documents/database-design.md`](../service-contract-documents/database-design.md) — 表索引
- [`../service-contract-documents/error-codes.md`](../service-contract-documents/error-codes.md) — 错误码索引

---

## 1. 为什么要这个 domain

chat 发消息时要回答"该调 OpenAI 的 gpt-4o 还是 Anthropic 的 claude-3-5-sonnet？"——**谁该决定这件事**？

当前三方零件分工：

| domain | 管 | 不管 |
|---|---|---|
| **apikey** | 凭证存储（"我是谁"）| "该用谁" |
| **model**（本 domain）| **策略**（"这个场景用谁"）| 怎么调 |
| **chat** / workflow / knowledge | 编排（"跑 LLM 调用"）| "该用谁" |

没有 model domain，"provider 从哪来"就没有归属——这个坑是在推演 chat 端到端调用链时发现的，立下了 **"端到端推演先行"** 设计原则（backend-design.md §设计原则 #5）。

---

## 2. 核心决策（已敲定）

| 决策 | 选择 | 理由 |
|---|---|---|
| Scenario 粒度 | **一个 scenario 最多 1 条活跃配置**（`UNIQUE(user_id, scenario)`）| 防止用户意外存两条互斥 |
| Scenario 白名单位置 | **app 层 `IsValidScenario()`**，**DB 不 CHECK** | 白名单会随 Phase 扩张（Phase 4 加 workflow_llm，Phase 5 加 embedding / intent），改 DB CHECK 成本高 |
| HTTP 路径形状（Q1）| **`/api/v1/model-configs/{scenario}`**（复数 + path param）| 单数 `/model-config` 把 Phase 4+ 扩展堵死；复数是 N5 规范 |
| 是否校验 provider 在 apikey 白名单（Q2，旧）| **不再相关** | 2026-05-28 redesign 后 ModelConfig 不存 provider；改成"`apiKeyId` 存在 + 跨用户隔离"，调 `keys.ResolveCredentialsByID`（F1）|
| 是否校验用户真有该 provider 的 key（Q3，旧）| **不再相关** | 同上——直接按 id 校验比按 provider 校验严格 |
| DELETE 端点？| **不做** | 删 = 未配置 = chat 报 `MODEL_NOT_CONFIGURED`；用户要改直接 PUT 新值即可 |
| PATCH 端点？| **不做** | provider + modelId 强耦合（换 provider 必换 modelId），PATCH 分开改会造非法组合 |
| GET 单条 `/{scenario}`？| **不做（Phase 2）** | Phase 2 最多 1 条，GET 列表够；未来 scenario 多了再加 |
| 事件 | **无**（Phase 2 不推） | 配置类资源由用户主动改，无异步通知需求 |

---

## 3. 多租户准备

继承项目级约定（同 apikey）：

- 表带 `user_id TEXT NOT NULL`
- 方法首次动作：`reqctxpkg.RequireUserID(ctx)` 取值；缺失返包装的 `reqctxpkg.ErrMissingUserID` —— 接线 bug，不是 401
- Phase 2 ctx 注入 `"local-user"`

---

## 4. Scenario 白名单（2026-05-28 redesign：3 scenarios）

代码位置：`internal/domain/model/model.go`

### 当前清单（3 个）

| Scenario 常量 | 值 | 含义 | 覆盖 callsites | 典型模型 |
|---|---|---|---|---|
| `ScenarioDialogue` | `"dialogue"` | 用户主对话 + subagent（subagent 继承父 conv 的 ModelOverride，归 dialogue）| chat runner 主循环 + subagent spawn | Claude Sonnet 4 / DeepSeek Chat / GPT-4o |
| `ScenarioUtility` | `"utility"` | 工具内部 LLM 活儿——无 instance override，统一一档 | autoTitle / compaction / WebFetch summary / function/handler/skill/mcp search rerank / function/handler env-fix（11 个 callsites）| Claude Haiku 4 / gpt-4o-mini / DeepSeek（小快省）|
| `ScenarioAgent` | `"agent"` | Workflow agent/llm 节点（接受 node 级 ModelOverride）| `app/scheduler/dispatch_agent.go` + `dispatch_llm.go` | 同 dialogue 档；workflow 批量跑可降级到便宜模型 |

**心智模型**：**Layer 1 默认配置（scenario 级）+ Layer 2 实例 override（conv / node 级）**。dialogue + agent 接 override；utility 不接（工具内部活儿无业务理由让用户挑模型）。详 spec `docs/superpowers/specs/2026-05-28-model-selection-redesign-design.md`。

### 删除的 scenarios（pre-redesign 残留）

老 `"chat"` / `"web_summary"` 两个 scenario 已从 const 表中删除——产品未上线无 migration 顾虑；onboarding 路径 + 12 个 callsite 同步迁移到 3 scenario。

### 演化（未来 Phase 再加 const）

| Phase | 可能新增 | 说明 |
|---|---|---|
| Phase 5 | `ScenarioEmbedding` | 知识库向量化（text-embedding-3-small / bge 等独立 model 家族）|
| Phase 5 | `ScenarioVision` | 图片附件分析（GPT-4o vision / Claude Sonnet vision 等）|
| Phase 5 | `ScenarioIntent` | 意图识别（Haiku / 4o-mini 小模型省钱）|

**扩展方式**：新增一个 const + 在 `IsValidScenario()` 返回 true + `ModelPicker` 接口加相应方法（`PickForEmbedding` 等）+ `llmclient` 加对应 `ResolveXxx` 函数 + onboarding 多写一行 PUT。**API 形状不变；前端 SettingsModal 自动多一卡。**

### 工具函数（代码设计）

```go
// internal/domain/model/model.go
const (
    ScenarioDialogue = "dialogue"
    ScenarioUtility  = "utility"
    ScenarioAgent    = "agent"
)

func IsValidScenario(s string) bool {
    switch s {
    case ScenarioDialogue, ScenarioUtility, ScenarioAgent:
        return true
    default:
        return false
    }
}

func ListScenarios() []string {
    return []string{ScenarioDialogue, ScenarioUtility, ScenarioAgent}
}
```

---

## 5. 领域模型

### ModelConfig struct（`internal/domain/model/model.go`）

```go
// internal/domain/model/model.go

// ModelRef = (apiKeyID, modelID) — provider is implicit via the api_key
// referenced by APIKeyID. Stored on conversation.modelOverride and
// workflow NodeSpec.modelOverride; persisted as JSON.
//
// ThinkingSpec 挂在 ModelRef 上，随 modelOverride 一起持久化/传播；
// nil = 使用 ModelConfig.Thinking 的 scenario 级默认。
type ModelRef struct {
    APIKeyID string        `json:"apiKeyId"`
    ModelID  string        `json:"modelId"`
    Thinking *ThinkingSpec `json:"thinking,omitempty"`
}

// ThinkingSpec 控制 LLM 推理行为；挂在 ModelRef + ModelConfig 上。
//   Mode:   "auto" = 按 provider 默认；"on" = 强制开推理；"off" = 强制关
//   Effort: 可选，低/中/高档，各 provider 映射不同字段
//   Budget: 可选，Anthropic budget_tokens（整型，token 级精细控制）
type ThinkingSpec struct {
    Mode   string `json:"mode"`             // "auto" | "on" | "off"
    Effort string `json:"effort,omitempty"` // "low" | "medium" | "high"
    Budget *int   `json:"budget,omitempty"` // Anthropic only: budget_tokens
}

type ModelConfig struct {
    ID        string         `gorm:"primaryKey;type:text" json:"id"`
    UserID    string         `gorm:"not null;type:text;uniqueIndex:idx_mc_user_scenario,priority:1" json:"-"`
    Scenario  string         `gorm:"not null;type:text;uniqueIndex:idx_mc_user_scenario,priority:2" json:"scenario"`
    APIKeyID  string         `gorm:"not null;type:text;column:api_key_id" json:"apiKeyId"`
    ModelID   string         `gorm:"not null;type:text" json:"modelId"`
    Thinking  *ThinkingSpec  `gorm:"type:text;serializer:json" json:"thinking,omitempty"` // 2026-05-30
    CreatedAt time.Time      `json:"createdAt"`
    UpdatedAt time.Time      `json:"updatedAt"`
    DeletedAt gorm.DeletedAt `gorm:"index" json:"-"`
}

func (ModelConfig) TableName() string { return "model_configs" }
```

### 字段说明

| 字段 | 说明 |
|---|---|
| `ID` | `mc_<16hex>` 格式（8 字节 crypto/rand，与 apikey 的 `aki_` 一致）|
| `UserID` | JSON 不输出（`json:"-"`，与前端无关）|
| `Scenario` | 白名单常量（`"dialogue"` / `"utility"` / `"agent"`，2026-05-28 redesign）|
| `APIKeyID` | 引用 `api_keys.id`（`aki_<16hex>`）；DB 列 `api_key_id`（snake_case）；app 层校验存在 + 跨用户隔离（F1：`keys.ResolveCredentialsByID`），无 GORM FK 声明（V1.2 D4）|
| `ModelID` | 字符串，如 `"deepseek-chat"` / `"claude-sonnet-4-5"`；**不校验**（不同 provider 的 model 命名无统一白名单）|
| `Thinking` | `*ThinkingSpec`，GORM `serializer:json` 存文本列；nil = 未设定（接受 provider/model 级默认）（2026-05-30）|
| 时间戳 | GORM 自动维护 |
| `DeletedAt` | 软删，GORM 内置 |

**字段变更（2026-05-28 redesign）**：原 `Provider TEXT NOT NULL` → `APIKeyID TEXT NOT NULL`（DB 列名 `provider` → `api_key_id`）。`ResolveCredentialsByID` 拿回的 `Credentials.Provider` 给 `llmclient.Bundle.Provider` 派生（日志用）。

### 唯一约束

```
UNIQUE(user_id, scenario)   -- 当前：GORM tag 全索引（含已软删行）
```

**当前实现**：GORM tag `uniqueIndex:idx_mc_user_scenario` 产生全索引（不带 WHERE）。`schema_extras.go` **没有** `model_configs` 这一组——partial UNIQUE 暂缓（详 §17）。

理由：当前 Service.Upsert 只走"查现有 → 决定 insert / update"，**无 delete + recreate 同 scenario 的路径**，全索引与 partial 等价。未来若引入 soft-delete 后立刻新建同 (user_id, scenario) 的路径，需要在 `infra/db/schema_extras.go` 追加：

```sql
-- 假设引入 soft-delete + recreate 路径时再加：
DROP INDEX IF EXISTS idx_mc_user_scenario;
CREATE UNIQUE INDEX idx_mc_user_scenario
  ON model_configs(user_id, scenario)
  WHERE deleted_at IS NULL;
```

在那之前**不**预设 partial UNIQUE。

### ModelCapOverride struct（`internal/domain/model/model.go`，2026-05-30 新增）

用户对某 (provider, model) 组合的能力 override，用于覆盖 `pkg/modelcaps` 的静态规则（stale-catalog 逃生舱）。

```go
// ModelCapOverride lets users correct stale or missing capability data
// when the static modelcaps catalog has not yet caught up to a new model.
//
// ModelCapOverride 允许用户为静态能力目录尚未收录的新模型手动填入 capability。
type ModelCapOverride struct {
    ID             string         `gorm:"primaryKey;type:text" json:"id"` // mco_<16hex>
    UserID         string         `gorm:"not null;type:text" json:"-"`
    Provider       string         `gorm:"not null;type:text" json:"provider"`
    ModelID        string         `gorm:"not null;type:text" json:"modelId"`
    ThinkingShape  *string        `gorm:"type:text" json:"thinkingShape,omitempty"`
    ContextWindow  *int           `gorm:"type:int" json:"contextWindow,omitempty"`
    MaxOutput      *int           `gorm:"type:int" json:"maxOutput,omitempty"`
    CreatedAt      time.Time      `json:"createdAt"`
    UpdatedAt      time.Time      `json:"updatedAt"`
    DeletedAt      gorm.DeletedAt `gorm:"index" json:"-"`
}

func (ModelCapOverride) TableName() string { return "model_cap_overrides" }
```

| 字段 | 说明 |
|---|---|
| `ID` | `mco_<16hex>` 格式 |
| `Provider` + `ModelID` | 联合唯一（per user；部分 UNIQUE `WHERE deleted_at IS NULL`）|
| `ThinkingShape` | 若非 nil，覆盖静态规则中的 thinking 形状（`"none"` / `"toggle"` / `"effort"` / `"budget"`）|
| `ContextWindow` | 若非 nil，覆盖上下文窗口大小（token 数）|
| `MaxOutput` | 若非 nil，覆盖最大输出 token 数 |

**合并优先级**（`apikey.CapabilityService.ResolveCapabilities`）：
```
用户 override（ModelCapOverride）> 静态规则（modelcaps.Lookup）
```
live overlay（未来从 provider API 自动拉取）留了接口位置但当前未实现（deferred）。

### CapabilityService（`internal/app/apikey/capability.go`，2026-05-30 新增）

将 provider 静态能力目录 + 用户 override 合并为 `ModelCapability`，供 LLM 推理层和前端 ThinkingControl 消费。归在 `apikeyapp` 包（消费 apikey + modelcaps 两域，无循环依赖）。

```go
type ModelCapability struct {
    Provider       string
    ModelID        string
    ThinkingShape  string  // "none" | "toggle" | "effort" | "budget"
    ContextWindow  int
    MaxOutput      int
    UsableInput    int     // ContextWindow - MaxOutput - SafetyBuffer
    IsOverride     bool    // true = 来自用户 override，非静态规则
}

// CapabilityService exposes resolved per-model capabilities and
// user override CRUD; consumed by contextmgr and the frontend.
//
// CapabilityService 暴露解析后的 per-model 能力 + 用户 override CRUD；
// 被 contextmgr（注入 Resolver）和前端 ThinkingControl 消费。
type CapabilityService interface {
    // ResolveCapabilities resolves the effective capability for (provider, model).
    ResolveCapabilities(ctx context.Context, provider, modelID string) ModelCapability

    SetOverride(ctx context.Context, provider, modelID string, ov CapOverrideInput) error
    ClearOverride(ctx context.Context, provider, modelID string) error
    ListOverrides(ctx context.Context) ([]*ModelCapOverride, error)
}

type CapOverrideInput struct {
    ThinkingShape *string
    ContextWindow *int
    MaxOutput     *int
}
```

### Sentinel 错误（4 个；2026-05-28 redesign：原 `ErrProvider…Required` 重命名为 `ErrAPIKeyIDRequired`）

```go
// internal/domain/model/model.go
var (
    ErrNotConfigured     = errors.New("model: not configured for scenario")
    ErrInvalidScenario   = errors.New("model: invalid scenario")
    ErrAPIKeyIDRequired  = errors.New("model: api_key_id is required")
    ErrModelIDRequired   = errors.New("model: model id is required")
)
```

**已删 sentinel**：原 `model.ErrProvider…Required`（重命名为 `ErrAPIKeyIDRequired`）。原 `apikeydomain.ErrProvider…HasNoKey` 也在 redesign 中删——`PUT /model-configs/{scenario}` F1 不再校验"provider 是否有 key"，改成"apiKeyId 是否存在 + 是否属于当前 user"（更精确，直接验 id 比验 provider 严格）；未知 apiKeyId → `apikeydomain.ErrNotFound`（404 `API_KEY_NOT_FOUND`，跨用户走同一路径）。

映射见 §13 错误码。

---

## 6. 对外 API vs 对内函数（速查表）

### 6.1 对外两类消费者

| 消费者 | 接口 | 位置 | 方法数 |
|---|---|---|---|
| 🌐 **前端 / curl** | HTTP REST | `/api/v1/model-configs/*` | **2 个端点** |
| 🧩 **其他 domain**（chat / workflow / knowledge）| `modeldomain.ModelPicker` 接口 | `internal/domain/model/model.go` | **1 个方法**（Phase 2，随 Phase 加）|

### 6.2 HTTP REST（详见 §10）

```
GET  /api/v1/model-configs              列出当前用户所有 scenario 的配置（200）
PUT  /api/v1/model-configs/{scenario}   upsert 指定 scenario（200）
```

无 POST / PATCH / DELETE / GET-by-scenario（见 §2 核心决策）。

### 6.3 `ModelPicker` 接口（跨 domain 唯一入口；2026-05-28 redesign：3 个 named methods）

```go
// domain/model/model.go

type ModelPicker interface {
    // PickForDialogue returns (apiKeyID, modelID) for the user-facing
    // dialogue scenario — used by chat main loop and subagent spawn.
    // Returns ErrNotConfigured if never set.
    //
    // PickForDialogue 返主对话档默认 (apiKeyID, modelID)；chat 主循环和
    // subagent spawn 用。用户未设过返 ErrNotConfigured。
    PickForDialogue(ctx context.Context) (apiKeyID, modelID string, err error)

    // PickForUtility returns (apiKeyID, modelID) for tool-internal LLM
    // work (autoTitle / compaction / WebFetch summary / search rerank /
    // env-fix). No conv override propagation — utility is per-callsite.
    //
    // PickForUtility 返辅助任务档默认 (apiKeyID, modelID)；工具内部 LLM
    // 活儿用，不参与 conv override 传播。
    PickForUtility(ctx context.Context) (apiKeyID, modelID string, err error)

    // PickForAgent returns (apiKeyID, modelID) for workflow agent / llm
    // node dispatchers; node-level ModelOverride takes precedence in the
    // resolver chain (ResolveAgentWithOverride).
    //
    // PickForAgent 返 workflow agent/llm 节点档默认；解析链中 node 级
    // ModelOverride 优先（ResolveAgentWithOverride 处理）。
    PickForAgent(ctx context.Context) (apiKeyID, modelID string, err error)

    // Phase 5+ 按需追加方法：
    // PickForEmbedding(ctx) (apiKeyID, modelID string, err error)
    // PickForVision(ctx)    (apiKeyID, modelID string, err error)
    // PickForIntent(ctx)    (apiKeyID, modelID string, err error)
}
```

**为什么不用通用 `Pick(ctx, scenario string)` 方法**：
- **类型安全**：拼错 `"dialgue"` 编译期抓不到；方法名拼错编译期立刻炸
- **演化独立**：`PickForEmbedding` 可能返不同形状
- **调用点自文档**：chat 代码里写 `mp.PickForDialogue(ctx)` 一眼就懂

实现：`app/model.Service`（有 `var _ modeldomain.ModelPicker = (*Service)(nil)` 编译期守护）。

### 6.4 对内类型速查

| 类别 | 名字 | 位置 | 谁用 |
|---|---|---|---|
| Repository 接口 | `Repository` | `domain/model/model.go` | Service；其他 domain 不许 import |
| Repository 实现 | `Store` | `infra/store/model/model.go`（别名 modelstore） | main.go DI |
| Service（CRUD + ModelPicker 实现）| `Service` | `app/model/model.go`（别名 modelapp；S12 主文件，含 `var _ ModelPicker = (*Service)(nil)` + 3 个 PickForX 方法）| handler + main.go + 其他 domain（通过接口）|
| ModelRef 值类型 | `ModelRef{APIKeyID, ModelID}` | `domain/model/model.go` | conv.ModelOverride / workflow NodeSpec.ModelOverride 持有；llmclient `ResolveXxxWithOverride` 接收 |
| Scenario 工具 | `ScenarioDialogue`, `ScenarioUtility`, `ScenarioAgent`, `IsValidScenario`, `ListScenarios` | `domain/model/model.go` | Service + handler 校验 |

---

## 7. Repository 接口

```go
// internal/domain/model/model.go

type Repository interface {
    // GetByScenario fetches the active config for (current user, scenario).
    // Returns ErrNotConfigured if none.
    //
    // GetByScenario 返回 (当前用户, scenario) 的活跃配置；无则返 ErrNotConfigured。
    GetByScenario(ctx context.Context, scenario string) (*ModelConfig, error)

    // List returns all active configs for the current user. No pagination
    // (Phase 2 has at most 1 entry; future phases ≤ 6).
    //
    // List 返回当前用户所有活跃配置；不分页（Phase 2 ≤ 1 条，未来 ≤ 6）。
    List(ctx context.Context) ([]*ModelConfig, error)

    // Upsert creates a new row or updates the existing (user_id, scenario)
    // row. Caller must have set m.UserID + m.Scenario before calling.
    //
    // Upsert 按 (user_id, scenario) 创建或更新。调用方须先填 m.UserID + m.Scenario。
    Upsert(ctx context.Context, m *ModelConfig) error
}
```

**注意**：无 `Delete` / `Get(id)` 方法 —— Phase 2 用不上，按需增加。

### Store 实现细节（`infra/store/model/model.go`）

- 每个方法前 `reqctxpkg.RequireUserID(ctx)` 取 uid，缺失返 wrapped 错误
- `GetByScenario`: `WHERE user_id=? AND scenario=?`（GORM 自动按 `gorm.DeletedAt` 字段补 `deleted_at IS NULL`）
- `List`: `WHERE user_id=? ORDER BY scenario`（同上 GORM 自动 soft-delete filter）
- `Upsert`: **就是** `db.Save(m)`——一行。**编排逻辑（查现有 / decide insert vs update）在 app 层 Service.Upsert**（详 §8 流程），store 只做最终持久化。
  - 并发安全靠 `UNIQUE(user_id, scenario)`
  - 当前不走 `ON CONFLICT DO UPDATE`（Service 层显式决定 insert / update 比 GORM 隐式 upsert 更可控）

---

## 8. Service 层

### Struct + 构造

```go
// app/model/model.go（S12 主文件——不叫 service.go）

type Service struct {
    repo modeldomain.Repository
    log  *zap.Logger
}

func NewService(repo modeldomain.Repository, log *zap.Logger) *Service {
    if log == nil {
        panic("model.NewService: logger is nil")
    }
    return &Service{repo: repo, log: log}
}
```

### Inputs

```go
// app/model/model.go

type UpsertInput struct {
    APIKeyID string
    ModelID  string
}
```

（scenario 不放 UpsertInput 里，它来自 HTTP path param，由 handler 透传给 Service 的独立参数。）

### 方法签名

```go
// 对前端（HTTP handler 调）
func (s *Service) List(ctx context.Context) ([]*modeldomain.ModelConfig, error)
func (s *Service) Upsert(ctx context.Context, scenario string, in UpsertInput) (*modeldomain.ModelConfig, error)

// ModelPicker 接口实现（同文件，3 个 PickForX 方法各自走 repo.GetByScenario）
func (s *Service) PickForDialogue(ctx context.Context) (apiKeyID, modelID string, err error)
func (s *Service) PickForUtility(ctx context.Context) (apiKeyID, modelID string, err error)
func (s *Service) PickForAgent(ctx context.Context) (apiKeyID, modelID string, err error)
```

Service 还有可选的 `SetKeyProvider(kp apikeydomain.KeyProvider)`（装配阶段注入，让 `Upsert` 能调 `ResolveCredentialsByID` 做 F1 校验）。

### Upsert 流程（2026-05-28 redesign 后）

```
1. 校验 scenario：
   !modeldomain.IsValidScenario(scenario) → ErrInvalidScenario
2. 校验 body：
   strings.TrimSpace(in.APIKeyID) == "" → ErrAPIKeyIDRequired
   strings.TrimSpace(in.ModelID)  == "" → ErrModelIDRequired
3. reqctxpkg.RequireUserID(ctx) → uid（缺失 = 接线 bug，包装上抛）
4. F1 校验 apiKeyID 存在 + 属于当前 user：
   keys.ResolveCredentialsByID(ctx, in.APIKeyID)
     → apikeydomain.ErrNotFound（404 API_KEY_NOT_FOUND；跨用户走同一路径）
     → 其他错误透传
   keyProvider == nil → 跳过 F1（测试便利;生产 main.go 必装配）
5. 查现有：existing, err := repo.GetByScenario(ctx, scenario)
   err == ErrNotConfigured → 新建分支：
     m := &ModelConfig{ID: newID(), UserID: uid, Scenario: scenario}
   err == nil → 更新分支：
     m := existing
   err 其他 → 上抛
6. m.APIKeyID = strings.TrimSpace(in.APIKeyID)
   m.ModelID  = strings.TrimSpace(in.ModelID)
   //（GORM 自动维护 UpdatedAt）
7. repo.Upsert(ctx, m)   //（store 内部 = db.Save(m)）
8. log.Info("model config upserted", user_id, scenario, api_key_id, model_id)
9. 返回最新的 *ModelConfig
```

### PickForDialogue / PickForUtility / PickForAgent 流程

3 方法对称，仅传入的 scenario 常量不同：

```
1. m, err := repo.GetByScenario(ctx, ScenarioDialogue|Utility|Agent)
   err == ErrNotConfigured → 向上抛 ErrNotConfigured
2. return m.APIKeyID, m.ModelID, nil
```

返回的 `(apiKeyID, modelID)` 由 `llmclient.ResolveXxx` 进一步走 `keys.ResolveCredentialsByID` 取 `Credentials{Provider, Key, BaseURL}` → `factory.Build` → `Bundle`。

### ID 生成

```go
func newID() string {
    var b [8]byte
    if _, err := rand.Read(b[:]); err != nil {
        panic(fmt.Sprintf("model: crypto/rand failed: %v", err))
    }
    return "mc_" + hex.EncodeToString(b[:])
}
```

---

## 9. ConnectivityTester？

**不存在**。model domain 没有"测试"语义 —— 真实验证发生在 chat 调 LLM 时，上游返错才真能暴露"model 不存在"或"provider 拒绝"。"测试模型可用"不是 model 的职责。

---

## 10. HTTP API 详细

### 通用约定

- 前缀：`/api/v1/model-configs`
- 中间件链：同 apikey
- 响应走 envelope（N1）

### 端点清单（3 个）

#### 10.1 `GET /api/v1/model-configs` — 列表（200）

**Request**：无 body，无 query（不分页，最多 5-6 条）。

**Response 200**（2026-05-28 redesign 后：3 行；每行 `apiKeyId` 字段，无 `provider`）：
```json
{
  "data": [
    {
      "id": "mc_abc123",
      "scenario": "dialogue",
      "apiKeyId": "aki_xxx",
      "modelId": "claude-sonnet-4-5",
      "createdAt": "2026-05-28T07:30:00Z",
      "updatedAt": "2026-05-28T07:30:00Z"
    },
    { "id": "mc_def456", "scenario": "utility", "apiKeyId": "aki_xxx", "modelId": "claude-haiku-4-5", ... },
    { "id": "mc_ghi789", "scenario": "agent",   "apiKeyId": "aki_xxx", "modelId": "claude-sonnet-4-5", ... }
  ]
}
```

从未配过 → `{"data": []}`（不是 null、不是 404）。onboarding 完成后 3 行齐全；删 api_key 走 RESTRICT（先扫引用 → 422 `API_KEY_IN_USE`），所以这 3 行的 `apiKeyId` 始终指向存在的 key。

#### 10.2 `PUT /api/v1/model-configs/{scenario}` — upsert（200）

**Path param**：`scenario` ∈ `{"dialogue", "utility", "agent"}`（白名单；扩展机制详 §4 演化表）

**Request body**（2026-05-28 redesign：`provider` → `apiKeyId`；2026-05-30：`thinking` 字段可选）：
```json
{
  "apiKeyId": "aki_xxx",
  "modelId": "claude-sonnet-4-5",
  "thinking": { "mode": "auto" }
}
```

`thinking` 为 nil 表示不设定推理行为（沿用 provider 默认）。

**Response 200**：完整的 `ModelConfig`（同 GET 单条形状，含 `apiKeyId`）

**错误**：
- 400 `INVALID_REQUEST` — JSON 畸形 / 含未知字段（`DisallowUnknownFields`）
- 400 `INVALID_SCENARIO` — path scenario 不在 3 个白名单
- 400 `API_KEY_ID_REQUIRED` — body `apiKeyId` 空或仅空白
- 400 `MODEL_ID_REQUIRED` — body `modelId` 空或仅空白
- 404 `API_KEY_NOT_FOUND` — apiKeyId 不存在 / 不属于当前 user（F1 走 `keys.ResolveCredentialsByID`）

**注意**：无 201（upsert 语义，既可创建也可覆盖，统一 200）。pre-redesign 的 provider-required / provider-has-no-key 错误码已删（直接按 id 校验比按 provider 严格）。

#### 10.3 `GET /api/v1/scenarios` — 白名单（200）

**用途**：暴露 `modeldomain.ListScenarios()` 给前端，让 SettingsModal 的 Model defaults 区始终展示后端所知的全部 scenario（无论用户是否配过）。2026-05-28 redesign 后稳定返 3 项 `dialogue/utility/agent`；前端 `useScenarios` hook 消费。Phase 5+ 加 `embedding` / `vision` 等 const 时，本端点自动跟进，前端 SettingsModal 自动多卡。

**Request**：无 body，无 query。

**Response 200**：

```json
{
  "data": [
    { "name": "dialogue" },
    { "name": "utility" },
    { "name": "agent" }
  ]
}
```

**特殊**：本端点**不**走 `RequireUser` middleware（与 `/api/v1/providers` 同列）—— 静态 metadata，onboarding 创号前也得可读。`router.requireUserExempt` 路径白名单已加。Phase 5+ 加 `embedding` / `vision` 等 const 时，本端点自动跟进，前端零改。

#### 10.4 `GET /api/v1/model-capabilities` — 当前用户已配置 provider/model 的能力目录（200，2026-05-30）

返回当前用户配置的所有 (provider, model) 对的 resolved capability（静态规则 ⊕ 用户 override），供前端 ThinkingControl 渲染。

**Response 200**：
```json
{
  "data": [
    {
      "provider": "anthropic",
      "modelId": "claude-sonnet-4-6",
      "thinkingShape": "budget",
      "contextWindow": 200000,
      "maxOutput": 16384,
      "usableInput": 181616,
      "isOverride": false
    }
  ]
}
```

#### 10.5 `PUT /api/v1/model-capabilities` — 设置 override（200，2026-05-30）

**Request body**：
```json
{
  "provider": "openai",
  "modelId": "gpt-5",
  "thinkingShape": "effort",
  "contextWindow": 500000
}
```
任意字段可 null（不覆盖该维度）。返回 merged `ModelCapability`。

**错误**：
- 400 `INVALID_THINKING_SHAPE` — thinkingShape 不在 `{"none","toggle","effort","budget"}` 白名单（handler 内联 400，不走 errmap）

#### 10.6 `DELETE /api/v1/model-capabilities` — 清除 override（204，2026-05-30）

**Query**：`?provider=xxx&modelId=yyy`

清除用户对该 (provider, model) 的 override；下次 `ResolveCapabilities` 退回静态规则。

### Handler 设计

**ModelConfigHandler**（`transport/httpapi/handlers/model.go`）：

```go
type ModelConfigHandler struct {
    svc *modelapp.Service
    log *zap.Logger
}

func (h *ModelConfigHandler) Register(mux *http.ServeMux) {
    mux.HandleFunc("GET /api/v1/model-configs", h.List)
    mux.HandleFunc("PUT /api/v1/model-configs/{scenario}", h.Upsert)
}
```

**ScenariosHandler**（`transport/httpapi/handlers/scenarios.go`）—— 无依赖、无 service 注入，直接读 `modeldomain.ListScenarios()`：

```go
type ScenariosHandler struct{}

func (h *ScenariosHandler) Register(mux *http.ServeMux) {
    mux.HandleFunc("GET /api/v1/scenarios", h.List)
}
```

注册在 `router.New` 的 health/providers 后面（永远 wire 进去，不依赖任何 service）。

---

## 11. 数据库表（2026-05-28 redesign：列名 `provider` → `api_key_id`；2026-05-30：`thinking` 列 + `model_cap_overrides` 表）

```sql
CREATE TABLE model_configs (
    id          TEXT PRIMARY KEY,
    user_id     TEXT NOT NULL,
    scenario    TEXT NOT NULL,                    -- 白名单由 app 层校验（3 值：dialogue/utility/agent）
    api_key_id  TEXT NOT NULL,                    -- 引用 api_keys.id；无 GORM FK（V1.2 D4）；app 层 RefScanner 兜底 RESTRICT
    model_id    TEXT NOT NULL,
    thinking    TEXT,                             -- JSON ThinkingSpec，nullable（2026-05-30）
    created_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deleted_at  DATETIME
);

-- 通过 GORM tag 生成（全索引，不带 WHERE）：
CREATE UNIQUE INDEX idx_mc_user_scenario ON model_configs(user_id, scenario);
CREATE INDEX        idx_mc_deleted_at    ON model_configs(deleted_at);

-- 用户 per-model 能力 override（2026-05-30，stale-catalog 逃生舱）
CREATE TABLE model_cap_overrides (
    id              TEXT PRIMARY KEY,              -- mco_<16hex>
    user_id         TEXT NOT NULL,
    provider        TEXT NOT NULL,
    model_id        TEXT NOT NULL,
    thinking_shape  TEXT,                          -- "none"|"toggle"|"effort"|"budget"，nullable
    context_window  INTEGER,                       -- nullable
    max_output      INTEGER,                       -- nullable
    created_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deleted_at      DATETIME
);

-- partial UNIQUE：同 user 同 (provider, model_id) 只允许一条活跃 override
-- 在 schema_extras.go 补充（GORM tag 不能表达 WHERE 子句）
CREATE UNIQUE INDEX idx_mco_user_provider_model
    ON model_cap_overrides(user_id, provider, model_id)
    WHERE deleted_at IS NULL;
CREATE INDEX idx_mco_deleted_at ON model_cap_overrides(deleted_at);
```

**partial UNIQUE 暂缓**：当前 Service.Upsert 模式无 delete + recreate 同 scenario 路径，全索引足够（详 §5 唯一约束 + §17 实现清单）。`schema_extras.go` 没有 `model_configs` 组。

**列名变更（2026-05-28 redesign）**：原 `provider TEXT NOT NULL` → `api_key_id TEXT NOT NULL`。**dev-only 迁移故事**：产品未上线无 production migration 顾虑；`make reset` 清 dev DB 重建即可；GORM AutoMigrate 会加 `api_key_id` 列但不自动删旧 `provider` 列——`make reset` 解决。

**删 api_key 的引用扫描**：`apikey.Service.Delete` 装 3 个 RefScanner，其中 `modelConfigScan.AnyReferencesApiKey(id)` 用 `WHERE api_key_id = ? AND deleted_at IS NULL` 扫；任一引用 → `apikey.ErrInUse`（422 `API_KEY_IN_USE`，详 `apikey.md`）。

**迁移**：`cmd/server/main.go` 的 `db.Migrate(gdb, &modeldomain.ModelConfig{})` 末尾追加。

---

## 12. 事件

**Phase 2 不推送事件**。ModelConfig 是用户主动改的设置型资源，无需异步通知前端；前端操作完立刻 GET 列表刷新就行。

---

## 13. 错误码（2026-05-28 redesign 后 4 个 model 自有 + 2 个相关）

| Code | HTTP | Sentinel | 场景 | 状态 |
|---|---|---|---|---|
| `MODEL_NOT_CONFIGURED` | 422 | `model.ErrNotConfigured` | 调 `PickForDialogue/Utility/Agent` 时用户未配过该 scenario | ✅ |
| `INVALID_SCENARIO` | 400 | `model.ErrInvalidScenario` | PUT path `scenario` 不在 3 白名单 | ✅ |
| `API_KEY_ID_REQUIRED` | 400 | `model.ErrAPIKeyIDRequired` | PUT body `apiKeyId` 空 | ✅ |
| `MODEL_ID_REQUIRED` | 400 | `model.ErrModelIDRequired` | PUT body `modelId` 空 | ✅ |

**相关跨 domain**：

| Code | HTTP | Sentinel | 场景 |
|---|---|---|---|
| `API_KEY_NOT_FOUND` | 404 | `apikeydomain.ErrNotFound` | F1 校验 PUT body `apiKeyId` 不存在 / 不属当前 user；同样用于 runtime 解析（llmclient.finishResolve） |
| `API_KEY_IN_USE` | 422 | `apikeydomain.ErrInUse` | DELETE /api-keys/{id} 时 modelConfigs / convs / workflow_versions 还引用着 → 拒删 |

**已删 errmap 行（2026-05-28 redesign）**：
- 老 `PROVIDER…REQUIRED` (400) sentinel — 重命名为 `API_KEY_ID_REQUIRED`
- 老 `PROVIDER…HAS…NO…KEY` (422) sentinel — 直接 F1 走 ResolveCredentialsByID（按 id 校验 → ErrNotFound 404），不再按 provider 校验

errmap 条目（当前）：
```go
// internal/transport/httpapi/response/errmap.go
modeldomain.ErrNotConfigured:    {http.StatusUnprocessableEntity, "MODEL_NOT_CONFIGURED"},
modeldomain.ErrInvalidScenario:  {http.StatusBadRequest, "INVALID_SCENARIO"},
modeldomain.ErrAPIKeyIDRequired: {http.StatusBadRequest, "API_KEY_ID_REQUIRED"},
modeldomain.ErrModelIDRequired:  {http.StatusBadRequest, "MODEL_ID_REQUIRED"},
apikeydomain.ErrInUse:           {http.StatusUnprocessableEntity, "API_KEY_IN_USE"},
```

---

## 14. 消费方如何用（跨 domain 示例；2026-05-28 redesign 后通过 `llmclient` 三件套）

### chat.Service 调 LLM 时（dialogue scenario）

调用方**不直接调** `ModelPicker.PickForX`——统一通过 `pkg/llmclient` 的 3 个解析函数：

```go
// internal/app/chat/runner.go（精简版）
import llmclientpkg "github.com/sunweilin/forgify/backend/internal/pkg/llmclient"

func (s *Service) processTask(ctx context.Context, conv *convdomain.Conversation, ...) {
    // 1. 解析一站式拿 Bundle（picker + keyProvider + llmFactory 三件套已注入 Service）
    bundle, err := llmclientpkg.ResolveDialogueWithOverride(
        ctx,
        conv.ModelOverride,           // *modeldomain.ModelRef，nil 则 fallback PickForDialogue
        s.modelPicker, s.keyProvider, s.llmFactory,
    )
    if err != nil { /* 映射 ErrPickModel/ErrResolveCreds/ErrBuildClient → SSE chat.error */ }
    // bundle.{Client, APIKeyID, Provider(派生), ModelID, Key, BaseURL}

    // 2. 把 effective override 透传到 ctx，给 subagent spawn 继承用
    agentCtx := reqctxpkg.WithModelOverride(ctx, conv.ModelOverride)

    // 3. baseReq + chatHost + loop.Run（消费 bundle.Client）
}

// 自动起标题 utility 档：
func (s *Service) autoTitle(ctx, ...) {
    bundle, err := llmclientpkg.ResolveUtility(ctx, s.modelPicker, s.keyProvider, s.llmFactory)
    // ...
}
```

**注意**：chat 只 import `modeldomain` 接口 + `llmclientpkg` 解析函数，**不** import `modelapp`（Service struct）。main.go 把 `*modelapp.Service` 作为 `modeldomain.ModelPicker` 传进 chat / subagent / scheduler / contextmgr / web 等的构造函数。subagent 的 `Spawn(parentCtx, type, prompt, opts, parentModelOverride)` 接收 conv 当前的 override，内部走同一 `ResolveDialogueWithOverride` —— 主 agent 用 Opus，subagent 也用 Opus（详 `subagent.md`）。

---

## 15. 完整调用链（S5 "端到端推演先行"）

### 15.1 GET /api/v1/model-configs（列出）

```
前端 GET /api/v1/model-configs
  → middleware 链（Recover / Logger / CORS / InjectLocale / InjectUserID）
      → reqctxpkg.SetUserID(ctx, "local-user")
  → mux 匹配 "GET /api/v1/model-configs"
  → ModelConfigHandler.List
      → svc.List(ctx)
          → repo.List(ctx)                 [infra/store/model]
              SELECT * FROM model_configs
              WHERE user_id = ? AND deleted_at IS NULL
              ORDER BY scenario
      → response.Success(200, items)       ← items 可能是 []，不是 nil
```

### 15.2 PUT /api/v1/model-configs/dialogue（upsert，2026-05-28 redesign 形式）

```
前端 PUT /api/v1/model-configs/dialogue  body={apiKeyId, modelId}
  → middleware 链（同上）
  → mux 匹配 "PUT /api/v1/model-configs/{scenario}"
  → ModelConfigHandler.Upsert
      → r.PathValue("scenario") → "dialogue"
      → decodeJSON → UpsertRequest{APIKeyID, ModelID}
          畸形 → 400 INVALID_REQUEST
      → svc.Upsert(ctx, "dialogue", UpsertInput{...})
          → IsValidScenario("dialogue")?
              false → 400 INVALID_SCENARIO
          → TrimSpace(APIKeyID) == ""?
              → 400 API_KEY_ID_REQUIRED
          → TrimSpace(ModelID) == ""?
              → 400 MODEL_ID_REQUIRED
          → reqctxpkg.RequireUserID → uid
          → keys.ResolveCredentialsByID(ctx, in.APIKeyID)   [F1]
              不存在 / 跨用户 → apikey.ErrNotFound → 404 API_KEY_NOT_FOUND
          → repo.GetByScenario(ctx, "dialogue")
              ErrNotConfigured → 新建分支
              nil → 更新分支
          → m.APIKeyID / m.ModelID 赋值
          → repo.Upsert(ctx, m)            [infra/store/model — store.Upsert = db.Save(m)]
          → log.Info("model config upserted")
      → response.Success(200, m)
```

### 15.3 chat.Send 调 ResolveDialogueWithOverride（跨 domain；通过 llmclient 编排）

```
chat.Service.processTask(ctx)
  → llmclientpkg.ResolveDialogueWithOverride(ctx, conv.ModelOverride, picker, keys, factory)
      → override.APIKeyID + override.ModelID 都非空 → 直接 finishResolve(override.APIKeyID, override.ModelID, ...)
      → 否则 → picker.PickForDialogue(ctx) → (apiKeyID, modelID)
            ErrNotConfigured → 上抛 → SSE chat.error MODEL_NOT_CONFIGURED
        → finishResolve(apiKeyID, modelID, keys, factory)
            keys.ResolveCredentialsByID(ctx, apiKeyID) → Credentials{Provider, Key, BaseURL}
                ErrNotFound → 上抛 → SSE chat.error API_KEY_NOT_FOUND
            factory.Build(llminfra.Config{...}) → llminfra.Client
        → return &Bundle{Client, APIKeyID, Provider, ModelID, Key, BaseURL}
  → reqctxpkg.WithModelOverride(ctx, conv.ModelOverride)  // 让 subagent spawn 继承
  → 后续 ReAct loop 消费 bundle.Client
```

**utility scenario callsites**（autoTitle / compaction / WebFetch summary / search rerank / env-fix 共 11 处）：直接 `ResolveUtility(ctx, picker, keys, factory)` —— 无 override 分支。

**agent scenario callsites**（workflow `dispatch_agent.go` + `dispatch_llm.go`）：`ResolveAgentWithOverride(ctx, node.ModelOverride, picker, keys, factory)`。

---

## 16. 安全考虑

model domain 不涉及明文凭证，安全面比 apikey 小。唯一关注：

| 点 | 设计 |
|---|---|
| `user_id` 隔离 | Repository 方法全都 `WHERE user_id=?` 过滤（store 里强制）|
| `user_id` 响应不泄漏 | ModelConfig struct 里 `UserID` 有 `json:"-"` 标签（与 APIKey 保持一致）|
| nil logger | `NewService(..., nil)` panic；单测守护 |

---

## 17. 实现清单（✅ 已全部完成；2026-04-25 初版 + 2026-05-28 redesign + 2026-05-30 thinking + capability）

> 注：文件命名遵循 S12 规范——所有层主文件统一用包名（`model.go`，不再叫 `service.go` / `store.go`）。

### domain 层 ✅
- [x] `internal/domain/model/model.go` — `ModelConfig` struct（`APIKeyID` + `Thinking` 字段）+ `ModelRef{APIKeyID, ModelID, Thinking}` 值类型（2026-05-30：`Thinking *ThinkingSpec` 新增）+ `ThinkingSpec` struct + `ModelCapOverride` struct + 4 sentinel（含 `ErrAPIKeyIDRequired`）+ 3 scenario 常量（`ScenarioDialogue/Utility/Agent`）+ `IsValidScenario` + `ListScenarios` + `Repository`（3 方法）+ `ModelPicker`（3 方法：`PickForDialogue/Utility/Agent`）
- [x] `internal/domain/model/model_test.go` — 单测（valid/invalid 3 scenario + ListScenarios 一致性）

### infra 层 ✅
- [x] `internal/infra/store/model/model.go` — Store 实现 Repository + `AnyReferencesApiKey(ctx, apiKeyID)` 给 apikey RefScanner 走（`WHERE api_key_id=? AND deleted_at IS NULL`）
- [x] `internal/infra/store/model/model_test.go` — 集成测试（CRUD / 跨用户隔离 / 唯一约束 / RefScanner True/False/CrossUserIsolated）

### app 层 ✅
- [x] `internal/app/model/model.go` — Service（List / Upsert + 校验 + ID 生成 + 3 个 PickForX + nil logger 守护 + `SetKeyProvider` 装配后置注入）
  - `Upsert` F1 走 `keys.ResolveCredentialsByID`（按 id 校验存在 + 跨用户隔离）；keyProvider nil 时跳过（测试便利）
- [x] `internal/app/model/model_test.go` — 单测（fake repo + fake keyProvider）

### transport 层 ✅
- [x] `internal/transport/httpapi/handlers/model.go` — ModelConfigHandler + GET + PUT（body `{apiKeyId, modelId}`）+ Register
- [x] `internal/transport/httpapi/handlers/model_test.go` — E2E 契约测试（真 SQLite + Service + InjectUserID）
- [x] `internal/transport/httpapi/handlers/scenarios.go` — ScenariosHandler + GET /api/v1/scenarios（无 service 依赖，直读 `ListScenarios()` → 3 项）
- [x] `internal/transport/httpapi/router/router.go` — `requireUserExempt` 白名单含 `/api/v1/providers` 和 `/api/v1/scenarios`

### 配套基础设施 ✅
- [x] `internal/transport/httpapi/response/errmap.go` — 4 条 model sentinel + `apikey.ErrInUse → 422 API_KEY_IN_USE`
- [x] `internal/transport/httpapi/router/deps.go` — `ModelService *modelapp.Service` 字段
- [x] `cmd/server/main.go` — `modelstore.New(gdb)` → `modelapp.NewService(...)` → `modelService.SetKeyProvider(apikeyService)` → `apikeyService.SetModelConfigRefScanner(modelStore)` → `router.Deps`

### capability 层 ✅（2026-05-30）
- [x] `internal/pkg/modelcaps/modelcaps.go` — `Cap` struct + `CapOverride` + `Apply` / `Lookup` / `UsableInput` / `SafetyBuffer`；按 family 规则 + per-model 精确行覆盖；详见 `documents/version-1.2/adhoc-topic-documents/llm-providers/04-capability-catalog.md`
- [x] `internal/app/apikey/capability.go` — `CapabilityService`（`ResolveCapabilities` / `SetOverride` / `ClearOverride` / `ListOverrides`）+ `ModelCapability` struct；`ResolveCapabilities` 合并优先级：用户 override > 静态规则（live overlay 留接口，当前 deferred）
- [x] `internal/infra/store/model/capability.go` — `CapOverrideStore` 实现 `CapabilityOverrideRepository`（CRUD + partial UNIQUE per user+provider+model）
- [x] `internal/transport/httpapi/handlers/capability.go` — GET / PUT / DELETE `/api/v1/model-capabilities`；`INVALID_THINKING_SHAPE` 400 内联 handler 校验（不进 errmap）

### 验收 ✅
- [x] `make verify` 绿
- [x] `make matrix` 已包含新 errcode `API_KEY_ID_REQUIRED` / `API_KEY_IN_USE` / `INVALID_NODE_MODEL_OVERRIDE`
- [x] pipeline `backend/test/cross/model_scenarios_pipeline_test.go` 验证 onboarding 3 行写入 / 缺 scenario 在 chat 中暴露

---

## 18. 遗留 / 未来

### 设计决定（已落定）

- **3 scenarios 是 V1.2 心智的最终形态**：`dialogue` / `utility` / `agent` 各自独立（无 fallback 链）；subagent 折进 dialogue（继承父 conv override，不引入 type 级分化）。spec：[`docs/superpowers/specs/2026-05-28-model-selection-redesign-design.md`](../../../docs/superpowers/specs/2026-05-28-model-selection-redesign-design.md)
- **ModelRef = (APIKeyID, ModelID)**：provider 由 apiKey 隐含；同 provider 多 key（个人/公司/备用）合法。runtime 按 id 精确查 key，不走 provider 模糊匹配
- **软删保留**：ModelConfig 保持 `gorm.DeletedAt` 软删，与 D1 规范一致
- **Upsert 方式**：Service 先 `GetByScenario` 判断存在性，再调 `repo.Upsert(m)`（GORM `Save()`）
- **partial UNIQUE 暂缓**：当前 Upsert 模式无 "delete+recreate 同一 scenario" 路径，GORM 全索引已足够
- **删 api_key RESTRICT**：被 model_config / conv override / node override 引用 → 422 `API_KEY_IN_USE`（详 `apikey.md`）

### backlog

- **Phase 5 scenarios**：`ScenarioEmbedding` / `ScenarioVision` / `ScenarioIntent` —— 按需加 const + IsValidScenario + `PickForXxx` + 对应 `llmclient.ResolveXxx` + onboarding 第 4/5/6 行 PUT + 前端 SettingsModal 多卡。**机制现成不需改架构**
- `Pick(ctx, scenario)` 通用方法：**不做**（类型安全 > DRY，见 §6.3 理由）
- GET /{scenario} 单条接口：暂不做，GET 列表够用
- DELETE 接口：暂不做，用户直接 PUT 新值即可
- **subagent type 级 override**（Plan vs Explore 差异化）：折入 dialogue 的决策定下了，未来真有需求时在 subagent type 内部加（不在 scenario 层）
- **"set all to X" 一键按钮**：3 个独立卡片足够；真有用户呼声后期再加
- **一键自动配置** `POST /api/v1/model-configs:auto-configure`：按每个 scenario 的 provider 偏好列表自动 Upsert——Phase 5 全部 scenario 定义完后 revisit

---

## 19. 与其他 domain 的协作图（2026-05-28 redesign 后）

```
         ┌─────────────────────────────────────────┐
         │  chat / subagent / scheduler /          │   ← 消费方（只见 ModelPicker 接口 +
         │  contextmgr(compaction) / web / tool... │     pkg/llmclient 三件套）
         └──────────┬──────────────────────────────┘
                    │ ResolveDialogueWithOverride / ResolveUtility / ResolveAgentWithOverride
                    │   → picker.PickForDialogue/Utility/Agent(ctx) → (apiKeyID, modelID)
                    │   → keys.ResolveCredentialsByID(ctx, apiKeyID) → Credentials{Provider, Key, BaseURL}
                    ↓
            ┌──────────────────┐
            │  model.Service    │ ← ModelPicker 唯一实现（3 个 PickForX 方法）
            └───┬──────────────┘
                │ GetByScenario / List / Upsert
                │ Upsert F1：keys.ResolveCredentialsByID 校验 apiKeyId 存在 + 跨用户隔离
                ↓
            ┌──────────────────┐
            │  Repository 实现  │ ← infra/store/model.Store（含 AnyReferencesApiKey
            └──────────────────┘    给 apikey RefScanner 走 RESTRICT）

model domain **轻依赖** apikey（只用 KeyProvider port 做 F1 校验 + Bundle 派生）。
apikey **不依赖** model（model_configs 的引用由 apikey Service 在 Delete 时用 RefScanner 反向扫）。
```
