# EDGE-321 草稿文档首次编辑：L4 真实 App 视觉 craft 证据

## Session

- session: `/private/tmp/anselm-rig-formal-20260831-11/sessions/20260901-214332`
- data: `/private/tmp/anselm-data-edge321-l4-20260901.iELpRk`
- workspace: `ws_d2bed7a5fd1f05d3`
- recording: `screen.mov`, `78.206667s`, owned window `14028`
- frames: `/private/tmp/edge321-l4-frames-20260901.y2BMn2`
- representative stable frame: `f0069.png`

## Product path

从 Library 无选区态进入空的 `Untitled` 草稿；先切到 Chat 再回到 Library，确认未编辑空稿不落盘。
随后在正文引导处输入 `EDGE321 body probe`，等待首次编辑认领新文档，再继续输入 ` + continued`，
等待保存，切到 Chat 后返回 Library。

上一场隔离副本因继承旧测试文档而产生 `Untitled`/`Untitled 2` 混淆，已明确作废且未写账；本文件只
记录删除污染行后的清洁副本重跑。

## Frame and craft review

清洁场首次输入后左树只出现一个 `Untitled`，中心编辑器标题、正文和右侧 Inspector 均指向同一对象。
继续输入后稳定帧正文为 `EDGE321 body prob + continuede`，右侧显示 `26 chars`、`30 B` 和
`Path /Untitled`；离开再返回后这些值保持一致，没有空白、重复文档、标题/路径错配、编辑器重挂、
焦点跳回或 Inspector 晚到覆盖。页面层级、留白、左树选中态和右侧属性排布保持稳定。

全程 1fps、内容 ROI `760,250,1500,950`、阈值 `0.0005` 的变化均绑定用户动作窗口：

```text
f0031→f0032  changed=0.03532  空稿进入/创建前后 UI 变化
f0032→f0033  changed=0.03534  草稿认领窗口
f0043→f0044  changed=0.00423   首次输入后编辑器局部收敛
f0044→f0045  changed=0.01379   创建后列表/Inspector 同步
f0054→f0055  changed=0.00123   继续编辑保存
f0067→f0068  changed=0.02534   离开/返回导航
f0068→f0069  changed=0.02523   返回后稳定态确认
```

未发现静止段持续漂移或用户不可解释的跳变。L4=`C4`。

## Five-channel cross-check

- **frames / Computer Use**：真实 App 覆盖空稿离开、首次输入、认领后继续输入、离开和重返；每个操作后重新读取 AX 状态。
- **backend**：`backend.log` 共 `304` 行；清洁场首次输入只产生一次 `POST /api/v1/documents` `201`，后续为同 ID 更新，无应用级红线。
- **SSE**：独立 witness `sse.jsonl` 共 `10` 行，三条 workspace stream 均连接，document created/updated durable 帧单调。
- **frontend console**：`frontend.log` 共 `4` 行；无 Flutter/Dart、RenderFlex、RenderBox、Unhandled 或 Exception 应用级红线，仅分类后的 macOS IMK 宿主诊断。
- **LLM wire**：`llm.jsonl` 共 `1` 行；握手记录存在，本格为 Library 编辑路径，不伪造 completion 证据。

## Durable truth and lifecycle

最终 SQLite 只有一篇新文档 `doc_56b8292aac2a60d4`，名称 `Untitled`，正文长度 `30` chars、
`30` bytes，路径 `/Untitled`；左树、中心和 Inspector 与此 durable 对象一致。`rig-check` 五通道、
D1 端口归属、录屏归属和 `rig-down` 收台通过，owned processes 已收尸。

## Boundary

L4 判定的是首次认领过程的视觉连续性、布局和对象一致性；空稿输入即创建的语义与可发现性另由 L5
单独判定，不由本格偷换结论。
