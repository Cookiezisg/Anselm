---
id: DOC-015
type: reference
status: active
owner: @weilin
created: 2026-06-11
reviewed: 2026-07-31
review-due: 2026-10-29
audience: [human, ai]
---

# Trigger

## 1. 定位

Trigger 是无版本的信号源配置实体。cron、webhook、fsnotify、sensor 满足条件
后，把事件扇出给所有引用它的 active workflow。手动运行属于 Workflow
`:trigger`，不是 Trigger source。

```text
infra listener
→ ReportFunc(triggerID, Activity) error
→ app onReport with detached workspace ctx
→ Activation audit
→ zero or more durable Firings
→ scheduler drain
```

Activation 记录 source 活动，sensor 未触发的 probe 也记录原因。`firingCount` 是**该条
activation 的 workflow 扇出数**（per-entry fan-out width），不是 trigger 历史累计次数；未触发
通常为 0，已触发但没有监听 workflow 时也可以为 0。Firing 是
persist-before-act 收件箱；只有 Fired activity 才为监听 workflow 创建。Webhook 的 `202`
只有在这条 durable audit/inbox 写入完成后才返回；scheduler 排空仍然异步。若持久化失败，
入口返回失败而不是给发送方一个会在崩溃中丢失的假确认。

## 2. Firing 状态

| 状态 | 语义 |
|---|---|
| `pending` | 等待 scheduler claim |
| `claimed` | claim 事务内状态 |
| `started` | 已创建 flowrun |
| `skipped` | overlap `skip` |
| `superseded` | `buffer_one` 淘汰较旧 pending |
| `shed` | 资源/结构原因不再可执行，或 workflow kill |
| `missed` | 停机/睡眠期间错过的 cron 刻度 |

skipped、superseded、shed、missed 都是“未执行”的中性处置，不是失败。
Scheduler 发现 active graph 已不再以该 trigger 为入口时，将 firing 收为 shed，
避免永久重试。

Firing 的列表响应在读时按页内去重的 `workflowId` 批量补 `workflowName`。这个字段是显示投影，
不写回 firing 历史；workflow 已软删、不可读或名称为空时省略，调用方必须诚实回落到原始
`workflowId`，不能从旧缓存或别的 workflow 猜一个名称。这样「为什么没跑」面默认给人看懂的
workflow 名，同时保留 opaque ID 作为审计与深链钥匙。

`idx_trf_dedup(workflow_id,trigger_id,dedup_key)` 保证同一物理事件对一个
workflow 只入账一次。`AppendFiring` 冲突时返回既有行；调用者必须检查返回
status，不能把 nil error 等同于“新建了可运行 firing”。

## 3. Listener 生命周期

多个 active workflow 共享一个 listener：

- 0→1 引用时 Register；
- 1→0 时 Unregister；
- Boot 通过 `ReattachActive` 重建内存 registry；
- stage 使用 `AttachOnce`，首次真实 fan-out 后自动 Detach。

Detach 先从 registry 移除引用，再等待已经越过 listener snapshot 的 report
落成 durable firing。未越过 snapshot 的晚到 report 丢弃。这样 draining
统计不会漏掉已接受但正在 append 的 firing。

`refCount`、`listening`、`lastFiredAt`、`nextFireAt` 是读时投影，不是表列。
`nextFireAt` 只对可解析且正在监听的 cron 提供。

### Pause / Resume

`paused` 是持久开关。Pause 在 source 层停止 listener：

- cron 删除 entry；
- webhook registry miss 返回 404；
- fsnotify watcher 停止；
- sensor probe 停止。

引用集保留，在途 run 与已有 pending firing 不受影响；手动 `:fire` 返回
`TRIGGER_PAUSED`。Resume 在仍有引用时按当前 config 重注册。Pause/Resume
幂等，真转移发送 entities ephemeral status `{paused}`。

Pause、Resume 通过同一 switch lock 串行，使数据库列与内存 registry 不分叉。
Resume 注册失败时回滚为 `paused=true`，保持状态诚实且允许重试。Edit 对正在
监听的 trigger 热重启；暂停项等 resume 时使用新 config。

## 4. Misfire

Cron misfire 策略是“记录错过，默认不补跑”。每个错过刻度为每个监听
workflow 写一条 `missed` firing：

