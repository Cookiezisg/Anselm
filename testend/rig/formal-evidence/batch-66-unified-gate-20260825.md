# Batch 66 unified gate · EDGE-181..190

- 批次：六十六
- 范围：`EDGE-181` 至 `EDGE-190`，50 个单格已逐格登记
- formal journal：`3436 = 2300 baseline + 1136 live judgments`
- COVERAGE：`848 rows / 687 carried judgments / 0 tombstones`
- anchors：`10/10`，judge unlocked
- alarms：clean；`gap-too-fast` 与 `discovery-collapse` 均按每格独立复审证据复核并 ack

## Unified gate

```text
make verify
  ✓ backend
  ✓ frontend
  ✓ docs
  ✓ demo
  ✓ workspace verified

make -C backend testend
  ok github.com/sunweilin/anselm/testend/scenarios 284.448s

python3 -m unittest discover -s testend/rig -p 'test_*.py' -v
  Ran 51 tests in 3.158s
  OK

make -C backend verify
  ✓ backend verified

python3 testend/rig/gen_coverage.py --check
  gen_coverage: clean (848 rows, 687 carried judgments, 0 tombstones)

RIG_HOME=/private/tmp/anselm-rig-formal-20260801-3 python3 testend/rig/anchors.py check .../anchor-quiz.json
  anchors: calibration passed (10 anchors); judge unlocked for 4h

RIG_HOME=/private/tmp/anselm-rig-formal-20260801-3 python3 testend/rig/alarms.py check
  alarms: clean (1136 live judgments; 2300 baseline judgments excluded from drift curves)

python3 -m py_compile testend/rig/*.py
  passed

for script in testend/rig/*.sh; do bash -n "$script"; done
  passed

gofmt + git diff --check
  passed

process/listener audit
  no residual anselm-server, llama-server, llmtap, ssetap or flutter_tester
```

## Batch result

Batch 66 is green and eligible for submission. EDGE-181..190 stayed within their evidence boundaries:
focused/service/runtime and real black-box evidence were recorded where available; absent independent
Computer Use, timing, visual-craft and discoverability sessions were explicitly recorded as `na`.
No Journey expansion was performed; P12 remains explicitly deferred to phase 2.
