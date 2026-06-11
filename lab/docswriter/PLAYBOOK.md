# docswriter PLAYBOOK —— 每模块循环

> 一模块一轮。**第 ③ 步是用户闸门**——未裁决不进 ④。每轮更新 `target/STATE.md`。
> docswriter = 以文档为手段的设计评审：真正的产出是 `findings.md`（偏差）+ `standards.md`（尺子），文档是副产品。

## ① 研究（代码是真相）

读该模块**全部**代码（`domain/X` + `app/X` + `infra/store/X` + `app/tool/X` + 折叠进来的 infra）。建立完整事实：**契约（端点/表/码/事件）· ID 前缀 · 心智模型 · 关键流程 · relation 边**。

## ② 列 findings + 确认/记 standards

- 拿 `standards.md` 已立的尺子（STD-N）逐条对照本模块。
- **猎设计问题**（透镜见下）→ 逐条记 `findings.md`（F-N，带**标准化、不打补丁**的建议修法 + 严重度）。
- 本模块确立了新的 canonical 标准 → 记 `standards.md`（STD-N），供后续模块对照。

**透镜（标准 > 冗余 / 清晰 / 不打补丁）**：定位/心智模型讲不清？两处实现同一概念（冗余）？依赖反向 / 绕？契约不一致（命名/分页/码）？是补丁而非根因？

## ③ 用户裁决 🚦（闸门）

把 findings 列给用户：**修哪些、怎么修**。机械确定的小修可提议即修；**产品岔路必须等裁决**，不擅自重设计。

## ④ 修 + 文档（同提交）

- 按裁决修代码：标准化、根因、**不打补丁**（不加特例 / 不留重复）。
- 写 `domains/<m>.md`（`skeleton.md` 7 节、只 Why）+ 同步 4 索引（端点→api / 表→database / 码→error-codes / 事件→events，**每条只此一处**）。
- 修了码 → 文档反映修后态；动了状态文档/CLAUDE → 状态即重述。
- `make verify` 绿。**同一提交**含 代码 + 文档 + 索引增量 + findings/standards 更新。

## ⑤ 下一模块

更新 `STATE.md`（本模块 done、findings 状态、下一个）。回 ①。
