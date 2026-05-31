---
id: DOC-240
type: reference
status: active
owner: @weilin
created: 2026-05-27
reviewed: 2026-05-31
review-due: 2026-06-30
audience: [human, ai]
---
# entities/skill — 前端 slice 详细设计

**所属层**：entities（对位后端 domain/skill）
**状态**：✅ 已实现
**职责**：只读查询 Skill 列表（技能以 name 为主键，从磁盘加载，前端不创建/修改）。

**关联文档**：
- [`../frontend-design.md`](../frontend-design.md) — FSD 总规范
- 后端 `references/backend/domains/skill.md`

---

## 1. 职责边界

- 列表查询（GET /skills）
- 单条详情（GET /skills/{name}）

Skill 是文件系统 + frontmatter 驱动的只读实体，前端无 create / update / delete。

---

## 2. 类型（`model/types.ts`）

```ts
interface SkillFrontmatter {
  name; description; whenToUse?; allowedTools?;
  disableModelInvocation?; userInvocable?; paths?; context?;
  agent?; arguments?; argumentHint?; model?; effort?;
}

interface Skill {
  name: string;       // 主键（无 id 前缀）
  source: string;
  dirPath: string;
  bodyPath: string;
  description: string;
  frontmatter: SkillFrontmatter;
  loadedAt: string;
}
```

主键是 `name`（string），区别于其他 entity 的 `id: string`。

---

## 3. API hooks（`api/skill.ts`）

| Hook | 方法 + 端点 | 说明 |
|---|---|---|
| `useSkills()` | GET `/skills?limit=200` | 全量列表；select pickList |
| `useSkill(id)` | GET `/skills/{id}` | 单条（id = name） |

---

## 4. 实现清单

| 文件 | 说明 |
|---|---|
| `frontend/src/entities/skill/model/types.ts` | Skill / SkillFrontmatter 类型 |
| `frontend/src/entities/skill/api/skill.ts` | 2 个只读 hooks |
| `frontend/src/entities/skill/index.ts` | public API |
