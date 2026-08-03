---
id: DOC-050
type: reference
status: active
owner: @weilin
created: 2026-07-07
reviewed: 2026-07-31
review-due: 2026-10-29
audience: [human, ai]
---

# Feature：Notifications（通知账本与即时舞台）——当前形态

> 后端事件分径见 [`events.md`](../../backend/events.md)，Dart DTO 见 [`contract.md`](../contract.md)。确认框属于 `core/overlay`，不属于通知系统。

## 1. 两类真相、三张脸

| 形态 | 职责 |
|---|---|
| 左岛铃托盘 | durable 通知账本、未读状态、搜索/过滤/分组，以及跨 run approval 带 |
| 顶带消息舞台 | 全 app 操作反馈和前台后台事件的短时展示副本 |
| OS 通知 | app 未聚焦时的后台事件出口 |

顶部关闭、超时或批清只影响展示队列，不能标记账本已读、删除 durable 行或替用户决定 approval。

## 2. 后端分径

- `Emit`：写 notification 行并广播，适用于需要事后追溯的失败、完成、审批与重要生命周期事件。
- `Broadcast`：只广播，不写通知行，适用于实体自身已有 durable 真相的高频刷新回声。
- `NotificationRepository` 只投影 Emit 行；unread count 必须从服务端重取，不能看到帧就本地 `+1`。
- 410 resync 后同时重取 feed 与 unread count。

## 3. 左岛账本

- keyset 分页，支持渲染后文案搜索和“仅未读”过滤。
- 按“待你处理 / 今天 / 昨天 / 更早”组织；搜索时展开结果并隐藏无关审批带。
- 点击通知执行深链并标已读；批量已读/未读作用于整个服务端集合，不只当前分页窗口。
- approval 复用 flowrun 的 first-wins `:decide`；批量决定先确认，再逐条执行并汇总反馈。

## 4. 顶带与分发

- `NoticeCenter` 维护 priority/normal 两条 O(1) 队列，只向 widget 暴露 current、最多两颗 cue 与总积压数。
- priority 决定下一条，不打断 current；normal 有积压时，连续三条 priority 后让一条 normal。
- 每条消息有单调身份，陈旧 dismiss/animation 回调不能关闭接班消息。
- 批清按点击时的快照换队列；清场动画期间新到消息保留。
- app 聚焦时 durable 事件进入顶带；未聚焦时进入 `OsNotifier`，不再补一份迟到顶带消息。
- 设置中的 level、类别与 4 秒去重由 `NoticeDispatcher` 执行。
- 审批顶带只在 parked 状态可操作：`NoticeDispatcher` 同时监听 entities 流的 durable `run_terminal`，按 `flowrunId` 撤销当前与候场中的审批展示副本，因此模型、其他客户端、调度器收件箱或取消动作完成后不会留下可点击的旧 Approve/Reject；如果决策由当前卡片发起，先保留本地判词回执，再按同一倒放退场。

## 5. 关键不变量

1. durable 账本与即时展示不可互相冒充。
2. Broadcast 不出现在通知历史，Emit 才能增加服务端未读数。
3. approval 的 UI 状态不能覆盖服务器 first-wins 结果。
4. 展示队列长度不增加可见 widget 数。
5. reduced motion、键盘焦点、语义播报与队列暂停必须覆盖普通消息和 approval。
6. demo 默认使用 fixture/Noop OS notifier，不得向真实系统发送通知。

## 6. 验证入口

- feature：`frontend/test/features/notifications/`
- notice 原语与队列：`frontend/test/core/notice/`、`frontend/test/core/ui/`
- approval：`frontend/test/core/run/` 与 Entities/Scheduler feature 测试
- 人眼验收：`make -C frontend demo`
