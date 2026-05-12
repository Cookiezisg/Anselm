// dispatch_skill.go — SkillDispatcher. Reads node.Config keys `skillName`
// + `arguments` (string slice for $1..$N substitution per skill spec).
// Calls skillapp.Service.Activate which returns the resolved skill body
// text; the workflow downstream node consumes that as input. (V1 keeps
// it simple — fork-mode subagent execution will come in Plan 06.)
//
// dispatch_skill.go —— SkillDispatcher;Activate 返替换 $1..$N 后的
// skill body;下游节点当 input 用。V1 简化版,fork-mode 跑子 agent 留 Plan 06。

package scheduler

import (
	"context"
	"fmt"

	skillapp "github.com/sunweilin/forgify/backend/internal/app/skill"
)

// SkillDispatcher bridges workflow skill nodes to skillapp.Service.Activate.
//
// SkillDispatcher 桥接 workflow skill 节点到 skillapp.Activate。
type SkillDispatcher struct {
	svc *skillapp.Service
}

// NewSkillDispatcher constructs SkillDispatcher.
//
// NewSkillDispatcher 构造 SkillDispatcher。
func NewSkillDispatcher(svc *skillapp.Service) *SkillDispatcher {
	return &SkillDispatcher{svc: svc}
}

// Dispatch reads skillName + arguments from node.Config and resolves the
// skill body via Activate.
//
// Dispatch 读 skillName + arguments 调 Activate 拿 skill body。
func (d *SkillDispatcher) Dispatch(ctx context.Context, in DispatchInput) DispatchOutput {
	name, _ := in.Node.Config["skillName"].(string)
	if name == "" {
		return DispatchOutput{Error: fmt.Errorf("skill node %q: skillName required", in.Node.ID)}
	}

	var args []string
	if raw, ok := in.Node.Config["arguments"].([]any); ok {
		args = make([]string, 0, len(raw))
		for _, v := range raw {
			if s, ok := v.(string); ok {
				args = append(args, s)
			}
		}
	}

	body, err := d.svc.Activate(ctx, name, args)
	if err != nil {
		return DispatchOutput{Error: err}
	}
	return DispatchOutput{Outputs: map[string]any{"out": body}}
}
