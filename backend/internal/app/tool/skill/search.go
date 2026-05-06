// search.go — search_skills system tool. LLM calls this to discover
// installed Anthropic Agent Skills matching a query. Returns top-K
// candidates each with name + description + isFork flag (so the LLM
// can predict whether activation will spawn a subagent).
//
// search.go ——search_skills 系统工具。LLM 调它发现匹配 query 的已装
// Agent Skill。返 top-K 候选含 name + description + isFork 标志（让
// LLM 预知激活会否 spawn subagent）。
package skill

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"strings"

	skillapp "github.com/sunweilin/forgify/backend/internal/app/skill"
	toolapp "github.com/sunweilin/forgify/backend/internal/app/tool"
)

// defaultTopK matches mcp.search_mcp's default — 3 keeps the result tiny
// (skills count is typically << MCP tool count) and makes the LLM commit
// to one candidate fast rather than ruminating.
//
// defaultTopK 与 search_mcp 同——3 让结果小（skill 数远小于 MCP tool
// 数）+ 让 LLM 快速决断而非纠结。
const defaultTopK = 3

// ErrEmptyQuery — query arg missing or whitespace.
//
// ErrEmptyQuery：query 缺失或全空白。
var ErrEmptyQuery = errors.New("query is required and must be non-empty")

const searchSkillsDescription = `Search the user's installed skills (procedural workflows + allowed-tools bundles) for ones relevant to a task.

Returns the top K candidate skills, each with their name, description,
and a flag indicating whether activation will spawn an isolated subagent
(context: fork) or run inline in the current conversation.

Use when:
- the user asks for a multi-step procedure that someone may have already
  encoded as a skill (PR review, deploy, data cleanup, ...)
- you want to see if there's an opinionated workflow before improvising
- you've forgotten the exact skill name

Don't use when:
- the task is a single tool call (just call that tool directly)
- you already know the exact skill name (call activate_skill directly)
- you've recently activated a skill in this conversation (it's still
  active until another activate_skill replaces it)`

var searchSkillsSchema = json.RawMessage(`{
	"type": "object",
	"required": ["query"],
	"properties": {
		"query": {
			"type": "string",
			"description": "Natural-language description of the task or workflow you need (e.g. 'review a pull request', 'deploy to staging', 'clean up CSV')."
		},
		"top_k": {
			"type": "integer",
			"minimum": 1,
			"maximum": 10,
			"description": "How many candidate skills to return. Default 3; max 10."
		}
	}
}`)

// SearchSkills implements the search_skills system tool.
//
// SearchSkills struct 是 search_skills 系统工具。
type SearchSkills struct {
	svc *skillapp.Service
}

// Identity --------------------------------------------------------------------

func (t *SearchSkills) Name() string                { return "search_skills" }
func (t *SearchSkills) Description() string         { return searchSkillsDescription }
func (t *SearchSkills) Parameters() json.RawMessage { return searchSkillsSchema }

// Static metadata -------------------------------------------------------------

func (t *SearchSkills) IsReadOnly() bool        { return true }
func (t *SearchSkills) NeedsReadFirst() bool    { return false }
func (t *SearchSkills) RequiresWorkspace() bool { return false }

// ── Args-dependent hooks ─────────────────────────────────────────────

func (t *SearchSkills) ValidateInput(args json.RawMessage) error {
	var a struct {
		Query string `json:"query"`
	}
	if err := json.Unmarshal(args, &a); err != nil {
		return fmt.Errorf("search_skills.ValidateInput: %w", err)
	}
	if strings.TrimSpace(a.Query) == "" {
		return ErrEmptyQuery
	}
	return nil
}

func (t *SearchSkills) CheckPermissions(_ json.RawMessage, _ toolapp.PermissionMode) toolapp.PermissionResult {
	return toolapp.PermissionAllow
}

// ── Execute ──────────────────────────────────────────────────────────

// searchResult is the per-skill row in the JSON response. Body is NOT
// included (L2 progressive-disclosure: only activation loads body).
//
// searchResult 是 JSON 响应里 per-skill 的一行。Body 不含（L2 progressive-
// disclosure：仅激活时加载 body）。
type searchResult struct {
	Name        string `json:"name"`
	Description string `json:"description"`
	IsFork      bool   `json:"isFork"`
	Arguments   []string `json:"arguments,omitempty"`
}

// Execute calls Service.Search and packs the result. Failure paths return
// friendly strings (per §S18) so the LLM can read the situation rather
// than getting an opaque tool failure.
//
// Execute 调 Service.Search 打包结果。失败友好字符串（§S18）让 LLM 自决，
// 不给不透明 tool 失败。
func (t *SearchSkills) Execute(ctx context.Context, argsJSON string) (string, error) {
	var args struct {
		Query string `json:"query"`
		TopK  int    `json:"top_k"`
	}
	if err := json.Unmarshal([]byte(argsJSON), &args); err != nil {
		return "", fmt.Errorf("search_skills.Execute: parse args: %w", err)
	}
	topK := args.TopK
	if topK <= 0 {
		topK = defaultTopK
	}

	skills, err := t.svc.Search(ctx, args.Query, topK)
	if err != nil {
		// LLM-resolution failure is the typical case (no chat model
		// configured). Friendly string so the LLM can suggest the user
		// configure one — search still works (alpha order) so the
		// failure surfaces only when ranking would have helped.
		// LLM 解析失败是典型场景（未配 chat model）。友好字符串让 LLM
		// 提示用户配；search 在 ≤topK 时仍工作（字母序），失败仅在排序
		// 真有用时暴露。
		return fmt.Sprintf("Search failed: %v. The skills catalog needs a chat model configured to rank results when there are many candidates.", err), nil
	}

	if len(skills) == 0 {
		return "No skills installed. Have the user install one (drag a SKILL.md folder into the skills panel, or write one to ~/.forgify/skills/<name>/SKILL.md).", nil
	}

	out := make([]searchResult, 0, len(skills))
	for _, sk := range skills {
		out = append(out, searchResult{
			Name:        sk.Name,
			Description: sk.Description,
			IsFork:      sk.Frontmatter.Context == "fork",
			Arguments:   sk.Frontmatter.Arguments,
		})
	}
	body, err := json.MarshalIndent(out, "", "  ")
	if err != nil {
		return "", fmt.Errorf("search_skills.Execute: marshal result: %w", err)
	}
	return string(body), nil
}

// ── Compile-time checks ──────────────────────────────────────────────

var _ toolapp.Tool = (*SearchSkills)(nil)
