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

# Feature:Notifications(通知中心 + 顶带胶囊)—— 当前形态

> 左岛铃的两段式托盘 + 顶带通知胶囊 + OS 原生通知,端到端落成。本篇 = **它现在是什么样**;**怎么一步步建的**(调研/词表台账/N0–N5 阶梯/决策)看建造账 [`WRK-058`](../../../archive/notifications/README.md);**DTO** 看 [`contract.md`](../contract.md);后端分径契约看 [`events.md`](../../backend/events.md) ⊞/⤳。

## 一句话

一个替你值守后台的收件箱:agent / workflow / 调度器在你不看时干了什么、坏了什么、等你什么——重要的当场**顶带胶囊**(app 未聚焦则走 **OS 原生通知**),半重要的进**左岛铃托盘**攒着,铃上红点,拉开一眼扫完,点一行跳到现场。

## 后端分径(N0,通知的地基)

`notificationapp.Emitter` 分两档 durable 信号(见 [`events.md`](../../backend/events.md) ⊞/⤳):**Emit** = 落收件箱行 + 推帧(失败 / AI 干的实体生命周期,值得事后找到);**Broadcast** = 只推帧不落行(高频对账回声:conversation.* 全族 / document 树刷新 / memory pin / handler 重启成功 / sandbox installing——进收件箱即噪音,其真相是实体自身状态)。**实体生命周期通知 payload 带 `name`**(N2a),故通知中心能渲「Agent『triager』已创建」而非仅 ID。

## 铃托盘 = 左岛 rail 架构（0719 重造）

铃接管态的托盘照**左岛 rail 同一套架构与原语**重建（`features/notifications/ui/notification_tray.dart` 的 `NotificationTray`）——常驻 `AnRailFilterField`（搜索「搜索通知…」 + ⚙ 显示菜单）在顶，下接**可折叠组**滚动体。**退役 chrome**：旧的「Notifications」标题、`AnDivider` 分割线、顶部「全部已读」钮**全部去掉**，其功能并入组头 ⋯ 菜单。

- **搜索**过滤 feed 内容（匹配渲染后的行文本 lead+name+trail+detail）；**⚙ 显示菜单** = 「仅显示未读」toggle（`keepOpen`）。
- **组头 = `AnRow`（1:1 chat rail 的 Pinned/Recents 头，0719 重造）**：每个组头就是**核心行原语** `AnRow`——**最左箭头常驻**（无图标 collapsible → 披露 chevron 是永久 lead、`open` 旋 90°、无 hover 互换）、**最右数字**（`meta`=计数）**hover 换 ⋯**（`AnRow` 的 meta↔actions 同锚互换白给）、**圆角 hover 块**（非直角）、**整行点击折叠**（`onSelect`+`onToggle` 双绑）。**几何 = chat 左岛 rail 律**（0719 用户复验「右退一格 / hover 块两边各小一块」修）：组头**裸放**（无外层水平 padding）——岛已给 s12 沟，故 `AnRow` hover 块**吃满岛内宽**（块边落岛内缘）、chevron/数字落 rail 的 **s8 内容内距**；`NotificationRow` 内容内距同步 s12→**s8**、审批卡水平内距去掉（卡边=hover 块线）。四者（搜索放大镜 / 组头 chevron / 行图标 / 卡边）与彼此**逐像素同竖线**，废弃托盘曾自立的「12 左缘单源 +s4」约定。**收起态无残留灰**：`AnRow` 底色 = `surfaceHover.whenActive(active)`（active=hover/press/focus），静息/收起（鼠标不悬停）态透明——修「收起后还是灰色」bug（旧 `AnGroupHead` 的病）。
- **折叠/展开 = 左岛 rail 同一套滑动**（0719 用户复验「展开收起的效果丢了」补）：feed 头+行持在 `_flat`、与 `SliverAnimatedList`（GlobalKey）锁步——**用户 toggle** 按 `AnSidebarList._toggle` 同配方对该桶连续行区间 `removeItem`/`insertItem`（行包 `SizeTransition(sizeFactor, axisAlignment -1)` 顶锚 + 时长 `AnMotion.mid`、reduced→`Duration.zero`），真滑动、非瞬跳；chevron 的旋转与滑动同步。**数据/过滤变**（feed 刷新/loadMore/mark-read/搜索/仅未读）→ 换新 `GlobalKey` 整重建、不插删动画（补间只给 toggle）。判据用 **`listEquals` 结构比对**（非 rows 身份）——feed provider 会递「新身份、等价内容」的 list，身份比对会误换 key 打断滑动。「待你处理」band 是**独立首 sliver**（不在被换 key 的动画列表里），其 `AnExpandReveal` 动画与状态不随 feed churn 重置。
- **组结构**：`待你处理`（注入的审批带，独立首 sliver）→ `今天`/`昨天`/`更早`（feed 时段桶，每组只在有行时出现）。每组可折叠（整头 toggle）；有 query 时强制全展开。
- **跨 feature 组合**：`app_shell._NotificationsTray` = `NotificationTray(approvalsBand: FlowrunInbox(sectioned: true))`——托盘持 rail chrome，app 壳**注入**「待你处理」带（entities feature 件，非 import），features 保持独立。搜索激活时藏 band（审批非「通知内容」）。

