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

无业务知识的 SQLite 网关（`infra/db` 无专篇，本节是它唯一事实源）：`Open`（glebarez 纯 Go 驱动，DSN pragma `auto_vacuum(INCREMENTAL)` → `journal_mode(WAL)` → `busy_timeout(5000)` → `foreign_keys(on)` → `synchronous(NORMAL)` → **补偿三件** `mmap_size(256MB)`·`cache_size(-65536=64MB)`·`temp_store(MEMORY)`——纯 Go 驱动页 IO 慢 2-5× 的性能补偿：mmap 直映省 read() 与拷贝〔转录形扫描实测 ~18% 快〕、热工作集常驻、排序溢出不落盘;零语义纯性能，`SetMaxOpenConns(1)` 单连接）+ **`Migrate`**（各 store 导出幂等 DDL、bootstrap `openDB` 汇总、单事务按序应用）+ **`MigrateRebuild`**（整表重建逃生口）+ **磁盘回收三件**（`vacuum.go`：`ReclaimFreePages` 自动 + `Compact` 用户触发 + `Stat` 度量，见下）。

**磁盘回收（`auto_vacuum=INCREMENTAL` + 保留清理后回收，T4/WRK-070，与 [database.md](../database.md) flowrun 节对齐）**：SQLite 的 `DELETE` 只把页移到 freelist、**绝不把字节还给文件系统**（`auto_vacuum` 默认 `NONE`）——故 run 历史保留清理删了真行、`.db` 文件却一字节不缩，存储面板的「Run 历史保留」成空头承诺。修法让库跑在 `auto_vacuum=INCREMENTAL`（选它而非 `FULL`：`FULL` 每次 commit 都回收 = 高频单写者 app 的常驻每写开销；`INCREMENTAL` 只在指针图记下腾空的页、显式索要时才回收）：
- **`auto_vacuum` 必须排 DSN 最前**——只能在 `journal_mode(WAL)` 初始化文件头**之前**设定，且 glebarez 驱动按 DSN 顺序应用 `_pragma`；排在 WAL 之后会静默留 `NONE`（实测）。全新文件库因此天生 `INCREMENTAL`（**无 boot 自动迁移**——项目未发版、不存在此顺序之前的用户安装；此顺序之前建的 dogfood 库 mode=0，靠用户主动 `Compact` 升级，见下）。
- **`ReclaimFreePages`**（bootstrap `sweepRetention` 在一趟清理真删了行后调**一次**，DB 全局非 workspace 隔离）：`wal_checkpoint(TRUNCATE)`（删落在 WAL、freelist/incremental_vacuum 作用于主文件，不 checkpoint 则回收量到零）→ **回收闸**（死空间 ≥ 25% 文件比例 **或** ≥ 128MiB 绝对量才回收——freelist 是**棘轮**非泄漏，稳态新 run 复用腾出的页，每 6h 都回收只会空折腾文件；日常 churn 两闸皆不过、收紧保留线才过）→ drain `PRAGMA incremental_vacuum` → 再 `wal_checkpoint(TRUNCATE)` 使缩小的文件落盘。**驱动坑**：modernc/glebarez 下 `Exec` 对 `incremental_vacuum` 只 step 一次（腾一页），须用 `Query` 遍历逐页结果行才腾光（实测）；drain 逐页查 ctx，关停在页边界可打断（同保留批循环）。
- **`Compact`**（`POST /storage:compact` → `app/storage.Service` → 此，用户在存储面板点「压缩数据库」时）：一次**全量 `VACUUM`** 回收**全部**死空间（不像 `ReclaimFreePages` 有闸——用户主动索要），并用指针图重写文件、**顺带把 mode=0 库升级到 `INCREMENTAL`**（`incremental_vacuum` 只在库已是 `INCREMENTAL` 时工作，故服务不了 mode=0 情形——手动按钮=知情等待，`VACUUM` 合适）。返 `(reclaimedBytes, migrated)`；`VACUUM` 前设 `auto_vacuum=INCREMENTAL`（已是则无害 no-op）、后 `wal_checkpoint(TRUNCATE)` 落盘。**尽力而为不再适用**：失败（磁盘满、无 `VACUUM` 临时空间）返错给调用方，`app/storage` 映射为 `STORAGE_COMPACT_FAILED`、存储面板诚实上报（库不动、可重试）。`SetMaxOpenConns(1)` 使锁库几秒期间并发请求在唯一连接上排队而非竞争（可接受的短暂阻塞——单用户桌面、用户主动）。
- **`Stat`**（`GET /storage-stat` → `app/storage.Service` → 此）：先 `wal_checkpoint(TRUNCATE)`（`freelist_count` 读主文件头，WAL 中未 checkpoint 的删除对它不可见，不 checkpoint 会把死空间低估到近零——同回收的仪器事故 #5）→ 返 `(sizeBytes=page_count×page_size, deadBytes=freelist_count×page_size)`，即存储面板显示的「库大小 + 可回收死空间」。
- **不是 D1 物理删例外**：`VACUUM`/`incremental_vacuum` 都不删任何逻辑行、只把**已腾空**的页还给 OS。删行的是 `PurgeTerminalRunsBefore`（例外②，立法在 database.md）；这里纯空间回收、无需新立法。守卫 `infra/db/vacuum_test.go`（真落盘库删行→回收→`os.Stat` 断言文件真缩且行完好 + 回收闸挡住日常 churn + `Compact` 把 mode=0 库升级+回收+零丢行+持久幂等 + `Stat` 报告死空间且压缩后回落）+ `app/storage/storage_test.go`（Service 把 infra 数字映射进线缆结构）。

