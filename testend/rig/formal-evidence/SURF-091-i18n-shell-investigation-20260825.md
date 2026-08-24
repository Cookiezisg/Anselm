# SURF-091 i18n/shell — investigation and stop-and-fix record

## Initial finding

The first real App AX tree showed `收起侧栏`, `对话`, `设置` and `通知`, but the three collapsed icon-only ocean slots were anonymous buttons. The screenshot showed the icons correctly, so a screenshot-only sweep would have missed the discoverability failure.

## Fix

`frontend/lib/core/ui/an_ocean_switcher.dart` now gives every slot the localized item label and forces it into the native accessibility order. This leaves the visual switcher geometry and animation unchanged. `frontend/test/core/ui/an_ocean_switcher_test.dart` locks the all-collapsed (`selectedIndex=-1`) case for `Chat`, `Entities`, `Scheduler` and `Library`.

## Revalidation

The old binary was stopped and discarded from green evidence. A fresh build/session=`20260825-050144` showed native AX labels for all four oceans, successful switching to entities/scheduler/library, settings/workspace menu labels, notification-tray takeover, and collapse/restore labels. Focused suite=`35/35`.

## Reserved coming-soon keys

`comingSoonTitle` and `comingSoonHint` still feed `_OceanPlaceholder` and `_RailPlaceholder`, but `OceanKind.isBuilt` is true for all enum values and both lazy stacks contain all five values. There is no user-reachable non-built ocean in this revision. The acceptance evidence records this as an explicit unreachable invariant rather than claiming a false UI interaction.

## Evidence integrity

The final session was owned by the conductor. `rig-check.sh` passed all five physical channels; the screen was window-bounded; backend/SSE/frontend/LLM journals were retained after `rig-down.sh`; no alarm threshold, law, anchor or gate was changed.
