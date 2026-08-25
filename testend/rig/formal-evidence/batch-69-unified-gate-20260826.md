# Batch 69 unified gate · EDGE-211..220

- 批次：六十九
- 范围：`EDGE-211..220`，共 50 个账本格（每个边界路径 L1-L5）
- formal journal：`3586 = 2300 baseline + 1286 live judgments`
- COVERAGE：`848 rows / 717 carried judgments / 0 tombstones`
- anchors：`10/10`，judge unlocked
- alarms：clean；复核后无 open alarm

## Unified gate

```text
make verify
  ✓ backend
  ✓ frontend
  ✓ docs
  ✓ demo
  ✓ workspace verified

make -C backend testend
  ok github.com/sunweilin/anselm/testend/scenarios 321.821s

python3 -m unittest discover -s testend/rig -p 'test_*.py' -v
  Ran 51 tests in 6.424s
  OK

make -C backend verify
  ✓ backend verified

python3 testend/rig/gen_coverage.py --check
  gen_coverage: clean (848 rows, 717 carried judgments, 0 tombstones)

RIG_HOME=/private/tmp/anselm-rig-formal-20260801-3 python3 testend/rig/anchors.py check .../anchor-quiz.json
  anchors: calibration passed (10 anchors); judge unlocked for 4h

RIG_HOME=/private/tmp/anselm-rig-formal-20260801-3 python3 testend/rig/alarms.py check
  alarms: clean (1286 live judgments; 2300 baseline judgments excluded from drift curves)

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

Batch 69 passed the unified gate and is eligible for submission. EDGE-211..220 remain honestly
bounded: focused/service regressions are recorded at L1, while missing independent managed-gateway,
Computer Use, timing, visual-craft and discoverability sessions remain `na` rather than being promoted
to fabricated five-channel evidence. P12 400+ Journey expansion remains deferred to phase 2.
