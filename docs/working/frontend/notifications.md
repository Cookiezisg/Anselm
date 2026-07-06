---
id: WRK-058
type: working
status: active
owner: @weilin
created: 2026-07-06
reviewed: 2026-07-06
review-due: 2026-10-04
audience: [human, ai]
---

# Feature:Notifications(通知中心 + 悬浮 toast)—— 建造文档(在建)

> chat B1–B7 收官后的下一模块。调研 workflow `wf_e4f43a45-d02`(10 agent:词表普查 / 契约深读 / 前端底盘 / 通知中心 bp / 桌面 toast bp,五份全对抗验证 confirmed)。四项拍板(§A)已定,按 §F 阶梯建;建完 → 结论提取进 `references/frontend/features/notifications.md` + 本页归 `archive/`。hub 见 [`README`](README.md)。

## 一句话 + IDEAL

一个**替你值守后台的收件箱**——agent / workflow / 调度器在你不看的时候干了什么、坏了什么、等你什么:重要的当场**右上 toast** 冒出来(app 未聚焦则走 **OS 原生通知**),半重要的进**左岛铃托盘**攒着,铃上一个数,拉开一眼扫完,点一行跳到现场。= Linear Inbox 的 triage 语义 + macOS 的 toast 心智 + 本项目「DB 行是真相、流只为实时」铁律。

## A. 四项拍板(2026-07-06,用户逐条定)

1. **boring 治理 = 后端分径**:Emitter 拆双径——**通知类**(important+semi)照旧「落行 + 推 durable 帧」;**信号类**(boring)改「只推 durable 帧、不落行」。rail/documents/entities 消费者零改(它们读帧不读行);notification 表从此只存值得看的,`unread-count` 天然干净、表不堆回声垃圾。
2. **托盘 = 两段式**:顶部「待你处理」段(现 `FlowrunInbox` 融入:approval 待决卡,批完自动消)+ 下面「通知」时间流(今天/昨天/更早轻节头)。
3. **toast 全体迁右上**:事件 toast 锚**右上**,且**既有动作回报 toast 一并迁右上**(单一 host、单一锚,用户拍板「那样舒服」)。只 important 弹;时长分级(ok/info 5s · warn 8s · danger/待决常驻);hover 暂停消隐;`(entityId, eventKind)` 风暴合并;≤3 条可见 + 溢出折叠。
4. **OS 原生通知进 v1**:app 未聚焦时发系统通知(`flutter_local_notifications`),点击深链回 app。

## B. 后端铁事实(调研核实,带 file:line 的全文见 workflow 产出)

