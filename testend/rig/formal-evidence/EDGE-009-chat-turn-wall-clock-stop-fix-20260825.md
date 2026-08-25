# EDGE-009 stop-and-fix · chat turn wall-clock timeout

## Red finding

The chat total wall clock did prevent a stalled turn from remaining `streaming`, but the shared
loop classified the deadline as ordinary user cancellation. A user therefore saw an ambiguous
cancelled terminal instead of learning that the app stopped the turn protectively to remain
responsive.

## Fix

Chat marks its own total deadline in the request context. The shared loop preserves ordinary
cancellation for every other host and for explicit user Cancel, while a chat-owned
`DeadlineExceeded` becomes `error/CHAT_TURN_TIMEOUT` with an actionable message. The transcript maps
that code to localized copy telling the user to send a follow-up or simplify the task; neither the
internal code nor `context deadline exceeded` is shown. The error-code, loop, and chat domain docs
now describe this durable terminal contract.

## Verification

The chat regression uses a stream that waits until its context is cancelled and a one-second
`ChatTurnSec` limit. It proves the assistant message is not left pending/streaming and now asserts:

```text
status=error
stopReason=error
errorCode=CHAT_TURN_TIMEOUT
errorMessage is non-empty and actionable
```

Focused backend suites passed:

```text
cd backend && mise exec -- go test ./internal/app/chat ./internal/app/loop \
  ./internal/app/agent ./internal/app/subagent ./internal/pkg/reqctx -count=1
→ PASS
```

Focused transcript regression covers the timeout together with `MAX_STEPS_REACHED`,
`TOOL_ERROR_STORM`, and `CONTEXT_INPUT_TOO_LARGE`; it asserts localized copy and no raw code/detail.
`make -C frontend analyze` → `No issues found`.

## Five-level applicability

- L1 `pass`: the stalled turn reaches an honest terminal and the user receives the correct next
  action instead of an ambiguous cancellation. Law `E1` applies.
- L2 `na`: the deterministic stream-stall fixture is a controlled harness boundary; no real
  five-channel gateway session is claimed for waiting several minutes.
- L3 `na`: the focused test records terminal behavior but not a real App frame/timing session for
  this injected stall.
- L4 `pass`: the actual transcript path was updated and locked by a widget regression. Law `E1`
  applies.
- L5 `na`: users do not navigate to the protective wall-clock boundary as a feature; it is a
  resilience boundary.
