---
id: WRK-074
type: working
status: archived
owner: @weilin
created: 2026-07-20
reviewed: 2026-07-20
review-due: 2026-10-18
audience: [human, ai]
landed-into: CLAUDE.md, working/frontend/README.md, references/frontend/features/notifications.md, references/frontend/design-system.md, references/frontend/architecture.md, references/frontend/features/settings.md
---

# 顶带消息舞台 —— 单一即时出口迭代（全落）

> **✅ 全落并归档（2026-07-20）**。共享 `NoticeCenter`、固定中心的当前面、两颗 cue + `+N→✕` 候场尾、快照清场、新到保留、审批失败内联与全应用操作反馈收口均已落地；右上 `AnToast` 展示链物理退役，overlay 只留 confirm。当前事实已提取进 [`notifications.md`](../../references/frontend/features/notifications.md)、[`design-system.md`](../../references/frontend/design-system.md)、[`architecture.md`](../../references/frontend/architecture.md) 与 [`settings.md`](../../references/frontend/features/settings.md)，本页冻结为建造账。

> 用户 2026-07-20 已逐项拍板。本页是本轮单一实施账；落地后把当前事实提取进
> `references/frontend/{design-system.md,features/notifications.md}`，填写 `landed-into` 并归档。

## 目标

把后台事件通知与用户操作反馈收口到顶带一个即时出口：同屏只展开一条真实消息，当前卡片恒定居中，
候场以最多两颗点 + `+N` 表达；每条可单独关闭，`+N` hover 原位变成清空钮。右上角 toast 展示退役，
确认对话框仍归 overlay。顶带收起/清空绝不修改左岛通知账本、未读状态或审批决策。

## 已拍板交互

- **真实队列**：只排真实后台通知与真实操作反馈；取消现有 cap=5 丢弃，逐条展示，不制造摘要假通知。
- **固定中心**：当前普通药丸或审批块的中心锚不因候场数量改变；候场尾巴只向右外长。
- **候场尾巴**：1 条=`•`；2 条=`• •`；≥3 条=`• • +N`，N 为两颗点之外的数量。两点取实际下一/再下一条 tone。
- **单关**：每个展开面右上/尾端常驻标准 ✕；关闭只收当前，下一条接班。
- **批清**：仅有 `+N` 时，hover 将固定尺寸的 `+N` 原位交叉换成 ✕；点击收起点击瞬间已在顶部的整批。
  清空以序号水位为边界，动画期间新到消息不误伤。无确认弹窗。
- **账本边界**：后台事件仍在左岛铃铛、未聚焦仍走 OS；顶带关闭/清空不标已读、不删行。操作反馈只进顶带。
- **审批**：仍可就地批/拒；✕ 只收起、不代表拒绝；决定失败在当前审批块内诚实反馈。审批可排到候场首位，
  但绝不硬切正在说话的卡片。
- **降噪**：既有同 `(type,entityId)` 4s 去重与类别登记保留；有积压时缩短停留但守最低可读时长；hover 暂停。

## 动画线

1. 普通面：像素 → tone 点 → 对称横拉药丸 → 文案由右缘扫出；退出同线倒放。
2. 到达：当前面零位移；尾巴新点 scale+fade 一拍，`+N` 数字固定盒内交叉换值。
3. 接班：当前缩回中心点并退场；下一条在同一中心锚出生展开，尾巴补位。
4. 审批：点 → 横条 → 向下长成块；关闭/判词按块 → 条 → 点倒放。
5. 批清：候场尾巴先短促收拢，当前面同线倒放；reduced motion 即时淡出、零位移。

动效只在状态变化时发生：无持续呼吸、闪烁或循环。卡内文字预量一次，逐帧只做 clip/transform/opacity；
仅顶带子树重建，候场长度不增加 Widget 数。

## 实施批次

1. `core/notice/` 建共享 `NoticeCenter`：`ListQueue` O(1) 进出，内部全队列 + 对外小投影
   （current / nextTwo / pendingCount / revision）；key 守陈旧退场回调，sequence 水位守批清竞态。
2. `AnNoticeQueueTail`：固定中心之外的两点 + `+N↔✕`，固定几何、tooltip/a11y、reduced 路径。
3. `AnNoticeCapsule` 扩 full `AnTone` + 标准 ✕ + 外部 dismiss 信号；`AnApprovalCapsule` 同步标准右缘与批清退场。
4. app 壳宿主接舞台；notification dispatcher 投递后台事件；全应用操作反馈从 `overlayProvider.showToast`
   迁到 `noticeCenterProvider.show`。overlay 仅留 confirm，物理删除 AnToast 栈与死样章/测试。
5. 五电池 + 状态机/竞态/中心不漂移/帧成本测试；gallery 四态 + 真 app 关键帧；`make fe-verify` + `make docs`。

## 验收不变式

- 任意 push/pop/clear 后，当前面中心 x 不变（≤0.5 logical px）。
- 队列 5 与 5000 条时，顶带可见 Widget 数和动画逐帧工作量相同。
- `+N` hover 前后外框尺寸相同；点击清空不影响点击后到达的新消息。
- 单关/批清后台事件后，通知 feed 行、readAt、unread-count 逐字不变。
- 审批关闭不调用 decide；批准/拒绝仍走既有 first-wins repository 链。
- reduced motion 下零 controller 位移动画；读屏可读当前消息、候场总数、单关与批清动作。
