# EDGE-185 异查询游标：产品表面适用性边界

## 裁决

`GET /api/v1/search` 的 cursor 绑定属于统一搜索 REST 合同：服务端用 query/filter
hash 约束 opaque cursor，异查询必须返回 `SEARCH_CURSOR_INVALID`。当前 Flutter
产品没有把这个统一搜索端点的 cursor continuation 或该错误作为独立操作控件、错误卡片
或可导航入口呈现。实体 rail 与对话 rail 的分页是各自的列表协议，不消费本端点的 cursor。

因此本行已经用真实 App + sidecar + 五通道完成 L2 事实验收后，L3（该 seam 专属的
用户动作反馈/时延）、L4（该 seam 专属的视觉表面）和 L5（该 seam 专属的发现入口）
均作适用性裁决，而不是用 REST 证据冒充 UI 通过。若未来把统一搜索 cursor 露出为
用户可操作的分页或错误状态，必须撤销这三项裁决并重新跑对应五级证据。

## 依据

- `frontend/lib/features/entities/state/entity_list_provider.dart`：实体 rail 的查询变化
  会从顶重新分页，使用各实体列表接口。
- `frontend/lib/features/chat/state/conversation_list_provider.dart`：对话 rail 的查询变化
  会丢弃旧游标并从顶重新分页，使用对话列表接口。
- `backend/internal/transport/httpapi/handlers/search.go`：统一搜索 cursor 仅作为
  `GET /api/v1/search` 的请求参数。
- `backend/internal/app/tool/contentsearch.go`：LLM 搜索工具 schema 只有 query，分页
  由 REST 侧承载，不构成独立 Flutter 操作面。
- L2 现场证据：
  `/private/tmp/anselm-rig-formal-20260801-7/sessions/20260830-233247/evidence/EDGE-185-search-cursor-query-binding-l2-real-app-20260830.md`
