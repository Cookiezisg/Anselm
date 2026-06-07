package agentstate

import "testing"

func TestActiveSkill_PreApproval(t *testing.T) {
	s := New()
	if s.ActiveSkill() != "" {
		t.Fatal("fresh state should have no active skill")
	}
	if s.IsToolPreApprovedBySkill("Read") {
		t.Fatal("nothing is pre-approved on a fresh state")
	}

	s.SetActiveSkill("code-review", []string{"Read", "Grep"})
	if s.ActiveSkill() != "code-review" {
		t.Fatalf("active skill = %q, want code-review", s.ActiveSkill())
	}
	if !s.IsToolPreApprovedBySkill("Read") || !s.IsToolPreApprovedBySkill("Grep") {
		t.Fatal("Read and Grep should be pre-approved")
	}
	if s.IsToolPreApprovedBySkill("Write") {
		t.Fatal("Write must NOT be pre-approved (not in allowed-tools)")
	}

	// 激活新 skill 整体替换旧的预授权集
	s.SetActiveSkill("other", []string{"Bash"})
	if s.IsToolPreApprovedBySkill("Read") {
		t.Fatal("previous skill's pre-approvals must be cleared on re-activation")
	}
	if !s.IsToolPreApprovedBySkill("Bash") {
		t.Fatal("new skill's tool should be pre-approved")
	}
}
