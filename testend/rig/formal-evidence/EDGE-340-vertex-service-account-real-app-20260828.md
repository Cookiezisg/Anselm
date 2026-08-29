# EDGE-340 · Vertex service-account 文件校验 · real App L2

## Session

- Session: `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260828-035055`
- Data directory: `/private/tmp/anselm-data-edge340-20260828-r2`
- Workspace: `ws_f2a1b420defc4117` (`EDGE-340 vertex validation`)
- Real App PID/window: `56376` / `4582`; recording: `85.241667s`

## Product walk

1. Created a fresh workspace in the real App and opened Settings → Models & keys.
2. Opened Add key and selected the real `Vertex` provider from the 213-item
   provider catalog.
3. The form presented `Service account (JSON)`, explained that Vertex uses a
   service-account file rather than an API key, and exposed both Paste JSON and
   Choose file paths. The Base URL field separately identified its required
   region placeholder.
4. Typed the non-sensitive fixture `{"project_id":"demo"}`. The form
   immediately rejected it with the localized message requiring `type`,
   `project_id`, and `private_key`; it did not silently treat the object as an
   API key.
5. Canceled the form. Models & keys returned with the managed Anselm row intact,
   two voice slots free, and no Vertex row or remote provider probe created.

This validates the malformed service-account boundary without entering or
transmitting a real credential. It does not claim that a valid Vertex file or
Vertex completion succeeds; that is a separate credential-backed cell.

## Five-channel evidence

- **Frames / Computer Use:** provider selection, Vertex-specific controls,
  immediate red validation message, and cancel return were directly inspected.
- **Backend journal:** the fresh workspace creation and settings reads are in
  the session journal; no panic or unhandled application failure is present.
- **SSE witness:** the independent tap connected to all three streams for
  `ws_f2a1b420defc4117` and closed them cleanly during `rig-down`.
- **Frontend console:** only normal Flutter startup output is present; no
  Flutter/Dart assertion, overflow, or unhandled exception occurred.
- **LLM tap:** managed challenge/install/models/quota probes were captured with
  HTTP 200. No Vertex request or real secret crossed the wire.

## Judgment

- `L2=pass (F1)`: the real form's type-specific validation and no-mutation cancel
  result agree with the independent session journals.
- `L3-L5=na`: this cell is limited to credential-shape validation; no new latency,
  visual geometry measurement, or independent discoverability study is claimed.
