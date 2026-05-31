---
id: DOC-126
type: reference
status: active
owner: @weilin
created: 2026-04-22
reviewed: 2026-05-31
review-due: 2026-06-30
audience: [human, ai]
---
# User — 本地多 Profile 切换

> V1.2 §20 / 2026-05-17。**单机多账号**（个人 / 工作 / 副业），不是真 auth。Slack workspace 切换风格——单机谁拿 laptop 谁有控制权。

---

> **2026-05-24 更新（user-identity-cleanup）**：删了 `DefaultLocalUserID` magic 字符串和 `EnsureDefault` 自动 seed。fresh install = 0 users → 走 onboarding；middleware 拆 `IdentifyUser`+`RequireUser`，unknown id → 401 / `UNAUTH_NO_USER`（无 first-user 兜底）；后台任务遍历真实 users（0 user → no-op）。前端 `apiFetch` 401 + App.jsx self-heal effect 自动清 stale id。规范见 `docs/superpowers/specs/2026-05-24-user-identity-cleanup.md`。

## 1. 为什么要这个 domain

V1.2 早期 backend 用硬编码 `DefaultLocalUserID = "local-user"` 处理所有请求；2026-05-24 之后该 magic id 已删除（见上方更新）。所有 entity 的 `user_id` 列都填**真实** user id。**用户实际场景**：

- 同一台 laptop 想分开"个人项目"与"工作项目"——不同 API key 池、不同 conv 历史、不同 forge 库
- 团队共享 dev 机（罕见但有），临时切到同事 profile dogfood
- 用户给不同领域起不同身份（"daily-research" vs "side-game-dev"）

**不是真 auth**——单机本地，密码 / OS 钥匙串都是反生产力。**身份 = 数据隔离器**而已。

---

## 2. 核心决策

- **DB 多用户已就绪**：14 entity 全带 `user_id` 列 + repo 自动 scope。User domain 只补"identity"那一层
- **Session = X-Forgify-User-ID header**（SSE EventSource API 限制 → `?userID=` query 兜底）
- **无密码 / 无锁**：V1.2 minimal scope；V1.5 真撞需求再加
- **无 magic id**：middleware 严格——header 缺 / id 不存在都直接 401 (`UNAUTH_NO_USER`)，前端 self-heal；不再静默降级到 first-user 或 `local-user`
- **后台 polling 真遍历 users**（catalog `RefreshAll`、scheduler `RehydrateOnBoot`）；mcp / skill 启动仍用一个共享路径 `legacyDefaultUserDir`（disk 路径，无 auth 语义；mcp/skill 真正 per-user 留 V1.5）
- **Trigger fire 用 workflow 所有者 user_id**：哪怕 active 是别人，A 的 cron workflow 仍 fire 进 A 的 flowrun（owner 缺失就 drop trigger，不再降级）
- **No 数据物理删除**：删 profile 走 GORM soft-delete，DB 行保留可恢复

---

## 3. 端到端推演

### 3.1 启动选 profile

```
[GET /api/v1/users]
  → app/user.Service.List → infra/store/user.Store.List → DB
  → []User
[frontend settings.activeUserId from localStorage (zustand persist)]
  ↓ if 0 users          → Onboarding overlay (POST /users to create first)
  ↓ if 1 user           → auto-select (silent, no picker)
  ↓ if 2+ & active null → user picker
  ↓ if active stale     → App.jsx self-heal effect clears it → re-evaluate
  → settings.activeUserId set
  → apiFetch injects X-Forgify-User-ID for each request
  → SSE reconnects with ?userID=<id>
```

### 3.2 切换 profile

```
UserSwitcher dropdown → switchTo(uid)
  → POST /users/{uid}:activate (touch last_used_at)
  → localStorage.setItem("forgify:active-user", uid)
  → window.location.reload()
  → 全前端 state 重建,新请求带新 user header
```

---

## 4. 领域模型

### User struct（`internal/domain/user/user.go`）

```go
type User struct {
    ID          string         `gorm:"primaryKey;type:text" json:"id"`
    Username    string         `gorm:"not null;uniqueIndex" json:"username"`
    DisplayName string         `gorm:"type:text;default:''" json:"displayName"`
    AvatarColor string         `gorm:"type:text;default:''" json:"avatarColor,omitempty"`
    Language    string         `gorm:"type:text;default:'zh-CN';check:language IN ('zh-CN','en')" json:"language"`
    LastUsedAt  *time.Time     `json:"lastUsedAt,omitempty"`
    CreatedAt   time.Time      `json:"createdAt"`
    UpdatedAt   time.Time      `json:"updatedAt"`
    DeletedAt   gorm.DeletedAt `gorm:"index" json:"-"`
}
```

