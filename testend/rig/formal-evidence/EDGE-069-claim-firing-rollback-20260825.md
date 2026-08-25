# EDGE-069 · ClaimFiring 事务崩溃回滚

## Verification

The ClaimFiring fault-injection callback writes a partial flowrun association after the firing has
entered the transaction, then fails before commit. The transaction rolls back both that write and
the pending→claimed transition: the firing remains pending with an empty flowrun id, so no
claimed-but-no-run strand can be retried or orphaned.

## Focused evidence

```text
cd backend
mise exec -- go test ./internal/infra/store/trigger \
  -run '^TestFiring_Claim(RollbackLeavesPending|SingleTx)$' -count=1
ok  github.com/sunweilin/anselm/backend/internal/infra/store/trigger

mise exec -- go test -race ./internal/infra/store/trigger \
  -run '^TestFiring_Claim(RollbackLeavesPending|SingleTx)$' -count=1
ok  github.com/sunweilin/anselm/backend/internal/infra/store/trigger

mise exec -- go test ./internal/infra/store/trigger -count=1
ok  github.com/sunweilin/anselm/backend/internal/infra/store/trigger
```

## Five-level applicability

- L1 pass: injected post-claim failure rolls back status and flowrun association, leaving a retryable pending row.
- L2 na: no independent formal five-channel App session was captured for this row.
- L3 na: no frame-timing evidence was captured for this row.
- L4 na: no visual artifact was captured for this row.
- L5 na: no Computer Use discoverability session was captured for this row.
