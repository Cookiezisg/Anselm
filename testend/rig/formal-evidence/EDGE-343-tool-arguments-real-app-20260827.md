# EDGE-343 · 工具参数双线缆形 · 真实 App 五通道验收

## 范围与环境

- 真实 Flutter macOS App 由 acceptance conductor 启动并录制；本次有效 session 为
  `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260827-215555/`。
- 同一 session 托管 backend、三路独立 SSE witness、LLM witness、frontend console 和连续录屏；
  运行中 `rig-check.sh` 五通道通过，收台后 `rig-down.sh` 无残留。
- 对话模型是本机隔离的 OpenAI-compatible `qwen-plus`，模型探测结果为 `tools=true`；函数
  `edge343_object_map` 为真实创建并执行的 Anselm function，未使用 fixture transcript。

## 正向路径：同一用户目的，两种参数线缆

1. App 模型菜单真实显示并选择 `qwen-plus · EDGE-342 local chat-only`；Composer 可用。
2. 第一轮用户请求要求调用 `edge343_object_map`，points=`6`、label=`object`。App 显示一次
   `已运行函数 edge343_object_map`，耗时 `124ms`，函数结果为
   `{"label":"object","points":6}`，随后助手显示“工具参数已归一化并执行成功”。
3. 第二轮用户请求要求调用同一函数，points=`7`、label=`string`。App 显示第二次真实执行，
   耗时 `31ms`，函数结果为 `{"label":"string","points":7}`，随后同样完成助手回复。
4. provider wire `/private/tmp/edge343-provider-wire.jsonl` 的两次实际 ReAct 请求对应的
   assistant tool call 参数分别为：
   - 原生对象：`{"args":{"label":"object","points":6},...}`
   - JSON 字符串：`{"args":"{\"label\":\"string\",\"points\":7}",...}`
   两种形态都穿过真实模型适配、loop 归一化、function sandbox、durable block 和 UI，未靠
   前端伪造结果。
5. messages SSE durable sequence 连续推进：第一轮 tool call `seq=4..5`、tool result
   `seq=6..8`、助手文本 `seq=9..10`，第二轮 tool call `seq=15..16`、tool result
   `seq=17..19`、助手文本 `seq=20..21`；工具结果中的实际输出与 App 卡片、provider
   wire 一致。entities SSE 记录 function run completed，messages SSE 记录一次聚合
   touchpoint，计数为 `2`。
6. backend journal 的对应执行无应用级 `WARN`/`ERROR`/panic/fatal；frontend console 无
   Flutter/Dart/RenderFlex/Unhandled/Exception 红线，仅保留已知 macOS IMK/TSM 宿主通知。

## 判定

- 本条 L2 通过：两种真实工具参数形态均完成用户目标，且 UI、function 输出、SSE durable
  真相、LLM wire、backend journal、frontend console 与录屏相互交叉验证。
- L1 原有 focused 契约证据保留：
  `testend/rig/formal-evidence/EDGE-343-tool-arguments-two-wire-shapes-20260826.md`。
- L3-L5 不由这一条两轮成功对话冒充；若要声明跨场景顺滑、craft 或可发现性，仍须单独
  依据 CODEX 法条和测量证据入账。
