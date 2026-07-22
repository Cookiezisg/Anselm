// Package skill provides the skill system tools (lazy, surfaced via the catalog overview).
// Six tools: activate (the core action) + run_skill_script (sandboxed bundled-script exec)
// + get + create/edit/delete (authoring). No search tool (catalog overview already exposes
// every skill) and no execution-query tools (skill activation is not a tracked execution).
//
// Package skill 提供 skill system tool（懒加载，经 catalog 概览浮现）。六个：activate（核心）
// + run_skill_script（沙箱执行捆绑脚本）+ get + create/edit/delete（创作）。无 search 工具
// （catalog 概览已曝光全部 skill）、无执行查询工具（skill 激活非受追踪的执行）。
package skill

import (
	skillapp "github.com/sunweilin/anselm/backend/internal/app/skill"
	toolapp "github.com/sunweilin/anselm/backend/internal/app/tool"
)

// SkillTools constructs the skill system tools over the app service. sbx nil-tolerant:
// run_skill_script is only registered when a sandbox is wired.
//
// SkillTools 在 app service 之上构造 skill system tool。sbx 容忍 nil：沙箱未接线时不注册
// run_skill_script。
func SkillTools(svc *skillapp.Service, sbx ScriptSandbox, deps toolapp.DependentCounter) []toolapp.Tool {
	tools := []toolapp.Tool{
		&ActivateSkill{svc: svc},
		&GetSkill{svc: svc},
		&CreateSkill{svc: svc},
		&EditSkill{svc: svc},
		&DeleteSkill{svc: svc, deps: deps},
	}
	if sbx != nil {
		tools = append(tools, &RunSkillScript{svc: svc, sbx: sbx})
	}
	return tools
}
