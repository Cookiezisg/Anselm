# EDGE-057 · 续传游标三来源

## Verification

The real stream handler tests cover all cursor sources and precedence: a valid
`Last-Event-ID` header wins over `fromSeq`, query `fromSeq` is used when the header is absent,
and absent or malformed values become `0` (live-only, no replay). The same handler maps an
evicted bridge cursor to HTTP 410, keeping cursor decoding and replay failure semantics aligned.

Focused verification passed:

```text
go test ./internal/transport/httpapi/handlers -run 'Test(DecodeFromSeq|StreamHandler_SeqTooOld410)$' -count=1 PASS
go test -race ./internal/transport/httpapi/handlers -run 'Test(DecodeFromSeq|StreamHandler_SeqTooOld410)$' -count=1 PASS
go test ./internal/transport/httpapi/handlers -count=1 PASS
```

## Five-level applicability

- L1 `pass`: header/query/missing/bad cursor semantics are deterministic and an evicted cursor
  remains a 410; measurement law `measure:edge057-sse-cursor-sources`.
- L2 `na`: this edge was verified through the real transport handler boundary, not a separate
  managed-gateway five-channel session.
- L3 `na`: the focused, race, and package tests provide no independent App frame, SSE tap,
  backend journal, or frontend console observation.
- L4 `na`: this is request decoding and transport recovery semantics, with no independent visual
  geometry, motion, or layout surface.
- L5 `na`: reconnect cursor handling is an existing stream behavior and introduces no new
  navigation or discovery entry.
