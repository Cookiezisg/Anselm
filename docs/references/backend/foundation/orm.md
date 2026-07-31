---
id: DOC-005
type: reference
status: active
owner: @weilin
created: 2026-06-11
reviewed: 2026-07-31
review-due: 2026-10-29
audience: [human, ai]
---

# ORM

## 1. 定位

`pkg/orm` 是 SQLite 的泛型数据访问地基。`infra/store/*` 通过它统一获得
workspace 隔离、软删、时间戳、constraint 翻译、事务与 keyset pagination。
FTS/embedding 等无法用 row mapper 表达的查询使用 ORM DB 的 raw read escape。

## 2. Model metadata

`For[T](db,table)` 从 `db` tags 建立类型化 Repo；T 必须是 struct 且恰有一个
`,pk`。常用 roles：

```text
pk
ws
created / updated
deleted
json
```

Metadata 反射一次并缓存。缺 pk、未知 role 等属于编程错误，在首次建 Repo 时
panic，使错误在启动/测试暴露。

## 3. Query

Query 是惰性 builder：

- conditions：Where、WhereEq、WhereIn、WhereNull/NotNull、WhereLike；
- shape：Order、Limit、Offset；
- scope：Unscoped、CrossWorkspace；
- reads：First、Find、Count、Exists、Pluck；
- writes：Create、Save、Update、Updates、Delete。

空 `WhereIn` 变为永假条件。WhereLike 转义 `%`、`_`，用户输入不成为 SQL
wildcard；空白 term 为 no-op。

Workspace model 的查询自动增加 context 中的 workspace predicate，写入自动填
workspace ID。CrossWorkspace 只用于系统级扫描。带 deleted role 的 model 默认
排除软删，Delete 写 `deleted_at`；Unscoped 才能包含它。

Create/Save 自动维护 created/updated。SQLite unique violation 统一翻为
`orm.ErrConflict`，由 domain service 转成实体错误码。

## 4. Pagination

三条 keyset：

| API | Key | Direction | 用途 |
|---|---|---|---|
| `Page` | time + PK | DESC | 常规 newest-first |
| `PageTimeAsc` | time + PK | ASC | history 向新侧续翻 |
| `PageAsc` | string COLLATE NOCASE + PK | ASC | name/title A–Z |

都使用 limit+1 探测下一页。`PageKeyset(col)` 必须与自定义 Order 的主要游标列
一致，否则跨页会漏/重。String ASC 的覆盖索引也必须使用相同 collation。

Page 可尊重调用方附加的前导排序，例如 pinned partition；这依赖置顶集合小且
位于首窗的产品假设，游标本身仍只编码主 keyset + PK。

## 5. Transactions 与 raw escape

`DB.Transaction`：

- 外层开启 transaction；
- 内层复用当前 transaction，不创建 savepoint；
- callback error 或 panic 都 rollback；
- panic 继续向上抛。

Panic-safe rollback 对单连接 SQLite 必不可少：否则被 recover 的 callback 可
永久占住唯一连接。

`Exec` 服务 DDL/PRAGMA/维护写；`Query`/`QueryRow` 服务 FTS、snippet 与复杂
aggregate read。业务 store 不应因为 API 方便而绕过 Repo 的 workspace/soft
delete 保护。

## 6. 边界

列名仍是字符串，拼写错误在运行时暴露；这是轻量 query builder 的明确取舍。
JSON role 自动 marshal/unmarshal。

错误码见 [`error-codes.md`](../error-codes.md)，workspace context 见
[`reqctx.md`](reqctx.md)，SQLite open/migrate 见
[`platform-pkgs.md`](platform-pkgs.md)。
