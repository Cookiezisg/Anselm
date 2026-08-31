# EDGE-200 · real App blob GC boot-only evidence

## Verdict scope

This evidence closes the real-app portion of `EDGE-200 | blob GC 只在 boot 跑`.
The test uses one real macOS Anselm app launch per session, the real managed gateway
`https://api.anselm.website` through `llmtap`, the independent SSE witness, the backend
journal, the frontend console journal, and a finalized Screen Recording. The same persistent
data directory was deliberately reused across three boots:

```text
data: /private/tmp/anselm-data-edge200-20260831-r1
workspace: ws_1376d8754387fd96
sha256: 56133a163bc6964931e961aa6482c4088ee09d31165aac5d9532ec56a0309846
blob: workspaces/ws_1376d8754387fd96/blobs/56/56133a163bc6964931e961aa6482c4088ee09d31165aac5d9532ec56a0309846
size: 2,995,581 bytes
```

## Three-session sequence

1. Session `20260831-085128` (`42.295000s`) uploaded four distinct attachment rows with the
   same SHA, then soft-deleted the first three and finally the fourth. After each deletion the
   blob was still present. The four rows retained their `deleted_at` values; deletion did not
   synchronously scan or remove the blob. Evidence action log:
   `/private/tmp/anselm-rig-formal-20260831-11/sessions/20260831-085128/edge200-actions.txt`.
2. Session `20260831-085315` (`164.188333s`) booted the same data directory. Backend startup
   reported `reclaimed orphaned attachment blobs {count: 1}` and the SHA path was absent after
   boot. The same session then uploaded `att_0c820a1397c598a2` and
   `att_2d6a13c64dddcbf9` with that SHA, deleted only the latter, and observed the blob still
   present while the former remained active. Evidence action log:
   `/private/tmp/anselm-rig-formal-20260831-11/sessions/20260831-085315/edge200-actions.txt`.
3. Session `20260831-085630` (`24.395000s`) booted the same data directory again. The active
   `att_0c820a1397c598a2` row remained live and the exact SHA path remained present. The four
   earlier orphan rows and the duplicate row remained as soft-deleted durable rows. No orphan
   reclaim was logged for the still-referenced SHA.

## Five-channel closure

The final session is the level-2 binding session:
`/private/tmp/anselm-rig-formal-20260831-11/sessions/20260831-085630`.

- Channel 1: `screen.mov` is finalized (`24.395000s`); the real Anselm window was owned by
  PID `41769`, recorder PID `41814`, bounds `0,30,1440,810`, with no external overlay.
- Channel 2: `backend.log` is attributed to PID `41426` on `:8778`; health stayed 200 and the
  session contains no WARN/ERROR/panic. Its boot log is the negative check: no reclaim for the
  still-referenced SHA.
- Channel 3: `ssetap` PID `41454` connected to `messages`, `entities`, and `notifications`;
  `sse.jsonl` contains the complete durable stream observation for the session.
- Channel 4: `frontend.log` is the direct app console journal. It contains no app error; the
  only diagnostic is the known macOS IMK input-method message.
- Channel 5: `llmtap` PID `41402` is wired to the real managed upstream. The final boot is a
  storage-only verification, so no model call is required for this edge; the tap remains
  present and attributed in the manifest.

## Measurements and applicability

- `measure:edge200-attachment-blob-gc-boot-only`: first deletion-to-blob observation was
  immediate within the same API action batch; the blob remained after all four rows were
  deleted. The next boot removed exactly the now-orphaned SHA. A later boot retained the same
  SHA when one active row existed. This is the required boot-only boundary and the live-SHA
  keep-set invariant.
- L4 is genuinely not applicable to this edge: blob reclamation is a backend boot maintenance
  operation and Anselm exposes no storage-status or GC-result UI for this mechanism. There is
  no visual artifact to judge without inventing a product surface.
- L5 is genuinely not applicable to this edge for the same product boundary: users do not need
  to discover an internal boot GC implementation; attachment deletion is the user-facing action
  and its durable row is already observable through the product. This is not a claim that a
  future storage-management surface has been tested.

## Source and regression checks

- Existing focused regression evidence:
  `formal-evidence/EDGE-200-attachment-blob-gc-boot-only-20260826.md`
- Backend tests:
  `internal/app/attachment` deletion/refcount tests, `internal/infra/fs/blob` sweep tests,
  and `internal/bootstrap` build/health tests, all passed with `-race`.
- Final session gate: `RIG_HOME=/private/tmp/anselm-rig-formal-20260831-11 ./testend/rig/rig-check.sh`
  passed all five channels.
