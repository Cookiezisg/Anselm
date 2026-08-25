# EDGE-071 · approval 三种超时行为

## Verification

The timeout sweep is exercised with all three configured behaviors. reject resolves the approval
to no and prunes publish, approve resolves to yes and dispatches publish once, and fail marks both
the approval node and run failed. Each branch is asserted from durable state.

## Focused evidence

```text
cd backend
mise exec -- go test ./internal/app/scheduler \
  -run '^TestApproval_(TimeoutBehaviors|HumanVsTimeoutFirstWinsRace)$' -count=1
ok  github.com/sunweilin/anselm/backend/internal/app/scheduler

mise exec -- go test -race ./internal/app/scheduler \
  -run '^TestApproval_(TimeoutBehaviors|HumanVsTimeoutFirstWinsRace)$' -count=1
ok  github.com/sunweilin/anselm/backend/internal/app/scheduler

mise exec -- go test ./internal/app/scheduler -count=1
ok  github.com/sunweilin/anselm/backend/internal/app/scheduler
```

## Five-level applicability

- L1 pass: reject/no, approve/yes, and fail/failed durable outcomes plus publish side effects are asserted.
- L2 na: no independent formal five-channel App session was captured for this row.
- L3 na: no frame-timing evidence was captured for this row.
- L4 na: no visual artifact was captured for this row.
- L5 na: no Computer Use discoverability session was captured for this row.
