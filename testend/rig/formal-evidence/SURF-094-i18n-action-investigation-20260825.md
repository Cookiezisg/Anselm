# SURF-094 i18n/action — investigation record

## Static inspection

The eight action resources were already semantically correct in `en.i18n.json` and `zh_CN.i18n.json`. The missing protection was a complete exact bilingual assertion, so `locale_boot_test.dart` was extended to lock all eight values. No source translation change or slang regeneration was needed.

The source audit found generated locale calls for the shared code editor, edit affordance, library inspector/rail, entity rail, chat actions and scheduler/workflow confirmations. Existing widget tests cover delete and cancel behavior; the targeted locale suite passed `6/6` and analysis passed.

## Real-App inspection

Fresh seeded session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260825-052544`.
The real App exposed `复制`/`自动换行` in an entity code detail, `展开全部`/`收起全部` in the library menu, and `添加`/`取消` in the MCP manual-add form. The final screenshot and AX tree agree. No destructive action was performed.

## Boundary

`编辑`/`保存`/`删除` were not forced through a destructive or mutation-heavy UI path solely to manufacture a frame. Their generated call sites and existing behavior tests were checked instead. The run did not require a model completion; readiness/wiring was observed but no completion was labeled.

The frontend journal's Flutter AXTree errors are retained as an external Computer Use/Flutter accessibility-bridge boundary. They appeared while the observer changed rapidly between AX trees, did not prevent subsequent AX reads, and did not produce a user-visible rendering failure. This boundary must remain visible in future rig audits.
