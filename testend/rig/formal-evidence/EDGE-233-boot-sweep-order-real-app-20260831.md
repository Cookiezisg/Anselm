# EDGE-233 boot 顺序 SweepMisfires：真实 App 五通道证据

## 结论

本格通过。使用同一数据目录完成真实 active cron listener 的 setup session 后，正常收台
再启动正式 App。正式 boot 先重挂 active workflow listener，再执行 misfire sweep；两条
跨停机窗口的 cron 刻度被记为 `missed`，没有生成 `flowrun`，没有补跑 workflow。

## Session

- setup session: `/private/tmp/anselm-rig-ep233-setup-20260831/sessions/20260831-135329`
- formal session: `/private/tmp/anselm-rig-formal-20260831-15-edge233/sessions/20260831-135552`
- shared data: `/private/tmp/anselm-data-edge233-20260831`
- real App recording: `screen.mov`, H.264, `3104x1844`, `60fps`, `58.195000s`
- real managed gateway: `https://api.anselm.website`; formal llmtap used the persisted managed key
  through `127.0.0.1:8846`

## Setup and restart path

1. Setup session used `seed_surf040.py` over the running backend to create and activate
   `surf040_hot_cron_pipe` with a real `surf040_hot_cron` listener. The setup session then
   stopped through `rig-down.sh`.
2. To model the elapsed shutdown window, only the persisted test data's trigger timestamps were
   backdated to two days before the formal boot. No firing row was inserted by hand.
3. Formal `rig-up.sh` booted the same data directory and a fresh backend/App/taps. Its boot order
   in `backend/internal/bootstrap/build.go` is `ReattachActive` followed by `SweepMisfires`.

## Cross-channel proof

- **Product/frame**: Computer Use opened the real Scheduler. The final frame
  `evidence/frames/edge233-final.png` shows `Running 0`, `Waiting 0`, `Failed · 24h 0`,
  `Missed · 24h 1`; the schedule row states `0 runs in 24h: 0 ok, 0 failed, 1 missed`,
  and the next fire remains visible. There is no misleading catch-up run or stuck loading state.
- **Backend/SQLite**: after formal boot, `trigger_firings` contained exactly 2 rows for the
  active cron, both `status=missed`, both with empty `flowrun_id`; `flowruns` for the workflow
  remained `0`. The trigger's `missed_checked_at` advanced to the boot sweep time.
- **SSE**: independent ssetap connected to notifications, entities and messages once each and
  disconnected cleanly at shutdown. This scheduler-only boot path emitted no fabricated message
  or entity durable event.
- **Frontend**: no `FlutterError`, `DartError`, `RenderFlex`, `Unhandled`, `Exception`, ERROR or
  FATAL line; final Scheduler frame has no clipping, overlap, white flash, stale loading state or
  input/viewport jump. The only known non-product host diagnostic was absent from this formal log.
- **LLM wire**: llmtap was ready and the persisted managed key passed through the fresh tap; formal
  bootstrap traffic was not confused with a fabricated completion. No model call was necessary
  to prove the scheduler invariant.

`rig-check.sh` passed while live and `rig-down.sh` finalized all owned processes, listeners and
the recording. Focused misfire and `ReattachActive_UsesReplayPath` tests remain the L1 detail;
this session is the independent real-App L2 evidence.

## Judgement boundary

L1 existing focused evidence uses `F5`. L2 uses this real restart session and `F2`: the durable
missed ledger, zero flowruns and Scheduler projection agree. L3 uses `A4`: the restarted App
shows the missed state and remains usable without an implicit execution. L4 uses `C4`: the final
Scheduler summary and schedule track are legible and stable. L5 uses `G1`: the missed state is
discoverable from the Scheduler overview without requiring knowledge of internal database terms.
