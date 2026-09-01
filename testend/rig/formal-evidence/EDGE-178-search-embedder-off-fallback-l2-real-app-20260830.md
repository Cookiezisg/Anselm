# EDGE-178 L2: search embedder off keeps lexical search truthful

- **Session:** `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260830-205857`
- **Workspace:** `ws_8e2b400de75043d1`
- **Document:** `doc_4b5e232e3db894bf` (`EDGE-178 Search Fixture`)
- **Verdict:** PASS for L2 data truth
- **Law:** `F2` (five-channel data truth)

## User purpose

The user asks Anselm to find a document containing the exact token
`EDGE178LEXICALFALLBACK` and explain whether search still works when the semantic
embedder is unavailable. The fixture body is:

`EDGE178LEXICALFALLBACK The ocean keeps this exact token for search fallback acceptance.`

## Controlled setup

This is a real App session with the fresh workspace created through the onboarding
screen. The machine-level search setting was changed through the local authenticated
API before the user action because the current App has no Search Engine settings panel:

```text
PATCH /api/v1/search/settings {"embedder":"off"}
200 {"data":{"embedder":"off","engine":{"status":"off"}}}
```

The fixture document was created through the workspace-scoped Documents API and
reindexed before the App action. Direct REST search returned exactly one hit, with
the expected document id, name, highlighted token, tags, and `total: 1`; the App
then independently exercised the user-facing chat tool path.

## Real App result

Computer Use created the workspace, entered the following request in the real Chat
composer, and sent it:

`Find the document containing EDGE178LEXICALFALLBACK and explain whether semantic search is unavailable but lexical search still works.`

The real model called `search_documents` with the exact token, received one result,
then called `read_document` for the returned document. The final App transcript
showed the fixture body and correctly stated:

- lexical search works because the literal token was found;
- this exact-token result alone does not prove whether semantic search is available;
- the fixture is a fallback test, not evidence that the semantic path is down.

There was no failure card, retry affordance, duplicate search call, or hidden
`Something went wrong` state. The transcript and Activity side stage remained
readable and stable in the final frame.

## Five-channel cross-check

1. **Frames:** `screen.mov` is a 60 fps Anselm-window recording, finalized at
   `171.086667s`; the stable final frame shows the exact document result and the
   distinction between lexical success and semantic availability.
2. **Backend journal:** `backend.log` has 271 lines, no panic/fatal/error/exception/
   warn records, and records the real document creation, reindex, conversation,
   tool loop, and clean shutdown.
3. **SSE witness:** `sse.jsonl` contains all three stream connections. The messages
   stream has durable seq `1..33`, including the user message, assistant tool calls,
   tool results, and final text. Notifications has durable seq `1..3` for document
   creation, conversation creation, and auto-title; entities was connected and had
   no entity mutation in this path. No gap event was recorded.
4. **Frontend console:** `frontend.log` contains only the normal Flutter startup
   lines and one macOS IMK mach-port diagnostic; no FlutterError, DartError,
   RenderFlex, Unhandled, or application exception. The IMK line is platform input
   host noise, not an App error, and did not grow during the stable interaction.
5. **LLM wire:** `llm.jsonl` records the real managed gateway challenge/install/
   models handshake and four streamed chat-completion turns, all HTTP 200. The
   tool sequence in the wire is `search_documents` then `read_document`, matching
   the durable transcript and the visible tool cards.

`rig-check.sh` passed all five physical observers before shutdown. `rig-down.sh`
finalized the recording and stopped the backend, SSE witness, LLM tap, and App;
there are no session processes left.

## Scope boundary

This L2 result proves the product's user-facing search path remains truthful when
the semantic layer is explicitly off. It does not claim that a user can discover or
change the machine-level embedder in the Settings ocean; that surface is not present
and is deferred to the appropriate settings/discoverability coverage row.
