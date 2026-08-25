# EDGE-073 · approval 版本 resolve 失败

## Verification

The approval inbox keeps a parked row actionable when its pinned approval version can no longer
be resolved. The row remains visible with its flowrun/workflow identity, while only the derived
`deadline` is omitted; the scheduler does not fabricate a zero deadline or discard the decision.

## Focused evidence

```text
cd backend
mise exec -- go test ./internal/app/scheduler \
  -run '^TestInbox_UnresolvableFormOmitsDeadlineOnly$' -count=1
ok  github.com/sunweilin/anselm/backend/internal/app/scheduler

mise exec -- go test -race ./internal/app/scheduler \
  -run '^TestInbox_UnresolvableFormOmitsDeadlineOnly$' -count=1
ok  github.com/sunweilin/anselm/backend/internal/app/scheduler
```

## Five-level applicability

- L1 pass: an unresolvable pinned approval version leaves the inbox row present and actionable while omitting only `deadline`.
- L2 na: no independent formal five-channel App session was captured for this row.
- L3 na: no frame-timing evidence was captured for this row.
- L4 na: no visual artifact was captured for this row.
- L5 na: no Computer Use discoverability session was captured for this row.
