# EDGE-025 · skill 信任门未批时预授权为空

## Verification

An installed skill's `allowed-tools` are a requested grant, not an automatic permission. Before
`:approve-tools`, activating the skill still injects its body and records the active skill name,
but the agent-state pre-authorization set remains empty; a dangerous tool not separately approved
therefore still goes through the per-call human gate. After explicit approval, activation installs
the declared pre-authorization.

Focused verification passed:

```text
go test ./internal/app/skill ./internal/app/loop -run 'TestTrustGate_WithholdsUntilApproved|TestDispatchWithGate_NotPreApprovedGated' -count=1  PASS
go test -race ./internal/app/skill ./internal/app/loop -run 'TestTrustGate_WithholdsUntilApproved|TestDispatchWithGate_NotPreApprovedGated' -count=1  PASS
```

## Five-level applicability

- L1 `pass`: 未批准 installed skill 正文/active 名称保留、预授权为空，危险调用仍逐次 gate；测量法 `measure:edge025-skill-trust-gate`。
- L2 `na`: 本轮未为 skill 安装与信任门单独启动真实 managed gateway 五通道 session。
- L3 `na`: focused/race 回归没有真实 App frame、SSE、backend journal 或 frontend console 观测面。
- L4 `na`: 本条验证 skill 信任状态，不含独立视觉几何/动效/排版 surface。
- L5 `na`: 信任门是 skill 安装后的状态协议；入口导航与用户理解由对应 skill 旅程覆盖。
