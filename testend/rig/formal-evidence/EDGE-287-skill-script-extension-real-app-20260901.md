# EDGE-287 · run_skill_script 扩展名不支持

## 现场

- session: `/private/tmp/anselm-rig-formal-20260831-11/sessions/20260901-124541`
- 真实 App: macOS debug bundle，Chat 中通过 `@edge287-scripts` 激活 skill
- workspace/data: `ws_d86d861e565a12ff` / `/private/tmp/anselm-edge287-data`
- 录像: `screen.mov`, 172.606667s；五通道由同一 conductor manifest 归属

## 操作与结果

1. 通过真实 sidecar API 创建 `edge287-scripts`，并写入 bundled `scripts/probe.rb`。
2. 真实 App Chat 使用 Mention an entity 选择该 skill，输入“请执行这个 skill 里的 scripts/probe.rb，并告诉我脚本执行结果”，再发送。
3. 模型第一次调用缺少 `name`，工具校验立即拒绝并回灌可重试错误；没有进入 sandbox。
4. 模型补齐 `name=edge287-scripts` 后再次调用，`run_skill_script` 返回 `SKILL_SCRIPT_UNSUPPORTED`，明确说明 sandbox 只支持 `.py` / `.js` / `.mjs` / `.cjs`，其它脚本应使用 Bash。
5. 模型按该明确替代路径调用 host Bash，在 skill 目录执行 `ruby scripts/probe.rb`，实际输出 `probe`、退出码 `0`。这不是 sandbox 越界误执行，而是错误契约明确指向的 host 工具路径。

## 五通道交叉证据

- channel 1: `screen.mov` 已封口；真实 App 逐帧可见 skill mention、两张失败工具卡、扩展名说明、Bash 成功卡和最终 `probe` 输出。
- channel 2: `backend.log` 记录两次 `run_skill_script` 校验失败（缺 name、扩展名无 sandbox runtime），无 `ERROR`、`panic` 或 `FATAL`；Bash 工具正常收尾。
- channel 3: `sse.jsonl` 记录 messages/entities/notifications 三流连接；messages durable 帧分别记录 `run_skill_script` 的 `input validation failed` 与 `tool_result`，随后记录 Bash tool call、progress 和成功结果。
- channel 4: `frontend.log` 无 `FlutterError`、`DartError`、`RenderFlex`、`RenderBox` 或未处理异常；唯一系统级 IMK 日志不属于 Flutter/App 错误。
- channel 5: `llm.jsonl` 记录真实 managed gateway challenge/install/models 均为 `200`，并记录本回合每次 chat completion request/response；LLM wire 与 SSE 中的工具顺序一致。
- `rig-check.sh` 通过五通道归属；`rig-down.sh` 正常收台并封存录像，owned processes 已收尸。

## 判定

- L1=`F1`: focused/race regression 已证明不支持扩展名返回 `SKILL_SCRIPT_UNSUPPORTED`，不调用错误解释器。
- L2=`F2`: 真实 App、真实受管网关、SSE tap、backend journal、frontend console、LLM tap 和录屏属于同一封存 session；工具校验拒绝、替代 Bash、脚本输出和退出码五通道一致。
- L3=`A5`: 校验错误即时回灌，Composer 未冻结；用户可见原因、替代动作和最终结果在同一回合连续收口，无孤儿 streaming 状态。
- L4=`E1`: 错误与替代路径均可理解，明确说明发生了什么、支持边界和下一步；成功结果展示输出与退出码。首个缺参调用是模型输入错误，服务端在执行前诚实拒绝，未冒充成功。
- L5=`G1`: 用户从 skill mention 入口即可完成“调用 skill 脚本”的真实目的；不支持格式时工具反馈直接指向可用的 Bash 路径，而不是留下无下一步的死路。

未改阈值、法典、锚点、五级标准或顺序 gate。
