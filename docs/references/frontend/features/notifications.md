---
id: DOC-050
type: reference
status: active
owner: @weilin
created: 2026-07-07
reviewed: 2026-07-07
review-due: 2026-10-05
audience: [human, ai]
---

# Feature:Notifications(通知中心 + 悬浮 toast)—— 当前形态

> 左岛铃的两段式托盘 + 右上悬浮 toast + OS 原生通知,端到端落成。本篇 = **它现在是什么样**;**怎么一步步建的**(调研/词表台账/N0–N5 阶梯/决策)看建造账 [`WRK-058`](../../../archive/notifications/README.md);**DTO** 看 [`contract.md`](../contract.md);后端分径契约看 [`events.md`](../../backend/events.md) ⊞/⤳。

## 一句话

一个替你值守后台的收件箱:agent / workflow / 调度器在你不看时干了什么、坏了什么、等你什么——重要的当场**右上 toast**(app 未聚焦则走 **OS 原生通知**),半重要的进**左岛铃托盘**攒着,铃上红点,拉开一眼扫完,点一行跳到现场。

## 后端分径(N0,通知的地基)

`notificationapp.Emitter` 分两档 durable 信号(见 [`events.md`](../../backend/events.md) ⊞/⤳):**Emit** = 落收件箱行 + 推帧(失败 / AI 干的实体生命周期,值得事后找到);**Broadcast** = 只推帧不落行(高频对账回声:conversation.* 全族 / document 树刷新 / memory pin / handler 重启成功 / sandbox installing——进收件箱即噪音,其真相是实体自身状态)。**实体生命周期通知 payload 带 `name`**(N2a),故通知中心能渲「Agent『triager』已创建」而非仅 ID。

## 铃托盘 = 左岛 rail 架构（0719 重造）

铃接管态的托盘照**左岛 rail 同一套架构与原语**重建（`features/notifications/ui/notification_tray.dart` 的 `NotificationTray`）——常驻 `AnRailFilterField`（搜索「搜索通知…」 + ⚙ 显示菜单）在顶，下接**可折叠组**滚动体。**退役 chrome**：旧的「Notifications」标题、`AnDivider` 分割线、顶部「全部已读」钮**全部去掉**，其功能并入组头 ⋯ 菜单。

- **搜索**过滤 feed 内容（匹配渲染后的行文本 lead+name+trail+detail）；**⚙ 显示菜单** = 「仅显示未读」toggle（`keepOpen`）。
- **组结构**（`AnGroupHead`，唯一大组头原语，`padding` 左缘单源 12）：`待你处理`（注入的审批带）→ `今天`/`昨天`/`更早`（feed 时段桶，每组只在有行时出现）。每组可折叠（整头 toggle）；有 query 时强制全展开。
- **跨 feature 组合**：`app_shell._NotificationsTray` = `NotificationTray(approvalsBand: FlowrunInbox(sectioned: true))`——托盘持 rail chrome，app 壳**注入**「待你处理」带（entities feature 件，非 import），features 保持独立。搜索激活时藏 band（审批非「通知内容」）。

## 四个面

| 面 | 在哪 | 是什么 |
|---|---|---|
| **通知行(建材)** | `features/notifications/ui/notification_row.dart` + `notification_copy.dart` | `NotificationRow` 纯展示件:`tone 图标 · {类}「{名}」{动词} · 相对时间` + 可选灰详情行(错误/依赖名)。**已读律(0719)**:**整行褪色是未读/已读唯一通道——无行首未读点**(`● ⚠`→`⚠`);kind/tone 图标=**唯一 lead 记号**(色管严重度:warn 琥珀 / danger 红)。未读=彩图标 + 墨字名(w400);已读=整行退 inkFaint、**留列表**(审计流)。hover=圆角灰块(`AnRadius.button`=8)+ 未读时换 mark-read 钩。文案 `notificationLine(item, t)`:后端不产文案故前端拥有 type→句子——compositional 生命周期(kind lead + 强调 name + verb)+ 重要 7 类 bespoke(danger/warn + detail)+ payload 分支(reconnected 按 status / attention 点亮·熄灭 / sandbox failed·ready / **`relation.dependency_broken` 标准主语句**见下)+ 未知 type 诚实兜底;`notificationLocation` 经 `panelLocationFor` 深链(无面板 kind 惰性、绝不死链)。三档 tone:neutral 灰 / warn 琥珀 / danger 红。 |
| **通知 feed(托盘下段)** | `NotificationTray` | 时段分组(今天/昨天/更早,各 `AnGroupHead` 可折叠 + ⋯ 菜单)+ 逐行 `NotificationRow`(点=深链 + 顺手已读 / hover=mark-read)+ 空态(收起形、无墓碑)+ 无限下滑。**组头 ⋯ 菜单**(有未读才显)= 「全部已读」——**作用于全部通知**(一本账,逐组已读语义怪;用户 0719 定调),即退役顶钮的新家。 |
| **待你处理(托盘上段)** | `features/entities/ui/flowrun_inbox.dart`(`sectioned` 模式) | 跨 run 审批收件箱作托盘首组:无待决则塌成空、有则可折叠 `AnGroupHead`「待你处理」+ `AnExpandReveal` 审批卡叠(`ApprovalGate`,共件化)。**组头 ⋯ 批量菜单** = 「全部批准 / 全部拒绝(danger)」——**走 Overview 批量引擎同款**(`overlay.confirm` 点名每一项的确认弹窗 + 逐条 `decideApproval` 挂账 ok/lost-422/failed + 诚实汇总 toast 取最坏 tone + 重取;**绝不裸批**)。**星号 bug 修**:审批问题句(`result['rendered']`,如 `Deploy **v2.4.0** …`)经 `AnMarkdown(scale: embedded)` 渲、**粗为粗**不再字面星号。 |
| **悬浮 toast(右上)** | `core/overlay/an_overlay.dart` + `features/notifications/state/toast_dispatcher.dart` | `AnOverlayHost` 锚**右上**(避开 macOS chrome 带,newest 顶插、cap 3);`AnToast` **hover 暂停消隐**(WCAG 2.2.1)。`ToastDispatcher`(core 事件→toast 桥):听流、只为 important(渲染 tone warn/danger)弹、neutral 静默归托盘;tone 定时长(danger 常驻/warn 8s)+「查看」深链;`(type,entityId)` 去抖窗吞风暴;**coalesce 只在 dispatcher 绝不进 gateway**。**焦点路由**(N4):派发时刻焦点快照——聚焦→toast / **未聚焦→OS 原生通知**。 |

