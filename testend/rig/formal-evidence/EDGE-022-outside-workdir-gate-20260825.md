# EDGE-022 · 驻地越界写人闸

## Verification

With a conversation work directory mounted, a `Write` call targeting an absolute path outside
that root is gated even when the model self-reports `danger=safe`. The surfaced payload contains
`outsideWorkDir=true`; denial returns the broker deny feedback and the tool is not executed.
The same behavior cannot be bypassed by `approve_always` or an active skill's `allowed-tools`
pre-authorization. Writes inside the root remain ungated when otherwise safe.

Focused verification passed:

```text
go test ./internal/app/loop -run 'TestDispatchWithGate_(OutsideWorkDirForcesGate|OutsideWorkDirIgnoresApproveAlways|OutsideWorkDirIgnoresSkillPreApproval)' -count=1  PASS
go test -race ./internal/app/loop -run 'TestDispatchWithGate_(OutsideWorkDirForcesGate|OutsideWorkDirIgnoresApproveAlways|OutsideWorkDirIgnoresSkillPreApproval)' -count=1  PASS
```

The tests exercise the same `fspath.ExpandIn` resolution used by the writer and verify that the
residency fact overrides both model self-report and tool/skill bypasses.

## Five-level applicability

- L1 `pass`: 驻地外写入强制人闸并带 `outsideWorkDir=true`，拒绝时不执行；测量法 `measure:edge022-outside-workdir-gate`。
- L2 `na`: 本轮未为驻地越界写单独启动真实 managed gateway 五通道 session。
- L3 `na`: focused/race 回归没有真实 App interaction frame、SSE、backend journal 或 frontend console 观测面。
- L4 `na`: 本条验证路径安全事实与闸时序，不含独立视觉几何/动效/排版 surface。
- L5 `na`: 驻地越界写闸是执行安全协议，不是用户可导航入口；可发现性由对应 chat/workdir 旅程覆盖。
