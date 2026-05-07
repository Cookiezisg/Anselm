// Package skill is the domain layer for Skill — Anthropic's Agent Skills
// abstraction (cross-vendor SKILL.md spec). A skill is a directory under
// ~/.forgify/skills/<name>/ containing a SKILL.md (YAML frontmatter +
// markdown body) plus optional resources (scripts/, templates/, etc.).
// LLM uses search_skills to find one and activate_skill to load its body
// + pre-approve its allowed-tools.
//
// V1 scope (skill.md §3):
//   - user-level only (~/.forgify/skills/), no project-level merge
//   - no scanning of external dirs (Claude Code / Cursor) — self-contained
//   - description sourced from frontmatter (author writes), no LLM rewrite
//   - body cap 32 KB (per spec); description cap 1536 chars
//   - context: fork → spawn subagent (composition with Subagent, not subset)
//   - paths-glob auto-trigger NOT in V1 (parsed but not consumed)
//   - shell-substitution `!`...` blocks NOT in V1
//
// Layering (per CLAUDE.md §S13):
//
//	internal/domain/skill/skill.go      — entities + 5 sentinels (this file)
//	internal/app/skill/skill.go         — Service: Scan/Search/Activate (D7-3)
//	internal/app/skill/polling.go       — 1s polling rescan
//	internal/app/tool/skill/            — search_skills + activate_skill tools (D7-5)
//	internal/transport/httpapi/handlers/skills.go — 9 HTTP endpoints (D7-7)
//
// Aliases:
//
//	skilldomain "…/internal/domain/skill"
//	skillapp    "…/internal/app/skill"
//	skilltool   "…/internal/app/tool/skill"
//
// Package skill 是 Skill —— Anthropic Agent Skills 抽象（跨厂 SKILL.md
// spec）的 domain 层。每个 skill 是 ~/.forgify/skills/<name>/ 下的目录，
// 含 SKILL.md（YAML frontmatter + markdown body）+ 可选资源（scripts /
// templates 等）。LLM 用 search_skills 找、用 activate_skill 加载 body +
// 预授权其 allowed-tools。
//
// V1 范围（skill.md §3）：仅用户级；不扫外部目录；description 由 author
// 写不走 LLM；body 32 KB 上限；fork 模式调 subagent；paths/shell 等高级
// 字段保留 schema 但不消费。
package skill

import (
	"errors"
	"time"
)

// Skill is the metadata cache for one ~/.forgify/skills/<name>/ entry.
// Body is NOT cached here (Activate re-reads on every call to avoid stale
// reads under user-edit; per skill.md §9.5).
//
// Skill 是 ~/.forgify/skills/<name>/ 一条条目的元数据缓存。Body 不缓存
// 在这里（Activate 每次重读，防用户编辑期错版；skill.md §9.5）。
type Skill struct {
	Name        string      `json:"name"`
	Source      string      `json:"source"`        // "user" (V1 only); "plugin" reserved
	DirPath     string      `json:"dirPath"`       // resolves ${CLAUDE_SKILL_DIR}
	BodyPath    string      `json:"bodyPath"`      // absolute path to SKILL.md
	Description string      `json:"description"`   // verbatim from frontmatter
	Frontmatter Frontmatter `json:"frontmatter"`
	LoadedAt    time.Time   `json:"loadedAt"`
}

// Frontmatter mirrors the Anthropic SKILL.md spec verbatim. Cross-vendor
// fields are preserved on the struct so users dragging a Claude Code /
// Cursor skill into ~/.forgify/skills/ work without edits even when V1
// doesn't yet consume every field.
//
// V1 consumes: Name, Description, AllowedTools, DisableModelInvocation,
// Context, Agent, Arguments. V1 parses but ignores: Paths (auto-trigger),
// Effort, WhenToUse, Model, ArgumentHint, UserInvocable.
//
// Frontmatter 镜像 Anthropic SKILL.md spec。跨厂字段全保留，用户拖拽其他
// 工具的 skill 进 ~/.forgify/skills/ 无需编辑可工作，即便 V1 暂不消费
// 全部字段。V1 真消费：Name/Description/AllowedTools/DisableModelInvocation
// /Context/Agent/Arguments；V1 解析不消费：Paths/Effort/WhenToUse/Model
// /ArgumentHint/UserInvocable。
type Frontmatter struct {
	Name                   string   `yaml:"name" json:"name"`
	Description            string   `yaml:"description" json:"description"`
	WhenToUse              string   `yaml:"when_to_use,omitempty" json:"whenToUse,omitempty"`
	AllowedTools           []string `yaml:"allowed-tools,omitempty" json:"allowedTools,omitempty"`
	DisableModelInvocation bool     `yaml:"disable-model-invocation,omitempty" json:"disableModelInvocation,omitempty"`
	UserInvocable          bool     `yaml:"user-invocable,omitempty" json:"userInvocable,omitempty"`
	Paths                  []string `yaml:"paths,omitempty" json:"paths,omitempty"`
	Context                string   `yaml:"context,omitempty" json:"context,omitempty"` // "fork" or empty
	Agent                  string   `yaml:"agent,omitempty" json:"agent,omitempty"`
	Arguments              []string `yaml:"arguments,omitempty" json:"arguments,omitempty"`
	ArgumentHint           string   `yaml:"argument-hint,omitempty" json:"argumentHint,omitempty"`
	Model                  string   `yaml:"model,omitempty" json:"model,omitempty"`
	Effort                 string   `yaml:"effort,omitempty" json:"effort,omitempty"`
}

// Sentinel errors per skill.md §12. Five total: NotFound (catalog miss) +
// InvalidFrontmatter (YAML parse / required fields) + BodyTooLarge (32KB
// cap) + NameConflict (POST /skills with existing name) + InvalidName
// (regex / length cap on user-supplied skill name).
//
// Sentinel 错误（skill.md §12）：5 个——NotFound / InvalidFrontmatter /
// BodyTooLarge / NameConflict / InvalidName。
var (
	ErrSkillNotFound      = errors.New("skill: not found")
	ErrInvalidFrontmatter = errors.New("skill: invalid frontmatter")
	ErrBodyTooLarge       = errors.New("skill: body exceeds size limit")
	ErrNameConflict       = errors.New("skill: name already exists")
	ErrInvalidName        = errors.New("skill: invalid name")
)

// MaxBodyBytes is the SKILL.md body size cap (Anthropic spec §10.6 for
// progressive disclosure: bodies bigger than ~32 KB defeat the L2 size
// budget the model expects to load eagerly).
//
// MaxBodyBytes 是 SKILL.md body 大小上限（Anthropic spec §10.6 progressive
// disclosure：body 超 32 KB 会击穿模型预期的 L2 预算）。
const MaxBodyBytes = 32 * 1024

// MaxDescriptionChars is the frontmatter.description cap (per spec — keeps
// L1 catalog injection cost predictable).
//
// MaxDescriptionChars 是 frontmatter.description 上限（per spec——让 L1
// catalog 注入成本可预测）。
const MaxDescriptionChars = 1536