- **Emit 机制**:`notificationdomain.Emitter.Emit(ctx, type, payload)`(domain/notification/notification.go:54)唯一实现 `notificationapp.Service`:造 `noti_<16hex>` 行 → `repo.Save` → 推 durable Signal 帧(scope=`notification:<id>`,`node.type`=事件类型,`node.content`=payload;Ephemeral 未设 → durable,seq>0 入 replay 环)。**恒双落、无旁路**(KindNotification Publish 全后端仅一处);producer 一律 log-warn 吞错(best-effort,通知不连累业务);非事务(业务写后独立写);15 模块持有、全 nil-tolerant。`workflow.approval_pending` 显式 at-least-once(可重发)。
- **DTO(域结构体直序列化,无独立 wire 层)**:`id` / `type`(`<domain>.<action>`,开放词表)/ `payload`(object,`omitempty` 空缺席)/ `readAt`(RFC3339,**缺席=未读**)/ `createdAt`(RFC3339,keyset 排序键);`workspaceId` 不上线缆。**后端刻意不产人类可读文案**——前端 i18n 模板化(§D.1)。
- **端点**:`GET /notifications`(cursor/limit[默认50钳200],**无任何过滤**,created_at DESC keyset,data 恒数组)· `POST /notifications/{id}:mark-read`(204;未知/跨 ws → 404 `NOTIFICATION_NOT_FOUND`;**无 IS NULL 条件**——重复调重盖时间戳、结果幂等)· `POST /notifications:mark-all-read`(204 恒幂等)· `GET /notifications/unread-count`(`{"data":{"unread":n}}`,COUNT WHERE read_at IS NULL,partial 索引)。**mark-read / mark-all-read 不发任何 SSE 回声**——多窗口 badge 同步无推送,自己 mutate 后本地扣减、resync 时重拉。
- **SSE**:帧上只有 type+payload(**无 createdAt/readAt/全行**);无单查端点 → 信号转全行只能重拉 List 首页(v1:直接以收帧时刻近似 + 首页重拉合并)。订阅 `GET /notifications/stream`,SSE 无法设 header → workspace 走 `?workspaceID=`(auth.go 明示);410 SEQ_TOO_OLD → 重取 REST 再续。
- **表**:`notifications(id, workspace_id, type, payload, read_at NULL, created_at)` + `idx_noti_ws_created` + partial `idx_noti_unread`;**append-only 无 deleted_at、无清理**(登记的延后特性)。
- **错误码**:`NOTIFICATION_NOT_FOUND`(404)· `NOTIFICATION_INVALID_TYPE`(内部 Emit 径,REST 永不返)+ 泛型 `MALFORMED_CURSOR`/`INVALID_REQUEST`/`NOT_FOUND`/`UNAUTH_NO_WORKSPACE`/`SEQ_TOO_OLD`。
- **gap 台账(v1 绕开,后端不加)**:无 type/unread 过滤 → v1 不做 unread-only toggle;无批量 mark-read → 用单条+全量两极;无删除/归档端点 → 已读留列表灰显(审计流语义,正好是调研推荐);无 severity 列 → **分级即词表**(§C),前端 `type→档` 映射(N0 分径后行集=important+semi,important 集前端硬表)。

## C. 词表台账(74 发射点 × 三档 × 分径;N0 的施工清单 + i18n 模板分母)

> 档位按用户口径「半重要都进,太无聊不进」;含对抗验证的 4 项裁决(`document.deleted`↑semi、`handler.restarted[ok:true]`↓boring、`mcp.reconnected` 后端补 status 留 semi、`memory.updated` pin 调用点拆仅帧径)。**径**:行+帧=通知类(落行+推流)/ 仅帧=信号类(N0 换径,不落行)。

### 🔴 important(7)——toast 弹 + 托盘 + OS 通知

| 事件 | payload | 调用点 | 时机 |
|---|---|---|---|
| `handler.crashed` | handlerId | app/handler/call.go:192 | :call 发现常驻进程已死 |
| `handler.restarted`(ok:false) | handlerId, ok | app/handler/crud.go:278 | 手动重启失败 |
| `workflow.run_failed` | workflowId, flowrunId, error | app/scheduler/kill.go:188 | run 结算 failed(唯一收口;cancelled/completed 不发) |
| `workflow.attention_changed` | workflowId, needsAttention, attentionReason | app/workflow/crud.go:337 | 调度器自愈 attention 点亮/熄灭(needsAttention=false 的熄灭帧**不弹 toast**、只更新托盘) |
| `workflow.approval_pending` | workflowId, flowrunId, nodeId | app/scheduler/dispatch.go:82 | run 堵到有人决策(at-least-once,前端按 (flowrunId,nodeId) 去重) |
| `relation.dependency_broken` | deletedKind, deletedId, dependents[{kind,id,name,edge}] | app/relation/relation.go:181 | 删了被依赖实体,聚合点名孤儿 |
| `sandbox.env_status_changed`(failed) | envId, status, ownerKind, ownerId, errorMsg | app/sandbox/sandbox.go:517 | env 构建/装依赖失败 |

### 🟡 semi(49)——只进托盘