## 四个面

| 面 | 在哪 | 是什么 |
|---|---|---|
| **通知行(建材)** | `features/notifications/ui/notification_row.dart` + `notification_copy.dart` | `NotificationRow` 纯展示件:`tone 图标 · {类}「{名}」{动词} · 相对时间` + 可选灰详情行(错误/依赖名)。**已读律(0719)**:**整行褪色是未读/已读唯一通道——无行首未读点**(`● ⚠`→`⚠`);kind/tone 图标=**唯一 lead 记号**(色管严重度:warn 琥珀 / danger 红)。未读=彩图标 + 墨字名(w400);已读=整行退 inkFaint、**留列表**(审计流)。hover=圆角灰块(`AnRadius.button`=8)+ 未读时换 mark-read 钩。文案 `notificationLine(item, t)`:后端不产文案故前端拥有 type→句子——compositional 生命周期(kind lead + 强调 name + verb)+ 重要 7 类 bespoke(danger/warn + detail)+ payload 分支(reconnected 按 status / attention 点亮·熄灭 / sandbox failed·ready / **`relation.dependency_broken` 标准主语句**见下)+ 未知 type 诚实兜底;`notificationLocation` 经 `panelLocationFor` 深链(无面板 kind 惰性、绝不死链)。三档 tone:neutral 灰 / warn 琥珀 / danger 红。 |
| **通知 feed(托盘下段)** | `NotificationTray` | 时段分组(今天/昨天/更早,各组头 = `AnRow` 可折叠 + hover ⋯ 菜单)+ 逐行 `NotificationRow`(点=深链 + 顺手已读 / hover=mark-read)+ 空态(收起形、无墓碑)+ 无限下滑。**组头 ⋯ 菜单**(骑 `AnRow` 的数字↔hover ⋯ 槽)= 「全部已读」+「全部未读」——**均作用于全部通知**(一本账,逐组已读语义怪;用户 0719 定调),退役顶钮的新家。**两项恒在且幂等**:分页 feed 窗口无法权威回答「是否存在已读行」,门控会撒谎;退化态(全已读点已读 / 全未读点未读)是无害 no-op。全部未读 = mark-all-read 的镜像(后端 `POST /notifications:mark-all-unread`,清全部 read_at),按 N0 **重取权威 unread-count 对账**(未读数非已知常量、不可本地臆造)。 |
| **待你处理(托盘上段)** | `features/entities/ui/flowrun_inbox.dart`(`sectioned` 模式) | 跨 run 审批收件箱作托盘首组:无待决则塌成空、有则可折叠 `AnRow`「待你处理」头(同款 rail 原语)+ `AnExpandReveal` 审批卡叠(`ApprovalGate`,共件化)。**组头 hover ⋯ 批量菜单** = 「全部批准 / 全部拒绝(danger)」(`_bulkBusy` 时同槽换 spinner)——**走 Overview 批量引擎同款**(`overlay.confirm` 点名每一项的确认弹窗 + 逐条 `decideApproval` 挂账 ok/lost-422/failed + 诚实汇总 toast 取最坏 tone + 重取;**绝不裸批**)。**星号 bug 修**:审批问题句(`result['rendered']`,如 `Deploy **v2.4.0** …`)经 `AnMarkdown(scale: embedded)` 渲、**粗为粗**不再字面星号。 |
| **顶带通知胶囊** | `core/ui/an_notice_capsule.dart` + `features/notifications/state/notice_capsule_provider.dart` + `toast_dispatcher.dart` | **事件通知唯一浮层**(用户 0720 拍板:右上事件 toast 退役,浮层降级为例外——右上 `AnOverlayHost` 仍服务**操作反馈** showToast)。胶囊=白岛药丸住 `AnShell.bandNotice` 顶带中段槽(带高即 chrome,**永不盖工作内容/不顶布局**):tone 点(danger 红/warn 琥珀)+kind 图标+一句话+灰「查看」尾;自驱生命周期(淡入下滑 mid→停 `AnMotion.toast` hover 暂停 WCAG→淡出缩回 slow),点击深链、宿主出队递补;队列有界(cap 5,保在显头+最新尾)。**严重度分层**:danger→胶囊;warn(默认级)**不浮**——铃红点(权威 unread-count 驱动)即其呈现;`all` 级 warn/中性也弹;S1 应用内开关同闸,danger 穿透。`(type,entityId)` 去抖窗吞风暴;**焦点路由**不变:未聚焦→OS 原生通知。 |

## relation 句式归队（0719）

`relation.dependency_broken` 旧渲成无主语的「left 2 references dangling」。现按**标准主语句**：被删实体作主语（`deletedKind` 作 kind lead + `deletedId` 作 name），trail = 「删除后留下 N 处悬空引用 / was deleted, leaving N references dangling」，被依赖者进灰详情行。**按 id 命名而非 name**：发通知时实体已被 `PurgeEntity` 抹除（见 [`relation.md`](../../backend/domains/relation.md) / `events.md`），其显示名不再可解——后端 payload 只带 `deletedId`、无 `deletedName`，故前端用 id。i18n 双表 `notifications.depBrokenOne/Many`。

