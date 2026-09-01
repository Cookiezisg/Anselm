# EDGE-352 | 分叉携带附件与 subagent 树 | L3 真实 App 证据

## 判定

L3 通过，法典 `A4`：用户目标“带着附件和实体上下文分叉，并继续沿用这段工作”在真实 App 中完成，持久数据、SSE 和 LLM 线缆互相一致。

## 真实路径

正式 session=`/private/tmp/anselm-rig-formal-20260902-33/sessions/20260902-060049`。全新隔离 workspace 中，真实 App 上传
`edge352-reference.txt`，提及一次 `greet`，发送要求只派生一个 general-purpose subagent 的普通用户目标。
真实 subagent 返回摘要后，从用户可见的 `Fork from here` 入口分叉。新线程保留附件卡、单个 `@greet`、subagent
树和回答；源线程仍在 rail 中可回到。

## 五通道互证

- **录屏 / Computer Use**：`screen.mov`=`200.926667s / 3104x1848 / 60fps`；观察到上传、提及、派生、完成、分叉和血缘回源。
- **backend**：真实 `:fork` 返回 `201`，新线程读取消息 `200`；无应用级 WARN/ERROR/panic。
- **SSE**：messages durable seq `1..28` 连续，notifications durable seq `16..18` 连续；包含 source turn、subagent/tool 结果和 fork created 信号。
- **frontend console**：无 Flutter/Dart/PlatformException/RenderFlex/Unhandled/Exception/overflow 红线，仅已分类 IMK 宿主诊断。
- **LLM wire**：真实受管网关 challenge/install/models 全 `200`，四次 chat completion 全 `200`；其中一轮真实请求包含 `Subagent`，没有第二个直接工具调用。

## 结论

附件引用、实体提及和 subagent 子树没有在分叉时丢失或重复，用户可以继续在新线程工作。