- `created_at` 是原调度刻度；
- `flowrun_id` 为空；
- 与真实 fire 使用同一 dedup key；
- 默认策略 `skip` 只记账；
- `catchup_one` 将本次新记账的最近一个 missed 行守卫式转回 pending。

### 水位与窗口

`triggers.missed_checked_at` 表示水位前的刻度均已入账。Sweep 窗口下界取水位，
并不早于 trigger 创建时间；上界不越过 live listener 仍可能接受的
`MisfireTolerance` 尾带。

Listener 每次 Register 保存 `hotSince`：

- 当前进程 Register 之前的刻度已不可能由该 listener 投递，可立即记账；
- 容差尾带内仍可能到来的回调不能提前占用 dedup key；
- 水位只推进到本次实际检查的上界，尾带在下次 sweep 处理。

水位在四处推进：

1. cron 真实 fan-out 后；
2. misfire sweep 收尾；
3. resume 时跳过用户主动暂停的区间；
4. 实时 0→1 Attach 时跳过冷态无人监听的区间。

Boot 的 `AttachReplay` 不推进水位，使停机缺口可被发现。实时 `Attach` 与 boot
`AttachReplay` 是不同 binder 语义。

### 去重与 catchup

Missed 与 live fire 共用 `croninfra.DedupKey(trigger,tick)`。Fan-out 遇到：

- existing pending：计为可运行；
- existing missed：`RequeueMissedFiring` 后计为可运行；
- existing terminal outcome：不创建 run，也不增加 firingCount。

Catchup 只允许本次 sweep 真正新落账的最近刻度；不能仅凭窗口非空触发，
否则“firing 已提交、水位尚未推进”这一崩溃窗会重复运行。Catchup 不创建平行
dedup key，一个刻度始终只有一行台账。

Sweep 对每 trigger 限制记录数量与回看时间；超大高频缺口只保留最近刻度并将
水位推进到检查上界。稀疏 cron 在数量上限内保持完整。Sweep 在 boot
ReattachActive 后执行，并由周期 ticker 覆盖进程存活期间的睡眠恢复。

Robfig 醒来可能补送过期回调；listener 只接受能吸附到
`MisfireTolerance` 内最近刻度的回调。更早的缺口交给 sweep。

## 5. Source 契约

| Source | Dedup key | Payload |
|---|---|---|
| cron | trigger + tick | `{firedAt}` |
| webhook | body hash prefix + minute bucket | `{firedAt,method,path,headers,body\|bodyRaw}` |
| fsnotify | path + op + second bucket | `{firedAt,path,eventKind}` |
| sensor | trigger + probe second | `config.output` CEL 的结果 |

Webhook 同 payload 的网络重试只在分钟桶内折叠；fsnotify 折叠编辑器同秒突发。
Sensor 是 level-triggered：每次 probe 条件为真都可产生新 firing，持续状态由
workflow concurrency 控制，不内置 edge state。

`outputs` 声明下游可读字段。cron/webhook/fsnotify 由
`CanonicalOutputs(kind)` 覆盖，必须与 listener payload 同步；sensor 由作者
根据 `config.output` 声明。Workflow capability check 以此提供建议性 output
读取诊断。

### Config

- cron：robfig 五段表达式；不支持秒级或 `@every`；
- webhook：path + 可选 secret；支持直接 secret 或 HMAC-SHA256 header；
- fsnotify：path + 可选 event kind/pattern；
- sensor：interval、function/handler/MCP target、可选 method/tool、CEL
  condition 与 output。存储态 `config.output` 是 CEL 字符串；面向自然语言
  agent 的 `{"field":"payload.value"}` 对象简写由 `create_trigger` 稳定转换为
  CEL object literal 后再校验，不能把 map 直接落盘。

`create_trigger` 与 `edit_trigger` 的 `config` 线缆都接受两种等价编码：schema
规定的原生 JSON object，或其**精确 JSON 编码字符串**（字符串内容去掉首尾空白后
必须仍是 object）。数组、标量、普通文本和坏 JSON 字符串均拒绝，避免把模型的
编码错误猜成另一种配置。`edit_trigger` 在写入前按当前 trigger 的 kind 对 sensor
的 `config.output` 对象简写执行同一稳定归一化；省略 `config`（或显式 `null`）
仍表示不修改，不会清空既有配置。

