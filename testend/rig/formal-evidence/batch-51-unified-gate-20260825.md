# Batch 51 · unified long gate

## Scope

EDGE-032 through EDGE-041 were closed as ten coverage rows, five ledger levels each. Batch 51
reached `50/50` before this gate; no commit was made earlier.

## Stop-and-fix included

- EDGE-032 exposed a test seam defect: both queue idle-timer resets still used the production five-
  minute constant, so the first idle-recreate regression hung. The resets were changed to use the
  injected timeout and ordinary/race chat tests passed.
- EDGE-036 treated a real product loss as a defect: a transient first auto-title persistence failure
  could leave a one-turn conversation permanently named `New chat`. Persistence now retries once
  with a fresh bounded budget; ordinary/race chat tests passed.
- EDGE-040's first test draft assumed two rows would leave an `around` newer cursor. The test was
  stopped and corrected with a real later turn before it was counted.
- The final state recount caught a documentation-only `542` versus actual `538` carried-judgment
  mismatch. The three working records were corrected before this gate was closed.

## Gate results

- `make verify`: PASS — backend, frontend, docs and demo; final output `workspace verified`.
- `make -C backend testend`: PASS — `github.com/sunweilin/anselm/testend/scenarios`, `274.381s`.
- `python3 -m unittest discover -s testend/rig -p 'test_*.py' -v`: PASS — 51 tests in `3.413s`.
- `python3 -m py_compile testend/rig/*.py`: PASS.
- `bash -n testend/rig/*.sh`: PASS.
- `make -C docs verify`: PASS — documentation verified; six pre-existing review-due/drift warnings
  remain warnings, not failures.
- `gen_coverage.py --check`: clean — 848 rows, 538 carried judgments, 0 tombstones.
- `anchors.py check`: calibration passed — 10 anchors; judge unlocked.
- `alarms.py check`: clean — 391 live judgments; 2300 baseline judgments excluded from drift curves.
- `gofmt -d` on all changed Go files: clean.
- `git diff --check`: clean.
- Process and listener audit: no `anselm-server`, `llama-server`, `ssetap`, `llmtap`, Flutter tester,
  Anselm app process, or matching listener remained after testend.

## Boundary

The EDGE rows in this batch are protocol/lifecycle paths. Their evidence records the applicable
focused regression at L1 and marks non-applicable real-App/visual/discoverability levels `na` with
reasons. This gate does not promote those rows into five-channel product evidence.