**列演化两径**（SQLite 现实，与 [database.md](../database.md) 逐字对齐）：
- **加列 = `ALTER TABLE … ADD COLUMN`**，写进 store 的 `Schema` 序列，靠 **`isAddColumnApplied`** 做**结果幂等**——`duplicate column name` 即「已应用」信号、跳过不冒泡（其他语句的真重复列错误仍令整个迁移失败）。现有 6 条活 ALTER：`triggers.paused`/`missed_checked_at`（工单⑦/⑨）· `flowruns.origin`/`conversation_id`（工单①）· `flowrun_nodes.ready_at`/`started_at`（工单⑫）。
- **CHECK 加词无法 ALTER → 整表重建**：`MigrateRebuild(table, marker, stmts…)` 查 `sqlite_master` 的**现行** DDL，仅当标记词缺席才在单事务内跑调用方给的重建语句（建新表→逐列拷贝→删旧→改名→重建索引）。**结果幂等**：全新安装的 CREATE 已含新词 → 永不重建；重建后每次启动 no-op；表不存在同样 no-op。**两处在用**（皆在 `Migrate` **之后**跑——需表已存在）：`trigger_firings.status += 'missed'`（工单⑨）· `flowrun_nodes.status += 'cancelled'`（手动停掉的 run 所收割的审批记真实处置、不再假扮失败）。**这是本代码库仅有的会打在真实用户数据上的 `DROP TABLE`**，故每处都必须有**等价性**门禁钉住（`store/trigger/rebuild_test.go` 为范式）：升级后的表与全新安装的表逐列同形（`PRAGMA table_info` + 索引集），且「老安装」夹具从现行 `Schema` **派生**、不手抄（手抄一份历史 DDL 正是这门禁要禁的第二事实源）——往 CREATE 加一列却忘了重建 DDL，会在那里挂掉，而不是从已安装的库里静默删掉那一列。重建语句的 `INSERT … SELECT` 两侧**都点名列**：裸 `SELECT` 是按位的，加列/换序会把值静默灌进错误的列。

## transport

`router.Chain` 中间件栈（请求方向，外层在前：Recover → RequestLogger → CORS → InjectLocale → IdentifyWorkspace → RequireWorkspace（豁免 workspaces/webhooks/health/providers/scenarios））+ 28 个资源 handler 注册到一个 mux + `response`（N1 Envelope + `errmap.statusForKind` 唯一 Kind→HTTP 表 + FromDomainError）。auth：`RequireWorkspace` 在边界以 401 `UNAUTH_NO_WORKSPACE` 拒（与内部 500 `MISSING_WORKSPACE_ID` 之分见 [reqctx.md](reqctx.md)#4）。

