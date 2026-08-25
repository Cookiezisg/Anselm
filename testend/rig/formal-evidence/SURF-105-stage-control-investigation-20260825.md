# SURF-105 · stage/control · 正式调查记录

## 受验对象

`SURF-105 stage/control`：control build stage 是否在真实托管模型参数形态下稳定呈现有序决策梯、连续的透传幽灵和独立的 `否则` 兜底徽记，并在落定后与 control 实体真相一致。

## 真实现场

session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260825-083508`，隔离数据目录=`/private/tmp/anselm-data-surf105-20260825-r1`，workspace=`ws_49c1d61cd9a50d3a`。真实 Flutter macOS App 经 Computer Use 操作，LLM 请求经真实 Anselm managed gateway 和独立 llmtap；screen recorder、backend journal、三路 SSE witness 同时在线。

## 观察与 stop-and-fix

静态反查发现 `controlBranches` 只读取 `PartialJsonSession.arrayItemsAt(['branches'])`，而 hosted gateway 已实际产生完整 JSON 字符串形式的 `branches`。若不处理，实时 stage 会把已闭合字符串误判为空 ladder。stop-and-fix 在 `tool_card_control_approval.dart` 增加窄兼容 seam：原生数组优先，闭合且合法的 JSON 数组字符串才解码，部分/畸形字符串仍返回诚实空集；按 `PartialJsonSession` 实例缓存，避免流式重建抖动。新增回归覆盖 stringified branches、`port`、`when`、`emit` 和 catch-all。

定向验证：`tool_card_control_approval_test.dart`、`stages_w3_test.dart`、`stage_alignment_test.dart` 共 `20/20` 通过。

## 真实 App 结果

首条人为输入在 Computer Use 的 AX `set_value` 与可视编辑器不同步后产生了残缺中文请求；模型没有静默执行，而是停在澄清交互。选择 `< 30` 后，第一次 `create_control` 因 `inputs` 不是 JSON array 被后端在 mutation 前拒绝，随后模型修正为 native array 并成功创建唯一 `SURF105` v1。该失败卡是观察器输入事故的诚实负路径，不计为产品红点，也没有产生实体副作用。

真实成功 stage 展开后逐帧确认：

- `hot`、`normal`、`otherwise` 三级顺序与 REST branches 一致；
- 每级几何高度连续，条件代码可读，`otherwise` 以独立灰色徽记呈现；
- 没有 `emit` 的分支明确显示“透传”，不是空白，也没有把 catch-all 当普通条件吞掉；
- 活动岛成功行显示 `SURF105 · 创建`，失败行保留“草稿未保存 · 尚未创建实体”，两种状态没有混成一张假成功卡；
- REST `GET /api/v1/controls/ctl_164a2a8923191722` 返回 active v1，inputs 为 `temperature:number`，branches 为 `hot >=30`、`normal <30`、`otherwise=true`，与画面和助手正文一致。

## 五通道事实

- Screen：`screen.mov` 与 `screen-rebind-5997.mov` 已封口，总录制时长 `540.676667s`；Computer Use 观察了错误澄清、成功结果、活动岛展开和最终 control ladder。
- Backend：端口 `:8742` 归属 PID `5237`，health 通过；除故意坏 `inputs` 负路径的 validation WARN 外，无 ERROR/panic/fatal/unknown。
- SSE：messages durable `1..33`、notifications `1..3`、entities `1..2` 分流单调唯一；三路均真实连接，未把 seq=0 delta 冒充 durable。
- LLM wire：managed proof challenge/install/models 与业务 chat completions 均返回 HTTP `200`；请求体留存于 `llm-bodies/`，响应体留存于 `llm-responses/`。
- Frontend：journal 仅有 Dart VM、正常 App 启动和已知 macOS IMK 平台噪声；无 FlutterError、DartError、RenderFlex/layout overflow、Unhandled 或 SEVERE 红线。
- `rig-check.sh` 在 rebind 后通过五通道物理归属；`rig-down.sh` 通过，进程与监听端口均收台。

## 产品裁决

本格关注的 stage 视觉契约已达成：托管模型的字符串化分支形态不再让决策梯空白；成功 stage 的透传语义和否则徽记可发现、连续、稳定，且落定实体真相对账一致。前置 AX 输入不同步属于台架操作约束，已保留为负事实，不伪装成产品缺陷或绿路径。
