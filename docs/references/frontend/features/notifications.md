---
id: DOC-050
type: reference
status: active
owner: @weilin
created: 2026-07-07
reviewed: 2026-07-20
review-due: 2026-10-18
audience: [human, ai]
---

# Feature: Notifications（通知账本 + 顶带消息舞台）—— 当前形态

> 本篇只写当前事实。通知模块最初的 N0–N5 建造史见 [`WRK-058`](../../../archive/notifications/README.md)，顶带单一即时出口的收口过程见 [`WRK-074`](../../../archive/notice-stage/README.md)；DTO 看 [`contract.md`](../contract.md)，后端 Emit/Broadcast 分径看 [`events.md`](../../backend/events.md)。

## 一句话

通知有三张脸，但只有两类真相：**左岛铃铛是可追溯账本**，保留 durable 后台事件与未读状态；**顶带是全 app 唯一即时消息舞台**，顺序播放后台事件的展示副本和用户操作反馈；app 未聚焦时，后台事件改走 **OS 原生通知**。顶带的单关或批清只改变顶部展示，绝不标已读、删通知、决定审批或清空左岛账本。

## 后端分径：什么值得落账

`notificationapp.Emitter` 分两档 durable 信号（见 [`events.md`](../../backend/events.md)）：

- **Emit**：落 notification 行并推帧。失败、AI 执行结果、实体生命周期等值得事后追溯的事件走此档。
- **Broadcast**：只推帧不落行。conversation/document 刷新、memory pin、handler 重启成功、sandbox installing 等高频对账回声走此档，真相留在实体自身。

实体生命周期 payload 带 `name`，所以 UI 可写「Agent『triager』已创建」而不是只露 ID。`relation.dependency_broken` 在实体已删除、名字无法再解析时诚实使用 `deletedId` 作主语，受影响对象放详情行。

## 左岛铃铛：持久通知账本

`features/notifications/ui/notification_tray.dart` 的 `NotificationTray` 与 chat rail 共用同一套左岛原语：顶部是 `AnRailFilterField`，下方是可折叠分组与 `SliverAnimatedList`。app 壳通过 `NotificationTray(approvalsBand: FlowrunInbox(sectioned: true))` 注入「待你处理」，notifications 与 entities feature 不互相 import。

- **搜索与筛选**：搜索匹配渲染后的通知文案；⚙ 菜单提供「仅显示未读」。搜索时全部展开，并隐藏不属于通知内容的审批带。
- **分组**：「待你处理」→「今天 / 昨天 / 更早」。组头用 `AnRow`，左侧常驻 chevron，右侧计数在 hover 时原位换成 ⋯；整行点击折叠，几何与 chat rail 对齐。
- **行语法**：`NotificationRow` 只用 tone/kind 图标表达严重度；未读与已读的唯一差异是整行显隐层级，不另画未读点。点击行深链并顺手已读，hover 可单行标记已读。
- **账本动作**：组头菜单里的「全部已读 / 全部未读」都作用于整本通知账，且始终可点、幂等。动作后重取权威 unread count，不从当前分页窗口臆算。
- **待你处理**：审批卡仍走既有 `decideApproval` first-wins 链。批量批准/拒绝先 `overlay.confirm` 点名确认，再逐条执行并将结果汇总为一条顶带操作反馈；关闭顶部审批块不等于拒绝。

## 顶带消息舞台：唯一即时出口

实现由以下几层组成：

| 层 | 当前职责 |
|---|---|
| `core/notice/notice_center.dart` | 跨 feature 的消息队列、身份守卫、快照清场与小投影 |
| `core/ui/an_notice_island_frame.dart` | 普通与审批共用的岛面、发丝线、岛影与裁切外壳 |
| `core/ui/an_notice_capsule.dart` | 普通药丸：全 `AnTone`、深链、常驻标准 ✕、hover / focus 暂停、读屏播报 |
| `core/ui/an_notice_queue_tail.dart` | 候场尾巴：一/两颗 tone 点，或两点 + `+N`；hover/键盘焦点时同盒交叉换成 ✕ |
| `core/run/an_approval_capsule.dart` | 审批块：就地批/拒、失败内联、标准右缘关闭、粘性停留 |
| `features/notifications/state/notice_dispatcher.dart` | durable 事件的登记过滤、4 秒去重、前台/OS 路由 |
| `app/app_shell.dart` | 顶带中心锚、当前面与候场尾巴装配、停留与退场时序 |

### 队列与投影

