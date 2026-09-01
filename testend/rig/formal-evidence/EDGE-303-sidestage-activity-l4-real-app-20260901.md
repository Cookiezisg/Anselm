# EDGE-303 侧幕 activity 门控：L4 真实 App 视觉 craft 证据

- session: `/private/tmp/anselm-rig-formal-20260831-11/sessions/20260901-152604`
- data: `/private/tmp/anselm-data-edge303-real-20260901-r1`
- screen: `screen.mov`, 1366x768 capture, finalized `354.335000s`
- stable frames: `evidence/EDGE-303-activity-open.png`, `evidence/EDGE-303-activity-closed.png`, `evidence/EDGE-303-activity-reopened.png`

## Product path

1. 在真实 App 的空 Chat 中先确认没有 activity 时没有右岛入口。
2. 通过真实聊天请求创建文档，等待真实 `create_document` 活动完成。
3. 活动到达后检查 Activity 右岛、头部入口、触点计数和文档名称；随后关闭再重新打开侧幕。

## Craft review

- 右岛完整落在 shell 的 8px 外缘内，右侧和底部留白一致；面板没有 clipping、溢出、重复边框或空的第二层内缩。
- Activity 头部的图标、标题、更多操作和关闭入口在同一控件带；单条触点行的图标、名称和 `Created` 元信息中线对齐，长名称按既有单行省略，不挤压状态词。
- 面板关闭后，中心海洋恢复完整宽度，头部 Toggle panel 入口仍在；重新打开后同一触点、名称和状态稳定重现，没有重复行或空面板。
- 圆角按组件语义核对：`AnIsland` 使用 `AnRadius.chip=12`，窗口/模态的 `AnRadius.island=20` 不误套到这个浮动侧幕；截图中的边界、发丝线和阴影均保持一个 surface 皮肤，没有混用圆角层级。
- 文本层级与颜色沿用 design tokens；`ink` 对白底为 `16.83:1`，`inkMuted` 对白底为 `5.07:1`，均达到 WCAG AA 普通文字门槛。未发现内联颜色或额外字重。

## Five-channel cross-check

- frames: Computer Use 读取真实 App 稳定态；三张稳定截图与窗口专属 `screen.mov` 同 session。
- backend: `backend.log` 1032 行；无 `FlutterError`、Dart/布局异常、应用级 `WARN`/`ERROR`/`panic`/`FATAL` 红线。
- SSE: `sse.jsonl` 135 行；三路流均连接，`notifications` 收到 `document.created` durable seq `16`，无断流缺口。
- frontend: `frontend.log` 5 行；只有已知 macOS IMK 宿主诊断，无 Flutter/Dart/RenderFlex/Unhandled 红线。
- LLM wire: `llm.jsonl` 19 行；真实 managed challenge/install/models 与聊天 completion 均经 `https://api.anselm.website`，状态均为 `200`。

## Focused verification

`stage_alignment_test.dart`、`sidestage_ondemand_shell_test.dart` 和 `stage_panel_test.dart` 全部通过，`16` tests passed。

## Judgment

- L4 `pass (C4)`: 真实 App 的 Activity 侧幕在 activity 门控场景下具有一致的 surface 皮肤、圆角层级、内缩、对齐和省略行为；关闭/重开不制造空面板、重复内容或视觉残留。
- L3 的目标布局重排与揭示时长仍由既有独立证据负责；本证据不把一次布局切换改写成“零像素变化”。
