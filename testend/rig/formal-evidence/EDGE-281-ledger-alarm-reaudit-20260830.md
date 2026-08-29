# EDGE-281 ledger and alarm re-audit

Date: 2026-08-30

## Regression evidence

- `mise exec -- go test -count=1 ./internal/infra/skillfetch -run '^(TestFetch_GuardsAndJunk|TestUntar_ArchiveBombLimits)$'` passed.
- `mise exec -- go test -race -count=1 ./internal/infra/skillfetch -run '^(TestFetch_GuardsAndJunk|TestUntar_ArchiveBombLimits)$'` passed.
- `mise exec -- go test -count=1 ./internal/app/skill` passed.
- `mise exec -- go test -race -count=1 ./internal/app/skill` passed.
- `mise exec -- go test -count=1 -timeout 5m ./scenarios -run '^TestSkillInstall_FullChain$'` passed.
- `mise exec -- go test -race -count=1 -timeout 5m ./scenarios -run '^TestSkillInstall_FullChain$'` passed.
- The fetch tests reject over-limit regular-entry count and unpacked bytes while dropping symlinks, traversal paths, and platform junk; the service and HTTP chain still complete normal inspect/install/trust-gate behavior.

## Applicability and scheduling

`EDGE-281` is an install safety boundary with a user-visible failure surface. Internal and HTTP regressions establish the archive limits and ordinary install path, but L2-L5 still require a real desktop App and five channels to judge preview behavior, blocking feedback, wait-state copy, visual craft, and discoverability. Keep the row unfinished and in the manual queue; do not convert missing product observation into `na` or `pass`.

The alarm ledger was not used to waive this row. Existing alarm rules, thresholds, anchor set, sequence gate, five-level standard, and evidence requirements remain unchanged. The next autonomous frontier is determined by the sequence gate after this queue entry.