| 族 | 事件(payload 形共享) | 调用点 |
|---|---|---|
| function(6) | created/edited/reverted(id+versionId+version)· env_rebuilt(id+versionId)· updated/deleted(id) | app/function/crud.go:144/223/244/186/270/284 |
| handler(9) | created/edited/reverted · env_rebuilt · updated×2(meta 两径)· deleted · config_updated/config_cleared · restarted(ok:true→**仅帧**,见 boring) | app/handler/crud.go:142/243/263/184/215/314/330 + config.go:62/76 + crud.go:281 |
| agent(5) | created/edited/reverted/updated/deleted | app/agent/crud.go:283/330/349/373/385 |
| workflow(6) | created/edited/reverted/updated/deleted · lifecycle_changed(+lifecycleState,active) | app/workflow/crud.go:127/224/252/292/424/317 |
| control(5) / approval(5) | created/edited/updated/reverted/deleted | app/control/crud.go · app/approval/crud.go |
| skill(3) | created/updated/deleted(name) | app/skill/mutate.go:44/67/82 |
| memory(3) | created/updated(内容更新源)/deleted(name) | app/memory/memory.go:99/124 |
| mcp(5) | installed×2 / updated / removed / reconnected(payload `{name, status, lastError?}`——**N0 已补 status**:reconnect 成败都发,status 载 ready/degraded/failed,通知中心分清恢复与仍坏) | app/mcp/install.go:96/143/141/192 + mcp.go:189 |
| document(1) | deleted(裁决升档:破坏性、AI 可删用户文档) | app/document/document.go:421 |
| sandbox(1) | env_status_changed(ready) | app/sandbox/sandbox.go:446 |

### ⚪ boring(18)——N0 换仅帧径(不落行,rail/树同步照旧)

| 族 | 事件 | 调用点 |
|---|---|---|
| conversation(10) | created / updated / archived / unarchived / pinned / unpinned / model_override / auto_titled / compacted / deleted | app/conversation/conversation.go:285/386/418/440/463 |
| document(4) | created×2(单建/树导入)/ updated / moved | app/document/document.go:124/232/313/402 |
| memory(1) | updated(pin 回声源——调用点级拆径,顺手解决「一词双源」) | app/memory/memory.go:148 |
| handler(1) | restarted(ok:true,纯按钮成功回执) | app/handler/crud.go:281 |
| sandbox(2) | env_status_changed(installing)/ env_deleted | app/sandbox/sandbox.go:429/501 |

## D. 设计规范

### D.1 托盘(左岛铃接管,壳已有)

```
┌──────────────────────────────┐
│ 通知                    全部已读 │  托盘头:标题 + mark-all 文字钮
├──────────────────────────────┤
│ 待你处理                    (2) │  段1:actionable(FlowrunInbox 融入;approval 待决卡,批完自动消)
│ ⏸ 部署流水线 · 等待审批     2m │
├──────────────────────────────┤
│ 今天                           │  段2:通知时间流,sticky 轻节头(今天/昨天/更早)
│ ● ⚠ handler「值班」崩溃了   5m │  未读:行首点 + 宾语 w400
│   ✎ AI 更新了记忆「偏好」    2h │  已读:全灰无点、留列表(审计流不蒸发)
└──────────────────────────────┘
```

- **行解剖**(32px 单行):`未读点 · 类型图标(AnIcons 按事件族) · 主语+动词+宾语(宾语 w400、余 w300) · 相对时间(fmtWaitedSince,core 已有)`;hover 时间换动作组(已读/未读往返 + ⋯)。**主语必写**(哪个 agent/调度器/你)——agentic app 里「谁干的」是行的灵魂。
- **已读语义**(四家一致标准):开托盘**绝不**自动清未读;点行 = 深链(`panelLocationFor`,无面板 kind 渲惰性行绝不放死链)+ 顺手 mark-read;误读可 hover 回退 unread(注:后端无 mark-unread 端点——v1 已读钮单向,回退排 gap);「全部已读」一键。已读灰显留列表。
- **铃徽标**:数字(封顶 99+),= `unread-count`(N0 分径后天然只数 important+semi);配 Semantics 文本等价物;归零即无。
- **i18n 模板策略**:后端不产文案 → 前端 `type → 模板` 两层:①动词模板 × 实体 kind 显示名拼装(`{kind}「{name}」已创建/已编辑/已删除…`,覆盖 semi 大盘)②important 7 个专属文案 ③未知 type 通用兜底(直显 type,不崩)。payload 取键全部防御性(`?? ''`)。
- **与 rail 状态点分工**(一事一面,防红点疲劳):会话级状态(生成中/等你/未读)归 chat rail 三色点;托盘只收「会话之外」的系统事件。conversation.* 全族仅帧径,物理上进不了托盘,分工由 N0 结构性保证。