## pkg 工具箱（一行职责）

`agentstate`（**对话级**跨工具共享状态：discovered 工具/active skill/读写不变式——同一实例由 convQueue 建一次、re-seed 进每个回合，活到对话空闲拆除；写前必读的 `seenFiles` 是 **LRU 有界**，最久未标的淘汰，使跨数千文件的长重构不无界增长、近期工作集不变式不破）· `idgen`（`<prefix>_<16hex>`，S15）· `jsonrepair`（LLM 脏 JSON 尽力修复，strict 解析前置）· `limits`（用户可调上限单源——schema 即现实投影：每字段必有消费方；`app/settings` 启动读 `<dataDir>/settings.json`（`fileShape` 含 `limits` + `network` + `retention` 三段）经 `SetProvider` 装源、PATCH /limits 热换（**PATCH 任一段绝不丢其余段**——`persist(limits, network, retention)` 三段整体写）；`Default()` 是默认常量、`WithDefaults` 补零字段、`Schema()` 投影每字段元数据（default/min/max/unit/desc，bounds 镜像 `settings.validate()`、与结构 1:1 由反射测试守）供 UI 渲染范围免硬编）· **`app/settings` network 段**（工单⑩）：`Network{httpProxy?,httpsProxy?,noProxy?}` 出站代理,`GET/PATCH /network`（PATCH 整体替换）;`applyProxy` 在 boot 与 PATCH 时 `os.Setenv HTTP_PROXY/HTTPS_PROXY/NO_PROXY`（Go 默认 transport 的 `http.ProxyFromEnvironment` 读之）,完整生效须重启 sidecar（既有 client 缓存代理）;空字段 unset · **`app/settings` retention 段**（scheduler 工单⑬）：`Retention{runRetentionDays}` run 历史保留线,`GET/PATCH /retention`（PATCH **部分合并**、基底是**当前值**非默认值——`0`=永久是**有意义**的值,从默认值起底会把显式的永久静默弹回 90d［present-zero-vs-absent bug 的镜像,载荷是**数据丢失**］;`fileShape` 里该段用**指针**使「段缺席」与显式 0 可区分、往返存活）;无 provider 热换——清理循环每趟现读 `Retention()`,故天然热;`SetOnRetentionChanged` 钩子（bootstrap 接）在 PATCH 落盘后**于 mu 之外**触发,踢一趟即时清理;校验只守物理（负数 400 `SETTINGS_RETENTION_INVALID`,UI 的 30/90/180 值集是产品可供性、不在此强制） · `logtail`（头+尾限长日志收集器，io.Writer；fn/hd/mcp 执行链落 `logs` 列的共用预算 64KiB）· `pagination`（keyset 游标编解码）· `pathguard`（文件系统工具的 deny-list 安全层 + `allow` 豁免谓词——先于 deny 判定、为宽黑名单开精确的洞；bootstrap 用它把 skills 子树从 `~/.anselm` 规则豁免〔谓词 `skillfs.IsInSkillsTree`，先解 symlink 防链接走私出树〕，WRK-076 B2）· **`mediaref`**（WRK-082 批B' MediaRef 文法的**纯半**：`Key = "attachmentId"`、id 形 `att_<16hex>`、`Collect(v)` 走已解码 JSON 值收集合法 id、首见序去重、`MaxRefs`=8 封顶〔防退化 payload 把一轮变成上百媒体 part〕。零 I/O、仅标准库,故任何层可用——产出侧写它、消费咽喉读它,绝无第二种拼法。**认字符串形**：含 Key 的字符串标量先试整串 JSON 解码并继续走其值,因为 receipt 在 workflow 节点间**就是**以文本流动的〔agent 终答成 `node.text`、下游 input 拿到的是字符串〕;闸只看裸 Key 而非 `"Key"`——嵌一层的 receipt 引号是转义的。**整串不是 JSON 时逐 `{` 试解嵌入对象**〔`json.Decoder` + `InputOffset` 推进,故一段答案里多份 receipt 都收得到〕——agent 的终答是**模型**写的,而模型写的是「已绘制…receipt 如下:」再把 JSON 放进围栏,那是一个**本身不是 JSON** 的字符串;只认整串 JSON 曾让媒体**在真模型面前必然停止跨节点**,而这在 mock 上永远是绿的〔脚本化回合一字不差回显 receipt、别的什么都不写〕。走**解析嵌入对象**而非正则刮裸 id,是为了让每份 receipt 留着自己的 `source`——ADR 0017 的产地过滤读的正是它,裸 id 不带产地。散文里只提到 Key、没有任何对象,仍然收集不到东西(正确)。另有 **`CollectURIs(text)`** 扫**文档正文**形 `anselm://media/<id>`（批F 值形）:它是**扫描**而非解析,因为引用住在散文里——文档正文是 markdown,id 在一个图像链接里、不在某个字段上;`URIPrefix` 常量与前端 `core/media/media_uri` 同源）· `schema`（Field 粗类型模型 + JSON Schema 双向转换）· `tokencount`（启发式 token 估算+可校准）· `wikilink`（`[[id]]` 引用抽取）· **`fspath`**（路径规则的**唯一物理执行点**，两条：①无驻地时 `Expand` 展开 `~`、拒相对（无 cwd 可解析，`FSPATH_NOT_ABSOLUTE`）②挂了驻地时 `ExpandIn(root, p)` 把仍相对的路径接到 root 上、绝对路径原样放行——**zoom 非笼子**。外加 `Inside(root, target)`，即越界写闸的谓词：**fail-closed**（任何不确定都答 false → 宁可**多**弹一次人闸也不跳过）、建在 **`os.Root`** 上（Go ≥1.24；本仓 `mise.toml` 钉 **1.25**）而非字符串前缀之上——前缀会在三处出错：兄弟目录（`HasPrefix("/root-evil", "/root")` 为真）、符号链接逃逸（字面在内、物理在外）、尚不存在的目标（全新 Write 无文件可解析）。实现自顶向下逐组件 `Root.Stat`（**Stat 而非 Lstat**：Write/Edit 会**跟随**末段链接，故指向根外的末段是真逃逸）、首个 `ErrNotExist` 即止步（不存在之物之下不可能有链接）；darwin/go1.25 实测：绝对、相对**与目录**三种逃逸链接皆报 `path escapes from parent`，即 `os.Root` 的判词与真 syscall 一致。**已知保守边界**（fail-closed，记档而非糊过去）：`filepath.Rel` 那一步对大小写敏感，故大小写不敏感文件系统上「同一目录的另一种拼法」会**多设一次闸**；根给的是 symlink 而目标给真实路径同理）。**驻地本身不住 pkg 工具箱**——它是 `reqctx` 的一个 ctx 值（`SetWorkDir` / `GetWorkDir`，见 [reqctx.md](reqctx.md)）：逐回合**不可变配置**、非可变的跨工具状态，且**正因搭 ctx 才让 subagent 继承免费**（子运行刻意拿一个全新 AgentState，存那儿会把驻地丢掉）。

