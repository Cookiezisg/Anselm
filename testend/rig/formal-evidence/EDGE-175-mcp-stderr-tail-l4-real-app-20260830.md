# EDGE-175 · MCP 失败附 stderr 尾 · real App L4

## Formal session

- Session: `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260830-202150`
- Data directory: `/private/tmp/anselm-data-edge175-l4-final5-20260830`
- Workspace: `ws_29db253a5c490760`
- MCP server: `edge175`, tool `crash_with_stderr`
- Fixture: `/private/tmp/anselm-edge175-crash-mcp.py`, deterministic local stdio MCP

## Product path and result

The conductor started a fresh real macOS App after the UI and prompt fixes. Through the real Chat
surface, a user turn asked Anselm to run the connected MCP tool once and explain the expected
failure. The fixture wrote its diagnostic stderr tail and terminated while the call was in flight.

The default settled screen was reviewed with Computer Use. The center tool card owns the failure
title, the plain-language next-step hint, and the collapsed `Technical details` disclosure. The
assistant prose is reduced to one localized handoff sentence, `The failure and next step are shown
in the tool card above.`, followed by the requested marker; it does not repeat the transport
protocol, fixture identity, tool-call method, or stderr wording. The Activity panel remains
readable with the failed tool and human failure summary. There was no clipping, overlap, jump, or
duplicate assistant handoff in the settled frame.

Computer Use then explicitly opened `Technical details`. Only after that user-facing disclosure
did the card show the raw `mcp tool call failed (reason=calling "tools/call": EOF)` string. This
keeps debugging evidence copyable without making protocol vocabulary the default product copy.

## Five-channel closure

- Channel 1: the conductor-owned `screen.mov` for this session is readable and contains the real
  App default and technical-detail states. The final Computer Use screenshot showed the center
  card, single assistant handoff, and Activity failure state without layout defects.
- Channel 2: backend PID `50850` owned `:8742` and health passed. The journal contains the expected
  failed-tool warning and the server stderr tail through diagnostic line `179`; no panic or fatal
  process failure occurred.
- Channel 3: independent `ssetap` recorded the messages search/tool-call/result/assistant close
  sequence and entities MCP run lifecycle for this workspace, with durable cursors and no stream
  error.
- Channel 4: the direct Flutter App journal contains no Flutter, Dart, RenderFlex, overflow,
  assertion, Unhandled, or application error. The only unrelated line is the known macOS IMK host
  diagnostic.
- Channel 5: `llmtap` recorded managed challenge, install, models, and streamed chat completions;
  all upstream responses were HTTP `200`, and the request/response bodies are preserved per call.

`rig-check.sh` passed with all five observers physically attached. `rig-down.sh` finalized the
recording at `152.375s` and left no owned App, backend, SSE tap, LLM tap, recorder, or fixture
process behind.

## Judgment boundary

This evidence proves the product-level default/error-detail separation and the readable visual
presentation of a failed MCP call with preserved stderr evidence. The raw tail remains available
in durable backend/MCP records and the explicit technical disclosure; it is intentionally not
repeated in assistant prose or the default Activity summary.
