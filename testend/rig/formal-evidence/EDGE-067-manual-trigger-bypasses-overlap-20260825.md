# EDGE-067 · 手动 :trigger 绕过 overlap

## Verification

The shared manual StartRun throat used by HTTP :trigger and chat trigger_workflow does not
consult real-firing overlap policy. Under both replace and buffer_one, two concurrent manual
runs enter the slow action together and both complete after release. The real-firing inbox remains
the only path where those overlap policies apply.

## Focused evidence

```text
cd backend
mise exec -- go test ./internal/app/scheduler \
  -run '^TestManualTriggerBypassesOverlapPolicies$' -count=1
ok  github.com/sunweilin/anselm/backend/internal/app/scheduler

mise exec -- go test -race ./internal/app/scheduler \
  -run '^TestManualTriggerBypassesOverlapPolicies$' -count=1
ok  github.com/sunweilin/anselm/backend/internal/app/scheduler

mise exec -- go test ./internal/app/tool/workflow \
  -run '^TestTriggerWorkflow_' -count=1
ok  github.com/sunweilin/anselm/backend/internal/app/tool/workflow

mise exec -- go test ./internal/app/scheduler -count=1
ok  github.com/sunweilin/anselm/backend/internal/app/scheduler
```

## Five-level applicability

- L1 pass: both replace and buffer_one manual cases enter two runs concurrently and finish with two completed runs.
- L2 na: no independent formal five-channel App session was captured for this row.
- L3 na: no frame-timing evidence was captured for this row.
- L4 na: no visual artifact was captured for this row.
- L5 na: no Computer Use discoverability session was captured for this row.