| 字段 | 说明 |
|---|---|
| `ID` | 默认 user 固定 `"local-user"` 匹配 reqctxpkg.DefaultLocalUserID；新用户 `u_<16hex>` |
| `Username` | 1-32 [a-z0-9_-]；UNIQUE；登录态键 |
| `DisplayName` | 展示用昵称（缺省 = username）|
| `AvatarColor` | hex 色 `#4f46e5`；UI tile + dropdown 用 |
| `Language` | `zh-CN` 默认 / `en`；CHECK 约束；§21 i18n |
| `LastUsedAt` | activate 时刷；picker 高亮最近用 |

### 错误 sentinel

```go
var (
    ErrNotFound          = errors.New("user: not found")
    ErrUsernameRequired  = errors.New("user: username required")
    ErrUsernameConflict  = errors.New("user: username already exists")
    ErrUsernameInvalid   = errors.New("user: username must be 1-32 chars, [a-z0-9_-]")
    ErrCannotDeleteLast  = errors.New("user: cannot delete the last user")
    ErrLanguageInvalid   = errors.New("user: language must be one of zh-CN, en")
)
```

errmap 见 [`../service-contract-documents/error-codes.md`](../service-contract-documents/error-codes.md)。

---

## 5. Repository 接口

```go
type Repository interface {
    Save(ctx, *User) error
    Get(ctx, id) (*User, error)
    GetByUsername(ctx, username) (*User, error)
    List(ctx) ([]*User, error)
    Delete(ctx, id) error
    Count(ctx) (int, error)
    TouchLastUsed(ctx, id) error
}
```

**注**：唯一不按 ctx user_id scope 的 repo——user 自己就是身份。

---

## 6. Service 层

### Create 流程

1. lowercase username + regex 校验 `^[a-z0-9_-]{1,32}$`
2. 默认 Language = `zh-CN`；显式传入校验白名单
3. DisplayName 缺省 = username
4. ID = `u_<16hex>`
5. UNIQUE conflict → `ErrUsernameConflict`

### EnsureExists（测试 harness 用，非生产）

生产代码用 `Create`（生成随机 `u_<16hex>` id）。`EnsureExists(ctx, id, username)` 是测试 harness 用的幂等 helper —— 按指定 id 创建，已存在则 no-op：

```go
if existing, err := repo.Get(ctx, id); err == nil { return existing, nil }
return repo.Save(ctx, &User{ID: id, Username: ..., ...})
```

老代码里的 `EnsureDefault`（boot 时给空表 seed `id="local-user"` 的 default user）已删除（2026-05-24）。fresh install 现在就是 0 users → onboarding。**已有的 `local-user` row 不动**：升级后它继续作为一个普通 user 存在，前端 self-heal + auto-select 会把它选上，老的关联数据（`user_id="local-user"`）继续可见。

### Delete 守卫

```go
if Count == 1 → ErrCannotDeleteLast
```

防止"删光最后一个 user 进入无 user 死状态"。

---

## 7. HTTP API（5 端点）

详细 wire 形见 [`../service-contract-documents/api-design.md`](../service-contract-documents/api-design.md)。

| Method | Path | 用途 |
|---|---|---|
| `GET /api/v1/users` | 列表（无分页，量小）|
| `POST /api/v1/users` | 创建 |
| `GET /api/v1/users/{id}` | 单查 |
| `PATCH /api/v1/users/{id}` | partial update（displayName / avatarColor / language）|
| `DELETE /api/v1/users/{id}` | 软删（拒最后一个）|
| `POST /api/v1/users/{id}:activate` | touch last-used + 返当前 User |

---

## 8. 数据库表

```sql
CREATE TABLE users (
    id            TEXT PRIMARY KEY,
    username      TEXT NOT NULL UNIQUE,
    display_name  TEXT NOT NULL DEFAULT '',
    avatar_color  TEXT NOT NULL DEFAULT '',
    language      TEXT NOT NULL DEFAULT 'zh-CN' CHECK(language IN ('zh-CN','en')),
    last_used_at  DATETIME,
    created_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deleted_at    DATETIME
);

CREATE UNIQUE INDEX idx_users_username ON users(username);
CREATE INDEX idx_users_deleted_at ON users(deleted_at);
```

---

## 9. Session 机制（与 middleware 协议）

middleware 拆两层（2026-05-24 之后）：

