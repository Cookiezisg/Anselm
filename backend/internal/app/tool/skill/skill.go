// Package skill (app/tool/skill) hosts the two LLM-facing system tools
// for Anthropic Agent Skills: search_skills (discovery / L1 catalog
// query) + activate_skill (load body, set permissions, dispatch to
// subagent if context=fork).
//
// Tools split per §S12 (one tool family in one nested package):
//
//	skill.go    — SkillTools(svc) factory (DI entry point for main.go)
//	search.go   — SearchSkills implementation (9 methods + schema)
//	activate.go — ActivateSkill implementation (9 methods + schema)
//
// Aliases (§S13 nested-subpackage rule): consumers import as `skilltool`
// (parent app/tool family alias is `tool`; this nested package follows
// the `<sub>tool` form).
//
// Package skill（app/tool/skill）—— Anthropic Agent Skills 的 2 个 LLM-
// facing 系统工具：search_skills（发现 / L1 catalog 查询）+
// activate_skill（加载 body、设权限、fork 模式派 subagent）。子包结构
// 同 §S12 嵌套规则；调用方按 `skilltool` 别名引用（§S13）。
package skill

import (
	skillapp "github.com/sunweilin/forgify/backend/internal/app/skill"
	toolapp "github.com/sunweilin/forgify/backend/internal/app/tool"
)

// SkillTools returns the SearchSkills + ActivateSkill pair wired against
// svc. Called once during DI assembly in main.go (and harness.go for
// pipeline tests).
//
// SkillTools 返回接到 svc 的 SearchSkills + ActivateSkill。main.go（与
// harness.go pipeline）DI 装配时调一次。
func SkillTools(svc *skillapp.Service) []toolapp.Tool {
	return []toolapp.Tool{
		&SearchSkills{svc: svc},
		&ActivateSkill{svc: svc},
	}
}
