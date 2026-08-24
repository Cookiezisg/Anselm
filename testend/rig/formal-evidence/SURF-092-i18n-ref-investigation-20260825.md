# SURF-092 i18n/ref — investigation and product review

## Static finding

`AnRefPill` routes every reference label through `entityKindWord(context, kind)`. The switch covers the eleven supported entity kinds: function, handler, workflow, agent, document, conversation, skill, mcp, trigger, control and approval. Unknown kinds intentionally fall back to their raw value so a forward server value is not silently hidden.

The existing widget tests cover glyph resolution, interactive tap payloads, semantic labels, empty/null IDs, unknown kinds and long labels. A new locale regression asserts the complete eleven-word set in both `en` and `zh_CN`; the focused locale/ref suite passed `12/12`.

## Real App witness

Session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260825-051028`, data=`/private/tmp/anselm-data-surf092-20260825-r1`.

Computer Use navigated Entities, Library and Settings/MCP, opened the Chat mention picker, selected `sync_inventory`, and sent `请简要说明这个实体的作用。` with the inserted reference. The managed gateway model interpreted the reference as the `sync_inventory` function, executed it once, and returned `{"synced":42}`. The transcript and Activity island both showed the same successful execution; SSE close frames and the LLM tap corroborate it.

The visible chip uses the function glyph plus `sync_inventory`. This is the intended compact product treatment; repeating `函数` beside every chip would create visual noise. The localized type word remains available in the semantic and annotation paths and is locked by the new exact-set regression.

## Product judgment

No stop-and-fix defect remained in this surface. The real path was discoverable, the reference achieved its purpose, the type/name distinction was visually clean, and no label overflow or unexplained state transition appeared. The evidence deliberately separates the real one-function execution from the eleven-kind static contract instead of claiming eleven live executions.

## Cross-channel result

- screen: `102.840000s`, window-bounded, final frame only Anselm;
- backend: `228` lines, no application panic/error red line;
- SSE: `76` lines, three streams, monotonic durable messages and completed notification;
- frontend: `4` lines, only reviewed VM/IMK host noise;
- LLM wire: `19` lines, managed proof/install/models plus the real completion.

Old sessions were not used as green evidence. No gate, law, alarm threshold or anchor was changed.
