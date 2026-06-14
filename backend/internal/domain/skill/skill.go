// Package skill is the domain layer for file-based Agent Skills (SKILL.md directories).
//
// skill is an instruction CARRIER, not a forge entity: name(slug) IS its identity — no
// generated id, no version (editing overwrites the file). It is memory's kin (a file-backed
// injectable), NOT function's kin (an execution entity): hence no execution log, no search,
// zero DB tables, zero LLM dependency.
//
// Package skill 是文件式 Agent Skill（SKILL.md 目录）的 domain 层。
// skill 是「指令载体」非锻造实体：name(slug) 即身份——无生成 id、无版本（编辑即覆盖文件）。
// 它是 memory 的近亲（文件式注入物），不是 function 的近亲（执行实体）：故无 execution、
// 无 search、零 DB 表、零 LLM 依赖。
package skill

import (
	"context"
	"regexp"
	"time"

	errorspkg "github.com/sunweilin/forgify/backend/internal/pkg/errors"
)

// Skill is one SKILL.md entry's metadata. Body is populated only by Get (single read);
// List omits it to stay cheap.
//
// Skill 是单条 SKILL.md 的元数据。Body 仅 Get（单文件读）时填，List 省略以保持轻量。
type Skill struct {
	Name        string      `json:"name"`           // slug = 身份，无生成 id（同 memory）
	Description string      `json:"description"`    // 便利字段 = Frontmatter.Description
	Source      string      `json:"source"`         // user | ai
	Context     string      `json:"context"`        // inline | fork
	Body        string      `json:"body,omitempty"` // 仅 Get 填
	Frontmatter Frontmatter `json:"frontmatter"`
	UpdatedAt   time.Time   `json:"updatedAt"` // 文件 mtime
}

// Frontmatter mirrors the Anthropic SKILL.md spec verbatim — all cross-vendor fields kept
// for seamless import even though only a subset is consumed today. Source is Forgify's
// own extension (who authored the skill), persisted alongside the standard fields.
//
// Frontmatter 逐字镜像 Anthropic SKILL.md spec——跨厂字段全留以便无缝导入，当前只消费子集。
// Source 是 Forgify 自有扩展（谁创作），与标准字段一起持久化。
type Frontmatter struct {
	Name                   string   `yaml:"name" json:"name"`
	Description            string   `yaml:"description" json:"description"`
	AllowedTools           []string `yaml:"allowed-tools,omitempty" json:"allowedTools,omitempty"`
	Context                string   `yaml:"context,omitempty" json:"context,omitempty"`
	Agent                  string   `yaml:"agent,omitempty" json:"agent,omitempty"`
	Arguments              []string `yaml:"arguments,omitempty" json:"arguments,omitempty"`
	DisableModelInvocation bool     `yaml:"disable-model-invocation,omitempty" json:"disableModelInvocation,omitempty"`
	UserInvocable          bool     `yaml:"user-invocable,omitempty" json:"userInvocable,omitempty"`
	WhenToUse              string   `yaml:"when_to_use,omitempty" json:"whenToUse,omitempty"`
	Model                  string   `yaml:"model,omitempty" json:"model,omitempty"`
	Effort                 string   `yaml:"effort,omitempty" json:"effort,omitempty"`
	Source                 string   `yaml:"source,omitempty" json:"source,omitempty"` // Forgify 扩展：user | ai
}

// Context modes: inline injects into the current dialogue; fork dispatches an isolated subagent.
//
// Context 模式：inline 注入当前对话；fork 派一个隔离 subagent。
const (
	ContextInline = "inline"
	ContextFork   = "fork"
)

// Source values.
const (
	SourceUser = "user"
	SourceAI   = "ai"
)

func IsValidSource(s string) bool { return s == SourceUser || s == SourceAI }

const (
	MaxBodyBytes        = 32 * 1024 // 物理护栏（非 token 预算）
	MaxDescriptionChars = 1024      // 对齐 Anthropic 规范
)

// NameRegex constrains skill names to filesystem-safe slugs — slug IS the identity, so a
// valid name maps 1:1 to a directory and needs no separate path-traversal guard.
//
// NameRegex 把 skill name 限制为文件安全的 slug——slug 即身份，合法 name 1:1 映射目录、
// 无需单独的路径穿越守卫。
var NameRegex = regexp.MustCompile(`^[a-z][a-z0-9_-]{0,63}$`)

func IsValidName(name string) bool { return NameRegex.MatchString(name) }

var (
	ErrNotFound            = errorspkg.New(errorspkg.KindNotFound, "SKILL_NOT_FOUND", "skill not found")
	ErrInvalidName         = errorspkg.New(errorspkg.KindInvalid, "SKILL_INVALID_NAME", "invalid skill name (must be a lowercase slug)")
	ErrInvalidFrontmatter  = errorspkg.New(errorspkg.KindUnprocessable, "SKILL_INVALID_FRONTMATTER", "invalid skill frontmatter")
	ErrBodyTooLarge        = errorspkg.New(errorspkg.KindUnprocessable, "SKILL_BODY_TOO_LARGE", "skill body exceeds size limit")
	ErrNameConflict        = errorspkg.New(errorspkg.KindConflict, "SKILL_NAME_CONFLICT", "skill name already exists")
	ErrForkRequiresAgent   = errorspkg.New(errorspkg.KindUnprocessable, "SKILL_FORK_REQUIRES_AGENT", "context=fork requires an agent type")
	ErrSubagentUnavailable = errorspkg.New(errorspkg.KindUnavailable, "SKILL_SUBAGENT_UNAVAILABLE", "fork skill requires a subagent runner (not wired)")
)

// ListFilter narrows List queries; zero value = all skills.
//
// ListFilter 收窄 List 查询；零值 = 全部。
type ListFilter struct {
	Source string // "" = all
}

// Repository is the persistence port — file-backed, so signatures carry no workspace id
// (the store derives the per-workspace directory from ctx).
//
// Repository 是持久化端口——文件式，签名不带 workspace id（store 据 ctx 推导每 workspace 目录）。
type Repository interface {
	List(ctx context.Context, filter ListFilter) ([]*Skill, error) // 不含 Body
	Get(ctx context.Context, name string) (*Skill, error)          // 含 Body
	Save(ctx context.Context, name string, fm Frontmatter, body string) error
	Delete(ctx context.Context, name string) error
	Exists(ctx context.Context, name string) (bool, error)
}

// SubagentRunner is the fork-mode port: a context:fork skill dispatches its rendered body as
// an isolated subagent run. Kept self-contained (no subagentapp types) so skill carries no
// dependency on the subagent layer; a nil runner makes fork degrade to ErrSubagentUnavailable.
//
// SubagentRunner 是 fork 模式端口：context:fork 的 skill 把渲染后的正文派给隔离 subagent 跑。
// 自包含（不引 subagentapp 类型）使 skill 不依赖 subagent 层；nil runner
// 时 fork 降级为 ErrSubagentUnavailable。
type SubagentRunner interface {
	Spawn(ctx context.Context, agentType, prompt string) (result string, err error)
}
