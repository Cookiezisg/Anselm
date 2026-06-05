# Round 0027 — permissions / hooks / settings（M1.9）判定解散

类型 / 目标：M1.9 **不重写**——permissions domain + app/hooks + infra/settings 三者**整个判定解散**,不迁 backend-new。一次错误抽象的解构（对齐 userpath R0004 判删）。

## 核心判断（一句话）
**permissions/hooks/settings 是个"中央配置门控",但 Forgify 单人本地不需要中央集权——hooks 是 Claude Code 花活、危险控制该下放工具、limits 本就独立、settings.json 没必要存在。**

## 解散理由（经讨论拍板）
旧设计抄 Claude Code 的"交互式逐步授权"（有人盯着、agent 每动手弹框问）。落到 Forgify（单人、本地、Wails 桌面）拧巴：
- **交互聊天**：自己机器自己 agent，大概率嫌烦直接 `bypass` → allow/ask/deny 闲置。
- **无人值守 workflow**：没人答 `ask` → 交互授权空转。
- 且这套主要挂在交互式 chat（hooks/gate 被 chat 调），恰好是会 bypass 的场景 → 实际闲置。

## 各部分归宿
| 旧物 | 处置 |
|---|---|
| **hooks**（PreToolUse/PostToolUse/Stop 挂脚本） | **删**——Claude Code 花活，单人本地用不上 |
| **危险控制**（allow/ask/deny + DangerLevel） | **不做中央门控**——危险控制由别处管（工具自管），M1.9 不实现 |
| **protectedPaths**（写保护） | 归危险控制，别处管；`pathguard`（M0.1）已有默认禁区 |
| **limits**（maxSteps/超时…） | **用 `pkg/limits` 默认**（M0.1 已迁），不暴露用户调、不进 settings |
| **settings.json + infra/settings** | **砍**——上述搬走后无内容可存 |
| **permissions domain / app/hooks** | 全不迁 backend-new |

## 连带影响
- **M5.4 tool/permissionsgate**：随之解散（无中央 permissions 可评估）。
- **M5.2 chat**：依赖去掉 hooks + tool/permissionsgate；危险控制下放工具。
- **pkg/limits**：保留（M0.1 已迁），`Current()` 走默认，删 settings-backed `SetProvider` 装配（M7 不接 settings）。

## 契约清理
删 `domains/permissions.md`；api.md 6.1 删 7 端点（/settings ×5 + /permissions ×2）、标题 → "API Keys & Auth"；error-codes 删 `INVALID_SETTINGS`/`BLOCKED_BY_RULE` + 标题去 Perms；database.md 2.1 标题去 Settings；contract-changes #7。

## 遗留 / 下一步
- **M1.10 document**（波次 1 续）。
- **危险控制 + protectedPaths**：由别处/工具管（用户定，M1.9 不碰）；登记 deps-todo 给波次 2 `tool/shell`·`tool/filesystem` 参考。
- **limits 用户可调**（若将来要）：另设渠道，不复活 settings.json。
