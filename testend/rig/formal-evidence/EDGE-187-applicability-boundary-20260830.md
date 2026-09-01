# EDGE-187 fts_schema_version 不匹配：产品表面适用性边界

## 裁决

`fts_schema_version` 不匹配是搜索派生索引在 boot 阶段的内部迁移 seam。服务端
清理旧 FTS/embedding 投影、写入当前 schema 版本，再从 live source 重建；迁移
完成后 Flutter 只消费正常的搜索结果，不接收或展示 schema migration 状态。

当前 Flutter 没有迁移进度、迁移错误卡片、重建按钮或对应导航入口。故本行的
L2（该 seam 的独立 App/持久产品表面）、L3（该 seam 专属的用户反馈时延与动效）、
L4（该 seam 专属的视觉 craft）和 L5（该 seam 专属的发现入口）均作适用性裁决，
不是把 focused boot 回归冒充真实 UI 证据。搜索结果恢复、启动健康和用户检索目标
由相应的搜索与启动产品面验收。

若未来把迁移状态或等待反馈公开给用户，必须撤销 L2-L5 裁决，重新建立真实 App
五通道证据并按五级标准验收。

## 依据

- `backend/internal/app/search/service.go`：schema mismatch 在 `Start` 的后台重建路径
  处理，属于派生索引维护。
- `frontend/lib`：未发现 schema migration 状态、控件或 reindex/migration 调用点。
- focused 证据：
  `testend/rig/formal-evidence/EDGE-187-search-schema-version-rebuild-20260825.md`
