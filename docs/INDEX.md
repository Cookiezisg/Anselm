# Forgify 文档索引

> AI 会话入口。先读本文，再循链接。**文档规范见 [`GOVERNANCE.md`](GOVERNANCE.md)（强制）。**

## 找什么去哪

| 要找 | 去 |
|---|---|
| 系统架构 / Phase 路线 / 愿景 | `concepts/architecture.md` |
| 工程纪律 + 代码规则（S/T/N/D/E 系列） | `../CLAUDE.md` |
| 文档规范（类型 / frontmatter / 同步 / 执行） | `GOVERNANCE.md` |

## 结构 —— 骨架已建、内容待填（V0.2 → V-next）

下树即 canonical 组织（依 `GOVERNANCE.md`）。reference / decision / how-to / working / archive 当前为**空占位**（`.gitkeep`，各含一行职责）——随重写覆盖回 + 前端重建，按新结构往里填。

```
docs/
├── INDEX.md          ← 本文（AI 入口）
├── GOVERNANCE.md     ← 文档规范（强制）
├── concepts/         ← architecture.md（唯一存内容的文档）
├── references/       ← 与代码同步的契约（空）
│   ├── backend/      ← api / database / events / error-codes / changelog + domains/
│   └── frontend/     ← fsd-layers / entity-types / cross-cutting + slices/
├── decisions/        ← ADR（空）
├── how-to/           ← 操作手册（空）
├── working/          ← 在研，≤90 天（空）
└── archive/          ← 只读墓地（空）
```

**前版完整文档**在 `version-0.2` 分支 —— `git checkout version-0.2 -- docs/...` 取回。

## 权威层级

`CLAUDE.md` > `references/` > `concepts/` > `working/` > `archive/`
