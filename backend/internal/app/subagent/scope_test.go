package subagent

import (
	"context"
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"

	toolapp "github.com/sunweilin/anselm/backend/internal/app/tool"
	reqctxpkg "github.com/sunweilin/anselm/backend/internal/pkg/reqctx"
)

type scopeProbeTool struct {
	name   string
	called bool
}

func (t *scopeProbeTool) Name() string                        { return t.name }
func (t *scopeProbeTool) Description() string                 { return t.name }
func (t *scopeProbeTool) Parameters() json.RawMessage         { return json.RawMessage(`{"type":"object"}`) }
func (t *scopeProbeTool) ValidateInput(json.RawMessage) error { return nil }
func (t *scopeProbeTool) Execute(context.Context, string) (string, error) {
	t.called = true
	return "executed", nil
}

var _ toolapp.Tool = (*scopeProbeTool)(nil)

func TestForkScopedExplore_BlocksSearchWithoutResidency(t *testing.T) {
	probe := &scopeProbeTool{name: "Glob"}
	ctx := reqctxpkg.SetSkillForkScope(context.Background(), true)
	out, err := (&forkScopedTool{inner: probe}).Execute(ctx, `{"path":"~","pattern":"**/*"}`)
	if probe.called || err == nil || !strings.Contains(err.Error(), "mount a working directory") || out != "" {
		t.Fatalf("home search must be a pre-execution scope error, called=%v out=%q err=%v", probe.called, out, err)
	}
}

func TestForkScopedExplore_AllowsExactArgumentRead(t *testing.T) {
	path := filepath.Join(t.TempDir(), "README.md")
	if err := os.WriteFile(path, []byte("x"), 0o644); err != nil {
		t.Fatal(err)
	}
	probe := &scopeProbeTool{name: "Read"}
	ctx := reqctxpkg.SetSkillForkScope(context.Background(), true)
	ctx = reqctxpkg.SetSkillForkReadPaths(ctx, []string{path})
	out, err := (&forkScopedTool{inner: probe}).Execute(ctx, `{"file_path":`+jsonString(path)+`}`)
	if err != nil || out != "executed" || !probe.called {
		t.Fatalf("exact argument Read should pass, out=%q err=%v called=%v", out, err, probe.called)
	}
}

func TestForkScopedExplore_SearchStaysInsideResidency(t *testing.T) {
	root := t.TempDir()
	probe := &scopeProbeTool{name: "Grep"}
	ctx := reqctxpkg.SetSkillForkScope(context.Background(), true)
	ctx = reqctxpkg.SetWorkDir(ctx, root)
	out, err := (&forkScopedTool{inner: probe}).Execute(ctx, `{"path":"/tmp","pattern":"x"}`)
	if probe.called || err == nil || !strings.Contains(err.Error(), "inside the mounted working directory") || out != "" {
		t.Fatalf("outside search must be a pre-execution scope error, called=%v out=%q err=%v", probe.called, out, err)
	}
}

func jsonString(s string) string {
	return `"` + strings.ReplaceAll(strings.ReplaceAll(s, `\`, `\\`), `"`, `\"`) + `"`
}
