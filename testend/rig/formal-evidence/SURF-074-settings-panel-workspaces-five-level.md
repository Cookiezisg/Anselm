# SURF-074 · settings/panel-workspaces · 五级正式证据

## Scope

真实 macOS App + 真实受管网关，覆盖 Workspaces 名册、新建工作区、创建后落入 Chat、当前工作区切换、编辑名称、六色选择、危险区删除确认、删除后的名册真相，以及最后一个工作区不可删除的保护。所有产品结果均通过真实 UI 操作取得，没有用 fixture UI 或直接写数据库冒充结果。

## Sessions and attribution

- Green session: `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260820-002515`
- Data: `/private/tmp/anselm-data-surf074-20260820-r1`
- Initial workspace: `ws_d026c963ede54bdf`
- Created workspace: `ws_bd1e1d04dfb5778b`
- Recording: `screen.mov`, `1286.935000s`, `2560x1584`, H.264, 60fps
- `rig-check` passed while the App was running; `rig-down` finalized the recording and stopped all conductor-owned processes.

## Product paths

- Opened the Workspaces roster and observed the active row with a color dot and `Current` marker.
- Created `Product Lab` through the minimal name form. The product switched directly to Chat; the side rail, workspace footer, empty-chat prompt, and composer all agreed on `Product Lab`.
- Returned to the roster, selected the other workspace, and observed the current marker move without leaving Settings. Selected `Product Lab` again before destructive testing.
- Opened the non-current workspace editor, changed its name from `演示工作台` to `Demo Hub`, selected the sixth color swatch, and saved. The danger copy refetched the new name and real counts: `1 conversations · 4 entities · 2 documents · 0 B of attachments.`
- Entered the exact confirmation text `Demo Hub` with real keyboard events and clicked `Delete forever`. The backend returned `204`; the UI returned to the roster, `Demo Hub` disappeared, and only `Product Lab` remained marked `Current`.
- Opened the remaining workspace editor. It showed the name, six color swatches, Save, and `Current`, with no danger zone or delete action. This proves the last-workspace guard is visible in the product rather than only enforced by an API error.

## Five channels

- Frames: the owned-window recording shows the roster, create-to-Chat transition, active-row switch, edit form, six-color selection, real danger counts, confirmed deletion, post-delete roster, and final-workspace protection. No visible clipping, white flash, stale name, or layout jump was observed.
- Backend: `backend.log` has 1429 lines. Workspace mutations include create `201`, activation `200`, edit `200`, and deletion `204`; post-delete roster requests return the single remaining workspace. No `WARN`, `ERROR`, panic, fatal, exception, or traceback was present.
- SSE: `sse.jsonl` has 15 lines. The independent witness discovered both workspace scopes, connected notifications/messages/entities for each, and recorded clean disconnects at shutdown. No durable sequence gap was reported.
- Frontend console: `frontend.log` has 4 lines containing App launch, Dart VM startup, and known macOS CapsLock host noise only. No Flutter runtime exception or render error was present.
- LLM wire: `llm.jsonl` has 16 lines; managed proof challenge/install/models requests returned `200`. This settings path does not require a model completion, so none was fabricated.

## Laws and level mapping

- L1 / achieved: `G1` — a user can create, switch, edit, and remove a workspace while understanding the current destination.
- L2 / true: `F1` — roster, current marker, danger counts, REST mutation status, SSE scope observation, and final remaining workspace agree.
- L3 / smooth: `B2` — creation lands in a usable Chat, row switching is immediate, destructive deletion requires exact confirmation, and the last workspace is protected without a dead end.
- L4 / beautiful: `C4` — the roster hierarchy, color swatches, danger callout, counts, and final `Current` state preserve spacing, contrast, and action clarity.
- L5 / discoverable: `G1` — New workspace, row switching, edit affordance, color choices, deletion confirmation, and the last-workspace boundary are discoverable at the point of need.

## Result

No product-level stop-and-fix defect remains in SURF-074. The workspace deletion was performed only after explicit user confirmation. The Computer Use runtime was restarted once after a stale kernel; this was an instrument recovery, not a product behavior, and the final UI result was freshly re-read before the action.
