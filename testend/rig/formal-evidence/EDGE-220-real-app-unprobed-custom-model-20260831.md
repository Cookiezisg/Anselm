# EDGE-220 · 未探测/custom 模型：真实 App L2-L5 复核

## 结论

`L2`、`L3`、`L4` 通过；`L5` 记为明确适用性 `na`，不是 waiver。未探测的 custom
model 没有进入“已探测模型”选择器，当前 App 没有一个用户可发现的入口去直接输入并选择
任意未探测 modelId；该低层 escape hatch 仍由 API/持久化合同保留，调用失败必须大声收口。

## 正式 session

- session=`/private/tmp/anselm-rig-formal-20260831-11/sessions/20260831-121247`
- workspace=`ws_db8af25193ebeccf`，data=`/private/tmp/anselm-rig-formal-20260831-11/data-edge220`
- custom key=`aki_74d1e0912912c877`，展示名=`EDGE220 Unprobed`；密钥只使用受控 fixture，未写入证据
- custom base URL=`http://127.0.0.1:65534`，故意无监听；modelId=`edge220-unprobed-model`，options 为空
- managed gateway 的 challenge/proof 与自动标题请求均经 llmtap；受管 install 未被 custom 失败替换
- `rig-check` 五通道通过，`rig-down` 后 conductor/backend/App/两类 tap/recorder 进程归零，录屏=`131.453333s`

## L2 · 真实状态与数据真相

通过真实 REST 写入空 options 的 ModelRef 后，SQLite 与 `GET /workspaces` 保留：

```text
defaultDialogue.apiKeyId = aki_74d1e0912912c877
defaultDialogue.modelId = edge220-unprobed-model
defaultDialogue.options = absent/empty
```

`GET /model-capabilities` 不虚构该未探测模型的能力；只返回 managed `anselm-auto`。真实 App
的 Models & keys 页面仍显示 `edge220-unprobed-model` 为 Dialogue 默认，但不会把 custom 未探测
模型伪装成已探测目录项。证据帧=`evidence/edge220-unprobed-picker-boundary.png`。

## L3 · 失败反馈与线缆

真实 App 从新 Chat 发送 `Please reply with exactly EDGE220FIXED.` 后，唯一 assistant 终态为
error。messages SSE 同一 durable close 同时记录：

```text
status=error
errorCode=LLM_STREAM_ERROR
errorMessage=llm.custom: do: Post "http://127.0.0.1:65534/chat/completions": dial tcp 127.0.0.1:65534: connect: connection refused
```

UI 修复前的原始错误已由前一段真实 session=`20260831-120859` 的录屏与 backend/SSE 记录保留；
修复后 fresh session 的主时间线只显示：

```text
The model service didn't finish this response. Try again; if the request is large, send it in smaller parts.
```

原始码、URL、socket 细节仍在 durable/backend/SSE 诊断面，没有被吞掉，也没有 fallback 成 managed
回答。前端定点 widget 回归覆盖 `LLM_STREAM_ERROR` 不泄漏 gateway details。

## L4 · 视觉复核

最终帧=`evidence/edge220-human-copy-green.png`。失败行在正文列内稳定呈现，红色提示与用户消息有
清晰层级，未出现原始 URL 导致的长行溢出；Composer、左侧会话列表与主内容区无 clipping、overlap
或残留 loading。选择器边界帧保留已探测目录只含 `Anselm Auto` 的诚实状态。

## L5 · 适用性边界

`na→note:`：当前产品选择器只接受 probe-OK 的 capability rows；对 custom 未探测 key/model
没有用户可发现的任意 modelId 输入入口。因此本格的“未探测模型可保存”是面向 API/持久化调用方的
兼容性 escape hatch，不是一个独立的 App discoverability journey。若未来在 App 公开 custom
modelId 输入或选择入口，必须撤销本项 `na` 并重新跑 L2-L5；不能沿用本证据。

## 五通道交叉核验

- screen：窗口录屏与两个 Computer Use 关键帧属于本 session
- backend：backend journal 非空，无 panic/ERROR/FATAL；SQLite durable ModelRef 与 error turn 一致
- SSE：notifications/messages/entities 三流均连接；消息 user open/close、assistant open/error close 完整
- frontend：只有已知 macOS `IMKCFRunLoopWakeUpReliable` 平台诊断，无 Flutter/Dart 应用红线
- LLM wire：managed challenge 与自动标题请求均 `200`；custom dead endpoint 是目标故障注入，不伪装为 managed 失败

