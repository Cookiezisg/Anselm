# EDGE-218 · real App free-tier seeding preserves explicit selection

## Result

GREEN for the required boundary: provisioning fills only unset workspace model
scenarios and does not overwrite an explicit Dialogue selection. The final real App
state shows the user-selected Dialogue model while the other five unset scenarios
remain on the managed Anselm Auto defaults.

Formal session:
`/private/tmp/anselm-rig-formal-20260831-11/sessions/20260831-113541-edge218`

Workspace: `ws_98a8f99fb7bbf385` (`EDGE218 seed defaults`). The managed gateway
challenge, install, models, and quota exchanges all completed through the real LLM
tap. A disposable local OpenAI-compatible endpoint supplied `gpt-4o` only so the
explicit BYOK selection was visibly distinct; it was not used as a managed route and
no real user secret was used.

## Controlled sequence

The conductor started a fresh data directory with `RIG_SEED=0` and launched the real
App. Computer Use created the workspace, opened Settings → Models & keys, selected
the Dialogue `gpt-4o · EDGE218 Explicit` model from the tested disposable key, and
applied the change. Provisioning was then triggered through the real HTTP route
`POST /freetier:provision`.

The authoritative read after provisioning was:

- Dialogue: `apiKeyId=aki_d0c2f00223c2994d`, `modelId=gpt-4o`
- Utility, Agent, Image generation, Speech synthesis, Video generation:
  managed `anselm-auto`

The same values were present in the SQLite workspace row and in the App's rendered
Models & keys panel. The explicit Dialogue selection survived; only the five zero
slots were seeded.

## Five-channel evidence

- **Frame**: `evidence/edge218-seed-defaults-fixed.png` shows all six scenario rows:
  Dialogue is `gpt-4o · EDGE218 Explicit`; the other five are `anselm-auto · Anselm
  Free`. The settings surface is complete and the selected state is not clipped.
- **Backend**: the post-provision REST response and direct SQLite read agree on all
  six defaults. The backend journal contains no panic, application `ERROR`, or
  `FATAL`.
- **SSE**: all three resident streams connected for the created workspace and ended
  with clean EOF at teardown. This settings-only operation produced no durable chat
  or entity frame, so none is fabricated here.
- **Frontend console**: `frontend.log` contains no Flutter, Dart, RenderFlex, or
  unhandled application error. The only host diagnostic is the known macOS IMK
  message.
- **LLM wire**: `llm.jsonl` records managed gateway challenge/install/models/quota
  responses as `200`. The disposable local provider was used only for the explicit
  BYOK model probe; no key value was logged or sent to the managed gateway.

`rig-check` passed all five physical observers after an unrelated persistent
`UserNotificationCenter` window was removed from the recording surface. `rig-down`
finalized the `614.816667s` recording and stopped all owned processes. The temporary
local provider was terminated after capture.

## Judgement

- **L2 F2**: final frame, durable REST/SQLite state, backend journal, three-stream
  observer, frontend console, and managed wire observer agree.
- **L3 A4**: the applied selection is immediately reflected and remains stable after
  the provisioning action; no silent overwrite occurs.
- **L4 C4**: the six-row settings hierarchy is readable, aligned, and unclipped in
  the finalized frame.
- **L5 G1**: a user can discover the Dialogue model picker in Settings → Models &
  keys and understand that explicit configuration is preserved when enabling the
  free tier.

This evidence covers provisioning's unset-only semantics. It does not claim that a
chat completion was performed in this settings-only session.
