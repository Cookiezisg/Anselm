# SURF-099 i18n/tree 调查

## 结论

本格先修复中文无障碍树标签的半角逗号，改为 `JSON 树，N 项`，并重新生成 slang 产物。真实 App 通过 Workflow → Flowrun → Scheduler 检查器展示 2100 项列表：树可滚动到末端，1998 后准确显示 `… 101 项已省略`，没有静默丢项或空白折叠。

## 修复与回归

- `frontend/lib/i18n/zh_CN.i18n.json`：`JSON 树,$count 项` → `JSON 树，$count 项`。
- `frontend/lib/i18n/strings_zh_CN.g.dart`：由 `mise exec -- dart run slang` 重新生成。
- `frontend/test/core/settings/locale_boot_test.dart`：新增英文/中文 JSON tree、invalid JSON、circular、more-items 文案断言。
- focused Flutter suite：`an_json_tree_test.dart`、`locale_boot_test.dart` 全部通过。

## 五通道真实证据

正式 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260825-065746`，workspace=`ws_e647ec85f166dac4`。录屏最终帧为 `sessions/20260825-065746/evidence/frames/SURF-099-i18n-tree-final.png`；backend 670 行、frontend 4 行、SSE 348 行、LLM 43 行。三路 SSE 均连接，durable 区间为 notifications 16–26、messages 1–76、entities 7–24。LLM tap 全部 HTTP 200。

真实 UI 路径为调度 → `surf099_tree_workflow` → 运行 → 手动 07:05 → 打开 → `tree` 节点。AX 读到 `JSON 树，1 项`，这是顶层 `text` 键的真实计数；滚动树尾读到 `1993..1998` 和 `… 101 项已省略`。录屏中右岛布局、行高、颜色和省略标记清晰。

前端 journal 有一条 macOS 输入法平台日志 `error messaging the mach port for IMKCFRunLoopWakeUpReliable`；它不伴随 Flutter/Dart/RenderFlex/RenderBox/Unhandled/Exception，已在 session evidence 中作为环境事实披露，不把它误判成产品错误。

## 边界

invalid JSON、循环引用的组件级行为已由 focused widget tests 覆盖；正常 Workflow 输出不能构造 Dart 循环引用，也不会把非法 JSON 字符串交给 `AnJsonTree(jsonString:)`，因此不伪造真实 UI 触发证据。未修改 `_maxNodes`、CODEX、anchors、alarm 算法或阈值。
