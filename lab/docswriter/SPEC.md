# docswriter SPEC —— 阶段 / 闸门 / 禁止

## 阶段

| Phase | 内容 | 出口 |
|---|---|---|
| **0 计划** | lab 定稿（README / SPEC / PLAYBOOK / skeleton / inventory / order / criteria） | 用户确认 |
| **1 索引骨架** | 建 5 索引文件空骨架（api/database/events/error-codes/changelog）+ 表头 + frontmatter | `make docs` 绿 |
| **2 逐模块** | 按 `order.md` 波次，每模块走 PLAYBOOK 四步（写 module 文档 + 同步索引） | 每模块四步闭环 |
| **3 收尾** | 全量 parity 抽查 + INDEX/GOVERNANCE 链接对账 + capability 对账（每个代码模块都有文档） | 全绿 + 无孤儿 |

## 验收闸门（每篇文档「完成」必过）

1. **结构**：符合 `skeleton.md` 章节（module 文档）/ 索引格式（索引文件）。
2. **精确**：枚举条目逐条对得上代码（端点 = handler 路由；表 = store schema；码 = errorspkg；事件 = stream producer）。
3. **单源**：本篇没重复别处已枚举的东西（端点只在 api.md、schema 只在 database.md…）。
4. **零历史**：无 R 轮次 / 演化叙述 / 「曾经」。
5. **frontmatter**：合法（`make docs` 过）。
6. **无孤儿链接**：引用的索引锚点 / 他篇都存在。

## 禁止清单（违反 = 重写这篇）

- ❌ **重复枚举**：在 module 文档里重列端点 / schema / 错误码 / 事件 / 工具——它们的家是 4 索引，module 文档只**引用**。
- ❌ **历史叙述**：写 R 轮次、「原来 X 后来 Y」、迁移过程、被否决的旧方案的演化（设计取舍可写「为什么不选 X」，但不写「我们曾用 X」）。
- ❌ **What 灌水**：逐字段/逐方法复述代码（那看代码即知）。文档写 **Why + 心智模型 + 取舍 + 边界 + 坑**。
- ❌ **海拔混装**：一篇里又当索引又当设计。索引文件 = 纯枚举；module 文档 = 纯设计。
- ❌ **投机/前瞻**：写还没在代码里的东西。文档 = 当前代码的投影，不是路线图（路线在 `concepts/architecture.md`）。
- ❌ **照搬 version-0.2**：旧文档是反面教材；可 checkout 参考事实，但结构/措辞从零按 skeleton。

## 完成定义（covering 前）

- `target/inventory.md` 每个模块 ☑（有对应文档或明确归并）。
- 5 索引枚举 = 代码全集（parity 抽查无缺无多）。
- `make docs` 全绿、`INDEX.md` 链接对账、无孤儿。
- 每篇 module 文档 7 节齐、单源、零历史。
