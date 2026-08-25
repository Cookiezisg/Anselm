# Batch 67 unified gate · EDGE-151..200

- 批次：六十七
- 范围：本批最后 50 格，`EDGE-191..200`；本批累计覆盖 `EDGE-151..200`
- formal journal：`3486 = 2300 baseline + 1186 live judgments`
- COVERAGE：`848 rows / 697 carried judgments / 0 tombstones`
- anchors：`10/10`，judge unlocked
- alarms：clean；`gap-too-fast` 与 `discovery-collapse` 均按每格证据复核并 ack

## Unified gate

```text
make verify
  ✓ backend
  ✓ frontend
  ✓ docs
  ✓ demo
  ✓ workspace verified

make -C backend testend
  ok github.com/sunweilin/anselm/testend/scenarios 290.620s

python3 -m unittest discover -s testend/rig -p 'test_*.py' -v
  Ran 51 tests in 3.133s
  OK

make -C backend verify
  ✓ backend verified

python3 testend/rig/gen_coverage.py --check
  gen_coverage: clean (848 rows, 697 carried judgments, 0 tombstones)

RIG_HOME=/private/tmp/anselm-rig-formal-20260801-3 python3 testend/rig/anchors.py check .../anchor-quiz.json
  anchors: calibration passed (10 anchors); judge unlocked for 4h

RIG_HOME=/private/tmp/anselm-rig-formal-20260801-3 python3 testend/rig/alarms.py check
  alarms: clean (1186 live judgments; 2300 baseline judgments excluded from drift curves)

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

Batch 67 is green and eligible for submission. The ten final attachment edges were kept within their
evidence boundaries: focused/service regression was recorded at L1; absent independent managed gateway,
Computer Use, timing, visual-craft and discoverability sessions were explicitly recorded as `na` rather
than promoted to fabricated five-channel evidence. P12 400+ Journey expansion remains deferred to phase 2.
