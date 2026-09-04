# EDGE-216 · 被引用的 key 拒删：正式真实 App 证据

- Session: `/private/tmp/anselm-rig-formal-20260905-edge293/sessions/20260905-030139`
- Workspace: `ws_9c6defd281bd5957`
- App: real macOS App, window `16801`, PID `75835`; renderer switch `enable-impeller=false` is recorded in the manifest.

## Fixture and product state

The same workspace contains three isolated user-key fixtures and one managed Anselm key. The real
Settings → Models & keys screen shows the managed key, the two LLM user keys, and the dialogue default;
the Search keys section contains the Brave fixture and its default-search state. The visual witness is
`evidence/EDGE-216-settings-keys-list.png`.

The fixture references are:

- `aki_9098575ed6009a66` → workspace `dialogue` scenario default;
- `aki_2fcfd05dbeea7d89` → workspace default search key;
- `aki_d68d36fe814d6d5d` → agent override on `ag_46ab5d6f94ca6203` (`EDGE216 override agent 20260905`).

## Same-session contract probes

`evidence/EDGE-216-delete-probes-final.txt` records exact-ID DELETE requests for all three sources.
Each returned HTTP `422 API_KEY_IN_USE` with the structured reference kind, id, and human-facing name;
the workspace defaults and agent override remained intact. No fixture was deleted.

This proves the durable deletion guard and all three reference-scanner branches. It does not claim the
UI delete confirmation was exercised: the current Computer Use surface can open the row editor but
cannot reliably trigger the row's hover-only action buttons. Therefore this evidence is intentionally
limited to L2 and is not used to mark L3-L5 green. The product-facing delete confirmation, rejection
feedback timing, visual craft, and discoverability remain in the forced queue until a reliable real
pointer action is available.

## Five-channel witness

- Channel 1: `screen.mov` captures the real settings page and the key rows; the extracted target frame
  is `evidence/EDGE-216-settings-keys-list.png`.
- Channel 2: `backend.log` records all three authenticated `422 API_KEY_IN_USE` responses and no
  application panic/error.
- Channel 3: `sse.jsonl` records connections to messages, entities, and notifications; rejected deletes
  correctly produce no mutation frame.
- Channel 4: `frontend.log` has no application-level Dart/Flutter/RenderFlex/runtime error.
- Channel 5: `llm.jsonl` records managed gateway bootstrap; this deterministic settings path has no
  chat completion, which is expected.

`rig-check.sh` passed while the session was live. After this evidence was collected, `rig-down.sh`
must seal the recording before any L2 ledger action.
