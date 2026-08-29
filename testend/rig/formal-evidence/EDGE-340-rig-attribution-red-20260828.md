# EDGE-340 · invalid rig session (not ledger evidence)

The first attempt used session `20260828-034655` and is explicitly rejected.
While `rig-up` was still building Flutter, a Computer Use state probe launched an
unowned App process (`55310`). The conductor later launched App PID `55440`, but
the probe continued operating the other window. That session also had no
workspace-connected SSE streams and no LLM request journal, despite the product
screen being visible.

This was a test-instrument attribution failure, not an EDGE-340 product result.
No judgment was written from it. The rig was changed to re-check for App
processes after the build and to fail if any unowned App exists at launch or at
`rig-check`; the clean rerun is session `20260828-035055`.
