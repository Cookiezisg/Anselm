# EDGE-276 并发同父建文档：真实 App 五级证据

- 日期：2026-09-01
- session：`/private/tmp/anselm-rig-formal-20260831-11/sessions/20260901-101356`
- workspace：`ws_635759dfbee2513e`
- parent：`doc_325473f7911ab7b5`（`EDGE276 Concurrent Parent`）
- 录屏：`sessions/20260901-101356/screen.mov`，已由 `rig-down.sh` 正常封存
- 稳定画面：`sessions/20260901-101356/evidence/edge276-tree-ordered.jpeg`

## 场景与事实

在真实 App、真实 backend、三路 SSE witness、frontend console 和 LLM recorder 均在线时，向同一个父文档并发发送 20 个 `POST /api/v1/documents` 请求。20 个请求全部返回 `201`，没有错误；服务端返回的 `position` 唯一且连续覆盖 `0..19`。

随后通过 `GET /api/v1/documents?parentId=doc_325473f7911ab7b5&limit=50` 复核，结果为 20 个子文档、20 个唯一 position、按 position 有序。真实 App 的 Library 树显示同一顺序：`Child 01, Child 03, Child 04, Child 02, Child 06, Child 05, Child 13, Child 16, Child 19, Child 12, Child 07, Child 15, Child 14, Child 17, Child 11, Child 09, Child 10, Child 20, Child 18, Child 08`。该顺序与 REST 的 `position=0..19` 一一对应，并非依赖请求完成顺序。

在 Computer Use 中选中父节点并滚动 Library 树，层级、缩进和子项持续存在，没有空白、重复、错序、旧计数或 spinner 卡住。录屏中保留了父节点选中、子节点树和 Inspector 的稳定画面。

## 五通道健康

- `rig-check.sh`：通过；backend、ssetap、llmtap、frontend console 和录屏均已接线。
- backend journal：无 panic、fatal、exception、traceback 或应用级错误。
- frontend log：无 Dart/Flutter 应用级错误；仅有已知 macOS 平台诊断。
- SSE journal：连接和帧记录正常，无断流或伪造 durable mutation。
- LLM wire：bootstrap 请求真实经过 recorder；本场景不需要聊天 completion，不虚构不存在的对话帧。
- App CPU 约 `0.2%`，台架收尾后 owned processes 已全部停止。

## 分级结论

- L2 / 真相：`F2`。20 次并发写入与 REST 树查询闭合，唯一 position 和有序结果与真实 App 展示一致。
- L3 / 顺滑：`B2`。并发结果出现后选择、滚动和继续浏览无非用户触发的跳变、空白或重复。
- L4 / 精致：`C4`。父子缩进、行间距、选中背景和 Inspector 边界稳定，无裁切或布局破坏。
- L5 / 可发现：`G1`。普通用户通过 Library 的父子树即可理解页面归属和顺序，不需要知道 REST、position 或并发实现。

本证据只证明该并发同父建文档路径，不外推到其他文档编辑或批量操作路径。
