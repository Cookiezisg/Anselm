# EDGE-084 ledger / alarm re-audit

- `judge.py`: 5 cells for `菱形 join 未守 has()` (`pass/na/na/na/na`)
- journal: `2906` total = `2300` baseline + `606` live
- `gen_coverage.py --check`: `848 rows / 581 carried judgments / 0 tombstones`
- `alarms.py check`: clean after the expected tight-write statistical alarms were acknowledged
- no anchor change; 400+ journeys remain phase 2
