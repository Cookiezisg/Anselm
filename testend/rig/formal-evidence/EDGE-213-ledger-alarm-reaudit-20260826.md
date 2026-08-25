# EDGE-213 · ledger alarm re-audit

- `gap-too-fast` and `pass-burst` are valid guard signals for a focused-only sequence: one atomic row
  is being settled from a local regression plus four explicit `na` entries, not from five independent
  end-to-end observations.
- `discovery-collapse` remains explained by the batch boundary: no product failure was found in this
  narrow quota-not-provisioned regression, while all absent App/five-channel evidence stays `na`.
- Anchor calibration is still `10/10`, and the sequence gate admitted only `EDGE-213`. Keep `✓~~~~`,
  retain the typed-error evidence, and acknowledge these three alarms with this review.
