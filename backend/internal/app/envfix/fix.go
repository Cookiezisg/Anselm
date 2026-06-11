package envfix

import (
	"context"
	"encoding/json"
	"fmt"
	"strings"

	modeldomain "github.com/sunweilin/forgify/backend/internal/domain/model"
	llminfra "github.com/sunweilin/forgify/backend/internal/infra/llm"
	jsonrepairpkg "github.com/sunweilin/forgify/backend/internal/pkg/jsonrepair"
)

// suggestDeps asks the utility model for a revised dependency list given the failing
// deps + captured stderr. Chain mirrors the rest of backend-new:
// model.Resolve(utility) → keys.ResolveCredentialsByID → factory.Build → llm.Generate.
//
// suggestDeps 给定失败的 deps + 捕获的 stderr，让 utility 模型给修正依赖列表。链与
// backend-new 其余处一致：model.Resolve(utility) → ResolveCredentialsByID → factory.Build → llm.Generate。
func (p *Provisioner) suggestDeps(ctx context.Context, currentDeps []string, lastErr string, history []Attempt) ([]string, error) {
	ref, err := modeldomain.Resolve(ctx, modeldomain.ScenarioUtility, nil, p.picker)
	if err != nil {
		return nil, fmt.Errorf("envfix.suggestDeps: resolve utility model: %w", err)
	}
	creds, err := p.keys.ResolveCredentialsByID(ctx, ref.APIKeyID)
	if err != nil {
		return nil, fmt.Errorf("envfix.suggestDeps: resolve credentials: %w", err)
	}
	client, modelID, err := p.factory.Build(llminfra.Config{
		Provider:  creds.Provider,
		APIFormat: creds.APIFormat,
		ModelID:   ref.ModelID,
		Key:       creds.Key,
		BaseURL:   creds.BaseURL,
	})
	if err != nil {
		return nil, fmt.Errorf("envfix.suggestDeps: build client: %w", err)
	}
	out, err := llminfra.Generate(ctx, client, llminfra.Request{
		ModelID:  modelID,
		Key:      creds.Key,
		BaseURL:  creds.BaseURL,
		Options:  ref.Options,
		Messages: []llminfra.LLMMessage{{Role: llminfra.RoleUser, Content: buildFixPrompt(currentDeps, lastErr, history)}},
	})
	if err != nil {
		return nil, fmt.Errorf("envfix.suggestDeps: llm generate: %w", err)
	}
	return parseDeps(out)
}

// parseDeps extracts {"deps":[...]} from the model reply, repairing malformed JSON
// (fences / trailing commas) via jsonrepair before unmarshal.
//
// parseDeps 从模型回复抽 {"deps":[...]}，unmarshal 前用 jsonrepair 修畸形 JSON
// （围栏 / 尾逗号）。
func parseDeps(resp string) ([]string, error) {
	var out struct {
		Deps []string `json:"deps"`
	}
	repaired := jsonrepairpkg.Repair(strings.TrimSpace(resp))
	if err := json.Unmarshal([]byte(repaired), &out); err != nil {
		return nil, fmt.Errorf("envfix.parseDeps: no parseable deps JSON in reply: %w", err)
	}
	return out.Deps, nil
}

// buildFixPrompt constrains the model to ONLY adjust dependencies (versions / names /
// constraints) — never code — and to return JSON only.
//
// buildFixPrompt 把模型约束为只调依赖（版本 / 名字 / 约束）、绝不碰代码、只返 JSON。
func buildFixPrompt(currentDeps []string, lastErr string, history []Attempt) string {
	var sb strings.Builder
	sb.WriteString("A Python/Node package install failed. Suggest a revised dependency list.\n\n")

	sb.WriteString("Current dependencies:\n")
	if len(currentDeps) == 0 {
		sb.WriteString("  (empty)\n")
	} else {
		for _, d := range currentDeps {
			fmt.Fprintf(&sb, "  - %s\n", d)
		}
	}

	sb.WriteString("\nInstall error (package-manager stderr):\n")
	if strings.TrimSpace(lastErr) == "" {
		sb.WriteString("  (no stderr captured)\n")
	} else {
		fmt.Fprintf(&sb, "%s\n", strings.TrimSpace(lastErr))
	}

	if len(history) > 1 {
		sb.WriteString("\nPrior attempts:\n")
		for _, a := range history {
			fmt.Fprintf(&sb, "  attempt %d: deps=%v ok=%v err=%q\n",
				a.Number, a.Deps, a.OK, truncate(a.Error, 200))
		}
	}

	sb.WriteString(`
Rules:
- Only fix the dependency list (typos, version conflicts, missing/over-tight constraints).
- Do NOT add packages unrelated to the current list.
- Do NOT modify any code — code is not your concern here.
- Keep the same packages where possible; adjust versions or fix names.
- If you cannot determine a fix, return the deps unchanged.

Return JSON only, no commentary:
{"deps": ["pandas>=2.0", "numpy"]}
`)
	return sb.String()
}

func truncate(s string, n int) string {
	if len(s) <= n {
		return s
	}
	return s[:n] + "…"
}
