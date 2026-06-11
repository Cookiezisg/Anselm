# docswriter

后端 reference 文档全量重写计划。把 `docs/references/backend/`（覆盖回后清空）从零重建成 **`backend/` 代码的精确投影 + 干净结构**——全面覆盖每个模块，无重复、无历史、无混淆。

与 `lab/backendcleaner`（重写代码）对偶：**backendcleaner 把代码洗干净，docswriter 把文档写成那份干净代码的精确投影**。

## 为什么重写（旧的为什么烂）

旧 36 篇 domain 文档 + 4 索引被删，因为**堆太多、混淆视听**。诊断（看旧 `workflow.md` 244 行就知道）：

1. **同一事实写在多处** —— 端点在 domain §9 又在 `api.md`；schema 在 domain §2 又在 `database.md`；工具各域重列。必然漂移 + 臃肿。
2. **历史焊进文档** —— "§7 D1, R0066" 这种轮次号写进文档（违反零历史包袱）。
3. **海拔混乱** —— 一篇文档既当索引、又当设计、又当参考，没人知道该看哪。

## 四条反堆叠铁律（贯穿全程，违反 = 这篇没写完）

1. **枚举一次、解释一次**：端点/表/码/事件的**枚举**只在 4 个索引文件里各一行；**为什么/怎么工作**只在 module 文档里。module 文档**引用**索引、**绝不重列**。
2. **精确投影**：每条文档事实 1:1 映射当前 `backend/` 代码（`make docs` + 逐条对码 parity 抽查）。
3. **零历史**：无 R 轮次、无「原来…后来」、无演化叙述。只留当前物理事实（历史从 git）。
4. **统一骨架**：每篇 module 文档同一套章节（`skeleton.md`）——结构可预测，杜绝 kitchen-sink。

## 核心决策

1. **代码是真相、文档是投影**：不在文档里"设计"，只如实写代码现状 + 解释其 Why。代码与文档冲突 = 文档错（除非发现代码 bug，那走 backendcleaner 那条线）。
2. **全面 = 模块意识**：不只实体域，**每个有意义的模块**（地基 pkg / 共享引擎 / infra / 工具组 / transport）都进计划（见 `target/inventory.md`）。
3. **不开分支**：全程 main commit+push（同 backendcleaner）。
4. **门禁机械化**：`make docs`（`cmd/docs`）每篇必过；未来加 `--parity` 扫代码 vs 文档枚举。
5. **垂直切片、按波次**：逐模块写，依赖基础→复杂（见 `target/order.md`），不重不漏。

## 目录

| 文件 | 作用 |
|---|---|
| `SPEC.md` | 阶段 / 验收闸门 / **禁止清单** |
| `PLAYBOOK.md` | 每模块循环：研究 → 列 findings / 记 standards → **用户裁决** → 修 + 文档 → 下一模块 |
| `target/skeleton.md` | canonical module 文档骨架（统一章节） |
| `target/inventory.md` | **全量模块清单**（5 索引 + 全模块，doc 分配 + 海拔） |
| `target/order.md` | 依赖波次写作顺序 |
| `target/criteria.md` | done = 干净 + 完整 + 精确 判据 |
| `target/standards.md` | **尺子**：评审中确认的 canonical 标准（STD-N），后续模块对照 |
| `target/findings.md` | **产出**：发现的偏差（F-N，不合理/冗余/产品），待用户裁决 |
| `target/STATE.md` | **单一状态源**：阶段 + 进度 + 下一步 |
| `target/ROUNDS.md` | 已写文档轮次索引 |
| `target/rounds/NNNN/` | 每轮执行记录 |

## 当前状态

**Phase 1 评审中** —— errors 模块已评审 → `standards.md` STD-1（错误处理）+ `findings.md` F-1（todo 违 S20）/ F-2（websearch 待查）。评审顺序待用户确认（见 `order.md`）。`docs/references/backend/` 现为空（仅 `.gitkeep`），随评审逐模块落文档。
