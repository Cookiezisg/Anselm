# STATE —— 单一状态源

> 改进度/阶段 = **整体重述本文件到当前**（非追加）。

## 阶段
**Phase 1 评审中** —— 以文档为手段的全后端设计评审，按 `order.md` 评审序（P0–P8）逐模块走 PLAYBOOK 循环。

## 进度
| 阶段 | 模块 | 状态 |
|---|---|---|
| P0 | errors | ✅ → STD-1；F-1/F-2 |
| P1 | orm ✅（STD-2，无 findings）· **reqctx** | **reqctx ← 下一步** |
| P2 | function · handler · agent | ⬜ |
| P3 | trigger · control · approval · workflow · flowrun · scheduler | ⬜ |
| P4 | skill · mcp · document | ⬜ |
| P5 | conversation · chat · messages · attachment · memory · todo · subagent | ⬜ |
| P6 | catalog · relation · mention · model · apikey · websearch · notification · workspace · sandbox · aispawn · humanloop · contextmgr · envfix · entitystream | ⬜ |
| P7 | cel · crypto · stream · loop · tool · llm · db · pkg-utils · transport | ⬜ |
| P8 | bootstrap | ⬜ |

## 账本
- `standards.md`：STD-1（错误处理）· STD-2（数据访问 / orm）
- `findings.md`：F-1（todo 违 S20，**open 待裁**）· F-2（websearch 待查，open）
- 索引（api/database/events/error-codes/changelog）：随评审逐模块填，现空

## Full coverage
130 个 internal 包全有归属（order.md 折叠规则 + P8 bootstrap + logger 显式豁免）。covering 前逐包对账（inventory §对账）。

## 决议记录
- changelog.md：保留（未来 dev log）。
- `lab/*/target/` 已豁免 `**/target/`（.gitignore，2026-06-11）——docswriter 计划文件本被 `**/target/` 误 ignore（只 README/SPEC/PLAYBOOK 进过 git），已修、本次首次全量入库。
- 范围 = 全模块（domains + foundation + bootstrap），见 inventory。