## relation 句式归队（0719）

`relation.dependency_broken` 旧渲成无主语的「left 2 references dangling」。现按**标准主语句**：被删实体作主语（`deletedKind` 作 kind lead + `deletedId` 作 name），trail = 「删除后留下 N 处悬空引用 / was deleted, leaving N references dangling」，被依赖者进灰详情行。**按 id 命名而非 name**：发通知时实体已被 `PurgeEntity` 抹除（见 [`relation.md`](../../backend/domains/relation.md) / `events.md`），其显示名不再可解——后端 payload 只带 `deletedId`、无 `deletedName`，故前端用 id。i18n 双表 `notifications.depBrokenOne/Many`。

## OS 原生通知(N4)

`OsNotifier` 端口(DIP):`NoopOsNotifier`(默认——测试/gallery/demo 绝不发真通知)+ `LocalOsNotifier`(`flutter_local_notifications` v22:macOS UserNotifications / Linux DBus / Windows WinRT;点击深链回 app 复用同一 go_router)。`appFocusedProvider`(`AppLifecycleState` 驱动,默认聚焦)。真 app 根 override 成 Local 并在 dispatcher build 一次性 init。**macOS 签名**:unsigned dev bundle 静默失败(UNErrorDomain Code=1),真投递只在签名 build 验证(WRK-043 Developer ID),故通知集成不入 fe-verify(macOS debug build 已验证原生集成编译链接通过)。

## 数据缝 + state

- **唯一缝** `NotificationRepository`(`features/notifications/data/`):`LiveNotificationRepository`(`ApiClient` + `SseGateway`)/ `FixtureNotificationRepository`(内存 + 脚本化 emit/emitEcho/emitResync)/ `notificationRepositoryProvider` 单点 override。面:`listNotifications`(keyset)/ `markRead`/`markAllRead`/`unreadCount`(权威 COUNT)/ `signals`(实时 nudge)/ `resync`(410)。
- **`NotificationSignal` 投影器**:notifications 流一帧的语义投影(type + durable + `inboxCandidate` + payload)。**关键裁决**:N0 后流上 Emit(落行)/Broadcast(仅帧)帧形一致、且 `memory.updated`(pin 仅帧 vs 内容落行)同 type 同 payload **不可分** → 前端**绝不能靠 type 判是否有新收件箱行**。故:`unreadCountProvider` **从不据帧 +1**,而是 inbox-worthy durable tick 去抖 **refetch 权威 COUNT** / 410 立即重读 / 本地 mark 乐观扣减;`inboxCandidate` 是纯**性能**过滤(滤确定仅帧的 conversation.*/document 树刷新,歧义 type 留候选免漏真行、代价=一次对账 refetch)。
- **state**(`features/notifications/state/`):`unreadCountProvider`(AsyncNotifier,铃徽标真相)· `notificationFeedProvider`(AsyncNotifier + `KeysetQueryPaging`:首页 + inbox-worthy tick 去抖并首 refetch + 410 重翻 + markRead/All 乐观)· `toastDispatcherProvider`(事件→toast,app_shell eager watch 保活)· `appFocusedProvider`(焦点信号)。
- **DTO** `core/contract/notification.dart` `NotificationItem`(id/type/payload/readAt?[null=未读]/createdAt + domain·action·isUnread 读派生),只投影 Emit 落行档。
- **shell 接线**:`app_shell._NotificationsTray` = `NotificationTray(approvalsBand: FlowrunInbox(sectioned: true))`(托盘持 rail chrome、app 壳注入审批带);铃徽标接 `unreadCountProvider`(footer 28px 铃格红点,非数字)。

## 状态

✅ **全落**:N0(后端分径 Emit/Broadcast + mcp 补 status)→ N1(契约数据缝 + Signal + unreadCount)→ N2(N2a 后端补名字 + N2b 行原语·文案 + N2c 托盘接壳)→ N3(toast 迁右上 + hover 暂停 + 事件→toast 派发器)→ N4(OS 原生通知 DIP + 焦点路由)。**0719 托盘重造**:铃托盘照左岛 rail 架构重建(`NotificationTray`:搜索 + ⚙ 菜单 + 可折叠 `AnGroupHead` 组 + 组头 ⋯ 批量/已读菜单)+ 已读律(整行褪色唯一通道、退未读点)+ relation 句式归队 + 审批问题句嵌入档 markdown 修星号 bug;上收两原语 `AnGroupHead`/`AnRailFilterField`。`make verify`(后端)+ `make fe-verify`(前端)+ macOS debug build 全绿。真壳 E2E 截图 + 右上 toast 截图肉眼核对。
