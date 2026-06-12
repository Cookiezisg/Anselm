---
id: WRK-003
type: working
status: archived
owner: @weilin
created: 2026-06-11
reviewed: 2026-06-12
review-due: 2026-09-11
expires: 2026-09-11
landed-into: "docs/archive/backend-review/REPORT.md"
audience: [human, ai]
---

# DECISIONS-PENDING —— 等待产品级裁决

> 评审中发现、但修法需要产品决策的问题。**三条全部已裁决并实现（2026-06-11）**：
>
> - **PD-1 → A 级联销毁 ✅ 已实现**：workspace.Delete 经 Reaper 端口（bootstrap 后注入）——wf.Kill 全部（摘监听+杀 run+inactive，含手动 run）→ handler.StopWorkspaceInstances + mcp.DisconnectWorkspace → 删 `<dataDir>/workspaces/<ws>` 文件树 → 删行。Detached(目标 ws) ctx（请求可来自另一 ws）。
> - **PD-2 → 允许+自动解档 ✅ 已实现**：conversationapp.Unarchive + chat ConversationReader 端口扩展；Send 见 archived 即解档（软失败不挡消息）。
> - **PD-4 → C 配置项 ✅ 已实现（2026-06-12）**：workspace 表加 `web_fetch_mode`（local|jina，空=local 默认）；WebFetch 按模式抓取——local 仅本机直 GET（URL 不出本机），jina 走公共 reader+直 GET 兜底；读不到配置一律收敛 local。PATCH /workspaces 设置。
> - **PD-3 → B 完整修复 ✅ 已实现**：5 实体（function/handler/agent/control/approval）store 各加 `CreateWithVersion`（实体行+v1 单事务）与 `SaveVersionAndActivate`（新版本+指针移单事务），app Create/Edit 10 个调用点全改，domain Repository 接口同步。
>
> 以下为裁决时的原始留档。

## PD-1 workspace 删除：数据与运行时清理策略 📋

- **现状**：`DELETE /workspaces/{id}` 只删 workspaces 表一行（守"最后一个不能删"）。该 ws 的一切——实体行、常驻 handler 实例、mcp 连接、active workflow 的 trigger 监听、在途 flowrun——**全部原样留下**。监听甚至还会再触发：下次 firing 会在已删 ws 上正常起 run（实体行都在，orm 按 ws_id 过滤照常命中）。
- **影响**：删除语义名存实亡（数据全在、自动化还在跑）；长期积累孤儿数据。
- **候选**：
  - **A（推荐）级联销毁**：Delete 时逐步——kill 该 ws 全部在途 run → deactivate 全部 active workflow（摘监听）→ 停 handler/mcp 实例 → 软删全部实体行（或留行、只标记 ws 删除态）→ 删 ws 行。重操作但语义诚实；单用户本地删 ws 频率极低，可同步做。
  - **B 禁删改归档**：workspace 只支持 archive（隐藏+停自动化），永不物理删。实现更简单，数据永不丢。
  - **C 现状 + 文档声明**："删除 = 仅从列表移除"，数据/自动化遗留为已知行为。不推荐（自动化还在跑是惊吓）。

## PD-2 归档对话是否允许 Send 📋

- **现状**：`Send` 不读 `archived` 标志——归档对话照常接收消息并生成（CR-9 修复后会查存在性，但不查归档态）。
- **候选**：A 允许（很多产品如此，可顺带自动解档）；B 拒绝（409 CONVERSATION_ARCHIVED，前端引导解档）。一行代码的事，纯产品语义选择。

## PD-3 versioned 实体 Edit 的两步写是否上事务 📋

- **现状**：5 个 versioned 实体（function/handler/agent/control/approval）的 Edit = `CreateVersion` → `SetActiveVersion` 两条独立语句。中间失败 → 孤儿版本（无害的多余行）+ 指针不动 + 用户收 500 可重试。**不是数据损坏**。
- **权衡**：修法明确（store 加复合事务方法，orm 有 Transaction 设施）但要动 5 实体×3 层（~200 行）；而 SQLite 单进程下两语句间失败 ≈ 磁盘满/库损坏级灾难，事务也救不了多少——疑似反校验剧场（原则#6）。
- **候选**：A wontfix + findings 记录理由（我的倾向）；B 借 store 复合方法统一修 5 处（顺带消掉 app 层两步样板）。
