# EDGE-171 · MCP 媒体逐件 best-effort · real App L2

## Scope

This is the second, clean formal run after a product copy defect was found in the first run.
The first run displayed `1 calls`; it is discovery evidence only and is not used for the green
judgment. The fix added a singular English `call` translation and a regression assertion while
leaving the Chinese wording unchanged.

## Formal session

- Session: `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260830-175550`
- Data directory: `/private/tmp/anselm-data-edge171-20260830-r2`
- Workspace: `ws_8ee7385198b80627`
- MCP server: `edge171`, tool `mixed_media`
- Source: `/private/tmp/anselm-edge171-scripted-mcp.py`, a local deterministic stdio MCP server

## Product path and result

The real App was started by `rig-up.sh`, with the real App MCP settings surface open. The real
product `PUT /api/v1/mcp-servers/edge171` connected the local stdio server, and the real product
MCP invoke endpoint ran `mixed_media` once. The server returned text, a PNG, an MP3, and a second
PNG whose decoded bytes were `50 MiB + 1 byte`, over the configured single-attachment limit.

The HTTP invoke response was `200` and retained all three positional placeholder stories:

```text
EDGE171 mixed media result[image: image/png][audio: audio/mpeg][image: image/png]
```

Two successful items became first-class receipts, in order:

- `att_c8aaa792a49a66b7` · `mcp-mixed_media-0.png` · `image/png` · `317` bytes
- `att_cea71d3006d2d5b0` · `mcp-mixed_media-1.mp3` · `audio/mpeg` · `19` bytes

The oversized third item produced no receipt and kept its `[image: image/png]` placeholder. The
MCP call audit row remained `status=ok`, `triggeredBy=manual`, `elapsedMs=971`; the backend journal
explicitly recorded `file exceeds the 50 MB limit` as the expected per-item warning. Fetching the
two attachment content endpoints returned valid PNG and ID3/MP3 bytes with SHA-256 values matching
the persisted attachment rows.

## App observation

Computer Use observed the repaired settings surface after the call:

- roster card: `ready · 1 tools · 1 call` (not `1 calls`)
- detail page: `edge171`, `ready`, one tool, and `Call history`
- call history: `✓ 1 · ✗ 0`, `mixed_media`, `manual · 971ms`

The first-run copy defect was fixed before this session and the corrected binary was rebuilt.
No App restart, delete, OAuth, credential, or external account action was needed.

## Five-channel closure

- Channel 1: `screen.mov` is readable, `3104x1844`, `60fps`, `84.128333s`; the recorder was
  window-bound and `rig-check.sh` passed the no-overlay guard.
- Channel 2: backend PID was the listener on `:8742`; health passed; the expected upload warning
  and `200` invoke were journaled; no panic/FATAL occurred.
- Channel 3: independent ssetap connected to `messages`, `entities`, and `notifications`; the
  MCP run terminal emitted one open and one completed close frame for the same server scope.
- Channel 4: the exact rebuilt macOS App was conductor-owned; frontend console had no Flutter,
  Dart, RenderFlex, overflow, unhandled, assertion, or application error. The only diagnostic was
  the known macOS IMK host message.
- Channel 5: llmtap was listener-attributed and recorded managed challenge/install/models traffic;
  no provider model call was required for this direct MCP product path.

`rig-check.sh` passed before and during the run. `rig-down.sh` finalized the recording and left no
owned App, backend, ssetap, llmtap, recorder, or local MCP process behind.

## Judgment boundary

This evidence proves the product-side partial-success data contract and its honest failure
behavior. It does not prove multi-item visual craft, animation smoothness, or a new-user's ability
to discover this edge path. Therefore only L2 is eligible here; L3-L5 remain open.
