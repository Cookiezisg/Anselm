# EDGE-026 · allowed-tools 变更重置信任门

## Verification

Updating an installed skill with a changed `allowed-tools` set resets the trust gate: the old
approval is not carried to the new requested grant. The complementary no-semantic-change path is
also covered: when only the body/description changes and `allowed-tools` is unchanged, the user's
existing approval remains effective. Local drift still refuses a non-force update before either
path is applied.

Focused verification passed:

```text
go test ./internal/app/skill -run 'TestUpdateInstalled_DriftRefusalAndToolChangeResetsGate|TestUpdateInstalled_UnchangedToolsKeepApproval' -count=1  PASS
go test -race ./internal/app/skill -run 'TestUpdateInstalled_DriftRefusalAndToolChangeResetsGate|TestUpdateInstalled_UnchangedToolsKeepApproval' -count=1  PASS
```

## Five-level applicability

- L1 `pass`: allowed-tools 改变重置旧授权，未改变则保留，local drift 非 force 仍拒绝；测量法 `measure:edge026-skill-allowed-tools-reset`。
- L2 `na`: 本轮未为 skill update trust gate 单独启动真实 managed gateway 五通道 session。
- L3 `na`: focused/race 回归没有真实 App frame、SSE、backend journal 或 frontend console 观测面。
- L4 `na`: 本条验证授权状态迁移，不含独立视觉几何/动效/排版 surface。
- L5 `na`: trust gate 是 skill 更新后的状态协议，不是用户可导航入口；更新引导由对应 skill 旅程覆盖。
