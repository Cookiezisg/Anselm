# EDGE-277 文档改名子树级联：修复后真实 App 验收

- 日期：2026-09-01
- 现场：`/private/tmp/anselm-rig-formal-20260831-11/sessions/20260901-103306`
- 结论：通过，红点已修复
- 规格：`docs/working/acceptance-loop/CODEX.md` 的 B2、F2、C5、G1

## 目标

把三层文档树的根节点从 `EDGE277 Fixed Rename Root` 改为 `EDGE277 Renamed Root`，验证后端路径级联、SSE 通知、左侧树、当前打开页标题、Inspector 标题/路径和已加载正文最终保持同一真相。

## 真实现场

- 使用修复后的 Flutter Debug App，App PID `9744`，窗口录制 PID `9798`，后端 PID `9235`，SSE observer PID `9284`，LLM observer PID `9202`。
- 通过 REST PATCH 只修改根文档 `doc_e01584d2b0ecb52e` 的 `name`，后端返回 `200`，返回路径 `/EDGE277 Renamed Root`，正文仍为 `Root body stays loaded`。
- 后端树查询随后确认三条路径均已级联：
  - `/EDGE277 Renamed Root`
  - `/EDGE277 Renamed Root/EDGE277 Fixed Child`
  - `/EDGE277 Renamed Root/EDGE277 Fixed Child/EDGE277 Fixed Grandchild`
- 真实 App 画面同时显示：左侧树为 `EDGE277 Renamed Root`，中心标题为 `EDGE277 Renamed Root`，Inspector 标题为 `EDGE277 Renamed Root`，Inspector 路径为 `/EDGE277 Renamed Root`，正文仍为 `Root body stays loaded`。稳定画面：`sessions/20260901-103306/evidence/edge277-renamed-root.jpeg`。

## 五级判定

| 层级 | 法条 | 证据与结论 |
|---|---|---|
| L2 真 | F2 | REST 树、SSE durable `document.updated`、App 树/标题/Inspector 四面交叉一致；SSE 记录见 `sse.jsonl`，包含 `documentId=doc_e01584d2b0ecb52e` 与新路径。正文未被重载或丢失。 |
| L3 顺 | B2 | 受控改名后没有非用户触发的旧标题残留、空白、加载卡住或内容位移；页面稳定后采集录屏画面。 |
| L4 美 | C5 | 同一文档名称在左树、中心主标题和 Inspector 头部一致呈现，标题层级和列内对齐稳定，无截断遮挡；画面证据见稳定 JPEG。 |
| L5 找得到 | G1 | 用户只需在 Library 选择文档即可看到改名后的当前页和属性，不需要理解 provider 刷新或 REST；树、页面、Inspector 给出同一可理解反馈。 |

## 代码修复

- `frontend/lib/features/library/state/library_state.dart:36-55` 新增 `mergeDocumentTreeMetadata`：以树行作为外部改名/移动的元数据真相，但保留已加载正文。
- `frontend/lib/features/library/ui/library_ocean.dart:465-493` 当前文档页以合并元数据渲染标题、描述和标签，同时继续以已加载正文初始化编辑器，避免丢光标。
- `frontend/lib/features/library/ui/library_inspector.dart:480-494` Inspector 标题与路径使用同一合并结果。
- `frontend/test/features/library/library_test.dart` 新增单测，锁定“标题更新但正文保持已加载内容”的不变量。

## 五通道台架

- `testend/rig/rig-check.sh`：五通道物理归属全部通过。
- `backend.log`：无 panic、fatal、error 或 warn。
- `frontend.log`：无 Flutter error/exception/overflow；唯一匹配为 Dart VM service 启动提示。
- `sse.jsonl`：三条流均连接并收到 durable `document.updated`，关停时正常 EOF。
- `llm.jsonl`：LLM observer 已接线并记录启动握手；本场景无模型回合。
- 录屏：已正常 finalize，时长约 78.98 秒，无外部覆盖层。

## 本地验证

```text
flutter analyze lib/features/library/state/library_state.dart lib/features/library/ui/library_ocean.dart lib/features/library/ui/library_inspector.dart
No issues found!

flutter test test/features/library/library_test.dart
58 tests passed

go test ./internal/app/document ./internal/infra/store/document
PASS

go test -race ./internal/app/document ./internal/infra/store/document
PASS
```
