// Package forge provides the 5 system tools the LLM uses to interact with
// the user's forge library: search_forges, get_forge, create_forge,
// edit_forge, run_forge.
//
// Imported as `forgetool` per §S13 nested sub-package alias rule
// (`<sub><parent>` = forge + tool). Distinguish from `forgeapp` which is the
// app/forge service itself.
//
// Package forge 提供 5 个 system tool，让 LLM 与用户的 forge 库交互：
// search_forges / get_forge / create_forge / edit_forge / run_forge。
//
// 调用方按 §S13 嵌套子包别名规则导入 `forgetool`（`<子名><父名>` = forge + tool）。
// 区别于 `forgeapp`——后者是 app/forge service 本身。
package forge

import (
	"context"
	"encoding/json"
	"fmt"
	"strings"

	forgeapp "github.com/sunweilin/forgify/backend/internal/app/forge"
	toolapp "github.com/sunweilin/forgify/backend/internal/app/tool"
	apikeydomain "github.com/sunweilin/forgify/backend/internal/domain/apikey"
	chatdomain "github.com/sunweilin/forgify/backend/internal/domain/chat"
	eventsdomain "github.com/sunweilin/forgify/backend/internal/domain/events"
	modeldomain "github.com/sunweilin/forgify/backend/internal/domain/model"
	llminfra "github.com/sunweilin/forgify/backend/internal/infra/llm"
)

// ── ForgeTools factory ────────────────────────────────────────────────────────

// ForgeTools constructs the 5 forge system tools wired with their dependencies.
// Returns []toolapp.Tool because the chat ReAct loop consumes the abstract
// Tool interface; the concrete struct types (SearchForge, GetForge, etc.) are
// implementation details.
//
// ForgeTools 构造装配好依赖的 5 个 forge system tool。
// 返回 []toolapp.Tool——chat ReAct 循环消费的是抽象 Tool 接口；具体类型
// （SearchForge / GetForge 等）是实现细节。
func ForgeTools(
	svc *forgeapp.Service,
	attachRepo chatdomain.Repository,
	picker modeldomain.ModelPicker,
	keys apikeydomain.KeyProvider,
	factory *llminfra.Factory,
	bridge eventsdomain.Bridge,
) []toolapp.Tool {
	return []toolapp.Tool{
		&SearchForge{svc: svc, picker: picker, keys: keys, factory: factory},
		&GetForge{svc: svc},
		&CreateForge{svc: svc, picker: picker, keys: keys, factory: factory, bridge: bridge},
		&EditForge{svc: svc, picker: picker, keys: keys, factory: factory, bridge: bridge},
		&RunForge{svc: svc, attachRepo: attachRepo},
	}
}

// ── Shared LLM client builder ─────────────────────────────────────────────────

// builtClient is the shared LLM client + identity bundle returned by buildClient.
//
// builtClient 是 buildClient 返回的 LLM 客户端 + 身份打包。
type builtClient struct {
	client  llminfra.Client
	modelID string
	key     string
	baseURL string
}

// buildClient resolves the chat scenario's provider/model, fetches API key,
// and constructs an LLM client. Used by SearchForge (LLM ranking),
// CreateForge (code gen), EditForge (code gen).
//
// buildClient 解析 chat 场景的 provider/model、取 API key、构造 LLM 客户端。
// 供 SearchForge（LLM 排序）/ CreateForge（代码生成）/ EditForge（代码生成）使用。
func buildClient(
	ctx context.Context,
	picker modeldomain.ModelPicker,
	keys apikeydomain.KeyProvider,
	factory *llminfra.Factory,
) (*builtClient, error) {
	provider, modelID, err := picker.PickForChat(ctx)
	if err != nil {
		return nil, fmt.Errorf("forge: pick model: %w", err)
	}
	creds, err := keys.ResolveCredentials(ctx, provider)
	if err != nil {
		return nil, fmt.Errorf("forge: resolve credentials: %w", err)
	}
	client, baseURL, err := factory.Build(llminfra.Config{
		Provider: provider, ModelID: modelID,
		Key: creds.Key, BaseURL: creds.BaseURL,
	})
	if err != nil {
		return nil, fmt.Errorf("forge: build client: %w", err)
	}
	return &builtClient{client: client, modelID: modelID, key: creds.Key, baseURL: baseURL}, nil
}

