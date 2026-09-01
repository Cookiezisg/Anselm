# EDGE-343 · 工具参数双线缆形 · 真实 App L4 验收

## 现场

- session=`/private/tmp/anselm-rig-formal-20260902-11/sessions/20260902-024745`
- 真实 Flutter macOS App 由 acceptance conductor 启动并连续录制；`screen.mov` 时长
  `196.840000s`，`rig-check.sh` 与 `rig-down.sh` 均通过，收台后没有 conductor-owned
  进程残留。
- workspace=`ws_c8d1de09906bc858`，数据目录为本次隔离台架专用目录；慢函数
  `edge343_slow_object_map` 仅用于制造可观察的真实等待，不属于产品数据。

## Stop-and-fix 边界

上一轮复查中曾在复用旧对话的画面看到 Activity 的 `Live` 行。该现象没有直接归因于
产品：冷启动后先复走快速调用，再用一个明确超过 1 秒的隔离 function 重跑，旧 `Live`
残留不再出现。为确认不是“看起来消失”而是真实收尾，本轮使用前端临时诊断构建追踪
tool call 与 tool result 的父子配对；诊断输出只进入本 session 的 `frontend.log`，诊断
代码已在正式记录前撤回，未改变产品行为或验收阈值。

## 产品路径与结果

1. 冷启动真实 App，打开隔离 workspace，确认没有未执行的 Activity `Live` 行。
2. 在 Chat 中以 `points=51/object` 和 `points=52/string` 各执行一次快速
   `edge343_object_map`；两次均显示已执行，Activity 仅保留对应的 `Ran` 历史。
3. 发送普通用户目标，让模型调用 `edge343_slow_object_map`，参数为
   `{"label":"object","points":53}`。该函数真实等待约 `1.033s`。
4. 等待期间，中心 transcript 明确显示 `Running function…`；Activity 显示
   `fn_e9e71245165e36c2 Live` 及 `Listening live · settle follows the truth`，用户能
   判断操作仍在进行，而不是误以为已经结束或界面卡死。
5. tool result 完成后，中心和 Activity 均收口为 `edge343_slow_object_map Ran`；
   Activity 汇总为 `2 touched · 2 executed`，历史的 `edge343_object_map Ran ×2`
   仍在，`Live` 行完全消失。Composer 恢复可输入，未出现第二个执行行、残留进度态或
   视口跳变。

## L4 产品判断（A4）

这条路径满足“超过 1 秒的操作必须有进度/状态文案”：等待期间状态为 Live，完成后
只转成 Ran，且转变由真实 tool result close 驱动。状态没有提前谢幕，也没有在完成后
继续占据 Live；Activity 数量、执行实体和中心结果保持同一事实，用户无需刷新、重开
对话或猜测是否仍在运行。

本格只验真实等待期间的状态反馈、收尾稳定性和视觉连续性；object/string 参数线缆
兼容性本身仍由 EDGE-343 L3 覆盖，不用 L4 重复宣称解析正确。

## 五通道交叉证据

- **帧 / Computer Use**：同一 `screen.mov` 记录冷启动、两次快速执行、慢执行期间的
  `Live` 状态和完成后的 `Ran` 状态；AX 现场同时观察到上述中心文案与 Activity 汇总。
- **Backend journal**：`backend.log` 共 `701` 行，包含三路 SSE 的完整生命周期；未发现
  应用级 panic、FATAL、ERROR 或 WARN，结束时按序 graceful shutdown。
- **SSE witness**：`sse.jsonl` 由独立 ssetap 同时连接 `messages`、`entities`、
  `notifications` 三流；慢函数的 entities open/close、messages tool-result close、
  touchpoint signal 和 assistant close 均存在。tool result 返回
  `{"ok":true,"output":{"label":"object","points":53},"errorMsg":"","elapsedMs":1033}`。
- **Frontend console**：日志没有 Flutter/Dart/RenderFlex/Unhandled/Exception 应用级
  红线；唯一系统级错误文本是已分类的 macOS IMK 输入法宿主诊断。`stage-trace` 是本轮
  已撤回的临时诊断构建输出，不是产品错误，也不作为产品日志契约的一部分。
- **LLM wire**：`llm.jsonl` 记录真实请求链路；对话 fixture 的 tool call/result 与
  session SSE 的 `points=53` 结果一致，未用前端显示反推函数已执行。

## 证据文件

- 录屏：`/private/tmp/anselm-rig-formal-20260902-11/sessions/20260902-024745/screen.mov`
- 后端：`/private/tmp/anselm-rig-formal-20260902-11/sessions/20260902-024745/backend.log`
- SSE：`/private/tmp/anselm-rig-formal-20260902-11/sessions/20260902-024745/sse.jsonl`
- 前端：`/private/tmp/anselm-rig-formal-20260902-11/sessions/20260902-024745/frontend.log`
- LLM：`/private/tmp/anselm-rig-formal-20260902-11/sessions/20260902-024745/llm.jsonl`
- 归属清单：`/private/tmp/anselm-rig-formal-20260902-11/sessions/20260902-024745/manifest.json`

本次没有发现可重复的产品缺陷，因此没有产品修复提交；没有修改 CODEX、阈值、锚点集、
五级标准或顺序门。
