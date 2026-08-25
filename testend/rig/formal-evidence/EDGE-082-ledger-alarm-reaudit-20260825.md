# EDGE-082 ledger / alarm re-audit

- `RIG_HOME=/private/tmp/anselm-rig-formal-20260801-3`
- `judge.py`: 5 cells for `replay 与保留清理竞速` (`pass/na/na/na/na`)
- journal: `2896` total = `2300` baseline + `596` live
- `gen_coverage.py --check`: `848 rows / 579 carried judgments / 0 tombstones`
- `alarms.py check`: clean after acknowledging the two expected statistical alarms raised by the tight five-cell write
- no anchor change; phase-2 400+ journey expansion remains deferred by user decision
