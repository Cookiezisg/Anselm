# SURF-073 · settings/panel-sandbox · 五级正式证据

## Scope

真实 App + managed gateway，覆盖 Sandbox 的健康门、机器级磁盘占用、用户运行时安装/删除、五类 owner 环境、环境删除、GC 两步确认和恢复路径。所有操作在同一真实窗口逐帧完成，未使用 fixture UI 或直接改数据库冒充产品结果。

## Sessions and attribution

- Green session: `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260820-001124`
- Data: `/private/tmp/anselm-data-surf073-20260820-r1`
- Workspace: `ws_a8955c11bf9eccd4`
- Recording: `screen.mov`, 572.355000s, 2560x1584, H.264, 60fps
- `rig-check` passed before and after the walk; `rig-down` stopped and finalized all owned processes.

## Product paths

- Healthy landing state showed honest `453.1 MB`, installed engine runtimes, Python `3.12`, UV `0.11.4`, function environments, and all five owner tabs.
- Installed Python `3.13` through the real form; the roster and disk projection changed to `515.4 MB`, then returned to `453.1 MB` after confirmed deletion.
- Confirmed deletion of Python `3.12` while two function environments referenced it; backend returned `409`, the runtime stayed visible, and the UI showed `Envs still reference this runtime — clear them first`.
- Opened and cancelled an unused-runtime deletion, then confirmed deletion; the confirmation copy explicitly stated permanence and the ability to reinstall later.
- Visited Functions, Handlers, MCP, Skills, and Conversations. Functions showed real environments; empty owners showed the honest `No environments` state rather than a loading or fake row.
- Opened and cancelled environment deletion, then confirmed deletion. The owning function remained; the environment row disappeared and the machine disk projection refetched.
- Opened the GC confirmation, cancelled it, reopened it, confirmed `Reclaim all now`, and observed `Reclaimed 2`, all owner tabs refetched, and `No environments`.
- Induced a real degraded bootstrap by temporarily replacing the sandbox directory with a file, then restored the directory before recovery. The UI showed a localized health callout without leaking the filesystem path; `Retry` restored the healthy state.
- Used real keyboard events for malformed dotnet input and received the immediate actionable message `dotnet not-a-version isn't supported. Use a release version such as 10.0.300, then try again.` The first attempt using `set_value` is excluded as product evidence because it changed the visible Flutter field without invoking `onChanged`; it installed the field's default version and was cleaned up.

## Five channels

- Frames: the owned window recording contains healthy, install, confirmation, 409 protection, owner tabs, GC completion, degraded callout, retry recovery, and invalid-version feedback.
- Backend: `backend.log` has 726 lines. Sandbox endpoints include runtime install `201`, runtime-in-use `409`, runtime delete `204`, environment delete `204`, GC `200`, bootstrap failure/retry `200`, and invalid-version `422`. The only WARN is the intentionally induced degraded bootstrap; no panic, fatal, exception, traceback, or frontend layout redline.
- SSE: `sse.jsonl` has 11 lines, including independent connections to all three streams and durable `sandbox.env_deleted` notifications for direct deletion and GC; all streams closed cleanly at shutdown.
- Frontend console: `frontend.log` has 4 lines: direct App launch, Dart VM, and known macOS CapsLock host noise. No Flutter exception or application error.
- LLM wire: `llm.jsonl` has 10 lines; managed challenge/install/models all returned `200`. This deterministic settings path produced no model completion, which is recorded rather than fabricated.

## Laws and level mapping

- L1 / achieved: `G1` — the user can understand and complete the Sandbox maintenance task through the product surface.
- L2 / true: `F1` — UI projections agree with backend rows, SSE facts, disk bytes, and the final filesystem state.
- L3 / smooth: `B2` — destructive actions have explicit confirmation, busy/disabled behavior, honest recovery, and no silent empty-state substitution.
- L4 / beautiful: `C4` — health/error/empty/success states preserve the panel's spacing, hierarchy, contrast, and concise copy.
- L5 / discoverable: `G1` — runtime, owner tabs, retry, and GC actions are visible at the point of need and do not hide the next action.

## Result

No product-level stop-and-fix defect remains in SURF-073. The `set_value` observation is an instrument limitation and is explicitly excluded from the green judgment; the same path was re-run with real key events and rejected immediately by the product.