## infra/gitinfo（驻地的整个 git 面：四读 + 三写，WD1→WD3）

驻地的 git 表面全在此一包：它**显示**的事实与它能在那里**做**的三件改动。**调 `git` 二进制、不手搓解析 `.git/`**（原则 #8：git 早已懂 detached HEAD、`.git` 是**文件**的 worktree、submodule、packed refs、`.gitignore`——手搓的 `.git/HEAD` 读法每一样都会微妙地弄错；而对那三个**写**根本没有别的清醒选项——一个 worktree 是 `.git/worktrees` 里的一条 + 一个 gitfile + 一份 checkout + 一个 ref）。所有调用一律经 `exec.CommandContext` 传**参数数组**、**绝不拼 shell 字符串**（分支名是用户输入、可能含 `;`、空格或前导 `--`；不让 shell 参与是唯一能让注入不可能的办法），且都用 `-C` 而非 `cmd.Dir`（目录已消失时退化成与「不是仓库」同形的普通非零退出，使调用方的错误处理只剩一条分支）。

**读（`probeTimeout` 2s）**：`Branch(ctx, dir)`（一次 `rev-parse --abbrev-ref HEAD`，O(1)，供**每轮** system prompt）· `Status(ctx, dir)`（一次 `status --porcelain=v2 --branch` 同时给分支 + 脏）· **`Branches(ctx, dir)`**（WD2：`for-each-ref --sort=-committerdate refs/heads` —— **只**本地 heads、最近提交在前。`refs/remotes` **刻意排除**，而正是这个排除让投影保持**有界、无游标**：`refs/heads` 是这个人自己建的那一集［人类尺度］，而一份 fetch 过的远端可以带来上千条；按最近而非字母排，因为菜单问的是「我刚在哪干活」）· **`Worktrees(ctx, dir)`**（WD3：`worktree list --porcelain`，**含主树**——「这个仓库有哪些 worktree」的诚实答案包含你正站着的那一份；detached 的条目报**空**分支）。辅助读：`Toplevel`（**当前**工作树根）· **`MainToplevel`**（**主**工作树根＝`worktree list` 的第一条［git 明文规定］——WD3 的派生必须从它量起，否则约定会嵌套：在 `Anselm-a` 里开一份会得到 `Anselm-a-b`、再一份 `Anselm-a-b-c`，而纪律是主仓库旁边**一排平的**兄弟）· `BranchExists`（`rev-parse --verify refs/heads/<n>`）· `CheckRefFormat`（**问 git**：`check-ref-format refs/heads/<n>`，纯语法、不需要仓库；另加两条纯 Go 前置——拒空/裸 `@`/前导 `-`，因为以 `-` 开头的 ref 对 git **合法**却会被下一条命令读成**选项**）。

