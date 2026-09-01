# EDGE-219 · real App native model-option validation

## Result

GREEN for the native-option contract: a model's published knobs are rendered in the
real App, valid selections persist, an unknown knob is rejected as
`MODEL_OPTION_UNSUPPORTED`, and an invalid value for a published knob is rejected as
`MODEL_OPTION_VALUE_INVALID`. The two rejection codes are distinct at the real
backend boundary and the App keeps the model selection surface actionable.

Formal session:
`/private/tmp/anselm-rig-formal-20260831-11/sessions/20260831-115738-edge219`

Workspace: `ws_f7427c4dad1f2e5b` (`EDGE219 native knobs`). The managed Anselm route
completed challenge/install/models/quota through the real LLM tap. A disposable local
OpenAI-compatible endpoint supplied `gpt-5.5` solely for a controlled BYOK model
catalog; it was not a managed route and no real user secret was used.

## Controlled sequence

The conductor reused a data directory containing the managed key and a disposable
tested BYOK key, then launched a fresh real App so the key roster was read at startup.
Computer Use opened Settings → Models & keys → Dialogue → External model, selected
`gpt-5.5`, and showed both published parameters: `Reasoning effort` and `Verbosity`.
It selected `high` for each and saved the Dialogue default.

The same real backend was then exercised with exact JSON bodies:

- `{ "bogus": "x" }` returned `422 MODEL_OPTION_UNSUPPORTED`.
- `{ "reasoning_effort": "turbo" }` returned `400 MODEL_OPTION_VALUE_INVALID`.
- `{ "reasoning_effort": "high", "verbosity": "high" }` returned `200` and was
  persisted as the Dialogue default.

The final authoritative REST read was:

```json
{"apiKeyId":"aki_b6677b75870e1dbf","modelId":"gpt-5.5","options":{"reasoning_effort":"high","verbosity":"high"}}
```

## Five-channel evidence

- **Frame**: `evidence/edge219-native-knobs-fixed.jpeg` shows the real App model
  picker with the explicit `gpt-5.5` model and the two native parameters visible;
  the final saved summary reads `gpt-5.5 · EDGE219 Explicit` with no error residue.
- **Backend**: exact REST responses prove the unsupported-key and invalid-value
  error-code split, followed by the durable valid options state. The backend journal
  has no panic, application `ERROR`, or `FATAL`.
- **SSE**: all three resident streams connected for the workspace and ended with
  clean EOF at teardown. The settings operation produced no durable chat/entity frame,
  so none is fabricated here.
- **Frontend console**: the direct macOS App journal contains no Flutter, Dart,
  RenderFlex, or unhandled application error. The only host diagnostic is the known
  macOS IMK message.
- **LLM wire**: `llm.jsonl` records real managed challenge/install/models/quota traffic
  through `https://api.anselm.website`; the local endpoint was only the disposable
  BYOK probe and no secret was logged.

`rig-check` passed all five physical observers before teardown. `rig-down` finalized
the `243.450000s` window recording and stopped all owned processes. The malformed JSON
attempt made through Computer Use is not used as error evidence because this host's
keyboard bridge altered punctuation; the exact backend requests above are the
authoritative error split.

## Judgement

- **L2 F2**: final App frame, REST state, backend journal, three-stream observer,
  frontend console, and managed wire observer agree.
- **L3 A4**: published controls expose their legal values, and invalid input is
  rejected without silently changing the durable selection.
- **L4 C4**: the picker presents model capabilities and the two controls in a clean,
  aligned, unclipped hierarchy; the final summary is stable.
- **L5 G1**: a user can discover that native settings belong to the selected model and
  can distinguish an unsupported setting from an invalid value without knowing the
  internal error codes.

This evidence covers model-option validation and settings persistence. It does not
claim a model completion was performed through the disposable BYOK endpoint.
