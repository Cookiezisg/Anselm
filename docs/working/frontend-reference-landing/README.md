---
id: WRK-084
type: working
status: draft
owner: "@weilin"
created: 2026-07-26
reviewed: 2026-07-26
review-due: 2026-10-24
audience: [human, ai]
landed-into:
---

# WRK-084 · 把 `working/frontend/` 落地进 `references/frontend/`

> **一句话**：`working/frontend/` 是四海洋里若干块内容的**唯一事实源**，因此它现在归档不得——本工单补齐
> `references/frontend/`，填 `landed-into`，然后整册进 `archive/`。

## §0 为什么单独立项

2026-07-26 整理 `docs/working/` 时，本想把 `working/frontend/`（WRK-049，前端一站式 hub）一并归档，
查下来**不能**——它不是「做完的战役」，而是**部分内容的唯一出处**。归档它等于把规格埋进只读墓地。

按 GOVERNANCE 的生命周期（`收尾清单` 第 7 条：结论提取进 `concepts`/`references` → 填 `landed-into` → 移 `archive/`），
它欠的是**中间那一步**：**12 篇里一篇都没填 `landed-into`**。

这件事的本质是**写 reference 文档**、不是整理目录，故不塞进那次整理里草草了事。

## §1 缺口（2026-07-26 实测，不是估计）

体量对比：`references/frontend/` **1023 行** vs `working/frontend/` **8559 行**。

| 缺口 | 现状 | 唯一出处 |
|---|---|---|
| **scheduler 海洋** | `references/frontend/features/` 里**一篇都没有**（chat/entities/library 各 1 篇，scheduler **0** 篇） | `working/frontend/scheduler.md`（347 行，且仍是 `draft`） |
| **chat 主面** | 只落了侧幕一面（`features/chat-sidestage.md`）；rail 四段结构 / transcript / composer / 驻地**无对应 reference** | `working/frontend/chat.md` |
| **工具卡谱系** | `references/` 里只有 `design-system.md` 与 `chat-sidestage.md` 的零星提及，**无落点** | `tool-card-blueprints.md`(3867) + `tool-card-census.md`(2435) + `tool-cards.md`(113) = **6415 行** |
| **其余** | 需逐篇核 | `entity-pages.md` / `right-island-grammar.md` / `right-island-redesign.md` / `workflow-page.md` / `sidestage-polish.md` / `chat-iteration.md` |

**顺带查出的一处文档与事实不符（已在本工单同提交修掉）**：`CLAUDE.md` 写「形态见
`references/frontend/features/chat*.md`」——用的是复数通配，而实际只有 `chat-sidestage.md` 一篇。

## §2 做法

1. **逐篇判去向**：12 篇各自属于 ①提炼进既有 reference ②新建 reference ③纯过程记录、直接归档 中的哪一类。
   判据是**读者会去哪里找它**，不是文件当初为什么被写出来。
2. **补齐 reference**：至少 `features/scheduler.md` 与 chat 主面；工具卡谱系另择落点
   （6415 行不宜整体搬进 features，需先判「哪些是**契约**、哪些是**建造过程**」）。
3. **逐篇填 `landed-into`**，再整册 `git mv` 进 `archive/`。
4. 同提交更新指向 `working/frontend/` 的 **10 处引用**（含 `CLAUDE.md`、`docs/INDEX.md`、
   `concepts/architecture.md`、三篇 `references/frontend/*`），`make -C docs verify` 绿。

## §3 完成定义

- ☐ `references/frontend/features/` 覆盖**四海洋**（chat 含主面、entities、library、scheduler）。
- ☐ 工具卡谱系有明确落点，且**契约与建造过程分开**。
- ☐ `working/frontend/` 12 篇逐篇 `landed-into` 非空，整册进 `archive/`。
- ☐ 10 处入链全部改到新位置，无孤儿链接，`make -C docs verify` 绿。
