# Batch 49 · unified long gate

## Scope

EDGE-012 through EDGE-021 were closed as ten coverage rows, five ledger levels each. The batch
reached `50/50` before this gate; no commit was made earlier.

## Gate results

- `make verify`: PASS — backend, frontend, docs and demo; final output `workspace verified`.
- `make -C backend testend`: PASS — `github.com/sunweilin/anselm/testend/scenarios`, 270.240s.
- `python3 -m unittest discover -s testend/rig -p 'test_*.py' -v`: PASS — 51 tests.
- `python3 -m py_compile testend/rig/*.py`: PASS.
- `bash -n testend/rig/*.sh`: PASS.
- `gofmt -d` on all Go files changed in this batch: clean.
- `gen_coverage.py --check`: clean — 848 rows, 518 carried judgments, 0 tombstones.
- `anchors.py check`: calibration passed — 10 anchors; judge unlocked.
- `alarms.py check`: clean — 291 live judgments; 2300 baseline judgments excluded from drift curves.
- `git diff --check`: clean.
- Process and listener audit: no `anselm-server`, `llama-server`, `ssetap`, `llmtap`, Flutter Anselm
  process or matching listener remained after testend.

## Boundary

The EDGE rows in this batch are protocol/lifecycle paths. Their evidence records the applicable
focused regression at L1 and marks non-applicable real-App/visual/discoverability levels `na` with
reasons. This gate does not promote those rows into five-channel product evidence.
