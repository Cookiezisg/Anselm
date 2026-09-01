# EDGE-331 限额面板载入失败：L3 真实 App 顺滑证据

- session: `/private/tmp/anselm-rig-formal-20260901-14/sessions/20260901-233914`
- recording: `screen.mov`, `118.508333s`, `3104x1848`, 60fps
- law: `A1`（可见反馈 ≤100ms）
- verdict: `pass` for L3

## Product path

1. 从真实 Chat 壳进入 Settings → Advanced limits。
2. 台架代理仅对第一次 `GET /api/v1/limits/schema` 返回 503；画面立即落到可解释的错误态，显示
   `Couldn't load limits`、面向用户的说明和 `Retry`，没有显示代理内部注入文本或 wire code。
3. 使用真实 Computer Use 点击 `Retry`。第二次 schema 请求真实转发并成功，随后 `GET /api/v1/limits`
   也成功；页面恢复 machine-wide 说明、Reset 按钮和五组限额字段。

## Measurement

从封口录像抽取 60fps、776px 宽的确定性分析帧：

```text
进入 Advanced limits：action frame 71 → first visible feedback frame 72 = 16.7ms
Retry：action frame 76 → first visible feedback frame 77 = 16.7ms
Retry 后最终列表重排：frame 86 → 87，稳定态随后无超过阈值的变化
```

对应分析目录为 session 下的 `evidence/frames-error-60-small/` 与
`evidence/frames-retry-60-small/`；`measure diff` 的可见变化仅落在用户操作后的面板区域，未发现
持续抖动、反复请求造成的闪回或输入冻结。两次用户动作的首个可见反应均满足 A1 的 100ms 门槛。

## Five-channel cross-check

- **frames / Computer Use**: 真实 App 观察到错误标题、说明、Retry，以及 Retry 后完整限额面板；AX 同时读到错误和恢复后的字段。
- **backend**: `backend.log` 共 `431` 行，无应用级 `WARN`、`ERROR`、`panic`、`fatal`；health、schema 重试和 limits 请求均可追溯。
- **SSE**: `sse.jsonl` 记录 messages/entities/notifications 三条真实连接并正常 EOF；本只读设置路径不产生业务 durable 事件，不伪造 seq。
- **frontend console**: `frontend.log` 仅含正常 Flutter VM 行，无 Flutter/Dart、RenderFlex、RenderBox、Unhandled、Exception 或 overflow。
- **LLM wire**: managed gateway challenge/install/models 均 HTTP `200`；设置页不应调用模型，本场景没有伪造 completion。
- **app proxy**: `appproxy.jsonl` 记录一次 503 failure，随后同一路径一次 forward；失败只发生一次。
- **rig lifecycle**: `rig-check.sh` 五通道和进程归属全通过；`rig-down.sh` 完成 118.508333 秒录像并收台。

## Verdict

`L3 pass (A1)`。失败反馈和 Retry 反馈都在首帧给出可见响应，真正恢复由第二次成功 schema/limits 请求
和恢复后的字段共同证明；L4 craft 与 L5 discoverability 不在本格重复结算。
