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

AI 工具的 `branches` 公开 schema 是 branch object 的 JSON array；每个 branch 的出口字段严格
叫 `port`，不是 `name`，形状例如
`{\"port\":\"pass\",\"when\":\"input.score >= 0.8\",\"emit\":{\"decision\":\"input.score\"}}`。
托管模型偶尔会把同一个 array 编成一个完整 JSON 字符串；`create_control` 与 `edit_control` 的
工具边界只兼容这一种等值编码，仍拒绝 malformed string、object 和非 array，不猜测或改写分支内容。

同一 assistant 响应内完全相同的工具调用只执行首个，后续调用返回 completed suppression 结果，防止
模型修正参数时重复执行 mutation；跨回合用户主动重复仍按正常的名称冲突/业务规则处理。

`edit_control` 每次写入不可变新版本都必须带非空 `changeReason`。这是 AI 工具边界的审计硬门，
缺失或空白值在 mutation 发生前以 `CONTROL_CHANGE_REASON_REQUIRED` 拒绝；HTTP/domain service
的内部调用不改变既有兼容性。

`revert_control` 的公开 schema 仍是 integer；为兼容托管模型，它的工具边界另外接受精确十进制整数字符串，
但拒绝浮点、布尔、数组和无法解析的字符串。Revert 只移动 active pointer，不新建版本、不改写历史快照。

`get_control` 的 `controlId` 是必填业务参数；托管模型不得以 `{}` 调用，缺少 id 时应先用
`search_control`。它是只读调用，标准 `danger` 应为 `safe`。`delete_control` 则是不可逆的破坏性
动作，具有不可绕过的静态 `dangerous` 下限；即使模型自报 `safe`，也必须携带 `controlId`、标准
`danger=dangerous`，并在 HumanLoop 用户批准后才可执行，不能被 skill 或 `approve_always` 预授权绕过；
删除前应先用 `get_relations` 说明会失效的 workflow 依赖。

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
