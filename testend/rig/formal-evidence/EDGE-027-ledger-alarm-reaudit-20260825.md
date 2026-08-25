# EDGE-027 · 账本警报独立复审

## Triggered alarms

- `gap-too-fast`: the five judgments were written as one controlled row-closing batch; the alarm
  measures ledger timing, not unsupported review speed.
- `discovery-collapse`: the no-interactive-user result is a deterministic unavailable boundary. The
  focused test passes and levels 2-5 are explicitly `na`, not hidden passes.

## Independent revalidation

- `TestExecuteWithoutInteractiveUserFailsLoudly` invokes the real ask tool with no broker.
- It returns `ErrNoInteractiveUser` / `ASK_NO_INTERACTIVE_USER` immediately, with no answer text.
- Focused and `-race` runs passed.
- No CODEX law, alarm threshold, coverage rule, anchor, or gate was changed.
- `gen_coverage.py --check` remains clean: 848 rows, 524 carried judgments, 0 tombstones.

The alarms describe controlled ledger timing and honest applicability, not an evidence failure.
They are acknowledged with this re-audit attached.
