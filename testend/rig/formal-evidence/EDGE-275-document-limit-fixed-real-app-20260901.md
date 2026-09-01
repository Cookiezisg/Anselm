# EDGE-275 · 文档超 1MB · 修复后真实 App 五级证据

## Session and setup

- session=`/private/tmp/anselm-rig-formal-20260831-11/sessions/20260901-100530`
- workspace=`ws_92a2f2d49d978016`
- document=`doc_a579d3c38f32919e` (`EDGE275 Fix Probe`)
- document body: exactly `1,048,576` bytes; API GET after the oversized attempt still reports `1,048,576`
- App/backend/SSE witness/frontend console/LLM recorder/recording were owned by one conductor; `RIG_HOME=... rig-check.sh` and `rig-down.sh` completed.

## L2 · true across the five channels

The real App opened the legal boundary document and showed its title, size, explicit read-only explanation,
full-text copy action, and body. The same session's API probe sent a `1,048,577`-byte body to
`PATCH /api/v1/documents/doc_a579d3c38f32919e`; it returned HTTP `413` with
`DOCUMENT_CONTENT_TOO_LARGE`. A subsequent GET confirmed the stored body remained exactly `1,048,576`
bytes. Backend had no application error, frontend had no Dart/Flutter error, and the SSE/LLM witnesses
remained connected. The App stayed responsive during the entire probe.

## L3 · smooth

The App did not enter the previous `BeginFrame`/100% CPU loop. It rendered the bounded preview, accepted
the copy action (`Copy full text` → `Copied`), and scrolled down two pages without blanking, jumping, or
losing the selected document. App CPU was approximately `0.4%` after the interaction; the fixed preview
does not manufacture a loading state for content already available.

## L4 · craft

The preview uses the existing content typography and spacing tokens. Its information callout, action row,
and body have clear hierarchy and no clipping or overlap at the 1366×768 App window size. The body is
split into bounded render chunks rather than one giant paragraph, while the UI makes the read-only tradeoff
visible instead of presenting a misleading editable surface. Screenshot evidence is
`sessions/20260901-100530/evidence/edge275-fixed-scrolled.jpeg`.

## L5 · discoverability

No API or size-limit knowledge is needed: the document opens to an explicit explanation, names the state as
read-only, and puts `Copy full text` directly below it. A user can understand what happened and how to take
the complete content away without reading a protocol error or guessing why the body was blank.

## Verdict

The original backend contract remains hard and lossless for `>1 MiB`; the frontend now handles the valid
boundary case without freezing or pretending to edit an unsafe single-layout document. This evidence is
for the repaired run only; the earlier red session remains immutable.
