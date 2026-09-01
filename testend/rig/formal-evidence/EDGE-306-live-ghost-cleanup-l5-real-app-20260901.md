# EDGE-306 导演器清 Live 幽灵：L5 真实 App 可发现性证据

## Blind product path

- session: `/private/tmp/anselm-rig-formal-20260831-11/sessions/20260901-171649`
- data: `/private/tmp/anselm-data-edge306-l5-real-20260901`
- workspace: `ws_70605a425f4f5732`
- recording: `screen.mov`, `152.021667s`
- final frame: `evidence/EDGE-306-l5-final.png`

The test began from a clean Chat landing page. The user did not mention `Activity`, `Library`,
tool names, or internal IDs in the goal. They asked in ordinary language to create a document named
`EDGE306-L5-Discoverable` with body `discoverability check`, then say where it could be viewed and
edited.

The first real response completed the creation and told the user to use the left-side `Library`.
The response did not expose implementation terms or ask the user to guess where the result lived.
Computer Use then clicked `Library`: the document appeared in the list. Clicking the document opened
the editor with the exact title, exact body, path `/EDGE306-L5-Discoverable`, size `21 B`, and the
properties panel. This verifies the promised next step rather than accepting prose-only guidance.

## Product judgment

The route is discoverable from the user's goal alone: creation result in Chat, explicit destination
in the response, visible `Library` navigation, document row, then editable document surface. The
empty editor shown immediately after entering Library is an intentional no-selection state; selecting
the named row reaches the correct document without a dead end or hidden internal concept. The final
frame shows the document content and properties without clipping, overlap, or stale Live activity.

## Five-channel cross-check

- Channel 1 frames: window-owned recording and final frame show Library, the selected document, exact
  body, path, size, and properties.
- Channel 2 backend: PID `38521` owned `:8743`; backend journal has no application `WARN`, `ERROR`,
  `panic`, or `FATAL` line.
- Channel 3 SSE: `ssetap` PID `38569` connected to notifications, entities, and messages; the
  messages witness recorded `47` durable frames for the create and conversation updates.
- Channel 4 frontend: direct App PID `39021`; the only error text is the known macOS IMK host line;
  no Flutter, Dart, RenderFlex, RenderBox, Unhandled, or Exception application error appears.
- Channel 5 LLM wire: `llmtap` PID `38490`; managed proof/install/models and the chat completion
  returned HTTP `200`.
- Rig: `rig-check` passed the five physical observers before interaction; `rig-down` finalized the
  recording and left no managed process running.

## Judgment input

This evidence supports L5 `G1`: a first-time user can infer where the created result is and reach the
editable document without internal vocabulary, hidden route knowledge, or a second explanatory loop.
