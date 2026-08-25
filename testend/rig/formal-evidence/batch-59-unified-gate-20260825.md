# Batch 59 unified gate

## Scope

EDGE-111 through EDGE-120, 50 ledger cells, completed before this gate. Formal rig:
`RIG_HOME=/private/tmp/anselm-rig-formal-20260801-3`.

Measured state before submission:

```text
formal judgments: 3086 = 2300 baseline + 786 live
coverage: 848 rows / 617 carried judgments / 0 tombstones
anchors: 10/10
alarms: clean
```

## Gate results

```text
make verify
✓ backend
✓ frontend
✓ docs
✓ demo
✓ workspace verified

make -C backend testend
ok   github.com/sunweilin/anselm/testend/scenarios 312.905s

python3 -m unittest discover -s testend/rig -p 'test_*.py' -v
Ran 51 tests in 4.074s
OK

python3 -m py_compile testend/rig/*.py
PASS

for script in testend/rig/*.sh; do bash -n "$script" || exit 1; done
PASS

make -C backend verify
✓ backend verified

python3 testend/rig/gen_coverage.py --check
gen_coverage: clean (848 rows, 617 carried judgments, 0 tombstones)

RIG_HOME=... python3 testend/rig/anchors.py check .../anchor-quiz.json
anchors: calibration passed (10 anchors); judge unlocked for 4h

RIG_HOME=... python3 testend/rig/alarms.py check
alarms: clean (786 live judgments; 2300 baseline judgments excluded from drift curves)

git diff --check
PASS
```

The process and listener audit found no residual `anselm-server`, `llama-server`, `llmtap`, `ssetap`, or `flutter_tester` process/listener after the full suite. No test fixture or production data was used as acceptance evidence.

## Decision

Batch 59 is eligible for submission. The batch includes the two regression-test additions required by EDGE-113 and EDGE-114, all ten formal evidence files, the carried coverage judgments, and the synchronized working records.
