# EDGE-086 ledger / alarm re-audit

- `judge.py`: 5 cells for `advClosing 关停不跑缓冲 run` (`pass/na/na/na/na`)
- journal: `2916` total = `2300` baseline + `616` live
- `gen_coverage.py --check`: `848 rows / 583 carried judgments / 0 tombstones`
- `alarms.py check`: clean after the expected tight-write statistical alarms were acknowledged
- no anchor change; 400+ journeys remain phase 2