`NoticeCenter` 内部有 priority / normal 两条私有 `ListQueue<NoticeEntry>`，入队和出队均为 O(1)，**不设消息数量 cap，也不因 UI 容量丢消息**。对 widget 树只投影固定大小的 `current`、最多两条 `NoticeCue`、`pendingCount` 和序号；因此 5 条与 5000 条积压时，可见 widget 数不随队列长度增长。

- 操作反馈与 system 消息默认 priority；后台事件中，审批为 priority，普通事件为 normal。
- priority 只决定**下一个谁接班**，不会硬切正在说话的 current。
- 公平性采用「priority 最多连续 3 条」：normal 有积压时，每播放 3 条 priority 必须让 1 条 normal 接班；既不让普通后台事件被审批/操作反馈永久饿死，也不削弱短突发里 priority 的及时性。
- 每条用单调序号生成身份；延迟 dismiss / exit 回调必须带当前 id，陈旧回调不能误关接班消息。
- 可选 `coalesceKey` 只在消息仍可见或候场时合并；该消息退出后同 key 可再次入队。
- 有积压时，接班消息带 `briskPlayback`，停留从常态 `AnMotion.noticeHold` 缩到 `AnMotion.noticeQueuedHold`，但仍保留最低可读时间。停留计时从消息**完全展开后**才开始；指针 hover、键盘焦点或 hover / focus 候场尾巴都会暂停当前普通药丸。

### 几何、数量与清场

当前普通药丸或审批块用 `CompositedTransformTarget` 固定在顶带中心。两者共用一套「灵动岛冠部」规格：**高 36、最大宽 340、左右海岸各 12、紧凑半径 18**；审批保留冠部的身份与操作位置，只从冠部向下长成半径 16 的内容块。普通面、审批冠部、候场点和批清槽始终共用一条水平中轴。候场尾巴用 follower 锚到当前面的右侧，所以从一条变成两条、再变成 `+N` 时，**当前面的中心 x 不动**。

普通面与审批冠部共享岛屿专属关闭语法，而不是复用其他岛的可见方形按钮：**28×28 透明命中区 + 16px 裸 ✕**，命中盒尾缘距岛尾缘 2，✕ 的中心距尾缘 16；左侧 tone 点中心距首缘约 15.5，二者按视觉重心形成光学对称。静息只见低对比字形，指针 hover 只把 ✕ 变深，press 轻缩，不出现底块；仅键盘 focus 显示圆形发丝焦点环。普通与审批形态改变时，两端锚点都不跳位。

- 1 条候场：一颗实际下一条 tone 的点。
- 2 条候场：两颗实际下一/再下一条 tone 的点。
- 3 条及以上：两颗点 + 固定 **32px 布局槽**中的 `+N`；N 是两颗点之外的精确数量。视觉文案封顶 `999+`，tooltip 与 semantics 仍报精确总数。
- `+N` 在 hover 或键盘 focus 时，于同一 32px 槽内 cross-fade/scale 成**无底的 icon16 裸 ✕**；透明 28×28 命中区不变，不生成正方形内岛。它与当前面关闭采用同一字形状态：hover 仅变深、press 轻缩、键盘 focus 才有圆形发丝环。Enter/点击触发批清，布局槽与锚点不变，不引起当前面位移。
- `clearVisibleSnapshot()` 在点击瞬间交换两条 pending 队列，并给当前面发 `dismissRequested`。清的是那一刻已在顶部快照里的 current + pending；清场动画期间新到消息进入新队列并保留，不会被旧清场误伤。
- 无论超时、查看、单关还是批清，current 退场前都先让尾巴 fade/scale 收起，再沿原路倒放 current；新尾巴在旧 current 离场前暂不露出，避免尾巴跟随收缩面漂移或两批消息视觉混叠。

### 动画与可访问性

普通面沿「像素 → tone 点 → 横向展开 36px 药丸」进入，审批沿「点 → 36px 冠部 → 向下展开块」进入，退出均沿原路径倒放。审批的状态文法固定：pending / busy 用 warn 身份点与 muted 状态词（busy 换进行中文案并压下双钮），error 用 danger 点与文字，approved 用 ok 点与文字，rejected 用 neutral 点与文字——人的否决不是系统失败。候场新点只在到达时做一次 fade + scale，不呼吸、不闪烁、不循环。reduced motion 路径取消位移动画并即时淡出。

