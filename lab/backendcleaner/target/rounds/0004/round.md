# Round 0004 — pkg/userpath 去留判定（波次 0 · M0.1 续）

类型 / 目标：判定 `userpath` 去留 —— 结论 **整包删除，不迁移**。

依赖扫描：
- 上游：`errors`/`fmt`/`os`/`path/filepath`（stdlib）。
- 下游：仅 `cmd/server/main.go`（M7.1 装配期）。

它是什么：`~/.forgify/users/<uid>/` 的 per-user 文件分桶（`UserHome`）+ 历史迁移（`MigrateLegacy` 把更早单用户版本的文件搬进桶）。`user` = Forgify user_id（要正名 workspace 的那个），非 OS 用户。

考古发现（main.go 揭示「多用户」是空架子）：
- uid 永远写死 `"local-user"`，注释自承认"不再有 auth 语义"。
- `MigrateLegacy(homeRoot, "local-user", "mcp.json","skills",".catalog.json","settings.json")` —— 为已不存在的旧安装做升级。
- 残留"切换 user / V1.5 按 user 重建 service"的未来幻觉 + `V1.2 §3 final-sweep` 注释。

判定：**整个 `userpath` 包删除**。它编码两个新架构里都不存在的概念：
- **多用户分桶** —— 新架构隔离单元是 workspace，不是 user 桶。
- **历史迁移** —— 项目未上线、无安装要兼容、数据可丢（#7 零包袱 + 无数据保留）→ `MigrateLegacy` 无存在理由。

这是「为已不存在的设计而留的死代码」教科书案例。不是改名 workspacepath，是比改名更彻底地删。

能力去向：`~/.forgify/` 下 app 资源（mcp.json/skills/settings.json/catalog）的文件布局属于 **M1.1 workspace 物理模型**该定的事（是否按 workspace 分桶、单根），不该由 pkg 地基预先编码 → 登记 `deps-todo.md`（R0004 节）。连带 cmd/server 装配残留登记 M7.1。

契约变更：无对外 API（pkg 工具）。下游 `cmd/server` 在 M7.1 按 M1.1 布局重做。

产出：**判定 + 登记，无 backend-new 代码**（结论是删，backend-new 全新目录本就不建它）。

覆盖状态：userpath 标 ⏭️ 删除；能力 + 清理项入 deps-todo（M1.1 / M7.1）。

下一步：`wikilink` 考古 → 余 jsonrepair/limits + `modelcaps` 判定 → M0.2 `infra/db`。
