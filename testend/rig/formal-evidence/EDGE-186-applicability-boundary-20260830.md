# EDGE-186 :reindex 并发与就地重建：产品表面适用性边界

## 裁决

`POST /api/v1/search:reindex` 是 workspace 搜索索引的内部维护动作：请求返回
`204`，没有可轮询的产物。当前 Flutter 代码没有调用该路径的 repository、按钮、
菜单项或错误卡片；`ApiClient.postNoContent` 只是通用传输方法，未形成该动作的
产品入口。搜索结果本身由已验收的搜索 surface 承担，不把隐藏维护 API 冒充成
用户功能。

因此本行的 L2（该维护 seam 的独立 App/持久产品表面）、L3（该动作的用户反馈
时延与动效）、L4（该动作的视觉 craft）和 L5（该动作的发现入口）均作适用性裁决，
而不是用服务端回归替代 UI 证据。focused 与真实黑盒证据仍覆盖本行的 single-flight、
跨 workspace 隔离、就地 reconcile 与 `204/409` 合同。

若未来为 reindex 增加用户可操作入口、进度状态或错误呈现，必须撤销 L2-L5 裁决，
重新建立真实 App 五通道证据并按五级标准验收。

## 依据

- `frontend/lib/core/net/api_client.dart`：`postNoContent` 仅为通用 204 action helper，
  没有 reindex 调用方。
- `backend/internal/transport/httpapi/handlers/search.go`：reindex 是异步 fire-and-forget
  的 `POST /api/v1/search:reindex`。
- 既有 API 产品验收：`EP-196 POST /api/v1/search:reindex` 已覆盖 endpoint 本身的功能、
  数据与响应体验；本行只额外定义并发单飞与就地重建 seam。
- focused/black-box 证据：
  `testend/rig/formal-evidence/EDGE-186-search-reindex-singleflight-inplace-20260825.md`
