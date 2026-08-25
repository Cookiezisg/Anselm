# SURF-104 · stage/workflow · 正式调查记录

## 受验对象

`SURF-104 stage/workflow`：工作流创建/编辑舞台是否把已闭合的 graph ops 变成真实画布、节点/边计数和判别式信息，并在落定后以新鲜实体真相呈现，而不是把图变更误报为元数据编辑。

## 首轮真实缺陷

首轮 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260825-075835`。
真实 managed gateway 返回的 `edit_workflow` 参数中，`ops` 是精确 JSON 编码的数组字符串；后端按既定窄兼容契约正确接受并写入 v2，但前端只读取 `PartialJsonSession.arrayItemsAt(['ops'])`，因此空数组被错误分类为 `metaOnly`。真实 App 显示“仅改元数据(图未变)”，而 REST/后端真相已经是 `+1 节点、+1 边`。该红事实不计入绿账。

## Stop-and-fix

在 `tool_card_workflow.dart` 增加 `workflowOpsFromArgs`：优先读取原生数组；在数组缺失且 `ops` 已闭合为字符串时，仅尝试解析合法 JSON 数组，并按 `PartialJsonSession` 实例缓存；部分/畸形字符串继续保持空，避免把未闭合流误当成最终 graph。graph builder、delta classifier、workflow stage 的旧图重放和判别式抽屉统一走同一 seam，避免摘要与舞台各自解释参数。

focused Flutter suite：
`tool_card_workflow_test.dart stages_w3_test.dart scene_from_truth_test.dart stage_alignment_test.dart`，`41/41` 通过；新增回归覆盖字符串化 `ops` 仍生成节点/边且 `metaOnly=false`。

## 修复后真实 App

绿色 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260825-080352`，全新数据目录、真实 Flutter macOS App、真实 Anselm managed gateway、Computer Use、独立 SSE witness、LLM tap、连续录屏。

真实模型再次产生字符串化 `ops`；后端写入 workflow v2。修复后的 App 活动卡明确显示 `+1 节点 · +1 边` 与 `增量变换(图整体见实体面板)`；打开“活动”并展开 `surf104_graph` 后，真实画布显示 `节点 2 · 边 1`，两个节点为 `start/触发`、`run/动作`，视觉连线为 `start → run`。这证明 graph 变化已进入产品舞台，不是只修正文案。实体真相与画布一致，且没有重复 mutation。

## 五通道事实

- Screen：`screen.mov` 已正常封口，录制时长 `243.491667s`；Computer Use 观察了活动卡、侧幕和最终画布。
- Backend：`backend.log` 无 WARN/ERROR/panic/fatal/unknown；workflow v2 与触点 `surf104_graph` 已由 REST/SQLite 事实核对。
- SSE：`sse.jsonl` 真实连接 messages/entities/notifications；本场 durable messages `1..15`、notifications `16..19` 单调唯一、无 gap，`seq=0` delta 不计入 durable。
- LLM wire：managed proof challenge/install/models 与 4 次 chat completion 全部 HTTP 200。
- Frontend：仅正常 Dart VM 启动和已知 macOS IMK 平台噪声；无 Flutter/Dart exception、RenderFlex/布局溢出、Unhandled 或 SEVERE 红线。
- `rig-check.sh`、`rig-down.sh` 通过；D1 attribution、health、三流、LLM tap、App 窗口和录制均由台架检查，收台后无残留进程。

## 产品裁决

首轮是明确产品缺陷：后端真图变化却在前端被说成“图未变”。修复后同一真实 provider 形状重跑，活动摘要、侧幕画布、节点/边数量和实体 v2 一致，用户目标达成，SURF-104 可进入五级账本。
