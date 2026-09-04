# EDGE-293 · 删被依赖实体：真实 App 五通道验收

## 正式 session

- session=`/private/tmp/anselm-rig-formal-20260905-edge293/sessions/20260905-005633`
- data=`/private/tmp/anselm-data-edge-dependency-20260903c`
- workspace=`ws_342c9fbb7f746bfa`
- window=`16308`；录屏=`3016x1758 / 60fps / 131.281667s`
- 稳态画面=`sessions/20260905-005633/evidence/EDGE-293-post-delete-full-wrap.png`

## 场景与用户结果

真实 App 在 Entities 中打开 `edge293_full_fn`，其确认框现读关系图并明确列出三个受影响 Agent。用户确认最终 `Delete` 后，App 回到 Entities Overview：Function=0、Agent=9、Relationship graph=0 entities / 0 relations。Notifications 中出现一条聚合依赖告警，列出三个 Agent；不是静默删除，也没有多条重复告警。

## 五通道证据

- **Channel 1 / Computer Use + 录屏**：AX 树记录了确认框完整文案：`edge293_full_fn` 被 `edge293_full_agent_c/b/a` 使用，删除后需要修复；最终录屏显示 Function=0、Agent=9、关系图为空。通知中心中主句自然换行，`edge293_full_agent_a/b/c` 三个依赖者名称逐行完整可读，没有省略号或裁切。首轮录屏中发现窄 rail 截断，已保留红证据；修复为重要告警不截断的自然多行布局，widget 回归锁定该行为。
- **Channel 2 / backend journal**：关系清边 `removed=3`；DELETE 返回 `204`；删除后 `GET /functions` 返回空数组、`GET /relgraph` 返回空 nodes/edges、三项新建 Agent 仍在列表；backend 无应用级 `WARN/ERROR/panic`。
- **Channel 3 / independent SSE witness**：notifications 记录 `seq=7 sandbox.env_deleted`、`seq=8 function.deleted`、`seq=9 relation.dependency_broken`；`seq=9` 的 `dependents` 恰为三个 Agent，且只产生一条聚合关系告警。此前的 `seq=1..6` 是该场景创建 Function、环境和三个 Agent 的正常 durable lifecycle 帧。
- **Channel 4 / frontend console**：`frontend.log` 只有 App 启动行和 Dart VM service 行；无 `FlutterError`、`DartError`、`RenderFlex`、`RenderBox` 或未处理异常。`measure latency` 以删除反馈动作帧为起点测得首个明显画面变化 `800ms`；`rig-check.sh` 在真实窗口录制期间五通道全绿，`rig-down.sh` 正常封口。
- **Channel 5 / LLM wire**：本删除路径不触发模型调用；llmtap 完成 ready，未伪造上游调用。无 LLM 事实需要声明。

## 判定

这次正式复跑证明 L2 的后端/DB/SSE/App 状态闭合，L3 的可见收口及时且无卡死，L4 的高价值影响文案完整可读，L5 的入口与确认路径无需额外文档即可走通。首轮截断录屏作为红证据保留，不覆盖为绿。
