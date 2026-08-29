# EDGE-339 · BYOK base URL 模板未填占位 · real App L2

## Session

- Session: `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260828-031741`
- Data directory: `/private/tmp/anselm-data-edge339-20260828-r1`
- App: real macOS Flutter app, directly launched by the conductor
- Workspace: `ws_e3974b1ca4b6797e` (`EDGE-339 BYOK URL validation`)

## Product walk

1. Opened the real app's Settings and entered Models & keys.
2. Opened the provider market and selected the Azure template.
3. The form showed the catalog `baseUrlTemplateHint`, explicitly identifying the
   address as a template value that must be replaced rather than presenting it as
   an already usable endpoint.
4. Closed the add-key form without storing credentials. The app returned to the
   stable managed settings surface; no malformed key or partial provider row was
   created.

This validates the user-facing negative path that can be tested without inventing
or storing a real provider secret. It does not claim that Azure authentication or
an actual Azure completion succeeds; those remain separate credential-backed cells.

## Five-channel evidence

- **Frames / Computer Use:** the app was opened and the market, Azure form,
  template hint, and cancel return path were directly inspected.
- **Backend journal:** the session journal contains the workspace creation and no
  application panic or unhandled request failure for this walk.
- **SSE witness:** all three resident streams connected for the active workspace
  and closed cleanly during `rig-down`.
- **Frontend console:** only normal Flutter VM startup and known macOS IMK/TSM
  host diagnostics; no Flutter/Dart assertion, overflow, or unhandled exception.
- **LLM tap:** managed challenge/install/models/quota probes completed with HTTP
  200; no provider completion was attempted because this path intentionally does
  not submit a credential.

## Judgment

- `L2=pass (F1)`: the real App's visible template warning and safe cancel outcome
  are backed by the session's independent journals, with no hidden mutation.
- `L3-L5=na`: this cell is a boundary-validation path; no new latency, visual
  geometry measurement, or independent first-user discoverability study is being
  claimed here.
