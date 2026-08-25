# Batch 60 unified gate

## Scope

EDGE-121 through EDGE-130, 50 ledger cells, completed before this gate. Formal rig:
`RIG_HOME=/private/tmp/anselm-rig-formal-20260801-3`.

Measured state before submission:

```text
formal judgments: 3136 = 2300 baseline + 836 live
coverage: 848 rows / 627 carried judgments / 0 tombstones
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
ok   github.com/sunweilin/anselm/testend/scenarios 284.871s

python3 -m unittest discover -s testend/rig -p 'test_*.py' -v
Ran 51 tests in 3.413s
OK

make -C backend verify
✓ backend verified

python3 testend/rig/gen_coverage.py --check
gen_coverage: clean (848 rows, 627 carried judgments, 0 tombstones)

RIG_HOME=... python3 testend/rig/anchors.py check .../anchor-quiz.json
anchors: calibration passed (10 anchors); judge unlocked for 4h

RIG_HOME=... python3 testend/rig/alarms.py check
alarms: clean (836 live judgments; 2300 baseline judgments excluded from drift curves)

python3 -m py_compile testend/rig/*.py
PASS

for script in testend/rig/*.sh; do bash -n "$script" || exit 1; done
PASS

git diff --check
PASS
```

The residual audit after the complete suite found no `anselm-server`, `llama-server`, `llmtap`, `ssetap`, or `flutter_tester` process/listener. No test fixture or production data was used as acceptance evidence. The batch includes the fsnotify second-bucket production regression and all ten formal evidence files; no alarm threshold, CODEX law, anchor set, or gate rule changed.

## Decision

Batch 60 is eligible for submission. The next formal frontier is EDGE-131, but it is not started in this commit.
