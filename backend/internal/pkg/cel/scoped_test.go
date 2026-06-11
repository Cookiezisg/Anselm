package cel

import "testing"

// TestScopedEnv_NodeIDRoots: a ScopedEnv compiles expressions rooted at its declared node ids
// (+ the always-present ctx), and rejects a reference to any name outside that set — the free
// "the wiring only references existing nodes" check the workflow layer relies on.
//
// TestScopedEnv_NodeIDRoots：ScopedEnv 能编译以其声明的 node ids（+ 恒有的 ctx）为根的表达式，
// 并拒绝引用集合外的名字——workflow 层依赖的「接线只引用存在节点」白送校验。
func TestScopedEnv_NodeIDRoots(t *testing.T) {
	senv, err := NewScopedEnv([]string{"reviewer", "draft"})
	if err != nil {
		t.Fatalf("NewScopedEnv: %v", err)
	}
	for _, ok := range []string{
		"reviewer.score",
		"draft.text",
		"ctx.runId",
		`reviewer.score >= 0.9 ? draft.text : ""`,
	} {
		if _, err := senv.Compile(ok); err != nil {
			t.Errorf("Compile(%q) should succeed: %v", ok, err)
		}
	}
	if _, err := senv.Compile("ghost.x"); err == nil {
		t.Error("Compile(ghost.x) should fail: ghost is not a declared root")
	}
	// A root literally named "ctx" is skipped, so the env builds without a duplicate-var error.
	//
	// 名字恰为 "ctx" 的 root 被跳过，故 env 不因重复变量报错。
	if _, err := NewScopedEnv([]string{"ctx", "n1"}); err != nil {
		t.Errorf("NewScopedEnv with a 'ctx' root should not error: %v", err)
	}
}
