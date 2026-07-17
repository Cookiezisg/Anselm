---
id: DOC-033
type: reference
status: active
owner: @weilin
created: 2026-06-11
reviewed: 2026-06-14
review-due: 2026-09-14
audience: [human, ai]
---

# 平台小件 —— cel · crypto · db · transport · pkg 工具箱

> orm / reqctx / loop / stream + llm / sandbox / bootstrap / scheduler + flowrun 各有专篇（foundation/）；errors 机制见 [error-codes.md](../error-codes.md) + [ADR 0002](../../../decisions/0002-unified-error-type.md)。

## pkg/cel

裸 CEL 编译求值。宽容 `Compile` 一并声明 `payload`/`ctx`/`input`（RUNTIME 用、存储表达式已校验）；**`CompileFor(roots,expr)` 在恰好给定根集上编译（无自动 ctx）**——AUTHOR 期镜像各上下文真实活化、当场拒错命名空间：control when/emit + approval 模板只读 `input`、sensor condition/output 只读 `payload`（control/approval/trigger 的 create/edit 校验已切到它）。**env 无 now()/墙钟**——guard 重放确定（durable 引擎的前提之一）。`ScopedEnv`（scheduler 用）以图 node id 为根。模板模式 `{{ CEL }}`（approval 渲染，`CompileTemplateFor` 同受限）。

## infra/crypto

AES-GCM 整密文加解密（apikey 密文 / handler config / mcp config_enc 共用）+ 机器指纹派生密钥种子（`CRYPTO_*` 2 码）。本地单用户的"防瞄一眼"级别，非威胁模型级。

## infra/db

无业务知识的 SQLite 网关（`infra/db` 无专篇，本节是它唯一事实源）：`Open`（glebarez 纯 Go 驱动，DSN pragma `auto_vacuum(INCREMENTAL)` → `journal_mode(WAL)` → `busy_timeout(5000)` → `foreign_keys(on)` → `synchronous(NORMAL)`，`SetMaxOpenConns(1)` 单连接）+ **`Migrate`**（各 store 导出幂等 DDL、bootstrap `openDB` 汇总、单事务按序应用）+ **`MigrateRebuild`**（整表重建逃生口）+ **磁盘回收两件**（`vacuum.go`，见下）。

**磁盘回收（`auto_vacuum=INCREMENTAL` + 保留清理后回收，T4/WRK-070，与 [database.md](../database.md) flowrun 节对齐）**：SQLite 的 `DELETE` 只把页移到 freelist、**绝不把字节还给文件系统**（`auto_vacuum` 默认 `NONE`）——故 run 历史保留清理删了真行、`.db` 文件却一字节不缩，存储面板的「Run 历史保留」成空头承诺。修法让库跑在 `auto_vacuum=INCREMENTAL`（选它而非 `FULL`：`FULL` 每次 commit 都回收 = 高频单写者 app 的常驻每写开销；`INCREMENTAL` 只在指针图记下腾空的页、显式索要时才回收）：
- **`auto_vacuum` 必须排 DSN 最前**——只能在 `journal_mode(WAL)` 初始化文件头**之前**设定，且 glebarez 驱动按 DSN 顺序应用 `_pragma`；排在 WAL 之后会静默留 `NONE`（实测）。全新文件库因此天生 `INCREMENTAL`。
- **`EnsureIncrementalAutoVacuum`**（`openDB` 在 Migrate/MigrateRebuild 之后、仅文件库调）：存量安装文件头带 `NONE`，光 PRAGMA 翻不动，须一次**全量 `VACUUM`** 用指针图重写文件——它**同时**回收该安装攒下的死空间（用户可感修复）。结果幂等（文件头读作 `INCREMENTAL` 即 no-op）；**尽力而为**——`VACUUM` 需约等于库大小的临时空间，磁盘将满的用户（正是修复对象）可能没有，故失败只记日志不令 boot 失败、下次 boot 重试。
- **`ReclaimFreePages`**（bootstrap `sweepRetention` 在一趟清理真删了行后调**一次**，DB 全局非 workspace 隔离）：`wal_checkpoint(TRUNCATE)`（删落在 WAL、freelist/incremental_vacuum 作用于主文件，不 checkpoint 则回收量到零）→ **回收闸**（死空间 ≥ 25% 文件比例 **或** ≥ 128MiB 绝对量才回收——freelist 是**棘轮**非泄漏，稳态新 run 复用腾出的页，每 6h 都回收只会空折腾文件；日常 churn 两闸皆不过、收紧保留线才过）→ drain `PRAGMA incremental_vacuum` → 再 `wal_checkpoint(TRUNCATE)` 使缩小的文件落盘。**驱动坑**：modernc/glebarez 下 `Exec` 对 `incremental_vacuum` 只 step 一次（腾一页），须用 `Query` 遍历逐页结果行才腾光（实测）；drain 逐页查 ctx，关停在页边界可打断（同保留批循环）。
- **不是 D1 物理删例外**：`VACUUM`/`incremental_vacuum` 都不删任何逻辑行、只把**已腾空**的页还给 OS。删行的是 `PurgeTerminalRunsBefore`（例外②，立法在 database.md）；这里纯空间回收、无需新立法。守卫 `vacuum_test.go`（真落盘库删行→回收→`os.Stat` 断言文件真缩且行完好 + 回收闸挡住日常 churn + 存量 NONE 库迁移持久幂等）。

