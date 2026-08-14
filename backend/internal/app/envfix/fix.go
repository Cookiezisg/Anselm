package envfix

import (
	"context"
	"encoding/json"
	"fmt"
	"strings"

	modelclientapp "github.com/sunweilin/anselm/backend/internal/app/modelclient"
	modeldomain "github.com/sunweilin/anselm/backend/internal/domain/model"
	llminfra "github.com/sunweilin/anselm/backend/internal/infra/llm"
	jsonrepairpkg "github.com/sunweilin/anselm/backend/internal/pkg/jsonrepair"
)

// suggestDeps asks the utility model for a revised dependency list given the failing
// deps + captured stderr. Resolution goes through modelclient — the one shared chain,
// so the wire model id is never confused with the base URL.
//
// suggestDeps 给定失败的 deps + 捕获的 stderr，让 utility 模型给修正依赖列表。解析走
// modelclient——唯一共享解析链，故 wire model id 不会被误设成 base URL。
func (p *Provisioner) suggestDeps(ctx context.Context, currentDeps []string, lastErr string, history []Attempt) ([]string, error) {
	client, req, _, _, err := modelclientapp.Resolve(ctx, modeldomain.ScenarioUtility, nil, p.picker, p.keys, p.factory)
	if err != nil {
		return nil, fmt.Errorf("envfix.suggestDeps: resolve utility model: %w", err)
	}
	req.Messages = []llminfra.LLMMessage{{Role: llminfra.RoleUser, Content: buildFixPrompt(currentDeps, lastErr, history)}}
	out, err := llminfra.Generate(ctx, client, req)
	if err != nil {
		return nil, fmt.Errorf("envfix.suggestDeps: llm generate: %w", err)
	}
	return parseDeps(out)
}

// parseDeps extracts {"deps":[...]} from the model reply. Hosted models sometimes add prose
// or wrap the object in a Markdown fence despite the prompt, so try a fenced block, then a
// balanced object embedded in the reply, before applying the usual jsonrepair pass.
//
// parseDeps 从模型回复抽 {"deps":[...]}。托管模型即使收到约束也可能加散文或 Markdown 围栏，故先尝试
// 围栏块，再尝试回复中嵌入的完整对象，最后沿用 jsonrepair（尾逗号等）。
func parseDeps(resp string) ([]string, error) {
	input := strings.TrimSpace(resp)
	candidates := []string{input}
	if fenced, ok := extractFencedJSON(input); ok {
		candidates = append([]string{fenced}, candidates...)
	}
	for _, object := range extractJSONObjectCandidates(input) {
		candidates = append(candidates, object)
	}

	var lastErr error
	seen := make(map[string]struct{}, len(candidates))
	for _, candidate := range candidates {
		candidate = strings.TrimSpace(candidate)
		if _, ok := seen[candidate]; ok {
			continue
		}
		seen[candidate] = struct{}{}
		var object map[string]json.RawMessage
		repaired := jsonrepairpkg.Repair(candidate)
		if err := json.Unmarshal([]byte(repaired), &object); err != nil {
			lastErr = err
			continue
		}
		rawDeps, ok := object["deps"]
		if !ok {
			lastErr = fmt.Errorf("missing deps field")
			continue
		}
		var deps []string
		if err := json.Unmarshal(rawDeps, &deps); err != nil {
			lastErr = err
			continue
		}
		return deps, nil
	}
	if lastErr == nil {
		lastErr = fmt.Errorf("empty reply")
	}
	return nil, fmt.Errorf("envfix.parseDeps: no parseable deps JSON in reply: %w", lastErr)
}

// extractFencedJSON returns the first complete Markdown code fence, ignoring its optional
// language tag. It intentionally does not accept an unterminated fence as structured data.
func extractFencedJSON(s string) (string, bool) {
	open := strings.Index(s, "```")
	if open < 0 {
		return "", false
	}
	rest := s[open+3:]
	if newline := strings.IndexByte(rest, '\n'); newline >= 0 {
		rest = rest[newline+1:]
	}
	end := strings.Index(rest, "```")
	if end < 0 {
		return "", false
	}
	return strings.TrimSpace(rest[:end]), true
}

// extractJSONObjectCandidates returns balanced object slices, preserving string and escape
// semantics. Trying every balanced object lets a prose preamble contain harmless braces without
// making it mask a later valid deps object.
func extractJSONObjectCandidates(s string) []string {
	var out []string
	for start := 0; start < len(s); start++ {
		if s[start] != '{' {
			continue
		}
		depth := 0
		inString := false
		escaped := false
		for i := start; i < len(s); i++ {
			c := s[i]
			if escaped {
				escaped = false
				continue
			}
			if inString && c == '\\' {
				escaped = true
				continue
			}
			if c == '"' {
				inString = !inString
				continue
			}
			if inString {
				continue
			}
			switch c {
			case '{':
				depth++
			case '}':
				depth--
				if depth == 0 {
					out = append(out, s[start:i+1])
					start = i
					i = len(s)
				}
			}
		}
	}
	return out
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
- NEVER drop/remove a declared package just to make the error disappear: renaming a typo (e.g. "beautifulsoup" -> "beautifulsoup4") or loosening a version is a fix; removing a required package is NOT — the code still imports it, so the env would build but fail at runtime. Return one package per originally-declared package.
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
