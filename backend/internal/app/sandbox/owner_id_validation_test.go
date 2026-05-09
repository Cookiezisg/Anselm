// owner_id_validation_test.go — locks down the rule that EnsureEnv
// rejects owner.IDs containing PATH-meta or whitespace characters.
// This guard prevents regression of the bash auto-route bug where
// `cv_xxx:python` (containing a literal ":") became a directory name
// that, when prepended to PATH, was split by shell at the ":" and
// silently fell through to /usr/bin (running system Python instead
// of the conversation's mise-managed venv).
//
// owner_id_validation_test.go ——锁定 EnsureEnv 拒含 PATH-meta /
// 空白字符的 owner.ID 规则。防 bash auto-route 那个 bug 回归：
// `cv_xxx:python`（含字面 ":"）当目录名前置到 PATH 时被 shell 在
// ":" 处切，悄悄落到 /usr/bin 用系统 Python 而非对话 mise venv。

package sandbox

import (
	"context"
	"strings"
	"testing"

	dbinfra "github.com/sunweilin/forgify/backend/internal/infra/db"
	sandboxstore "github.com/sunweilin/forgify/backend/internal/infra/store/sandbox"
	sandboxdomain "github.com/sunweilin/forgify/backend/internal/domain/sandbox"
	"go.uber.org/zap"
)

func TestEnsureEnv_RejectsPATHMetaCharsInOwnerID(t *testing.T) {
	db, err := dbinfra.Open(dbinfra.Config{DataDir: ""})
	if err != nil {
		t.Fatalf("dbinfra.Open: %v", err)
	}
	if err := db.AutoMigrate(&sandboxdomain.Runtime{}, &sandboxdomain.Env{}); err != nil {
		t.Fatalf("migrate: %v", err)
	}
	repo := sandboxstore.New(db)
	svc := New(repo, t.TempDir(), nil, zap.NewNop())
	svc.MarkReadyForTest("/fake/mise") // bypass real bootstrap

	cases := []struct {
		name     string
		ownerID  string
		wantHint string // substring expected in the error
	}{
		{"colon", "cv_abc:python", "PATH-meta"},
		{"semicolon", "cv_abc;python", "PATH-meta"},
		{"equals", "cv_abc=python", "PATH-meta"},
		{"space", "cv abc python", "whitespace"},
		{"tab", "cv_abc\tpython", "whitespace"},
		{"newline", "cv_abc\npython", "whitespace"},
		{"null", "cv_abc\x00python", "whitespace"}, // \x00 falls into the "unsafe" set
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			_, err := svc.EnsureEnv(context.Background(),
				sandboxdomain.Owner{Kind: sandboxdomain.OwnerKindConversation, ID: c.ownerID},
				sandboxdomain.EnvSpec{Runtime: sandboxdomain.RuntimeSpec{Kind: "python"}},
				nil)
			if err == nil {
				t.Fatalf("ownerID %q should be rejected but EnsureEnv returned nil", c.ownerID)
			}
			if !strings.Contains(err.Error(), "PATH-meta") &&
				!strings.Contains(err.Error(), "whitespace") {
				t.Errorf("ownerID %q rejected with unexpected error %q (want hint about PATH-meta or whitespace)",
					c.ownerID, err.Error())
			}
		})
	}
}

func TestEnsureEnv_AcceptsCleanOwnerID(t *testing.T) {
	db, err := dbinfra.Open(dbinfra.Config{DataDir: ""})
	if err != nil {
		t.Fatalf("dbinfra.Open: %v", err)
	}
	if err := db.AutoMigrate(&sandboxdomain.Runtime{}, &sandboxdomain.Env{}); err != nil {
		t.Fatalf("migrate: %v", err)
	}
	repo := sandboxstore.New(db)
	svc := New(repo, t.TempDir(), nil, zap.NewNop())
	svc.MarkReadyForTest("/fake/mise")

	// "cv_abc_python" is the post-fix form: convID + "_" + runtimeKind.
	// EnsureEnv passes input validation; install will fail later because
	// no installer / EnvManager is registered for "python" — but the
	// error message must NOT mention "PATH-meta" or "whitespace".
	//
	// "cv_abc_python" 是修复后形态：convID + "_" + runtimeKind。
	// EnsureEnv 过入口校验；后面装会失败（没注册 python installer /
	// EnvManager），但错误信息不应含 "PATH-meta" / "whitespace"。
	_, err = svc.EnsureEnv(context.Background(),
		sandboxdomain.Owner{Kind: sandboxdomain.OwnerKindConversation, ID: "cv_abc_python"},
		sandboxdomain.EnvSpec{Runtime: sandboxdomain.RuntimeSpec{Kind: "python"}},
		nil)
	if err == nil {
		// Without a registered installer, install would normally fail.
		// If it didn't error at all, that's surprising but not a
		// validation regression — the validation case is what we care
		// about here.
		t.Skip("EnsureEnv unexpectedly succeeded; this test only checks input-validation path")
	}
	if strings.Contains(err.Error(), "PATH-meta") || strings.Contains(err.Error(), "whitespace") {
		t.Errorf("clean ownerID rejected with PATH-meta/whitespace error: %v", err)
	}
}
