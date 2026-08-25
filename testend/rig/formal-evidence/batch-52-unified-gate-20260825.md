# Batch 52 · unified long gate

## Scope

EDGE-042 through EDGE-051 were closed as ten coverage rows, five ledger levels each. Batch 52
reached `50/50` before this gate; no commit was made earlier.

## Stop-and-fix included

- EDGE-048 verified both directions of fork version lineage remap and the cut-window cleanup of
  `superseded_by` and `attrs.retryOf`.
- EDGE-049 verified cross-message subagent parent remap at both block and message attribute
  locations; no production defect was found.
- EDGE-050 added the missing real SQLite regression proving source deletion does not cascade-delete
  a fork or rewrite its historical lineage columns.
- EDGE-051 added the missing crash-window regression proving a durable compaction watermark makes
  recovery idempotent even when archive/anchor writes did not happen before the crash.

## Gate results

- `make verify`: PASS — backend, frontend, docs and demo; final output `workspace verified`.
- `make -C backend testend`: PASS — `github.com/sunweilin/anselm/testend/scenarios`, `327.911s`.
- `python3 -m unittest discover -s testend/rig -p 'test_*.py' -v`: PASS — 51 tests in `3.600s`.
- `python3 -m py_compile testend/rig/*.py`: PASS.
- `bash -n testend/rig/*.sh`: PASS.
- `make -C docs verify`: PASS — documentation verified; six pre-existing review-due/drift warnings
  remain warnings, not failures.
- `gen_coverage.py --check`: clean — 848 rows, 548 carried judgments, 0 tombstones.
- `anchors.py check`: calibration passed — 10 anchors; judge unlocked.
- `alarms.py check`: clean — 441 live judgments; 2300 baseline judgments excluded from drift curves.
- `gofmt -d` on all changed Go files: clean.
- `git diff --check`: clean.
- Process and listener audit: no `anselm-server`, `llama-server`, `ssetap`, `llmtap`, Flutter tester,
  Anselm app process, or matching project listener remained after testend.

## Boundary

The EDGE rows in this batch are protocol, persistence, and lifecycle paths. Their evidence records
the applicable focused regression at L1 and marks non-applicable real-App/visual/discoverability
levels `na` with reasons. This gate does not promote those rows into five-channel product evidence.
