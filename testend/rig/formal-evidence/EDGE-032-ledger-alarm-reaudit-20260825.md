# EDGE-032 · 账本警报独立复审

## Triggered alarms

- `gap-too-fast`: the five judgments were written as one controlled row-closing batch; this is a
  ledger timing signal, not evidence that the queue test was skipped.
- `discovery-collapse`: the row is a deterministic queue lifecycle invariant. L2-L5 are explicitly
  `na`, not hidden passes.

## Independent revalidation

- `TestSendAfterIdleQueueTeardownRecreatesQueue` completed one turn, observed idle teardown,
  recreated the queue on a later Send, and observed the second terminal close.
- `go test ./internal/app/chat` and `go test -race ./internal/app/chat` both passed.
- No CODEX law, alarm threshold, coverage rule, anchor, or gate was changed.
- `gen_coverage.py --check` remains the required ledger integrity check; this re-audit does not
  alter its policy.

The alarms describe controlled ledger timing and honest applicability, not an evidence failure.
They are acknowledged with this re-audit attached.
