# EDGE-021 · 账本警报独立复审

## Triggered alarms

- `gap-too-fast`: the five judgments were intentionally written in one controlled batch, so the
  timestamp-spacing curve detected the batch protocol rather than claiming human observation time.
- `discovery-collapse`: this row is a deterministic lifecycle/security invariant and has no product
  failure in the focused regression; levels 2-5 are explicitly `na`, not hidden passes.

## Independent revalidation

- `TestForgetConversationClearsOnlyDeletedConversationGrants` exercises the real
  `chat.Service.ForgetConversation` hook and checks both deletion and non-deletion scopes.
- `TestForgetDropsConversationGrants` independently checks broker prefix cleanup.
- Both focused and `-race` runs passed.
- No CODEX law, alarm threshold, coverage rule, anchor, or gate was changed.
- `gen_coverage.py --check` remains clean: 848 rows, 518 carried judgments, 0 tombstones.

These alarms describe the controlled ledger write pattern and the row's honest applicability;
they do not invalidate the evidence. They are acknowledged with this re-audit attached.
