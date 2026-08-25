# EDGE-076 · 收割闸破了会造永久停滞子图

## Verification

The first-wins loser must not call `CancelParkedNodes`. The deterministic natural-terminal seam makes
the dangerous counterexample reproducible: the run becomes failed and replayable, while its parked
approval remains `parked` and therefore decidable. This preserves the only state from which
`:replay` can recover the run; incorrectly writing `cancelled` onto the node would create a row
that neither the failed-run replay deletion nor the cancelled-run execution path can clear.

## Focused evidence

```text
cd backend
mise exec -- go test ./internal/app/scheduler \
  -run '^TestKillWorkflow_GuardLoser_LeavesParkedRowAlone$' -count=1
ok  github.com/sunweilin/anselm/backend/internal/app/scheduler

mise exec -- go test -race ./internal/app/scheduler \
  -run '^TestKillWorkflow_GuardLoser_LeavesParkedRowAlone$' -count=1
ok  github.com/sunweilin/anselm/backend/internal/app/scheduler

mise exec -- go test ./internal/app/scheduler \
  -run '^(TestKillWorkflow_GuardLoser_LeavesParkedRowAlone|TestCancelRun_GuardLoserLeavesNaturalTerminalAlone)$' -count=1
ok  github.com/sunweilin/anselm/backend/internal/app/scheduler
```

## Five-level applicability

- L1 pass: a guard loser preserves the failed run and its parked approval, preventing an unreplayable mixed-status subgraph.
- L2 na: no independent formal five-channel App session was captured for this row.
- L3 na: no frame-timing evidence was captured for this row.
- L4 na: no visual artifact was captured for this row.
- L5 na: no Computer Use discoverability session was captured for this row.
