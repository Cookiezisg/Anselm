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

Delete 是**软删除**：审批表从普通读/搜索中消失，且其 relation edges 被清理；`apfv_` 版本行
是不可变审计历史，保留而不硬删。工具层的 `delete_approval` 因此必须自报
`danger="dangerous"` 并等待用户批准，且应先用 `get_relations` 解释受影响的 workflow/agent。
删除后引用它的 workflow 仍保留原图，但 capability check 会诚实报告缺失引用，直到显式改绑。

`revert_approval` 的公开 schema 仍是 integer；为兼容托管模型，工具执行边界另外接受精确十进制整数字符串，
但拒绝浮点、布尔、数组和无法解析的字符串。Revert 只移动 active pointer，不新建版本、不改写历史快照。

AI `create_approval` / `edit_approval` 保持公开 schema 的强类型契约，同时在执行边界兼容已观测的
托管模型形状：`allowReason` 的精确布尔字符串，以及 `inputs` 的精确 JSON 编码数组或以字段名为
key 的 JSON 对象（两者也可作为字符串传入）。对象 key 会排序后转为稳定的 Field 列表；数字、任意
truthy 值、坏 JSON 和冲突字段名仍在 mutation 前拒绝。`edit_approval` 是完整版本替换而不是 delta，
因此 `approvalId`、`inputs`、`template`、`allowReason`、`timeout`、`timeoutBehavior` 与非空
`changeReason` 均必须显式提供（timeout 空字符串和 inputs 空数组是合法值）；执行边界与 schema
同时拒绝缺失或 null，防止零值或审计理由缺失静默写入错误版本。
该兼容只修正 wire shape，不改变 approval 语义，也不放宽 HTTP/API 的公开 schema。

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