func (b *builtClient) newRequest(system, prompt string) llminfra.Request {
	return llminfra.Request{
		ModelID: b.modelID,
		Key:     b.key,
		BaseURL: b.baseURL,
		System:  system,
		Messages: []llminfra.LLMMessage{
			{Role: llminfra.RoleUser, Content: prompt},
		},
	}
}

// ── resolveAttachments ────────────────────────────────────────────────────────

// resolveAttachments walks top-level string fields in input and rewrites any
// "att_xxx" value to the attachment's storage path on disk. Non-string fields
// and strings without the att_ prefix are passed through unchanged.
//
// Limitation: only top-level string fields are inspected. Nested lists or
// maps containing att_xxx values are NOT expanded. Forge functions are
// expected to take a flat input shape (file_path: "att_xxx").
//
// resolveAttachments 遍历 input 的顶层 string 字段，把 "att_xxx" 重写成附件
// 在磁盘上的存储路径。非 string 字段或不带 att_ 前缀的 string 原样透传。
//
// 限制：仅检查顶层 string 字段。嵌套 list/map 中的 att_xxx 不展开。
// Forge 函数预期接收扁平 input（如 file_path: "att_xxx"）。
func resolveAttachments(ctx context.Context, repo chatdomain.Repository, input map[string]any) (map[string]any, error) {
	out := make(map[string]any, len(input))
	for k, v := range input {
		s, ok := v.(string)
		if !ok || !strings.HasPrefix(s, "att_") {
			out[k] = v
			continue
		}
		att, err := repo.GetAttachment(ctx, s)
		if err != nil {
			return nil, fmt.Errorf("resolveAttachments: %w", err)
		}
		out[k] = att.StoragePath
	}
	return out, nil
}

// ── Streaming code generation ─────────────────────────────────────────────────

// streamCode calls the LLM to generate Python code, invoking onChunk after
// each text token with the fence-stripped accumulated code so the caller
// can publish snapshot events. Returns the final cleanly extracted code.
//
// onChunk receives the in-progress code (markdown fences best-effort stripped
// for live rendering); the returned code is the final post-stream stripped
// version. onChunk may be nil for non-streaming use.
//
// streamCode 调 LLM 生成 Python 代码，每个文本 token 后调用 onChunk（携带
// 已 trim fence 的累积代码），让调用方据此推快照。返回最终剥除 fence 的代码。
//
// onChunk 接收实时（已尽力剥 fence）代码；返回值是完整流结束后的最终结果。
// 不需要流式时可传 nil。
func streamCode(
	ctx context.Context,
	prompt string,
	picker modeldomain.ModelPicker,
	keys apikeydomain.KeyProvider,
	factory *llminfra.Factory,
	onChunk func(accumulated string),
) (string, error) {
	bc, err := buildClient(ctx, picker, keys, factory)
	if err != nil {
		return "", err
	}

	var buf strings.Builder
	for event := range bc.client.Stream(ctx, bc.newRequest("", prompt)) {
		switch event.Type {
		case llminfra.EventText:
			buf.WriteString(event.Delta)
			if onChunk != nil {
				onChunk(extractCode(buf.String()))
			}
		case llminfra.EventError:
			return "", fmt.Errorf("streamCode: %w", event.Err)
		}
	}
	if err := ctx.Err(); err != nil {
		return "", fmt.Errorf("streamCode: %w", err)
	}
	return extractCode(buf.String()), nil
}

// ── Code generation prompts ───────────────────────────────────────────────────