**列演化两径**（SQLite 现实，与 [database.md](../database.md) 逐字对齐）：
- **加列 = `ALTER TABLE … ADD COLUMN`**，写进 store 的 `Schema` 序列，靠 **`isAddColumnApplied`** 做**结果幂等**——`duplicate column name` 即「已应用」信号、跳过不冒泡（其他语句的真重复列错误仍令整个迁移失败）。现有 6 条活 ALTER：`triggers.paused`/`missed_checked_at`（工单⑦/⑨）· `flowruns.origin`/`conversation_id`（工单①）· `flowrun_nodes.ready_at`/`started_at`（工单⑫）。
- **CHECK 加词无法 ALTER → 整表重建**：`MigrateRebuild(table, marker, stmts…)` 查 `sqlite_master` 的**现行** DDL，仅当标记词缺席才在单事务内跑调用方给的重建语句（建新表→逐列拷贝→删旧→改名→重建索引）。**结果幂等**：全新安装的 CREATE 已含新词 → 永不重建；重建后每次启动 no-op；表不存在同样 no-op。**两处在用**（皆在 `Migrate` **之后**跑——需表已存在）：`trigger_firings.status += 'missed'`（工单⑨）· `flowrun_nodes.status += 'cancelled'`（手动停掉的 run 所收割的审批记真实处置、不再假扮失败）。**这是本代码库仅有的会打在真实用户数据上的 `DROP TABLE`**，故每处都必须有**等价性**门禁钉住（`store/trigger/rebuild_test.go` 为范式）：升级后的表与全新安装的表逐列同形（`PRAGMA table_info` + 索引集），且「老安装」夹具从现行 `Schema` **派生**、不手抄（手抄一份历史 DDL 正是这门禁要禁的第二事实源）——往 CREATE 加一列却忘了重建 DDL，会在那里挂掉，而不是从已安装的库里静默删掉那一列。重建语句的 `INSERT … SELECT` 两侧**都点名列**：裸 `SELECT` 是按位的，加列/换序会把值静默灌进错误的列。

## transport

`router.Chain` 中间件栈（请求方向，外层在前：Recover → RequestLogger → CORS → InjectLocale → IdentifyWorkspace → RequireWorkspace（豁免 workspaces/webhooks/health/providers/scenarios））+ 28 个资源 handler 注册到一个 mux + `response`（N1 Envelope + `errmap.statusForKind` 唯一 Kind→HTTP 表 + FromDomainError）。auth：`RequireWorkspace` 在边界以 401 `UNAUTH_NO_WORKSPACE` 拒（与内部 500 `MISSING_WORKSPACE_ID` 之分见 [reqctx.md](reqctx.md)#4）。

## pkg 工具箱（一行职责）

`agentstate`（**对话级**跨工具共享状态：discovered 工具/active skill/读写不变式——同一实例由 convQueue 建一次、re-seed 进每个回合，活到对话空闲拆除；写前必读的 `seenFiles` 是 **LRU 有界**，最久未标的淘汰，使跨数千文件的长重构不无界增长、近期工作集不变式不破）· `idgen`（`<prefix>_<16hex>`，S15）· `jsonrepair`（LLM 脏 JSON 尽力修复，strict 解析前置）· `limits`（用户可调上限单源——schema 即现实投影：每字段必有消费方；`app/settings` 启动读 `<dataDir>/settings.json`（`fileShape` 含 `limits` + `network` + `retention` 三段）经 `SetProvider` 装源、PATCH /limits 热换（**PATCH 任一段绝不丢其余段**——`persist(limits, network, retention)` 三段整体写）；`Default()` 是默认常量、`WithDefaults` 补零字段、`Schema()` 投影每字段元数据（default/min/max/unit/desc，bounds 镜像 `settings.validate()`、与结构 1:1 由反射测试守）供 UI 渲染范围免硬编）· **`app/settings` network 段**（工单⑩）：`Network{httpProxy?,httpsProxy?,noProxy?}` 出站代理,`GET/PATCH /network`（PATCH 整体替换）;`applyProxy` 在 boot 与 PATCH 时 `os.Setenv HTTP_PROXY/HTTPS_PROXY/NO_PROXY`（Go 默认 transport 的 `http.ProxyFromEnvironment` 读之）,完整生效须重启 sidecar（既有 client 缓存代理）;空字段 unset · **`app/settings` retention 段**（scheduler 工单⑬）：`Retention{runRetentionDays}` run 历史保留线,`GET/PATCH /retention`（PATCH **部分合并**、基底是**当前值**非默认值——`0`=永久是**有意义**的值,从默认值起底会把显式的永久静默弹回 90d［present-zero-vs-absent bug 的镜像,载荷是**数据丢失**］;`fileShape` 里该段用**指针**使「段缺席」与显式 0 可区分、往返存活）;无 provider 热换——清理循环每趟现读 `Retention()`,故天然热;`SetOnRetentionChanged` 钩子（bootstrap 接）在 PATCH 落盘后**于 mu 之外**触发,踢一趟即时清理;校验只守物理（负数 400 `SETTINGS_RETENTION_INVALID`,UI 的 30/90/180 值集是产品可供性、不在此强制） · `logtail`（头+尾限长日志收集器，io.Writer；fn/hd/mcp 执行链落 `logs` 列的共用预算 64KiB）· `pagination`（keyset 游标编解码）· `pathguard`（文件系统工具的 deny-list 安全层）· `schema`（Field 粗类型模型 + JSON Schema 双向转换）· `tokencount`（启发式 token 估算+可校准）· `wikilink`（`[[id]]` 引用抽取）· `fspath`（绝对路径/~ 展开守卫）。
