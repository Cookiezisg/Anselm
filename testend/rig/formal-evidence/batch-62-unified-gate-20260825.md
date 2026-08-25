# Batch 62 unified gate · EDGE-141..150

- 批次：六十二
- 范围：`EDGE-141` 至 `EDGE-150`，50 个单格已逐格登记
- formal journal：`3236 = 2300 baseline + 936 live judgments`
- COVERAGE：`848 rows / 647 carried judgments / 0 tombstones`
- anchors：`10/10`，judge unlocked
- alarms：clean；`gap-too-fast` 与 `discovery-collapse` 均按每格证据边界复核并 ack

## Unified gate

```text
make verify
  ✓ backend
  ✓ frontend
  ✓ docs
  ✓ demo
  ✓ workspace verified

make -C backend testend
  ok github.com/sunweilin/anselm/testend/scenarios 285.596s

python3 -m unittest discover -s testend/rig -p 'test_*.py' -v
  Ran 51 tests in 3.017s
  OK

make -C backend verify
  ✓ backend verified

python3 testend/rig/gen_coverage.py --check
  gen_coverage: clean (848 rows, 647 carried judgments, 0 tombstones)

RIG_HOME=/private/tmp/anselm-rig-formal-20260801-3 python3 testend/rig/anchors.py check .../anchor-quiz.json
  anchors: calibration passed (10 anchors); judge unlocked for 4h

RIG_HOME=/private/tmp/anselm-rig-formal-20260801-3 python3 testend/rig/alarms.py check
  alarms: clean (936 live judgments; 2300 baseline judgments excluded from drift curves)

python3 -m py_compile testend/rig/*.py
  passed

for script in testend/rig/*.sh; do bash -n "$script"; done
  passed

git diff --check
  passed

process/listener audit
  no residual anselm-server, llama-server, llmtap, ssetap, flutter_tester or matching listeners
```

## Batch result

Batch 62 is green and eligible for submission. EDGE-141..150 all stayed within their evidence
boundary: L1 mechanical/service/runtime contracts were judged `pass`, while the absent independent
Computer Use, timing, visual-craft, and discoverability sessions were explicitly recorded as `na`.
No Journey expansion was performed; P12 remains explicitly deferred to phase 2 by user decision.
