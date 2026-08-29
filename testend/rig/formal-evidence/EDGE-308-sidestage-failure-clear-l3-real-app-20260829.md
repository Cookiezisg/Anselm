# EDGE-308 侧幕失败行清除：L3 真实 App 帧级证据

- session: `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260829-164838`
- data: `/private/tmp/anselm-data-edge308-l3-20260829-r1`
- workspace: `ws_9268414dacf86f1f`
- function: `fn_8a0b5736890beaae` (`edge308_failure_l3`)
- conversation: `cv_3de2424359c10228`
- recording: `screen.mov`, `275.795000s`, App/window `53876/6386`
- frame samples: `evidence/EDGE-308-l3-failed.png`, `evidence/EDGE-308-l3-cleared.png`

## Product path

1. 真实 App 完成 onboarding 后，通过 Chat 先发现 `run_function`，再只调用一次故意抛出 `RuntimeError('edge308 intentional failure')` 的 Function；没有重试或第二次执行。
2. 失败返回后，中心 transcript 保留完整的 Function 详情、源代码、错误类型、错误文本和执行耗时；Activity 侧幕将同一活动显示为 `Failed`，带红点和 `Run failed · inspect the error below`。
3. 用户清除失败活动后，侧幕同一行变为无红点的 `Viewed` 普通历史行；中心 transcript 的 traceback、失败结果和执行审计没有被删除，也没有产生新的 tool call。

## Frame review

- `t≈194s` 的固定帧显示失败态：Activity 侧幕有 `1 touched · 1 executed`、目标 Function、`Failed` 和红点；中心仍可读失败结果与 `RuntimeError`。
- `t≈225s` 的固定帧显示用户清除后的状态：同一目标行变为 `Viewed`，红色失败驻留消失；中心内容和错误审计保持不变。
- 清除是一次单向状态收口，没有 Live/Failed/View 之间的自动往返、重复执行、布局跳回或消息内容丢失。失败活动的退出动作不会改变真实执行结果。

## Five-channel cross-check

- **frames**: 窗口专属 `screen.mov` 与两张固定帧覆盖失败驻留和清除后的历史态。
- **backend**: `backend.log` 共 `371` 行；没有应用级 `WARN`、`ERROR`、`panic` 或 `FATAL`。
- **SSE**: `sse.jsonl` 共 `178` 行；messages durable seq=`1..30`、entities=`1..4`、notifications=`1..5`，三路均连续无 gap。messages 线同时保留 `run_function` tool call、`ok:false` tool result 与失败正文。
- **frontend**: `frontend.log` 共 `4` 行；只有启动/宿主诊断，没有 Flutter、Dart、RenderFlex 或 Unhandled runtime 红线。
- **LLM wire**: `llm.jsonl` 共 `22` 行；managed challenge/install/models 与真实 Chat completion 请求均为 HTTP `200`，调用参数含精确 Function ID，非 fixture 回放。
- **durable truth**: SQLite 的 `function_executions` 中仅有一条目标 Function 执行，状态为 `failed`、耗时 `85ms`，错误为完整 traceback；消息块保留一次 `run_function` 调用及 `ok:false` 结果。
- **rig lifecycle**: `rig-check` 五通道通过；`rig-down` 正常停止 App、backend、ssetap、llmtap 和 recorder，录屏可读且 journals 保留。

## Judgment

- **L3 `pass (B2)`**: 真实失败活动的错误视觉状态、行级清除和清除后的稳定历史态均经过逐帧检查；既有内容没有非用户触发的跳位，清除动作单向、可解释，且不破坏 transcript 或 durable execution truth。
- 本证据只判定失败驻留的帧级稳定性，不把 Function 错误文案的整体视觉 craft 或盲走可发现性冒充为 L4/L5。
