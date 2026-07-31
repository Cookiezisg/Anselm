---
id: DOC-017
type: reference
status: active
owner: @weilin
created: 2026-06-11
reviewed: 2026-07-31
review-due: 2026-10-29
audience: [human, ai]
---

# Approval

## 1. 定位

Approval 是 `apf_` 命名实体及其不可变 `apfv_` 版本线。版本定义：

- 声明式 inputs；
- Markdown prompt template；
- `{{ CEL }}` 插值；
- 是否允许填写 reason；
- timeout 与 timeout behavior。

Workflow approval 节点使用固定 yes/no 出口。Approval 表只保存配置；一次运行中的
待审批事项不是独立实体表，而是 `flowrun_nodes` 的 parked 行。

## 2. Author-time 校验

Template 必须非空，所有插值只在 `input` 根下编译。Timeout 支持 Go duration 及 `d`、
`w` 后缀：

- 空字符串表示永不超时；
- 非空 timeout 必须为正；
- 非空 timeout 必须选择 `reject | approve | fail`；
- 显式 `0s` 被拒，不能伪装成有策略却永久 parked。

Create 产生 v1；Edit 追加版本；Revert 移动 active pointer。Workflow activation pin
具体版本，运行不会漂移到后来编辑。

## 3. Runtime

Interpreter 解析 pinned version、用节点 input 渲染模板，然后写 parked node result。
Result 包含 rendered Markdown 与 allowReason，供 inbox 展示；Flowrun 继续保持 running。

人工决定与 timeout sweep 竞争同一条 first-wins 状态变更。决策后使用 yes/no port 继续
Advance；`fail` timeout 使 run 失败。已落定的审批不会被迟到的第二个决定覆盖。

Inbox 的 `deadline` 由 `parkedAt + pinnedVersion.timeout` 派生，并与 timeout scanner
共用同一 domain 函数。无 timeout 时不返回 deadline，避免 UI 倒计时与真实扫描语义分叉。

## 4. 集成与契约

Approval 参与 catalog、mention、relation、search 与 AI iterate。CRUD、versions、
edit/revert/iterate 及 Flowrun decide 端点见 [`api.md`](../api.md)；表见
[`database.md`](../database.md)；错误见 [`error-codes.md`](../error-codes.md)。

Park、timeout、decision 与 replay 细节见
[`scheduler-flowrun.md`](../foundation/scheduler-flowrun.md)，图出口见
[`workflow.md`](workflow.md)，运行事件见 [`events.md`](../events.md)。
