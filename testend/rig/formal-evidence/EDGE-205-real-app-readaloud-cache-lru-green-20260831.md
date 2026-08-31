# EDGE-205 · real App read-aloud cache LRU eviction

## Result

GREEN for the bounded read-aloud cache. Four independent real speech artifacts were synthesized
through the managed gateway under the acceptance-rig-only `5,000,000` byte budget. Each artifact
was a real WAV with real persisted bytes. As the budget was exceeded, the least-recently-used
cache row was physically removed and its attachment was soft-deleted; the newest row was retained.
A fifth real App read-aloud artifact was then created and played, proving the product path still
returns a usable audio artifact after eviction activity.

Production behavior is unchanged: without the rig variable the service uses the domain constant
`50 MiB`. The reduced budget is an observation seam, not a production waiver or a fake size field.

Formal session:
`/private/tmp/anselm-rig-formal-20260831-11/sessions/20260831-094003`

Real upstream: `https://api.anselm.website`; workspace `ws_04ea81d4f95a5470`.

## Controlled sequence

The session manifest records `speechCacheBudgetBytes=5000000`. Four unique API reads returned real
uncached audio artifacts:

```text
A att_0c992f3129a7a1ae  3,176,684 bytes
B att_fead3c66fae9f6a4  3,422,444 bytes
C att_1599fac230fa938a  3,522,284 bytes
D att_2fdb6af3c3215cb2  3,361,004 bytes
```

The durable database state after D was:

```text
speech_cache: att_2fdb6af3c3215cb2  3,361,004  live cache row
attachments:  A  soft_deleted
attachments:  B  soft_deleted
attachments:  C  soft_deleted
attachments:  D  live
```

The observed order is the expected LRU walk: B evicted A, C evicted B, and D evicted C. The
cache's retained total is below the reduced budget, and the current row is not self-evicted.

The real App then opened a settled conversation, displayed `EDGE205 应用音频已就绪。`, and a
Computer Use click on the visible speaker action created `att_d260c22ad723c461` (`144,524` bytes)
and successfully obtained a playback lease with HTTP `200`. The final frame is
`/private/tmp/edge205-final.jpeg`.

## Five-channel evidence

- **Frame**: `recording.mov` is finalized (`412.046667s`). The real App shows the settled answer,
  visible read-aloud affordance, the resulting compact playback control, and an available
  composer. No cache key, reduced budget, soft-delete state, or internal error is exposed.
- **Backend**: `backend.log` records the five successful `read-aloud:read` operations, the final
  playback lease, and the rig budget declaration. SQLite in the same data directory proves real
  byte totals, physical `speech_cache` eviction, and soft-deleted old attachments. There is no
  ERROR or panic; the one WARN explicitly identifies the deliberate rig-only budget override.
- **SSE**: `sse.jsonl` records all three stream connections and the real App conversation's
  completed user/assistant message sequence. Read-aloud remains a zero-token media action and
  does not invent a chat turn.
- **Frontend console**: `frontend.log` contains no Flutter/Dart application exception; only the
  known macOS IMK diagnostic is present.
- **LLM wire**: `llm.jsonl` records the managed handshake and nine successful real
  `/v1/audio/speech` segment responses for A-D plus the fifth App artifact. Every resulting WAV
  size is measured from the returned bytes; no synthetic size accounting was used. The fifth App
  artifact also has a successful local playback lease and range/full reads.

## Measurement and judgement

`measure:edge205-readaloud-cache-lru` records the `5,000,000` byte rig budget, four real artifact
sizes, the A→B→C eviction order, the durable retained row, and the old attachment soft-deletes.
The production default is verified in the constructor regression: an absent/invalid override
falls back to the domain `50 MiB` budget.

The App surface keeps the same compact read-aloud/player geometry after the cache churn, without
exposing maintenance internals, so L4 uses `C4`. A user reaches read-aloud from the visible
settled-answer action and does not need to know cache or eviction rules, so L5 uses `G1`.
