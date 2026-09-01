# EDGE-333 · 保留面板无客户端默认 · L5

## 判定

`G1` 通过：starting from the real App's Settings surface, a user can identify `Storage & logs`, then the explicitly named `Run history retention` row, without documentation or hidden route knowledge. The scope badge, description and dropdown labels explain what is being changed.

## Blind product path

1. Start at the real App Settings surface.
2. Select `Storage & logs` from the visible System group.
3. Locate the row named `Run history retention`; its copy says settled runs older than the selected line are cleared and that statistics/failure aggregation are unaffected.
4. Open the visible dropdown and choose among 30/90/180 days or Keep forever.
5. Verify the success notification and the selected value; restore the original 90-day value.

The path was executed against workspace `ws_8397891fc75d3e99` in session `/private/tmp/anselm-rig-formal-20260902-02/sessions/20260902-001814`. The final UI and `GET /api/v1/retention` both reported `90`.

## Honest boundaries

The control is disabled until the server value resolves in code, so it cannot invent a 90-day client default during loading. There is no modified/reset affordance that would require an unowned client-side default. The same real session contains the complete frame, backend, SSE, frontend-console and LLM-wire journals; the settings journey correctly produces no business durable SSE event.