## OS 原生通知(N4)

`OsNotifier` 端口(DIP):`NoopOsNotifier`(默认——测试/gallery/demo 绝不发真通知)+ `LocalOsNotifier`(`flutter_local_notifications` v22:macOS UserNotifications / Linux DBus / Windows WinRT;点击深链回 app 复用同一 go_router)。`appFocusedProvider`(`AppLifecycleState` 驱动,默认聚焦)。真 app 根 override 成 Local 并在 dispatcher build 一次性 init。**macOS 签名**:unsigned dev bundle 静默失败(UNErrorDomain Code=1),真投递只在签名 build 验证(WRK-043 Developer ID),故通知集成不入 fe-verify(macOS debug build 已验证原生集成编译链接通过)。

## 数据缝 + state

- **唯一缝** `NotificationRepository`(`features/notifications/data/`):`LiveNotificationRepository`(`ApiClient` + `SseGateway`)/ `FixtureNotificationRepository`(内存 + 脚本化 emit/emitEcho/emitResync)/ `notificationRepositoryProvider` 单点 override。面:`listNotifications`(keyset)/ `markRead`/`markAllRead`/`unreadCount`(权威 COUNT)/ `signals`(实时 nudge)/ `resync`(410)。
- **`NotificationSignal` 投影器**:notifications 流一帧的语义投影(type + durable + `inboxCandidate` + payload)。**关键裁决**:N0 后流上 Emit(落行)/Broadcast(仅帧)帧形一致、且 `memory.updated`(pin 仅帧 vs 内容落行)同 type 同 payload **不可分** → 前端**绝不能靠 type 判是否有新收件箱行**。故:`unreadCountProvider` **从不据帧 +1**,而是 inbox-worthy durable tick 去抖 **refetch 权威 COUNT** / 410 立即重读 / 本地 mark 乐观扣减;`inboxCandidate` 是纯**性能**过滤(滤确定仅帧的 conversation.*/document 树刷新,歧义 type 留候选免漏真行、代价=一次对账 refetch)。
- **state**(`features/notifications/state/`):`unreadCountProvider`(AsyncNotifier,铃徽标真相)· `notificationFeedProvider`(AsyncNotifier + `KeysetQueryPaging`:首页 + inbox-worthy tick 去抖并首 refetch + 410 重翻 + markRead/All 乐观)· `toastDispatcherProvider`(事件→胶囊桥,_SessionServices postFrame 点火保活)· `noticeCapsuleProvider`(顶带胶囊队列)· `appFocusedProvider`(焦点信号)。
- **DTO** `core/contract/notification.dart` `NotificationItem`(id/type/payload/readAt?[null=未读]/createdAt + domain·action·isUnread 读派生),只投影 Emit 落行档。
- **shell 接线**:`app_shell._NotificationsTray` = `NotificationTray(approvalsBand: FlowrunInbox(sectioned: true))`(托盘持 rail chrome、app 壳注入审批带);铃徽标接 `unreadCountProvider`(footer 28px 铃格红点,非数字)。

## 状态

✅ **全落**:N0(后端分径 Emit/Broadcast + mcp 补 status)→ N1(契约数据缝 + Signal + unreadCount)→ N2(N2a 后端补名字 + N2b 行原语·文案 + N2c 托盘接壳)→ N3(toast 迁右上 + hover 暂停 + 事件→toast 派发器)→ N4(OS 原生通知 DIP + 焦点路由)。**0719 托盘重造**:铃托盘照左岛 rail 架构重建(`NotificationTray`:搜索 + ⚙ 菜单 + 可折叠 `AnGroupHead` 组 + 组头 ⋯ 批量/已读菜单)+ 已读律(整行褪色唯一通道、退未读点)+ relation 句式归队 + 审批问题句嵌入档 markdown 修星号 bug;上收两原语 `AnGroupHead`/`AnRailFilterField`。**0719 组头 1:1 归位左岛原语(用户否决后重造)**:托盘/铃组头从被否决的 `AnGroupHead`(label 最左·⋯ 常驻·直角灰底)**换成 `AnRow`**(最左箭头常驻 + 最右数字 hover 换 ⋯ + 圆角 hover 块 + 整行折叠,与 chat rail Pinned/Recents 头 1:1);修「收起后还是灰色」bug(`AnRow` 静息态透明);组头 ⋯ 补「全部未读」(新键 `notifications.markAllUnread` 双 locale + 后端镜像端点 `POST /notifications:mark-all-unread`);**`AnGroupHead` 物理退役**(删原语 + gallery 样章 + `SidebarGroup.label`/`collapsible`/`totalRows`/`SidebarNodeKind.groupHead`/flatten 分支——全仓核实唯 gallery/测试消费、5 个生产 rail 皆 label-less)。`make verify`(后端)+ `make fe-verify`(前端)+ macOS debug build 全绿。真壳 E2E 截图 + 右上 toast 截图肉眼核对。
