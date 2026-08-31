# EDGE-212 · real App transient free-tier failure red discovery

## Discovery result

The real App path was exercised with one injected `GET /v1/quota → 429` response from the local
llmtap. The managed row already existed and was not altered. The Models & keys card showed a
Repair button, but its error copy said:

> Couldn't read the free-tier quota — the device registration may have been revoked. Repair
> re-registers this device; conversations and settings are untouched.

That copy is too strong and misleading for a transient rate-limit or network failure: it implies
the existing installation may be broken and that repair will re-register it, while this scenario's
contract is specifically to preserve the existing install and retry without rotation. This is a
product-facing stop-and-fix finding, not a green judgement.

## Five-channel facts

- **Frame**: `edge212-quota-error-before-repair.png` shows the error card and visible Repair CTA;
  `edge212-quota-recovered-after-repair.png` shows the recovered quota card.
- **Backend**: the sidecar recorded `GET /api/v1/freetier/quota → 429`, then the repair
  `POST /api/v1/freetier:provision → 200` and quota reread `→ 200`; no panic or application error.
- **SSE**: all three streams were physically connected by `rig-check`; this settings-only path
  has no chat message stream event to invent.
- **Frontend console**: no Flutter/Dart/RenderFlex/Unhandled exception; only the known macOS IMK
  host diagnostic.
- **LLM wire**: llmtap recorded the real managed proof challenge, the injected quota response,
  the successful models probe, and the successful quota reread. No install request occurred.

## Stop-and-fix boundary

The current session is retained as the red observation. The repair copy must distinguish transient
read failures from a revoked install and explicitly state that the existing registration is kept.
No L2-L5 ledger cell is written from this session.