```
IdentifyUser(resolver)        ← 读 header / 校验 / 写 ctx 或留空
   ↓
RequireUser                   ← ctx 无 user 时 401 / UNAUTH_NO_USER
   ↓
handler
```

`IdentifyUser(resolver)` 注入路径：

```
1. Read header X-Forgify-User-ID
   OR fallback to query ?userID=  (SSE EventSource 不能自定义 header)
2. If non-empty:
   resolver.Get(ctx, uid) → 验证存在
   → 命中：ctx.userID = uid
   → 不存在：ctx.userID = nil
3. Else (header / query 都缺):
   → ctx.userID = nil
```

`RequireUser` 见到 nil ctx.userID 直接 401 `{"error":{"code":"UNAUTH_NO_USER"}}`，**例外**：`/api/v1/users` CRUD（onboarding 前必须可达）与 `/api/v1/health`。前端 `apiFetch` 拿到 401 后清 `settings.activeUserId`，App.jsx self-heal effect 切回 onboarding 或 auto-select。

前端 `api/client.js::activeUserHeader` 自动注入；SSE `sse/shared.js::createSSE` URL append `?userID=`（activeUserId null 时根本不开连接）。

---

## 10. 文件系统 per-user

`pkg/userpath.UserHome(homeRoot, uid)` 返 `homeRoot/users/<uid>/`。

| 子路径 | 用途 |
|---|---|
| `mcp.json` | MCP 服务器注册（per user）|
| `skills/` | Skill 目录（per user）|
| `.catalog.json` | Catalog 缓存（per user）|
| `settings.json` | Permissions / hooks 设置（per user）|

**`pkg/userpath.MigrateLegacy(homeRoot, uid, names...)`**：把单用户期 `homeRoot/<name>` 平迁到 `homeRoot/users/<uid>/<name>`，target 已存在则 skip。启动期对 default user 做一次。

**共享**：`homeRoot/sandbox/`（mise runtime + per-conv env）+ `homeRoot/forgify.db`（SQLite 内 user_id 列 scope）。

---

## 11. V1.5 已 defer 项

- **mcp / skill 真正 per-user**：当前两者启动用共享路径 `legacyDefaultUserDir = "local-user"`（disk 目录名，无 auth 语义；现有安装的数据继续可读）。catalog 已经在 2026-05-24 改为 `RefreshAll` 真遍历 users
- **Trigger 自动注册**：workflow create 时 auto-register trigger 路径未实装（今天只有手动 `:trigger`）；当真接入时 `Spec.UserID` 字段已就位
- **密码 / 锁**：单机本地不需要，真要做用 Argon2id + DB 加密敏感字段
- **macOS Keychain 集成**
- **远程同步 profile**

---

## 12. 与其他 domain 协作

```
Browser localStorage / cookie
  ↓ X-Forgify-User-ID
HTTP Middleware (InjectUserIDWith)
  ↓ reqctxpkg.SetUserID(ctx, uid)
  ↓
[14 个 user-scoped domain]
  ├── apikey / model / conversation / chat
  ├── function / handler / workflow / flowrun
  ├── mcp / skill / document / memory
  └── trigger (启动注册按 user iterate)
```

SSE Bridge（eventlog / notifications / forge）按 ctx user_id 路由 → User A 看不见 User B 的事件。

---

## 13. 实现清单（✅ V1.2 完成）

### domain 层 ✅
- `User` struct + 6 sentinel + `Repository` interface + `IsValidLanguage`

### infra 层 ✅
- `infra/store/user/user.go` GORM 实现 + UNIQUE conflict 翻 sentinel

### app 层 ✅
- `app/user/user.go` Service：`Create` / `Get` / `GetByUsername` / `List` / `Update` / `Delete` / `EnsureDefault` / `TouchLastUsed`

### transport 层 ✅
- `handlers/users.go` 6 endpoints + errmap 6 行

### 配套 ✅
- `middleware/auth.go` 重写为 `InjectUserIDWith(resolver)` + legacy `InjectUserID` 兜底
- `pkg/userpath` `UserHome` + `MigrateLegacy`
- main.go bootstrap：EnsureDefault + 4 个文件系统 root 切到 `defaultUserHome` + Rehydrate 遍历 user
- `triggerdomain.Spec.UserID` + onFire 用 spec.UserID

### 测试 ✅
- 8 user CRUD 单测 + 3 middleware header 路径单测 + 4 userpath 迁移单测 = **15 新单测**

### 前端 ✅
- `api/users.ts` + `stores/users.ts`
- `UserPicker.vue` 启动选择屏
- `UserSwitcher.vue` TopBar avatar dropdown
- `/config/profile` 管理页（含 language select）