**写（`writeTimeout` 60s）**：`Checkout`（`checkout <b>`，**不传 `--force`**、不 stash、不新建）· `CreateBranch`（`checkout -b <b>`）· `AddWorktree`（分支已存在 → `worktree add <path> <branch>`；不存在 → `worktree add -b <branch> <path>`——两种形状与 `make worktree` **逐字**一致）。

**`make worktree` 约定在此转录一次**：`WorktreeBranchPrefix = "wt/"` + `WorktreeTarget(top, name) = <top 的父目录>/<top 的 basename>-<name>`，即 `make worktree NAME=<x>` → `../Anselm-<x>` 分支 `wt/<x>`（Makefile 写死 `../Anselm-` 是因为 Anselm **就是**它那个根的名字；一般规则取根的 basename，故对挂在**任何**仓库上的驻地都成立）。兄弟位置同时是那条**安全**性质：调用方交进来的是**名字**、绝不是路径，故目标由此**派生**、只可能落在仓库旁边；`ValidWorktreeName` 保证名字是**单个**路径段（拒 `..`／`/`／`\`／绝对写法／前导 `-`），而正是它让这次派生密不透风。

**读与写的错误契约刻意相反**：**读**——「不存在」从不是错误（没有 `git` 二进制、不是仓库、目录已消失，一律答 `isRepo=false` / 空切片）。这是给一个菜单和一行 prompt 用的读，它绝不该成为某个回合或某个 HTTP 请求失败的原因。**写**——每次失败都上报，且带 git **自己的话**（`*CommandError{Args, Stderr, Err}`，`errors.As` 可取）:一个用户要求了、却静默什么都没做的版本控制动作，是绝不能有的结局；`app/conversation` 把它翻成 `CONVERSATION_GIT_FAILED` 并把 stderr 逐字放进 `details.git`。

`dirty` **含未跟踪文件**（驻地那个点的意思是「这里有没提交的活」，而一个全新文件正是如此）；`branch` 归一——porcelain=v2 的 `(detached)` 与 rev-parse 的 `HEAD` 统一成 `HEAD`（`gitinfo.DetachedBranch`），使两个探针对 UI 说同一套词汇、同一种状态不会显示成两样。**本包不做 commit / push / pull / merge / rebase / reset**，也不打算做（§1 拍板 #10：只做与「这段对话住在哪」有关的动作）。
