# EDGE-038 · :retry 重生成分支 · 修复后 L2

## 结论

`pass`。修复后，真实 App 的 `Retry` 会选择末个现行的真实 assistant 回答，而不会把
`compaction`/`marker` 这种 assistant-shaped synthetic row 当成回答。新版本的
`attrs.retryOf` 指向真实旧回答，旧回答的 `supersededBy` 指向新版本；压缩标记保持独立。

本证据只裁决 L2 数据真相与五通道一致性，不把 L3-L5 冒充为通过。

## Session

- Formal session: `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260830-160521`
- App binary: `/Users/sunweilin/Developer/Anselm/frontend/build/macos/Build/Products/Debug/anselm.app/Contents/MacOS/anselm`
- Screen recording: `screen.mov`, `227.523333s`; Computer Use 画面在动作前、生成中、收尾均可读
- Workspace: `ws_bf9aed46483af41a`; conversation: `cv_88b1ef075f48a164`
- 该 session 已由 `rig-down.sh` 收台，backend、ssetap、llmtap、App 和录屏进程均归零，journals 保留

## 真实 App 操作

1. 在真实 Anselm App 打开含历史 `Context compacted` 标记的对话。
2. 从最后一个真实回答的操作菜单点击 `Retry`，没有创建新的 user 消息。
3. 生成中 UI 显示 `thinking`，完成后显示新的回答和可用的 Retry 操作；压缩标记仍是独立时间线锚点。

## Durable 验证

`GET /api/v1/conversations/cv_88b1ef075f48a164/messages` 收尾返回的关键链为：

```text
msg_e95d53244b2fd3fe  assistant  retryOf=msg_a47649d7e916d11b  supersededBy=<empty>
msg_a286ded8668c4cae  assistant  compaction  supersededBy=<empty>
msg_a47649d7e916d11b  assistant  retryOf=msg_f18dfc7b6702beaf  supersededBy=msg_e95d53244b2fd3fe
msg_f18dfc7b6702beaf  assistant  compaction  supersededBy=msg_a47649d7e916d11b
```

`msg_a47649d7e916d11b` 是上一轮真实回答，拥有 reasoning/text/tool blocks；新版本正确
指向它并 supersede 它。`msg_f18dfc7b6702beaf` 是上一轮缺陷中被误选的 compaction marker，
本轮没有再被改写。重生成仍只有原有 user turn，没有追加用户问题。

## 五通道交叉证据

- REST/DB: 新旧 assistant 指针闭合，synthetic marker 不再被选择，消息均为 `completed`。
- SSE: `sse.jsonl` 共 137 条记录；messages 有三组 `open/delta/close`，durable seq 为
  `1..6` 且单调；notifications durable seq 为 `1`；没有 SSE error。
- Backend: `backend.log` 无 panic、FATAL、应用级异常红线；生成请求与收尾请求均成功。
- Frontend: `frontend.log` 无 `FlutterError`、`DartError`、`RenderFlex`、Unhandled 或断言错误。
- LLM wire: `llmtap` 记录 challenge 与两次 chat 请求，chat responses 均为 HTTP `200`；
  修复后的 retry 只发起一次新的 chat completion。

## 修复定位

`backend/internal/app/chat/retry.go` 的 `retryTargets` 现在排除只含
`compaction`/`marker` block 的 synthetic assistant row；
`backend/internal/app/chat/retry_test.go` 的
`TestRetryTargets_IgnoresSyntheticMarkers` 用真实 messages store 锁住该选择规则。
