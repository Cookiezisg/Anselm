package subagent

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"path/filepath"
	"strings"

	toolapp "github.com/sunweilin/anselm/backend/internal/app/tool"
	fspathpkg "github.com/sunweilin/anselm/backend/internal/pkg/fspath"
	reqctxpkg "github.com/sunweilin/anselm/backend/internal/pkg/reqctx"
)

// forkExploreTools is the product boundary for Explore when it is dispatched by a fork Skill.
// General-purpose Task/Subagent and ordinary Chat keep the existing whole-machine contract.
const forkExploreScopeHint = "Fork Explore scope: search roots must stay inside the conversation's mounted working directory; without one, use Read with the exact absolute file path from the Skill argument."

type forkScopedTool struct {
	inner toolapp.Tool
}

func (t *forkScopedTool) Name() string { return t.inner.Name() }

func (t *forkScopedTool) Description() string {
	return t.inner.Description() + "\n\n" + forkExploreScopeHint
}

func (t *forkScopedTool) Parameters() json.RawMessage { return t.inner.Parameters() }

func (t *forkScopedTool) ValidateInput(args json.RawMessage) error {
	return t.inner.ValidateInput(args)
}

func (t *forkScopedTool) Execute(ctx context.Context, argsJSON string) (string, error) {
	rawPath, ok := pathArgument(t.Name(), argsJSON)
	if !ok {
		return t.inner.Execute(ctx, argsJSON)
	}

	if t.Name() == "Read" {
		if forkReadAllowed(ctx, rawPath) {
			return t.inner.Execute(ctx, argsJSON)
		}
		return "", errors.New(forkExploreScopeError("Read only the exact file named by the Skill argument or a file inside the mounted working directory"))
	}

	root := strings.TrimSpace(reqctxpkg.GetWorkDir(ctx))
	if root == "" {
		return "", errors.New(forkExploreScopeError("mount a working directory before using LS, Glob, or Grep"))
	}
	resolved, err := fspathpkg.ExpandIn(root, rawPath)
	if err != nil {
		return "", err
	}
	if !fspathpkg.Inside(root, resolved) {
		return "", errors.New(forkExploreScopeError("keep LS, Glob, and Grep roots inside the mounted working directory"))
	}
	return t.inner.Execute(ctx, argsJSON)
}

// HaltOnRepeat makes a scope refusal terminal for an identical call in this run. A model may
// still try one different path, but it must not re-open the same blocked boundary indefinitely.
func (*forkScopedTool) HaltOnRepeat(_ string, errorText string) bool {
	return strings.Contains(errorText, forkExploreScopeHint)
}

func boundForkExploreTools(tools []toolapp.Tool) []toolapp.Tool {
	out := make([]toolapp.Tool, 0, len(tools))
	for _, tool := range tools {
		switch tool.Name() {
		case "Read", "LS", "Glob", "Grep":
			out = append(out, &forkScopedTool{inner: tool})
		default:
			out = append(out, tool)
		}
	}
	return out
}

func pathArgument(name, argsJSON string) (string, bool) {
	var args map[string]json.RawMessage
	if err := json.Unmarshal([]byte(argsJSON), &args); err != nil {
		return "", false
	}
	key := "path"
	if name == "Read" {
		key = "file_path"
	}
	var path string
	if err := json.Unmarshal(args[key], &path); err != nil || strings.TrimSpace(path) == "" {
		return "", false
	}
	return strings.TrimSpace(path), true
}

func forkReadAllowed(ctx context.Context, rawPath string) bool {
	root := strings.TrimSpace(reqctxpkg.GetWorkDir(ctx))
	if root != "" {
		resolved, err := fspathpkg.ExpandIn(root, rawPath)
		return err == nil && fspathpkg.Inside(root, resolved)
	}

	resolved, err := fspathpkg.Expand(rawPath)
	if err != nil {
		return false
	}
	for _, explicit := range reqctxpkg.GetSkillForkReadPaths(ctx) {
		explicitPath, explicitErr := fspathpkg.Expand(explicit)
		if explicitErr == nil && filepath.Clean(explicitPath) == filepath.Clean(resolved) {
			return true
		}
	}
	return false
}

func forkExploreScopeError(reason string) string {
	return fmt.Sprintf("%s %s", forkExploreScopeHint, reason)
}

var _ toolapp.Tool = (*forkScopedTool)(nil)
