# EDGE-178 L2 ledger/alarm re-audit

- **Trigger:** `discovery-collapse` opened after the formal L2 judgment because the trailing 50 live judgments have a fail share below the anti-rubber-stamp threshold.
- **Target:** `EDGE|搜索 embedder 缺席降级` L2.
- **Judgment:** `pass` under `F2`, backed by `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260830-205857/evidence/EDGE-178-search-embedder-off-fallback-l2-real-app-20260830.md`.
- **Calibration:** `anchors.py check` passed `10/10` before the judgment.

## Independent review

The low fail share is not being interpreted as evidence that the product is clean by
itself. The target was reviewed against the exact fresh real-App session, its
manifest-bound screen recording, backend journal, three SSE streams, frontend console,
and managed LLM wire. The session contains a real App onboarding flow followed by a
real user chat request; the model actually called `search_documents` and
`read_document`, and the direct REST/SQLite facts agree with the durable message
blocks and visible result.

The judgment is deliberately narrow. It proves that with the machine-level semantic
embedder explicitly set to `off`, the product keeps lexical document search available
and returns the correct document. It does not claim that the current Settings ocean
offers a user-discoverable embedder switch; that is a separate open product surface,
not silently converted to `na` or `pass` here.

No threshold, alarm algorithm, CODEX law, anchor set, sequence policy, or five-level
standard was changed. The prior open/failed evidence remains intact, and future
judgments continue to be subject to the same alarm gate.
