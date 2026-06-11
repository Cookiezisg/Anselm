---
id: DOC-005
type: reference
status: active
owner: @weilin
created: 2026-06-11
reviewed: 2026-06-11
review-due: 2026-09-11
audience: [human, ai]
---

# orm —— 自研泛型数据访问地基

## 1. 定位

`pkg/orm` 是后端**唯一**的数据访问层——自研、泛型、去 GORM、纯 Go（配 `glebarez/go-sqlite`，无 CGO）。所有 `infra/store/*` 经它读写 SQLite。它把多租户隔离 / 软删 / 时间戳 / 冲突翻译收进地基，业务层一律不手写。

## 2. 心智模型

`Repo[T]`（一张表的类型化句柄）→ `Query[T]`（链式构建器，**惰性**）。

- `For[T](db, table)` 建 Repo；`T` 是带 `db:"col,role"` tag 的 struct（含且仅含一个 `,pk`）。
- 链式累积条件（`Where`/`Order`/`Limit`/…），**直到终结方法才碰 DB**：读 `First`/`Find`/`Count`/`Exists`/`Pluck`/`Page`，写 `Create`/`Save`/`Update`/`Updates`/`Delete`。
- 表结构靠 tag **一次反射 + sync.Map 缓存**（`metaOf`）；配错（无 pk、未知选项、非 struct）直接 **panic**——编程错误，必须启动期暴露、而非查询期。

## 3. 五条自动行为（地基统一，取代每个 store 的样板）

| 行为 | 机制 | 规则 / 逃生 |
|---|---|---|
| **workspace 隔离** | 读 `whereClause` 自动加 `ws = ?`（从 ctx `RequireWorkspaceID`）；写 `applyWorkspace` 自动填 | D2；逃生 `CrossWorkspace()`（仅系统级查询） |
| **软删** | 有 `deleted` 列且非 `Unscoped` → `Delete` 设 `deleted_at`、查询自动 `deleted_at IS NULL`；否则物理删 | D1；逃生 `Unscoped()` |
| **时间戳** | `stamp`：`created`（首次/零值）+ `updated`（每次）自动设 | — |
| **UNIQUE 冲突 → `ErrConflict`** | `writeErr` 翻译 SQLite 约束错 | 业务层不手搓（强化地基，CLAUDE 原则 #8） |
| **keyset 分页** | `Page(cursor, limit)`：`(created, pk)` DESC 元组游标、`limit+1` 探下页 | N4；`Page` 给**默认** `(created, pk)` DESC 序、**可被先前 `.Order()` 覆盖**（如 conversation 置顶优先） |

## 4. API 面

- **链式入口**（Repo 简写 / `Query()` 起链）：`Where(raw, args…)` · `WhereEq` · `WhereIn`（空 vals → `1=0` 永假守卫）· `WhereNull` · `WhereNotNull` · `Order` · `Limit` · `Offset` · `Unscoped` · `CrossWorkspace`。
- **终结**：读 `First`(无则 `ErrNotFound`)/`Find`/`Count`/`Exists`/`Pluck`(单列入 `*[]T`)/`Page`；写 `Create`/`Save`(按 pk upsert，保留 created)/`Update`(单列)/`Updates`(多列)/`Delete`；by-pk `Get`/`Delete`。
- **`DB`**：`Open(pool)` · `Transaction`（**扁平嵌套**——已在 tx 内则复用、无 savepoint，故 store 方法可自由组合）· `Exec`（裸 SQL 逃生口：DDL / PRAGMA / 一次性维护）· `Close`。
- **json 列**：`db:"…,json"` 经 `[]byte` 暂存自动 marshal/unmarshal。

## 5. 关键设计决策 / 边界

- **泛型** = 类型安全、无 `interface{}` 转换（对比 GORM 的反射式无类型）。
- **tag 驱动 meta** = 声明式、缓存一次；**panic-on-misconfig** = 启动期 fail-fast。
- **ctx 驱动隔离** = 多租户**安全网**：取代每处手写 `WHERE workspace_id`，杜绝跨 workspace 误读/误写。
- **扁平事务**（无 savepoint）= 组合多个事务型 store 方法安全。
- **边界（可接受取舍）**：`Where`/`Order`/`Pluck`/`WhereEq` 的列名是**裸字符串**、不对 meta 校验——拼错是运行时错而非编译期。精简换灵活的取舍（要编译期列名安全得上重得多的 API，单用户本地不值）。
- `Page` 给**默认** `(created, pk)` DESC 序，但**可被先前 `.Order()` 覆盖**（conversation 置顶优先列表 `pinned DESC, created_at DESC` 即如此）——此时游标仍按 created 键，置顶少、都在首页，够用。这是有意保留的灵活，注释已写明「别强制默认序」。

## 6. 集成

被全部 **18 个 `infra/store/*`** 使用（100% 统一、无裸 SQL、无手搓 workspace_id）。错误经 [`pkg/errors`](../error-codes.md)（`ORM_NOT_FOUND` / `ORM_CONFLICT` 兜底码，domain `errors.Is` 后翻成具体码）。游标用 `pkg/pagination`；workspace ctx 用 `pkg/reqctx`。`infra/db` 负责 `Open` + migrate（`Exec` DDL）。
