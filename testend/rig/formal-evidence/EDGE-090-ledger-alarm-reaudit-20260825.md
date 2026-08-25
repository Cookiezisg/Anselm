# EDGE-090 ledger / alarm re-audit

- `judge.py`: 5 cells for `run 历史保留清理` (`pass/na/na/na/na`)
- journal: `2936` total = `2300` baseline + `636` live
- `gen_coverage.py --check`: `848 rows / 587 carried judgments / 0 tombstones`
- `alarms.py check`: clean after the expected tight-write statistical alarms were acknowledged
- no anchor change; 400+ journeys remain phase 2