当前消息、候场精确数量、单关与批清动作都有 semantics；后台事件/审批经 `AnA11y.announce` 使用相应 polite / assertive 语气。普通面与审批右侧常驻同一裸 ✕；审批决策失败直接在当前块内反馈，重试时清错，不会把失败再排到粘性审批后面。

性能边界同样属于规格：普通文案与审批高度在开拍前测量，正文在动画中不重排；但冠部伸展、内容揭示以及 `+N↔✕` 交叉切换仍会产生局部布局/重绘，不能虚称「每帧只有 clip/transform、零布局」。这些动画区域由 `RepaintBoundary` 隔离；候场尾只构建最多两颗点和一个定宽槽，绝不构建排队正文。配合 `NoticeCenter` 的 O(1) 队列操作与定长 UI 投影，积压从 5 条增长到 5000 条不会增加顶带 widget 数；每帧工作只与当前可见岛和定长尾巴有关，不随积压总量增长。

## 分发、登记与 OS 路由

`NoticeDispatcher` 只消费 durable 事件。通知设置仍保留 level 与类别登记：失败/崩溃、待审批、需要关注；`all / important / silent` 语义不变。事件先经过 `(type, entityId)` 4 秒会话去重，再按焦点分流：

- **app 聚焦**：送共享 `noticeCenterProvider`，成为顶部展示副本；持久行仍留在左岛账本。
- **app 未聚焦**：送 `OsNotifier`，不同时在顶带排一份迟到副本。

`OsNotifier` 是 DIP：默认 `NoopOsNotifier` 保证测试/gallery/demo 不发真通知；真 app override 为 `LocalOsNotifier`，点击复用 go_router 深链。macOS unsigned dev bundle 可能被 UserNotifications 静默拒绝，真投递以签名 build 为准。

## Demo 实机演示

`make -C frontend demo` 额外挂载一次性顶带巡演，**只**向 `NoticeCenter` 投递展示副本，不发 durable fixture 行；因此不会受本机已保存的通知类别开关影响，也不会把同一演示重复送进顶带。`DemoRoot` 默认关闭该脚本，测试与 perf 挂载保持确定。启动后第 2 / 6 / 10 秒依次演示成功操作、失败事件、需关注事件；第 14 秒进入真实 fixture parked node 的审批块；第 17 / 20 / 23 秒继续到达三条候场消息，审批停留期间可观察两颗 cue 与 `+N→✕` 的清场交互。脚本卸载会取消全部 timer，真 app 的 durable 事件仍只经 `NoticeDispatcher` 路由。

用户操作反馈不进 notification repository，只调用 `noticeCenterProvider.show(...)`。确认框仍由 `core/overlay` 的 `overlayProvider.confirm(...)` 提供；旧右上 `AnToast`、toast dispatcher 和右上展示宿主已物理退役，overlay host 不再绘制通知。

## 数据缝与 state

- **唯一仓储缝**：`NotificationRepository`；live/fixture 两实现，接口含 keyset list、mark read/all、权威 unread count、signals 与 410 resync。
- **Signal 投影**：Emit 与 Broadcast 帧形相同，部分同 type 事件也无法仅凭 payload 判断是否落行，因此 `unreadCountProvider` **绝不据帧 +1**；对 inbox-worthy durable tick 去抖后 refetch 权威 COUNT，410 立即重读。
- **主要 providers**：`unreadCountProvider`、`notificationFeedProvider`、`noticeDispatcherProvider`、`noticeCenterProvider`、`appFocusedProvider`。
- **DTO**：`core/contract/notification.dart` 的 `NotificationItem` 只投影已落账的 Emit 行；`readAt == null` 派生未读。
- **持久化边界**：`NoticeCenter` 只持展示副本，不持 repository 句柄；顶部关闭、超时和批清在结构上都无法修改 feed、readAt 或 unread count。

## 状态

✅ **当前全落**：后端 Emit/Broadcast 分径、左岛账本与审批带、权威未读对账、前台顶带/后台 OS 路由均已接通；后台事件与全应用操作反馈已收口到共享 `NoticeCenter`。顶带统一为 36px 冠部 / 340px 最大宽 / 双侧 12px 海岸，普通、审批和候场尾同中轴；关闭与批清采用 28×28 透明命中区中的无底裸 ✕，两端视觉锚点光学对称。固定中心、两 cue + `+N→✕`、无 cap 队列、priority 每 3 条让 1 条 normal 的公平调度、身份守卫、清场水位、新到保留、审批五态、退出编舞、reduced motion 与 semantics 均有对应测试。右上 toast 展示链已退役，overlay 仅保留 confirm。
