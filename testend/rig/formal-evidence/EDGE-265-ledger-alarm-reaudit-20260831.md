# EDGE-265 ledger and alarm re-audit

## Ledger

- `judge.py` wrote `EDGE|切驻地落 marker 块` L2=`F2`, L3=`B2`, L4=`C5`, L5=`G1`.
- L2 is bound to `/private/tmp/anselm-rig-formal-20260831-11/sessions/20260831-230948` and its in-session evidence file; L3-L5 point to the formal evidence file.
- `gen_coverage.py --check`: `848 rows, 848 carried judgments, 0 tombstones`.
- Current ledger: `753` fully settled rows, `95` open rows; `3939` settled cells, `301` open cells.

## Alarm re-audit

The first post-write `alarms.py check` opened the unchanged `gap-too-fast` and `discovery-collapse` alarms. This was mechanical feedback: the four ledger writes were close together, and the trailing 50 live judgments had no failures. Both alarms were independently re-audited against the sealed EDGE-265 session and evidence before serial acknowledgement; no threshold, law, anchor, or five-level standard was changed.

- `gap-too-fast`: acknowledged after confirming evidence viewing was complete before the mechanical writes; future writes continue with wider intervals.
- `discovery-collapse`: acknowledged after confirming this was a real stop-and-fix defect followed by a genuine green re-run; the zero-fail tail does not waive future discovery checks.
- Final `alarms.py check`: `clean (199 live judgments; 4240 baseline judgments excluded from drift curves)`.
- Anchor calibration remained valid at `10/10`; no new calibration or anchor-set change was introduced.
