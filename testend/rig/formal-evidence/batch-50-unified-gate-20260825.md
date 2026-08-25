# Batch 50 · unified long gate

## Scope

EDGE-022 through EDGE-031 were closed as ten coverage rows, five ledger levels each. Batch 50
reached `50/50` before this gate; no commit was made earlier.

## Stop-and-fix included

EDGE-023 exposed a real work-directory safety gap: indeterminable `Write` arguments could bypass a
mounted-residency gate when self-reported safe, and malformed raw JSON could erase the approval
payload. The fix added a distinct indeterminable-target state, a normal human gate, and safe raw
argument rendering; the real Write validator remains the final error boundary. The focused and
race regressions passed before this long gate.

## Gate results

- `make verify`: PASS — backend, frontend, docs and demo; final output `workspace verified`.
- `make -C backend testend`: PASS — `github.com/sunweilin/anselm/testend/scenarios`, 266.081s.
- `python3 -m unittest discover -s testend/rig -p 'test_*.py' -v`: PASS — 51 tests.
- `python3 -m py_compile testend/rig/*.py`: PASS.
- `bash -n testend/rig/*.sh`: PASS.
- `gofmt -d` on all Go files changed in this batch: clean.
- `gen_coverage.py --check`: clean — 848 rows, 528 carried judgments, 0 tombstones.
- `anchors.py check`: calibration passed — 10 anchors; judge unlocked.
- `alarms.py check`: clean — 341 live judgments; 2300 baseline judgments excluded from drift curves.
- `git diff --check`: clean.
- Process and listener audit: no `anselm-server`, `llama-server`, `ssetap`, `llmtap`, Flutter Anselm
  process or matching listener remained after testend.

## Boundary

The EDGE rows in this batch are protocol/lifecycle paths. Their evidence records the applicable
focused regression at L1 and marks non-applicable real-App/visual/discoverability levels `na` with
reasons. This gate does not promote those rows into five-channel product evidence.
