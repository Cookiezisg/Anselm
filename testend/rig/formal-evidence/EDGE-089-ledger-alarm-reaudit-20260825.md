# EDGE-089 ledger / alarm re-audit

- `judge.py`: 5 cells for `draining 最后一个 run 结算` (`pass/na/na/na/na`)
- journal: `2931` total = `2300` baseline + `631` live
- `gen_coverage.py --check`: `848 rows / 586 carried judgments / 0 tombstones`
- `alarms.py check`: clean after the expected tight-write statistical alarms were acknowledged
- no anchor change; 400+ journeys remain phase 2
