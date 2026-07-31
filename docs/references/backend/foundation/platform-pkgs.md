---
id: DOC-033
type: reference
status: active
owner: @weilin
created: 2026-06-11
reviewed: 2026-07-31
review-due: 2026-10-29
audience: [human, ai]
---

# Platform packages

本页登记没有独立域文档、但承载跨域不变量的平台小件。ORM、request context、
Loop、Streams/LLM、Sandbox、Bootstrap 与 Scheduler 各有独立 foundation
reference。

## 1. CEL

`pkg/cel` 提供无墙钟函数的确定性表达式：

- `Compile`：runtime 宽环境；
- `CompileFor(roots,expr)`：author-time 精确根集合；
- `ScopedEnv`：Workflow node IDs；
- `CompileTemplateFor`：Approval `{{ CEL }}`。

Control/Approval 只读 `input`，Sensor 只读 `payload`。Author-time env 必须镜像
真实 runtime roots；不提供 `now()`，保证 replay 结果不随墙钟变化。

## 2. Crypto

`infra/crypto` 使用 AES-GCM 加密 API key、Handler config 与 MCP config。
密钥种子来自机器 fingerprint。它防止本地文件被直接浏览时暴露 secret，不代表
对已控制本机进程的攻击者提供硬件级密钥保护。

## 3. SQLite gateway

`infra/db.Open` 使用纯 Go SQLite、WAL、foreign keys、busy timeout 与单连接。
Cache/mmap/temp-store 只调整性能，不改变业务语义。

Store `Schema` 由 Bootstrap 汇总并在单事务中迁移：

- Add column 使用 `ALTER TABLE ... ADD COLUMN`，duplicate-column 表示结果已存在；
- SQLite CHECK 扩词使用 `MigrateRebuild`：检查 sqlite_master marker，只在缺失
  时建新表、点名列复制、替换表并重建索引；
- Rebuild 必须有“升级表与全新建表同形、数据不丢”的 store 测试；
- `INSERT ... SELECT` 两侧禁止裸列顺序。

## 4. SQLite storage reclaim

数据库使用 `auto_vacuum=INCREMENTAL`。逻辑 DELETE 先释放 SQLite pages，但文件
不会自动缩小。

`ReclaimFreePages` 用于 retention 后自动回收：

1. checkpoint WAL；
2. 仅在 dead-space 比例或绝对量超过阈值时继续；
3. 逐页 drain incremental vacuum，并检查 context；
4. 再 checkpoint。

日常 churn 留在 freelist 供后续写复用，不反复抖动文件。

`Compact` 是用户主动的同步 full VACUUM，无自动阈值，并可把非-incremental
数据库迁到 incremental mode。失败返回 `STORAGE_COMPACT_FAILED`，不把“未回收”
报告成成功。

`Stat` checkpoint 后通过 page/freelist 计算 size/dead bytes。Vacuum 不删除
逻辑行，因此不是 durable truth 的额外物理删除例外。

## 5. HTTP transport

Router chain 请求方向：

```text
Recover
→ RequestLogger
→ RequireLoopbackHost
→ RequireBearerToken
→ CORS
→ InjectLocale
→ IdentifyWorkspace
→ RequireWorkspace
→ resource handler
```

`envelopeMuxErrors` 在最内层把 `/api/v1/*` 的标准库 404/405 改写为 N1 Envelope。
Workspace create/list、health、version、providers/scenarios、attachment playback 与 webhook
入口按路由规则豁免 workspace requirement；其中 playback URL 自带短期 workspace binding，
webhook 使用自身 secret/HMAC 并从注册关系解析 workspace。Response package 统一 Envelope
与唯一 Kind→HTTP 映射。完整端点见 [`api.md`](../api.md)。

## 6. Settings

`app/settings` 以一个文件持久化：

- Limits：字段与 Schema metadata 一一对应，Patch 热换；
- Network：HTTP/HTTPS/NO_PROXY，Patch 后应用环境；
- Retention：runRetentionDays，0=永久，Patch 部分合并。

Retention section 使用指针区分“段缺席”和“显式 0”。回调在 settings mutex 外
触发，避免持锁执行清理。

## 7. Filesystem safety

`pkg/fspath`：

- `Expand`：无 workdir 时展开 `~`，拒绝相对路径；
- `ExpandIn`：有 workdir 时相对路径接 root，绝对路径保持；
- `Inside`：用 `os.Root` 逐组件检查真实归属，不做字符串 prefix 判断。

Inside fail-closed：不存在目标在首个 missing component 停止，symlink escape
返回 false。它服务 Workdir 外写确认与媒体 artifact path guard。

`pkg/pathguard` 是 filesystem tools 的 deny list。精确 allow predicate 可为
workspace Skill subtree 开洞；predicate 先解析 symlink，不能用链接把允许路径
转出 subtree。

## 8. Git info

`infra/gitinfo` 调用 git binary，所有用户输入作为参数数组传递，不拼 shell。

只读：

- current branch/status；
- local branches；
- worktrees、current/main toplevel；
- branch existence/ref format。

读失败降级为“不是 repo/空投影”，不使 prompt/menu 失败。Dirty 包含 untracked。
Detached branch 统一投影为 `HEAD`。

写操作仅有 checkout existing branch、create branch、add worktree。写失败保留
CommandError stderr，由 Conversation 映射稳定 code/details。目标 worktree
由主仓 root、单段 name 与 `wt/` branch convention 派生；不接受任意 path。

## 9. Utility packages

| Package | 职责 |
|---|---|
| `agentstate` | 有界 lazy-tool recency、active Skill、file-read state |
| `idgen` | `<prefix>_<16hex>` |
| `jsonrepair` | LLM JSON 的有限修复 |
| `limits` | 热读 limits 与 schema |
| `logtail` | 头尾保留的有界日志 writer |
| `pagination` | keyset cursor 编解码 |
| `schema` | Field 与 JSON Schema 转换 |
| `tokencount` | 可校准启发式 token 估算 |
| `wikilink` | `[[id]]` 引用抽取 |

`pkg/mediaref` 定义唯一 receipt：

```json
{"attachmentId":"att_..."}
```

Collect 支持已解码值、完整 JSON string 与散文内嵌 JSON object，按首见顺序去重
并限制数量。它不执行 I/O 或 source 过滤。`CollectURIs` 只扫描 Document Markdown
中的 `anselm://media/<attachmentId>`。
