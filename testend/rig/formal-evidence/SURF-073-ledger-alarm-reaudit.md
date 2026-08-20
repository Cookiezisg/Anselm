# SURF-073 · 账本与警报复审

- Re-audit time: 2026-08-20 00:22 +08
- Scope: the independent five-level judgment for `settings/panel-sandbox`.
- Evidence: `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260820-001124/evidence/SURF-073-settings-panel-sandbox-five-level.md`
- The red observation was not a product failure: Computer Use `set_value` updated a visible Flutter field without firing `onChanged`. The resulting default-version installation was cleaned up, and the malformed-version path was repeated with real keyboard events and returned `422` immediately.
- The only backend WARN is the deliberately induced bootstrap failure used to prove the degraded health callout and Retry recovery. It is expected evidence, not an unexplained application fault.
- `gap-too-fast` and `discovery-collapse` may open after the five ledger writes; any opened alarm must be acknowledged against this independent evidence without changing thresholds, algorithms, CODEX laws, anchors, or the ledger gate.
- Final judgment must remain five serial writes: `G1 / F1 / B2 / C4 / G1`.
