# STATE —— 单一状态源

> 改进度/阶段 = **整体重述本文件到当前**（非追加）。

## 阶段
**Phase 1 评审中** —— 以文档为手段的全后端设计评审，按 `order.md` 评审序（P0–P8）逐模块走 PLAYBOOK 循环。

## 进度
| 阶段 | 模块 | 状态 |
|---|---|---|
| P0 | errors | ✅ → STD-1 + **全量统一**（类型移 pkg/errors、37 sentinel 全转 errorspkg.New、ADR 0002、error-codes.md seeded） |
| P1 | orm ✅（STD-2 + `foundation/orm.md`；F-4 撤回）· reqctx ✅（`foundation/reqctx.md` + F-5 `Detached` helper + F-6 kind 修） | ✅ 完成 |
| P2 | function · handler · agent | ✅ **完成**（亲审全栈 + F-7/F-8 全修 + `domains/{function,handler,agent}.md` 三篇 0 障碍级 + seed api/database/events 三索引） |
| P3 | trigger · control · approval · workflow · flowrun · scheduler | **← 下一步** |
| P4 | skill · mcp · document | ⬜ |
| P5 | conversation · chat · messages · attachment · memory · todo · subagent | ⬜ |
| P6 | catalog · relation · mention · model · apikey · websearch · notification · workspace · sandbox · aispawn · humanloop · contextmgr · envfix · entitystream | ⬜ |
| P7 | cel · crypto · stream · loop · tool · llm · db · pkg-utils · transport | ⬜ |
| P8 | bootstrap | ⬜ |

## 账本
- `standards.md`：STD-1（错误处理，已全量统一）· STD-2（数据访问 / orm）
- `findings.md`：F-1/F-2/F-3 ✅（错误统一）· F-4 撤回 · F-5/F-6 ✅（reqctx）· F-7 ✅（agent 挂载收尾）· F-8 ✅（P2 亲审批：X1-A flowrun 接通 / H1-H3 / X2 / X5 / Count / 预检 / F-3 漏网 67 处）
- 已落文档：`error-codes.md`（**246 码**+2 守卫）· `foundation/{orm,reqctx}.md` · `domains/{function,handler,agent}.md`（0 障碍级）· **api.md / database.md / events.md 已 seed**（三实体）。其余域随评审填

## Full coverage
130 个 internal 包全有归属（order.md 折叠规则 + P8 bootstrap + logger 显式豁免）。covering 前逐包对账（inventory §对账）。

## 决议记录
- changelog.md：保留（未来 dev log）。
- `lab/*/target/` 已豁免 `**/target/`（.gitignore，2026-06-11）——docswriter 计划文件本被 `**/target/` 误 ignore（只 README/SPEC/PLAYBOOK 进过 git），已修、本次首次全量入库。
- 错误类型移 `domain/errors` → `pkg/errors`（ADR 0002，2026-06-11）：纯机制下沉地基、全层可用；所有命名 sentinel 一律 `errorspkg.New`，无"是否冒泡 HTTP"之分。
- 范围 = 全模块（domains + foundation + bootstrap），见 inventory。
