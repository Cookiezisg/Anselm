---
id: DOC-016
type: reference
status: active
owner: @weilin
created: 2026-06-11
reviewed: 2026-07-31
review-due: 2026-10-29
audience: [human, ai]
---

# Control

## 1. 定位

Control 是 `ctl_` 命名实体及其不可变 `ctlv_` 版本线。它表达一组有序分支：

```text
input → first matching branch → named port + emitted payload
```

Workflow 节点只引用 Control；port 如何连接下游属于图。Control 无 Sandbox、env 或
execution 表，由 durable interpreter 内联求值，不是 activity。

## 2. 分支契约

每个 Branch 包含：

- `when`：读取 `input.*` 的布尔 CEL；
- `port`：图边匹配的具名出口；
- `emit`：可选的字段到 CEL 映射；空映射表示透传 input。

分支自上而下 first-true-wins。Port 必须非空且组内唯一，最后一条 branch 必须是
`when == "true"` 的 catch-all，保证任何输入都有出口。图允许某个 port 连回上游，
因此循环结构由 Workflow 表达，而不是由 Control 隐式实现。

Create/Edit 先做结构校验，再以 author-time `input` 根编译所有 when/emit；无效 CEL
不能进入版本线。Domain 不依赖 CEL runtime。

## 3. 版本与运行

Create 产生 v1 并设为 active。Edit 追加版本，Revert 只移动 active pointer，不修改
旧快照。Workflow activation 会 pin 引用 closure；已启动 run 始终解析钉死版本，不受
后来 Edit/Revert 影响。

运行结果包含 emit 字段及保留的 `__port`。Interpreter 用 `__port` 选边；实体流的 node
tick 同时投影所选 port，供 UI 显示真实路径。

## 4. 集成与契约

Control 参与 catalog、mention、relation、search 与 AI iterate。CRUD、versions、
edit/revert/iterate 端点见 [`api.md`](../api.md)；表与 ID 见
[`database.md`](../database.md)；错误见 [`error-codes.md`](../error-codes.md)。

Workflow pin、循环与 replay 语义见 [`workflow.md`](workflow.md) 和
[`scheduler-flowrun.md`](../foundation/scheduler-flowrun.md)。
