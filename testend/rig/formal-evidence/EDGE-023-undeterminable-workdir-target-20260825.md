# EDGE-023 · 越界判定路径解不开

## Verification

When a conversation has a mounted work directory but a `Write` call has malformed JSON or no
`file_path`, the loop does not silently trust a `danger=safe` self-report. It falls back to the
ordinary danger interaction without falsely labeling the request `outsideWorkDir`. If the user
approves, the real `Write` validator rejects the malformed call with `file_path is required`; no
filesystem side effect is treated as a success. Invalid provider JSON remains visible as a string
in the approval payload so the prompt is never blank.

Stop-and-fix performed:

- Added an explicit indeterminable work-directory target state, distinct from an outside target.
- Allowed that state to reach the human gate before the final tool validation, while preserving
  validation-before-gate for determinable mutations.
- Made malformed JSON safe to render in the approval payload.

Focused verification passed:

```text
go test ./internal/app/loop -run 'TestDispatchWithGate_(OutsideWorkDirForcesGate|OutsideWorkDirIgnoresApproveAlways|OutsideWorkDirIgnoresSkillPreApproval|UndeterminableTargetFallsBackToDangerGate|ApprovedUndeterminableTargetReachesExecuteValidation)' -count=1  PASS
go test -race ./internal/app/loop -run 'TestDispatchWithGate_(OutsideWorkDirForcesGate|OutsideWorkDirIgnoresApproveAlways|OutsideWorkDirIgnoresSkillPreApproval|UndeterminableTargetFallsBackToDangerGate|ApprovedUndeterminableTargetReachesExecuteValidation)' -count=1  PASS
```

## Five-level applicability

- L1 `pass`: 不可判定目标不静默放行，ordinary danger gate 有可解释 payload，批准后真实 Write 校验拒绝；测量法 `measure:edge023-undeterminable-workdir-target`。
- L2 `na`: 本轮未为畸形 Write args 单独启动真实 managed gateway 五通道 session。
- L3 `na`: focused/race 回归没有真实 App interaction frame、SSE、backend journal 或 frontend console 观测面。
- L4 `na`: 本条验证参数可解释性与安全闸时序，不含独立视觉几何/动效/排版 surface。
- L5 `na`: 这是工具参数失败边界，不是用户可导航入口；交互可发现性由对应 chat/workdir 旅程覆盖。
