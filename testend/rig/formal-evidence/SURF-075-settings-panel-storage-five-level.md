# SURF-075 · settings/panel-storage · 五级正式证据

## Scope

真实 macOS App、真实受管 Anselm 网关和 Computer Use 覆盖 Storage & logs 的数据目录、磁盘/数据库/附件统计、诊断复制、Run 历史保留、数据库压缩、Reset local preferences，以及最终的 Factory reset。此次确认的是不可逆出厂重置：用户在真实危险区输入 `Anselm` 并点击 `Erase everything & relaunch`，应用退出并重新启动到全新安装 onboarding。

## Sessions and attribution

- Green session: `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260820-121523`
- Data root: `/Users/sunweilin/Library/Containers/website.anselm.app/Data/.anselm-surf075-formal-r4`
- Initial workspace: `ws_1741cdc98bf0b39c`
- Initial App/sidecar: `57551 / 57583`, port `57881`
- Replacement App/sidecar after reset: `57682 / 57684`, port `58408`
- Window recording: `screen.mov` `322.903333s` plus `screen-rebind-57682.mov` `17.951667s`; combined `screen-final.mov` `340.870000s`, H.264, `2560x1584`, 60fps
- The post-reset window moved by one pixel (`80,40,1280,792` → `80,39,1280,792`). The conductor refused a stale crop, sealed the first segment, started an explicitly attributed second segment, and recorded the rebind in `app-rebind.jsonl`.

## Product path and result

- Fresh onboarding was used to create the temporary workspace `Factory reset acceptance`, then Settings → Storage & logs was opened through the real UI.
- The storage panel exposed the configured sidecar data root, storage statistics, diagnostics action, retention controls, compact action, reset-preferences action, and the danger zone.
- The danger-zone confirmation was entered with real keyboard events: `Anselm`.
- A fresh Computer Use state was read immediately before the final destructive click. The action was `Erase everything & relaunch`; the app quit as designed and a replacement App window appeared.
- The replacement App displayed `Create a workspace` and no prior workspace. No old workspace was shown in the UI.
- The configured data-root directory and `anselm.db` were absent after reset. This is consistent with the product contract: a new install does not create the database until a workspace is created.

## Stop-and-fix history

- A prior external-backend attempt correctly failed: the backend still held the database/WAL files, so recursive deletion returned `Operation not permitted`. That red attempt is retained as diagnostic evidence and is not counted as product success.
- The product/台架 fix made deletion asynchronous and bounded, stopped the App-owned backend before removal, restored an actionable danger zone on failure, and made `ANSELM_DATA_DIR` authoritative for fresh-install detection.
- The conductor fix added App-owned sidecar token discovery, atomic App/sidecar/SSE rebind, and an optional `ANSELM_RELAUNCH_LOG` so replacement App console output can remain in the same session journal.

## Five channels

- Frames: `screen.mov` and the post-reset `screen-rebind-57682.mov` are readable; the combined `screen-final.mov` is also readable. The first segment contains the real onboarding → workspace → Settings → Storage → confirmation path; the second contains the replacement App's onboarding state.
- Backend: `backend.log` has `119` projected entries and no panic, fatal, WARN, ERROR, or traceback marker. The reset shutdown includes the expected graceful sidecar stop and `factory-reset` controller markers. The replacement empty-onboarding state produced no workspace mutation to invent as backend evidence.
- SSE: `sse.jsonl` has `966` lines. The independent witness discovered the temporary workspace and connected `messages`, `entities`, and `notifications` separately. No `tap=gap` was recorded; this deterministic reset path produced no durable business frame. Shutdown connection-refused entries target the deliberately stopped pre-rebind port and are an expected conductor teardown tail, not an app error.
- Frontend console: `frontend.log` has `227` lines and no `Unhandled exception`, `FlutterError`, `RenderFlex`, `Dart Error/Exception`, or application panic/fatal/error marker. The log contains the real backend stop request and the conductor's explicit App rebind marker.
- LLM wire: `llm.jsonl` has `10` entries. The real managed gateway proof challenge, install, and model discovery all returned `200`. This settings/reset path does not require a model completion, so none is fabricated.

## Laws and level mapping

- L1 / achieved: `G1` — the user can inspect storage controls, understand the irreversible boundary, confirm it, and return to a genuinely fresh install.
- L2 / true: `F1` — UI onboarding, filesystem absence, sidecar lifecycle, SSE observation, frontend journal, and managed-gateway bootstrap agree; no stale workspace survives.
- L3 / smooth: `B2` — the destructive action has an exact confirmation gate, the old sidecar is stopped before deletion, and the relaunch lands in a usable onboarding state rather than a dead or stale screen.
- L4 / beautiful: `C4` — the storage panel and danger zone remain legible at the recorded geometry; the reset transition does not expose a desktop-wide or stale-crop frame.
- L5 / discoverable: `G1` — data controls, diagnostics, retention, compact, preferences reset, and the final factory-reset confirmation are discoverable where the user expects them.

## Result

SURF-075 has no remaining product-level stop-and-fix defect. The irreversible action was performed only after the user's explicit confirmation. The one-pixel relaunch geometry change was handled by the conductor as a recording-segment rotation, not hidden or silently accepted.

## Gate verification

- Focused Flutter settings/process suite: `40/40` passed.
- Rig Python suite: `44/44` passed; rig shell syntax and Python compilation passed.
- Root `make verify`: backend, docs, demo and the repaired frontend gate passed; frontend analyze was clean and the four complete test groups passed with `5376` tests.
- Full `make -C backend testend`: passed, `288.411s`, exit `0`.
- `gen_coverage.py --check`, anchors `10/10`, `alarms.py check`, `git diff --check`, changed-Go `gofmt` and process audit all passed.