### D.2 悬浮 toast(右上,单 host 全体迁移)

```
┌────────────────────────────────┐
│ ▌⚠ workflow「日报」运行失败      ✕ │  danger 常驻(手动关/点击跳转才消)
├────────────────────────────────┤
│ ▌⏸ 「部署」等待你审批    [去审批] ✕ │  常驻 + 单 action
├────────────────────────────────┤
│ ▌✕ 执行失败 ×3 · flowrun「同步」  │  风暴合并:同 key 更新计数不新弹
└────────────────────────────────┘
   右上堆叠:新条顶部插入、旧条下推;≤3 可见,溢出折叠「+N」
```

- **锚点迁移**:`AnOverlayHost` toast 层 `Positioned(right, bottom)` → `(right, top)`(避开浮层头:top 偏移 = 头高 + s24);`_AnToastLayer` 堆叠方向反转(newest at TOP、`VerticalDirection.down`);**既有动作回报 toast 一并受益,零调用方改动**。gallery specimen + 既有 host 测试同步更新。
- **阈值**:只 important 弹(§C 红档 7 个;`attention_changed` 仅 needsAttention=true 弹);semi 静默进托盘。
- **时长**:ok/info 5s · warn 8s · **danger/待决常驻**(错误 toast 自动消失=丢通知,Carbon 铁律);带 action 一律常驻。
- **hover 暂停消隐**(WCAG 2.2.1):`AnToast` 地基强化——现固定 Timer,加 MouseRegion 进入暂停/离开重启(全产品受益)。
- **风暴合并**:`ToastDispatcher`(core,纯 Dart Notifier 可单测,BlockTreeReducer 同款先例)按 `(entityId, eventKind)` coalesce——同 key 活跃 toast 存在期内只更新计数与时间戳(「×N」),不新弹。**合并只在派发器、绝不进 SSE gateway**(gateway 铁律不过滤;托盘要逐条真相)。
- **点击** = go_router 深链 + 消该条;action 最多 1 个;右上 hover 显 ✕。托盘 DB 行即 WCAG 兜底(toast 只是投影,错过了铃里找得回)。
- **溢出**:≤3 可见,更旧折叠成「+N」条(点击展开栈或开铃托盘,N3 细节定)。cap 从 5 调 3。

### D.3 OS 原生通知(v1,app 未聚焦时)

- **选型**(已核实):`flutter_local_notifications`(v22,verified,活跃,macOS `UserNotifications` / Linux DBus spec / Windows WinRT 三桌面全覆盖)。`local_notifier` 停更 2 年不选。
- **分工判定**:**dispatch 单点做、以派发时刻焦点快照为准**(防双弹/都不弹竞态)——聚焦 → in-app toast;未聚焦 → OS 通知(payload 带同一 go_router location,点击回 app 复用同一跳转)。焦点经 `AppLifecycleState`/window_manager,不轮询 `isFocused`(Windows 已知不可靠),不确定时保守当未聚焦。
- **阈值同 toast**(important-only);OS 侧不做风暴合并 v1(量小,交给系统 stack)。
- **坑(已核)**:macOS 对签名敏感——unsigned dev bundle `UNErrorDomain Code=1` **静默失败**;首用 `requestPermissions`;**通知相关集成测试不入 fe-verify**(无签名 CI 必红),真机验证走签名 build(与 WRK-043 发行 playbook 的 Developer ID 链路汇合);Linux `getCapabilities()` 探测降级;Windows 非 MSIX 无 cancel/检索(接受)。

## E. 前端底盘(普查核实:复用 vs 净新)

**全部现成**:SSE 三流常驻 + `rawStream(StreamName.notifications)`(注释明写留给通知中心)+ 410 resync 缝;`ConversationSignal`/`EntitySignal`/documents 三个 fromEnvelope 投影样板;托盘壳三件(`notificationsOpenProvider` 接管左岛中段 / `AnSidebarFooter` 铃格[unreadCount 硬编 0 待接] / app_shell `_NotificationsTray` 现= `FlowrunInbox`);`AnToast`+`AnOverlayController.showToast`(context-free)+`AnOverlayHost`(app/demo/gallery 三入口全挂);`AnRailStates` 空态 / `fmtWaitedSince`(core/model/time_format.dart,零上提)/ `panelLocationFor` 深链 / `KeysetQueryPaging` / `AnBadge` / repository Live+Fixture+override 拓扑。

