# EDGE-312 L5 独立账本与警报复审

- subject: `EDGE|版本组走 retryOf L5`
- primary evidence: `testend/rig/formal-evidence/EDGE-312-retry-version-groups-l5-real-app-20260901.md`
- session: `/private/tmp/anselm-rig-formal-20260831-11/sessions/20260901-200323`
- re-audit time: `2026-09-01T12:08:00Z` (approx.)

## Independent checks

- `anchors.py check`: 10/10 anchor classes passed before and after this judgment; no anchor drift or missing calibration.
- The primary evidence names a complete rig session and can be re-opened independently: `screen.mov` is `62.473333s`; backend, SSE, frontend and LLM journal files are present and non-empty where applicable.
- The product path is an ordinary user goal rather than an internal test instruction: open a conversation, find the visible `3/3` pager, inspect prior answers, understand the relationship note, and return to the current answer.
- The five channels agree on the same fact: the action changes only the viewed version of one assistant container; it does not create a new message, trigger a model request, or mutate durable history.
- `measure diff` on the extracted 1fps PNGs reports only one action-window change at `f021→f022=0.03515` with threshold `0.01`; no post-action drift or uncommanded redraw was observed.
- `frontend.log` contains no Flutter or application exception; `backend.log` contains no WARN, ERROR, panic or fatal.

## Alarm disposition

`discovery-collapse` opened because the trailing 50 live judgments contain no `fail` verdict. This is the expected statistical safeguard, not evidence that the product is broken: the judgment is supported by a fresh real-App session, independent five-channel agreement, anchor self-check, and a measurable stable-frame result. The alarm is acknowledged with this reason and the final alarm check is required to be clean.
