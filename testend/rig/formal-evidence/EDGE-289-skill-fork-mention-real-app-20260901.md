# EDGE-289 · @ 一个 fork skill：真实 App 五级验收

日期：2026-09-01

## 场景与用户目的

在同一隔离 workspace 创建两个 skill：`edge289-inline`（`context=inline`）与
`edge289-fork`（`context=fork, agent=Explore`）。用户从 Chat 的 `@` 入口选择一个可注入
当前回合的 skill；fork skill 不应作为 inline mention 候选，也不应被错误地预授权到父回合。

## 真实结果

- session：`/private/tmp/anselm-rig-formal-20260831-11/sessions/20260901-130723`
- workspace：`ws_1b05f72f7612c905`
- 真实 App 打开 Chat → `Mention an entity`。候选列表包含 `edge289-inline`，不包含
  `edge289-fork`，同时保留已有 function、agent、workflow 和 document 候选。
- 点击 `edge289-inline` 后，composer 显示清晰的 `@edge289-inline` chip；没有 fork skill
  被误注入，入口仍可继续发送。
- 录屏抽帧：`evidence/EDGE-289-mention-candidates.png`（候选列表）与
  `evidence/EDGE-289-inline-chip.png`（选择后 chip）。`measure diff` 的 ROI 只在列表一次
  展开/收起时报告 `changedFrac=0.08396`，稳定态没有额外报告，未见非用户触发的跳变。

## 五通道

- `screen.mov` 已封存 `46.173333s`，`rig-check`/`rig-down` 通过，录屏窗口归属正确。
- backend journal 记录两个 skill 创建和对应健康请求，无应用级 WARN/ERROR/panic/FATAL。
- `sse.jsonl` 记录 `messages`、`entities`、`notifications` 三流连接及两条 `skill.created`
  durable notification，连接关闭为正常 EOF。
- `frontend.log` 只有正常 Flutter VM 启动行和已知 macOS IMK 系统诊断，无 Flutter/Dart/
  RenderFlex/RenderBox/Unhandled 红线。
- `llm.jsonl` 记录 managed challenge/install/models 全部 `200`；本确定性 mention 路径没有
  completion，不伪造模型 wire。

## 五级判定

- L1=`G1`：既有 service、frontend 和合同回归通过，fork skill 不进入 `@` 候选且 mention
  预授权不污染父回合。
- L2=`F2`：真实 App、backend journal、三路 SSE、frontend console、LLM wire 和封存录屏由
  同一 session 归属；UI 候选、durable skill signals 与 REST 创建结果一致。
- L3=`A1`：`@` 候选展开、选择与 chip 呈现均为直接反馈；稳定态 ROI 无额外变化，未观察到
  等待、重复展开或选中后回跳。
- L4=`C4`：候选列表为单一圆角面板，条目图标、名称、说明和选中 chip 层级一致，浅色画面
  中没有裁切、重叠、异常留白或错位；稳定态不发生重排。
- L5=`G1`：新用户无需文档即可从 Chat 中可见的 `@` 按钮进入候选列表，能理解 inline skill
  可选择、fork skill 不应直接注入当前回合。

没有发现需要 stop-and-fix 的产品问题；本格验证的是 mention 的入口边界，不替代 fork
skill 的正常 Library/activate 路径或无 runner 装配防线。