**净新**:`core/contract/notification.dart` DTO;`NotificationRepository`(Live/Fixture);`NotificationSignal` 投影器(第四个 fromEnvelope——唯一消费「通知行本体」的);`unreadCountProvider`;通知行原语 + 两段式托盘;`ToastDispatcher`;`AnToast` hover-pause;OS 通知接入;i18n `notifications` 节。

## F. 建造阶梯(每步照 hub §2.2 流水线:gallery-first → 拍板长相 → 五电池 → 真机截图)

| 步 | 内容 | 状态 |
|---|---|---|
| **N0 后端分径** | Emitter 加 `Broadcast`(仅帧不落行)与 `Emit`(落行+帧)并列;18 boring 调用点换径——conversation 全族(单 helper flip)· document created/updated/moved(deleted 留 Emit)· memory pin 回声(`notifyFrame`,与内容写共用 "memory.updated" 词故调用点分流)· handler.restarted ok:true(`publishFrame`)· sandbox installing/env_deleted(publishEnv 按 `env.Status` 分)。帧仍 durable(reconnect 补得回)、临时 `noti_` id 锚定、线缆帧形与 Emit 一致。文档三处同步(events.md ⊞/⤳ 两档表 · support-services.md · database.md);单测(notification app Broadcast×3 + conversation/memory 仅帧断言 + 4 fake 补 Broadcast)+ **testend `TestNotification_FrameOnlyFork`**(流有帧/list 无行)+ ripple 按 kind 分 created/deleted 断言。**真后端 E2E 亲验**:conversation.created 只上流不落 list · function.created 流+行都在 · sandbox 一类型 2 帧上流(installing+ready)但 1 行落库(ready)——细粒度按状态分径成立。`make verify` 全绿。 | ✅ |
| **N1 契约+数据缝** | ✅ `core/contract/notification.dart`(`NotificationItem`:id/type/payload/readAt?/createdAt + domain·action·isUnread 读派生)· `NotificationRepository`(Live over ApiClient+SseGateway / `FixtureNotificationRepository` 内存+脚本化 emit/emitEcho/emitResync)· `NotificationSignal` 投影器 · `unreadCountProvider`(AsyncNotifier)。**关键设计裁决**:N0 后流上 Emit(落行)/Broadcast(仅帧)帧形一致、且 `memory.updated`(pin 仅帧 vs 内容落行)同 type 同 payload 不可分 → 前端**不能靠 type 判是否有新收件箱行**,真相唯 REST `unread-count`。故 unreadCount **从不据帧 +1**,而是「inbox-worthy durable tick → 去抖 refetch 权威 COUNT / 410 立即重读 / 本地 mark 乐观扣减」;`inboxCandidate` 是纯性能过滤(滤掉确定仅帧的 conversation.*/document 树刷新,歧义 type 留候选免漏真行)。18 单测全绿(DTO 4 + signal 6 + fixture 5 + unreadCount 5[含 non-candidate 回声不 refetch 的 call-count 证明])。契约 reference 同步。 | ✅ |
| **N2 托盘** | 通知行原语 + 两段式托盘 gallery specimen(未读/已读/hover/空态/节头/mark-all)→ 拍板 → 接壳(铃徽标真数 + FlowrunInbox 融入段1)+ i18n 模板表 | ⏳ |
| **N3 toast** | host 右上迁移(全体)+ AnToast hover-pause 地基强化 + ToastDispatcher(coalesce/cap3/溢出/时长分级)+ gallery 动效 GIF + demo 风暴演示 | ⏳ |
| **N4 OS 通知** | flutter_local_notifications 接入 + 焦点快照分工 + 深链 payload + macOS 签名 build 真机验证(不入 fe-verify) | ⏳ |
| **N5 组装收尾** | demo fixture 种满各档通知 + 五电池 + 真机截图全流程(收帧→toast→托盘→深链→已读→badge 归零)+ landed-into | ⏳ |
