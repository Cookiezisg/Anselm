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

## 四个面

| 面 | 在哪 | 是什么 |
|---|---|---|
| **通知行(建材)** | `features/notifications/ui/notification_row.dart` + `notification_copy.dart` | `NotificationRow` 纯展示件:`未读点 · tone 图标 · {类}「{名}」{动词} · 相对时间` + 可选灰详情行(错误/依赖名)。已读整行灰、无点、**留列表**(审计流);hover=标准 `AnHoverSurface` 圆角灰块(圆角 `AnRadius.button`=8,与各可悬列表行一致、非裸方框)+ 未读时换 mark-read 钩。文案 `notificationLine(item, t)`:后端不产文案故前端拥有 type→句子——compositional 生命周期(kind lead + 强调 name + verb)+ 重要 7 类 bespoke(danger/warn + detail)+ payload 分支(reconnected 按 status / attention 点亮·熄灭 / sandbox failed·ready / dependency 计数+被依赖名)+ 未知 type 诚实兜底;`notificationLocation` 经 `panelLocationFor` 深链(无面板 kind 惰性、绝不死链)。三档 tone:neutral 灰 / warn 琥珀 / danger 红。 |
| **通知 feed(托盘下段)** | `features/notifications/ui/notification_feed.dart` | 「通知」头 + **全部已读**(有未读才显)+ 时间分组(今天/昨天/更早 sticky 段头)+ 逐行 `NotificationRow`(点=深链 + 顺手已读 / hover=mark-read)+ 空态(都处理完了)+ 无限下滑。 |
| **待你处理(托盘上段)** | `features/entities/ui/flowrun_inbox.dart`(`sectioned` 模式) | 跨 run 审批收件箱融入托盘顶:无待决则塌成空、有则「待你处理」头 + 不滚动卡叠(feed 独占滚动)。`app_shell` 装配层组合两段(一件属 entities、一件属 notifications feature,故 app 层组合)。 |
| **悬浮 toast(右上)** | `core/overlay/an_overlay.dart` + `features/notifications/state/toast_dispatcher.dart` | `AnOverlayHost` 锚**右上**(避开 macOS chrome 带,newest 顶插、cap 3);`AnToast` **hover 暂停消隐**(WCAG 2.2.1)。`ToastDispatcher`(core 事件→toast 桥):听流、只为 important(渲染 tone warn/danger)弹、neutral 静默归托盘;tone 定时长(danger 常驻/warn 8s)+「查看」深链;`(type,entityId)` 去抖窗吞风暴;**coalesce 只在 dispatcher 绝不进 gateway**。**焦点路由**(N4):派发时刻焦点快照——聚焦→toast / **未聚焦→OS 原生通知**。 |

## OS 原生通知(N4)

`OsNotifier` 端口(DIP):`NoopOsNotifier`(默认——测试/gallery/demo 绝不发真通知)+ `LocalOsNotifier`(`flutter_local_notifications` v22:macOS UserNotifications / Linux DBus / Windows WinRT;点击深链回 app 复用同一 go_router)。`appFocusedProvider`(`AppLifecycleState` 驱动,默认聚焦)。真 app 根 override 成 Local 并在 dispatcher build 一次性 init。**macOS 签名**:unsigned dev bundle 静默失败(UNErrorDomain Code=1),真投递只在签名 build 验证(WRK-043 Developer ID),故通知集成不入 fe-verify(macOS debug build 已验证原生集成编译链接通过)。

## 数据缝 + state

- **唯一缝** `NotificationRepository`(`features/notifications/data/`):`LiveNotificationRepository`(`ApiClient` + `SseGateway`)/ `FixtureNotificationRepository`(内存 + 脚本化 emit/emitEcho/emitResync)/ `notificationRepositoryProvider` 单点 override。面:`listNotifications`(keyset)/ `markRead`/`markAllRead`/`unreadCount`(权威 COUNT)/ `signals`(实时 nudge)/ `resync`(410)。
- **`NotificationSignal` 投影器**:notifications 流一帧的语义投影(type + durable + `inboxCandidate` + payload)。**关键裁决**:N0 后流上 Emit(落行)/Broadcast(仅帧)帧形一致、且 `memory.updated`(pin 仅帧 vs 内容落行)同 type 同 payload **不可分** → 前端**绝不能靠 type 判是否有新收件箱行**。故:`unreadCountProvider` **从不据帧 +1**,而是 inbox-worthy durable tick 去抖 **refetch 权威 COUNT** / 410 立即重读 / 本地 mark 乐观扣减;`inboxCandidate` 是纯**性能**过滤(滤确定仅帧的 conversation.*/document 树刷新,歧义 type 留候选免漏真行、代价=一次对账 refetch)。
- **state**(`features/notifications/state/`):`unreadCountProvider`(AsyncNotifier,铃徽标真相)· `notificationFeedProvider`(AsyncNotifier + `KeysetQueryPaging`:首页 + inbox-worthy tick 去抖并首 refetch + 410 重翻 + markRead/All 乐观)· `toastDispatcherProvider`(事件→toast,app_shell eager watch 保活)· `appFocusedProvider`(焦点信号)。
- **DTO** `core/contract/notification.dart` `NotificationItem`(id/type/payload/readAt?[null=未读]/createdAt + domain·action·isUnread 读派生),只投影 Emit 落行档。
- **shell 接线**:`app_shell` `_NotificationsTray` 组合两段;铃徽标接 `unreadCountProvider`(footer 28px 铃格红点,非数字)。

## 状态

✅ **全落**:N0(后端分径 Emit/Broadcast + mcp 补 status)→ N1(契约数据缝 + Signal + unreadCount)→ N2(N2a 后端补名字 + N2b 行原语·文案 + N2c 两段式托盘接壳)→ N3(toast 迁右上 + hover 暂停 + 事件→toast 派发器)→ N4(OS 原生通知 DIP + 焦点路由)。`make verify`(后端)+ `make fe-verify`(前端,2429 测)+ macOS debug build 全绿。真壳 E2E 截图 + 右上 toast 截图肉眼核对。