func buildCreatePrompt(name, description, instruction string) string {
	return fmt.Sprintf(`Write a Python function named %q.

Description: %s
Instruction: %s

Requirements:
- Single function with type annotations
- Google-style docstring with Args: and Returns: sections
- Return value must be JSON-serializable (str, int, float, bool, list, dict)
- Only output the function definition, no main block, no explanation

Output only the Python code.`, name, description, instruction)
}

func buildEditPrompt(currentCode, instruction string) string {
	return fmt.Sprintf(`Modify the following Python function according to the instruction.

Current code:
%s

Instruction: %s

Requirements:
- Keep it a single function with type annotations
- Maintain Google-style docstring
- Return value must be JSON-serializable
- Output only the complete modified function, no explanation

Output only the Python code.`, currentCode, instruction)
}

// ── Helpers ───────────────────────────────────────────────────────────────────

// extractCode strips markdown code fences (```python ... ``` etc.) from a raw
// LLM response. If no fence is present, returns the trimmed input unchanged.
//
// extractCode 剥除 LLM 响应中的 markdown 代码 fence（如 ```python ... ```）。
// 不含 fence 时原样返回 trim 后的输入。
func extractCode(raw string) string {
	raw = strings.TrimSpace(raw)
	for _, fence := range []string{"```python\n", "```\n", "```python", "```"} {
		if after, ok := strings.CutPrefix(raw, fence); ok {
			raw = after
			if idx := strings.LastIndex(raw, "```"); idx >= 0 {
				raw = raw[:idx]
			}
			return strings.TrimSpace(raw)
		}
	}
	return raw
}

// extractJSON pulls a JSON value out of an LLM response, handling several
// common shapes the LLM may use:
//
//  1. Plain JSON ("[...]" or "{...}") — returned as-is.
//  2. Markdown code fence with json language hint (```json ... ``` or ``` ... ```).
//  3. Surrounding prose ("Here's the answer: [...]") — fallback to outer
//     bracket matching, less reliable.
//
// Returns the JSON substring and true when found; "", false when nothing
// matched. Markdown fences are tried first because they're unambiguous.
//
// extractJSON 从 LLM 响应中提取 JSON 值，处理几种常见情况：
//
//  1. 纯 JSON（"[...]" 或 "{...}"）原样返回
//  2. Markdown 代码 fence（```json ... ``` 或 ``` ... ```）
//  3. 周围有散文（"Here's the answer: [...]"）—— 兜底用外层括号匹配，不太可靠
//
// 找到时返回 JSON 子串和 true；都没匹配返回 "", false。优先试 markdown fence
// 因为它最明确。
func extractJSON(s string) (string, bool) {
	s = strings.TrimSpace(s)

	// Try markdown fences first (unambiguous).
	// 先试 markdown fence（无歧义）。
	for _, fence := range []string{"```json\n", "```json", "```\n", "```"} {
		if idx := strings.Index(s, fence); idx >= 0 {
			start := idx + len(fence)
			rest := s[start:]
			if end := strings.Index(rest, "```"); end >= 0 {
				candidate := strings.TrimSpace(rest[:end])
				if isLikelyJSON(candidate) {
					return candidate, true
				}
			}
		}
	}

	// Fallback: bracket matching on outer-most pair.
	// 兜底：外层括号匹配。
	for _, pair := range [][2]byte{{'[', ']'}, {'{', '}'}} {
		start := strings.IndexByte(s, pair[0])
		end := strings.LastIndexByte(s, pair[1])
		if start >= 0 && end > start {
			candidate := s[start : end+1]
			if isLikelyJSON(candidate) {
				return candidate, true
			}
		}
	}
	return "", false
}

// isLikelyJSON cheaply checks if s parses as valid JSON. Used by extractJSON
// to disambiguate between candidate substrings.
//
// isLikelyJSON 廉价检查 s 是否合法 JSON。供 extractJSON 在多个候选间挑选。
func isLikelyJSON(s string) bool {
	var v any
	return json.Unmarshal([]byte(s), &v) == nil
}
