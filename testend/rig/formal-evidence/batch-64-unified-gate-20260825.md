# Batch 64 unified gate · EDGE-161..170

- 批次：六十四
- 范围：`EDGE-161` 至 `EDGE-170`，50 个单格已逐格登记
- formal journal：`3336 = 2300 baseline + 1036 live judgments`
- COVERAGE：`848 rows / 667 carried judgments / 0 tombstones`
- anchors：`10/10`，judge unlocked
- alarms：clean；`gap-too-fast` 与 `discovery-collapse` 均按每格独立证据边界复核并 ack

## Unified gate

```text
make verify
  ✓ backend
  ✓ frontend
  ✓ docs
  ✓ demo
  ✓ workspace verified

make -C backend testend
  ok github.com/sunweilin/anselm/testend/scenarios 339.654s

python3 -m unittest discover -s testend/rig -p 'test_*.py' -v
  Ran 51 tests in 3.168s
  OK

make -C backend verify
  ✓ backend verified

python3 testend/rig/gen_coverage.py --check
  gen_coverage: clean (848 rows, 667 carried judgments, 0 tombstones)

RIG_HOME=/private/tmp/anselm-rig-formal-20260801-3 python3 testend/rig/anchors.py check .../anchor-quiz.json
  anchors: calibration passed (10 anchors); judge unlocked for 4h

RIG_HOME=/private/tmp/anselm-rig-formal-20260801-3 python3 testend/rig/alarms.py check
  alarms: clean (1036 live judgments; 2300 baseline judgments excluded from drift curves)

python3 -m py_compile testend/rig/*.py
  passed

for script in testend/rig/*.sh; do bash -n "$script"; done
  passed

git diff --check
  passed

process/listener audit
  no residual anselm-server, llama-server, llmtap, ssetap or flutter_tester
```

## Batch result

Batch 64 is green and eligible for submission. EDGE-161..170 stayed within their evidence boundary:
L1 mechanical/service/runtime contracts were judged `pass`, while absent independent Computer Use,
timing, visual-craft and discoverability sessions were explicitly recorded as `na`. EDGE-163's first
incorrect package path produced no evidence and was not counted; the corrected focused and real HTTP
rerun is the only evidence used. EDGE-164's intentional 30-second mock stall and test-server close
warning, plus testend's free-tier loopback isolation warnings, were disclosed rather than hidden.
No Journey expansion was performed; P12 remains explicitly deferred to phase 2.
