package agent

import (
	"context"
	"errors"
	"testing"

	agentdomain "github.com/sunweilin/anselm/backend/internal/domain/agent"
)

// fakeSkillGuide resolves only the names it was told exist (mirrors skillapp.Guide returning a
// not-found error for an unknown name).
type fakeSkillGuide struct{ known map[string]bool }

func (f fakeSkillGuide) Guide(_ context.Context, name string) (string, error) {
	if f.known[name] {
		return "## guide for " + name, nil
	}
	return "", errors.New("skill not found")
}

// TestCreateEdit_RejectsDanglingSkill: round-3 skillagent lane — create_agent/edit_agent accepted a
// non-existent skill name and persisted a dangling ref that failed only on the first invoke
// ("skill not found"), building a dead-on-arrival agent. The mounted skill is now validated eagerly
// against the SAME SkillGuide invoke uses, so an accepted agent resolves its skill at invoke.
func TestCreateEdit_RejectsDanglingSkill(t *testing.T) {
	svc, ctx := newSvc(t)
	svc.SetInvokeDeps(InvokeDeps{Skill: fakeSkillGuide{known: map[string]bool{"real-skill": true}}})

	// A non-existent skill is rejected at CREATE (was: accepted, dead until first invoke).
	if _, _, err := svc.Create(ctx, CreateInput{Name: "ghost", Config: Config{Prompt: "p", Skill: "nope"}}); !errors.Is(err, agentdomain.ErrSkillNotFound) {
		t.Fatalf("create with a non-existent skill must reject ErrSkillNotFound, got: %v", err)
	}
	// An existing skill is accepted.
	a, _, err := svc.Create(ctx, CreateInput{Name: "poet", Config: Config{Prompt: "p", Skill: "real-skill"}})
	if err != nil {
		t.Fatalf("create with an existing skill must succeed, got: %v", err)
	}
	// EDIT to a non-existent skill is rejected too (symmetric with create).
	if _, err := svc.Edit(ctx, EditInput{ID: a.ID, Config: Config{Prompt: "p", Skill: "nope"}}); !errors.Is(err, agentdomain.ErrSkillNotFound) {
		t.Fatalf("edit to a non-existent skill must reject ErrSkillNotFound, got: %v", err)
	}
	// No skill at all stays valid (the field is optional).
	if _, _, err := svc.Create(ctx, CreateInput{Name: "plain", Config: Config{Prompt: "p"}}); err != nil {
		t.Fatalf("create with no skill must succeed, got: %v", err)
	}
}
