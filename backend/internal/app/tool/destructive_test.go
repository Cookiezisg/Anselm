package tool_test

import (
	"strings"
	"testing"

	toolapp "github.com/sunweilin/anselm/backend/internal/app/tool"
	agenttool "github.com/sunweilin/anselm/backend/internal/app/tool/agent"
	approvaltool "github.com/sunweilin/anselm/backend/internal/app/tool/approval"
	controltool "github.com/sunweilin/anselm/backend/internal/app/tool/control"
	documenttool "github.com/sunweilin/anselm/backend/internal/app/tool/document"
	functiontool "github.com/sunweilin/anselm/backend/internal/app/tool/function"
	handlertool "github.com/sunweilin/anselm/backend/internal/app/tool/handler"
	skilltool "github.com/sunweilin/anselm/backend/internal/app/tool/skill"
	triggertool "github.com/sunweilin/anselm/backend/internal/app/tool/trigger"
	workflowtool "github.com/sunweilin/anselm/backend/internal/app/tool/workflow"
)

func TestDestructiveDeleteToolsHaveNonBypassableDangerFloors(t *testing.T) {
	tooled := []struct {
		name string
		tool interface {
			Description() string
			MinimumDanger() toolapp.DangerLevel
		}
		want toolapp.DangerLevel
	}{
		{"delete_function", &functiontool.DeleteFunction{}, toolapp.DangerDangerous},
		{"delete_handler", &handlertool.DeleteHandler{}, toolapp.DangerDangerous},
		{"delete_agent", &agenttool.DeleteAgent{}, toolapp.DangerDangerous},
		{"delete_workflow", &workflowtool.DeleteWorkflow{}, toolapp.DangerDangerous},
		{"delete_control", &controltool.DeleteControl{}, toolapp.DangerDangerous},
		{"delete_approval", &approvaltool.DeleteApproval{}, toolapp.DangerDangerous},
		{"delete_skill", &skilltool.DeleteSkill{}, toolapp.DangerDangerous},
		{"delete_trigger", &triggertool.DeleteTrigger{}, toolapp.DangerDangerous},
		{"delete_document", &documenttool.DeleteDocument{}, toolapp.DangerCautious},
	}
	for _, tc := range tooled {
		t.Run(tc.name, func(t *testing.T) {
			if got := tc.tool.MinimumDanger(); got != tc.want {
				t.Fatalf("minimum danger = %q, want %q", got, tc.want)
			}
			desc := tc.tool.Description()
			if tc.want == toolapp.DangerDangerous {
				for _, phrase := range []string{"always dangerous", "explicit user approval", "never downgrade"} {
					if !strings.Contains(desc, phrase) {
						t.Fatalf("description missing %q: %s", phrase, desc)
					}
				}
			} else if !strings.Contains(desc, `danger="cautious"`) {
				t.Fatalf("recoverable delete must anchor cautious danger: %s", desc)
			}
		})
	}
}
