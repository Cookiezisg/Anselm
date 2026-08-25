# EDGE-024 · 驻地只闸写不闸读

## Verification

With a conversation work directory mounted, reading outside that directory remains allowed. The
residency is a zoom for writes, not a jail for inspection: both `Read` and `Grep` are non-writing
tools and do not enter the path gate for an absolute outside path.

Focused verification passed:

```text
go test ./internal/app/loop -run 'TestDispatchWithGate_NonWriterToolNeverPathGated' -count=1  PASS
go test -race ./internal/app/loop -run 'TestDispatchWithGate_NonWriterToolNeverPathGated' -count=1  PASS
```

The regression covers both named read/search tools and asserts no interaction is surfaced and the
tool executes normally.

## Five-level applicability

- L1 `pass`: 挂载驻地后 Read 与 Grep 对驻地外绝对路径均不设闸并正常执行；测量法 `measure:edge024-read-outside-workdir-no-gate`。
- L2 `na`: 本轮未为驻地外读取单独启动真实 managed gateway 五通道 session。
- L3 `na`: focused/race 回归没有真实 App frame、SSE、backend journal 或 frontend console 观测面。
- L4 `na`: 本条验证读写权限语义，不含独立视觉几何/动效/排版 surface。
- L5 `na`: 这是驻地权限协议边界，不是用户可导航入口；发现路径由对应 chat/workdir 旅程覆盖。
