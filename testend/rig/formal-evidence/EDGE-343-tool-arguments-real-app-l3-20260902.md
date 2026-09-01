# EDGE-343 · 工具参数双线缆形 · 真实 App L3 验收

## 现场

- session=`/private/tmp/anselm-rig-formal-20260902-09/sessions/20260902-023042`
- 真实 Flutter macOS App 由 acceptance conductor 启动并连续录制；`rig-check.sh` 在运行中
  确认 backend、App/window、三路 SSE witness、managed LLM tap 和屏幕录制均归属于本次
  session，`rig-down.sh` 收台无残留。
- App 使用真实创建的 function `edge343_object_map` 和本机隔离的 Qwen
  OpenAI-compatible 模型；managed Anselm gateway 仍承担安装/探测链路，聊天模型请求由
  独立本机 fixture 驱动，未使用用户数据或主仓库数据。

## Stop-and-fix

第一版临时 fixture 把历史消息中的 `tool` 当成当前阶段，并用全局调用计数器决定参数形状，
造成一次错误的测试台结果。未将其归因于产品；已把阶段判定改为当前消息尾部，并按当前用户
输入解析 `points` 与 `label`，重新启动全新隔离台架和全新 workspace。最终证据只取本文件
所列的干净对话，不取修复前请求。

## 产品路径与实际结果

1. 在 Settings → Models & keys 刷新模型列表，进入 Dialogue → Change → External model，
   选择 `EDGE343 final local toolargs` 与 `qwen3.7-plus`，Apply 后回到 Chat。
2. Chat 模型菜单显示 `qwen3.7-plus`，Composer 可用。
3. 第一轮输入 `run edge343_object_map with points 21 and label object`。App 依次显示
   `Searched function`、`Ran function edge343_object_map · 110ms` 和成功回答；函数实际
   结果为 `{"label":"object","points":21}`。
4. 第二轮输入 `run edge343_object_map with points 34 and label string`。App 同样完成
   搜索、执行和回答；函数实际结果为 `{"label":"string","points":34}`，耗时 `33ms`。
5. 两轮结束后 Composer 回到可输入状态；最终画面中消息气泡、工具卡片、回答正文和底部
   Composer 没有遮挡、裁切、重叠、残留发送态或视口跳变。

## L3 顺滑判定（A1）

同一对话中的两种参数形状都走完了相同的用户可见路径：搜索目标、展示工具调用、等待真实
function sandbox 返回、展示结果并完成 assistant 收尾。两轮之间没有错误态、重复提交、
输入框锁死或需要用户刷新页面；第二轮工具耗时明显低于首轮冷启动，但 UI 没有产生布局
跳变或不一致的完成状态。

## 五通道交叉证据

- **帧 / Computer Use**：通过 `@oai/sky` 真实操作设置页、模型菜单、Composer 和 Chat；
  `screen.mov` 连续记录完整路径，最终 AX 状态同时包含两条用户消息、两组搜索/执行卡片
  和两条成功回答。
- **Backend journal**：session 的 backend journal 记录两次消息 POST=`202`，对应每轮的
  loop 收尾为 completed；未发现应用级 panic、FATAL、ERROR 或 WARN。
- **SSE witness**：独立 `ssetap` 同时连接 messages、entities、notifications。当前干净
  对话为 `cv_ada761b786fb2c12`：第一轮 user `seq=2`、search `5/7`、run `9`、result
  `12`、text `14`、assistant close `15`；第二轮 user `seq=17`、search `20/22`、run
  `24`、result `27`，随后 text/assistant close 为 `29/30`。每个 run 同时在 entities
  流留下 completed 记录。
- **Frontend console**：`frontend.log` 无 Flutter/Dart/RenderFlex/Unhandled/Exception
  应用级红线；唯一 error 文本是已知 macOS IMK 宿主诊断，不是 Flutter 应用错误。
- **LLM wire**：独立 `/private/tmp/anselm-edge343-wire.jsonl` 的最终两次调用记录真实
  `run_function` 参数：
  `{"args":{"label":"object","points":21},...}` 与
  `{"args":"{\"label\":\"string\",\"points\":34}",...}`；后续 tool result
  分别返回相同的 object/string 归一化结果。该线缆证据与 SSE、backend 和 App 卡片相互
  一致。

## 判定边界

- 本文件只声明 `EDGE-343` 的 L3 顺滑性，依据 CODEX `A1`；不以这两轮对话冒充 L4 craft
  或 L5 discoverability。
- 旧的 L2 证据仍保留在
  `testend/rig/formal-evidence/EDGE-343-tool-arguments-real-app-20260827.md`；本次不改写
  旧记录。
