# EDGE-285 ledger and alarm re-audit

Date: 2026-08-30

## Regression evidence

- `mise exec -- go test -count=1 ./internal/infra/fs/skill -run '^(TestStore_LowercaseManifestFallback|TestStore_SaveManifestHandlesCaseInsensitiveFilesystems)$'` passed.
- `mise exec -- go test -race -count=1 ./internal/infra/fs/skill -run '^(TestStore_LowercaseManifestFallback|TestStore_SaveManifestHandlesCaseInsensitiveFilesystems)$'` passed.
- The cross-platform test confirms lowercase fallback reads, same-inode preservation on case-insensitive filesystems, and stale lowercase-file cleanup on case-sensitive filesystems.

## Applicability and scheduling

`EDGE-285` is a cross-platform filesystem compatibility boundary with a user-visible skill editing consequence. The filesystem regressions establish the inode-safe write behavior, but L2-L5 still require a real desktop App and five channels to judge cross-platform feedback, visual craft, and discoverability. Keep the row unfinished and in the manual queue; do not convert missing product observation into `na` or `pass`.

The alarm ledger was not used to waive this row. Existing alarm rules, thresholds, anchor set, sequence gate, five-level standard, and evidence requirements remain unchanged. The next autonomous frontier is determined by the sequence gate after this queue entry.
