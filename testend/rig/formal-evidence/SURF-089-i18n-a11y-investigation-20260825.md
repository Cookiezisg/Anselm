# SURF-089 i18n/a11y investigation

Status: **BLOCKED / not a judgment**

This is an investigation record, not green evidence. The coverage row remains pending until the
macOS accessibility tree exposes the inline editor's field identity without a visual regression.

## Scope

- `i18n/a11y`: screen-reader labels for edit fields, more-actions menu, and relation-graph zoom controls.
- Real App build, real seeded workspace, real macOS AX tree, screen recording, backend journal, SSE tap,
  and LLM tap were all active under the acceptance rig.
- Final relevant sessions: `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260825-034727` and
  `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260825-035153`.

## Evidence

- Static Flutter tests passed: `an_a11y_test.dart`, `an_input_test.dart`, `an_inline_edit_test.dart`,
  plus the previously selected SURF-089 primitive suite.
- `更多操作` opened with localized `展开全部` and `收起全部`.
- Relation graph exposed localized `缩小`, `放大`, and `适应画布`; each action left the graph stable,
  with no clipping or overlap in the recorded frame.
- The edit affordance is field-specific (`编辑 描述` in the Chinese App) and entering edit announces the
  field identity through the shared `AnA11y` transition path.
- The real macOS AX tree still reports the focused inline editor only as an unnamed `text field (settable)`.
  Three implementations were tried in isolated builds: an outer `Semantics` label, an explicit editable
  semantics node, and an `InputDecorator` native label/hint. The first two were dropped by the bridge;
  the visible native hint was also visually clipped in the 32px empty editor and was reverted.
- Channel checks: backend attribution/health passed; three SSE streams connected with no gaps; LLM tap
  probes were HTTP 200; frontend journal had no `ERROR`, `Exception`, `RenderFlex overflow`, or panic marker;
  the final screen recording was sealed by `rig-down`.

## Required follow-up

Do not mark any of the five SURF-089 levels green, do not advance the 20/50 batch counter, and do not
run the unified gate or commit until the actual macOS AX node either carries the field identity or the
product constitution explicitly accepts the named affordance plus transition announcement as the
platform-specific equivalent.
