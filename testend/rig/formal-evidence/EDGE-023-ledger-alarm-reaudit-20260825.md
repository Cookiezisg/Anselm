# EDGE-023 · 账本警报独立复审

## Triggered alarms

- `gap-too-fast`: the five judgments were written as one controlled row-closing batch; the curve
  detected ledger timing, not an unsupported claim about observation speed.
- `discovery-collapse`: this is a deterministic malformed-argument safety boundary. The row has one
  focused L1 pass and explicit `na` levels, so the absence of a fail is not hidden coverage.

## Independent revalidation

- The focused regression covers missing path, empty path, whitespace path, and malformed JSON.
- The approved path reaches the real filesystem Write validator and returns `file_path is required`;
  malformed JSON is rendered as a visible string in the approval payload.
- Both focused and `-race` runs passed.
- No CODEX law, alarm threshold, coverage rule, anchor, or gate was changed.
- `gen_coverage.py --check` remains clean: 848 rows, 520 carried judgments, 0 tombstones.

The alarms describe the controlled ledger write pattern and honest applicability, not an evidence
failure. They are acknowledged with this re-audit attached.