Sensor target 在 create/edit 时通过注入的 validator eager 校验。Webhook
使用一个 `/api/v1/webhooks/` catch-all 和内存 path registry；Register/
Unregister 不向 ServeMux 动态增删 pattern。

## 6. CRUD 与动作

- Create/Edit 只写用户配置列；`EditTrigger` 不得整行覆盖 `paused` 或
  `missed_checked_at`。
- `:fire` 为当前监听者生成 `{manual:true}`；该标记表示**手动绕过 source condition 的动作**，不证明
  sensor 的 CEL 条件或阈值求值为真。零监听者时仍写一条
  firing_count=0 的 Activation；自定义测试 payload 应走 Workflow trigger。
  暂停时返回 `TRIGGER_PAUSED`，不得用 `edit_trigger` 清除暂停；恢复必须走 trigger
  的 Resume 控件或 `POST /api/v1/triggers/{id}:resume`，再执行 fire。
- `:pause` / `:resume` 控制 source，不取消既有工作。
- `:iterate` 打开 AI 编辑对话。
- `get_activation` 是单条 activation 审计记录的精确读取：必须传逐字复制的 `activationId`，返回
  `id`、`triggerId`、`kind`、`fired`、`returnValue`、`payload`、`error`、`detail`、`firingCount`、
  `createdAt`。工具卡片是这些机器字段的精确、可复制真相面；模型正文若需隐藏不透明 ID 或时间，必须
  指向相邻 activation 卡片，不能把占位词当成实际值。
- Create/Edit/Delete 发 notifications durable lifecycle signal（`trigger.created`、`trigger.edited`、
  `trigger.deleted`），使已打开的 rail/detail 在 AI 或其它客户端写入后回读实体真相；Pause/Resume
  不写通知中心，只发 trigger scope 的 ephemeral `status`。
- Delete 停 listener、软删主行并清 relation；既有 activation/firing 日志保留。主行**不可恢复**，当前没有
  restore 操作；`delete_trigger` 具有不可绕过的静态 `dangerous` 下限，即使模型自报 `safe` 也必须先经过
  HumanLoop 用户批准，且不能被 skill 或 `approve_always` 预授权绕过。删除前先用 `get_relations` 解释会
  失效的 workflow 依赖。

`get_trigger` 是精确读取，不是名称搜索：规范字段是从 mention、工具回执或 `search_triggers` 结果复制的
`triggerId`。为兼容已观测的 hosted-model 漂移，只有当 `file_path` 的值本身是明确的 `trg_...` 不透明 ID
时才会在工具边界将其改名为 `triggerId`；普通文件路径、`query`、名称、占位词和冲突字段仍然拒绝。只知道
名称时先搜索，再把返回的 `trg_...` id 原样传入。工具描述和 schema 都把这条边界直接告诉模型，避免把
通用文件读取参数误套到实体查询上。
若 hosted model 漏掉整个参数对象，loop 只在最新 user/tool 证据里恰有一个明确的 `trg_...` ID 时补回
`triggerId`；证据没有候选或包含多个候选时不猜测，仍保留真实失败。

Shutdown join cron、fsnotify、sensor 等 goroutine 后再关闭下游资源。Webhook
listener 由 HTTP server 生命周期承载。

## 7. 契约与集成

HTTP：

- Trigger CRUD 与 `:fire|:pause|:resume|:iterate`；
- activations 列表/单读；
- workspace 与 per-trigger firings（每行按读时 workflow hydration 可带 `workflowName`，缺席时保留 `workflowId`）；
- `GET /trigger-schedule`。

精确端点见 [`api.md`](../api.md)，表与状态见
[`database.md`](../database.md)，错误见
[`error-codes.md`](../error-codes.md)，事件见 [`events.md`](../events.md)。
ID：`trg_`、`tra_`、`trf_`。

Workflow 通过 Binder 的 `Attach`、`AttachOnce`、`AttachReplay`、`Detach`
驱动 listener。Scheduler 通过 FiringInbox list/claim/outcome/supersede/count
消费 durable inbox。Sensor invoker 通过窄端口调用 Function、Handler 或 MCP。
Catalog、Mention、Relation 与 Search 使用标准实体适配器。
