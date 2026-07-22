// Package skill is the domain layer for file-based Agent Skills (SKILL.md directories).
//
// skill is an instruction CARRIER, not a build entity: name(slug) IS its identity — no
// generated id, no version (editing overwrites the file). It is memory's kin (a file-backed
// injectable), NOT function's kin (an execution entity): hence no execution log, no search,
// zero DB tables, zero LLM dependency.
//
// Package skill 是文件式 Agent Skill（SKILL.md 目录）的 domain 层。
// skill 是「指令载体」非构建实体：name(slug) 即身份——无生成 id、无版本（编辑即覆盖文件）。
// 它是 memory 的近亲（文件式注入物），不是 function 的近亲（执行实体）：故无 execution、
// 无 search、零 DB 表、零 LLM 依赖。
package skill

import (
	"context"
	"regexp"
	"time"

	errorspkg "github.com/sunweilin/anselm/backend/internal/pkg/errors"
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

// Frontmatter is the TYPED VIEW of a SKILL.md frontmatter: the Agent Skills open-spec core
// (name/description/license/compatibility/metadata/allowed-tools) + the Claude Code extension
// fields + Anselm's own `source` extension (who authored the skill). It is a projection, not
// the truth — the store round-trips the raw YAML node tree so keys outside this struct (and
// key order) survive edits (WRK-076 D1/D2).
//
// Frontmatter 是 SKILL.md frontmatter 的**类型化视图**：开放规范核心 6 字段
// （name/description/license/compatibility/metadata/allowed-tools）+ Claude Code 扩展字段 +
// Anselm 自有扩展 `source`（谁创作）。它是投影、非真相——store 层以原文 YAML 节点树往返，
// 本 struct 之外的键（与键序）在编辑循环中不丢（WRK-076 D1/D2）。
type Frontmatter struct {
	Name                   string            `yaml:"name" json:"name"`
	Description            string            `yaml:"description" json:"description"`
	License                string            `yaml:"license,omitempty" json:"license,omitempty"`
	Compatibility          string            `yaml:"compatibility,omitempty" json:"compatibility,omitempty"`
	Metadata               map[string]string `yaml:"metadata,omitempty" json:"metadata,omitempty"`
	AllowedTools           []string          `yaml:"allowed-tools,omitempty" json:"allowedTools,omitempty"`
	Context                string            `yaml:"context,omitempty" json:"context,omitempty"`
	Agent                  string            `yaml:"agent,omitempty" json:"agent,omitempty"`
	Arguments              []string          `yaml:"arguments,omitempty" json:"arguments,omitempty"`
	DisableModelInvocation bool              `yaml:"disable-model-invocation,omitempty" json:"disableModelInvocation,omitempty"`
	UserInvocable          bool              `yaml:"user-invocable,omitempty" json:"userInvocable,omitempty"`
	WhenToUse              string            `yaml:"when_to_use,omitempty" json:"whenToUse,omitempty"`
	Model                  string            `yaml:"model,omitempty" json:"model,omitempty"`
	Effort                 string            `yaml:"effort,omitempty" json:"effort,omitempty"`
	Source                 string            `yaml:"source,omitempty" json:"source,omitempty"` // Anselm 扩展：user | ai
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
	MaxBodyBytes        = 32 * 1024   // SKILL.md 物理护栏（非 token 预算）
	MaxDescriptionChars = 1024        // 对齐 Agent Skills 规范
	MaxFileBytes        = 1024 * 1024 // 附属文件单文件护栏（对齐 document 的 1MB）
)

// Two name regexes (WRK-076 D3): the GUARD is what makes a name filesystem-safe (slug IS the
// identity, a valid name maps 1:1 to a directory — no `/`, no `.`, so no separate traversal
// guard needed); it is lenient (digit-start + `_` allowed) so legacy `_` skills stay readable
// and spec-named installs (e.g. 3d-print) resolve. The SPEC regex is the Agent Skills open-spec
// ASCII form enforced only at creation — no `_`, no leading/trailing/consecutive hyphens.
//
// 双正则（WRK-076 D3）：守卫正则是文件安全底线（slug 即身份、合法 name 1:1 映射目录——无 `/`
// 无 `.`，故无需单独穿越守卫），从宽（允数字开头 + `_`）保存量 `_` skill 可读、规范名安装
// （如 3d-print）可解析；创建正则是开放规范 ASCII 形态、仅新建时从严——无 `_`、无首尾/连续连字符。
var (
	NameRegex     = regexp.MustCompile(`^[a-z0-9][a-z0-9_-]{0,63}$`)
	SpecNameRegex = regexp.MustCompile(`^[a-z0-9]+(-[a-z0-9]+)*$`)
)

func IsValidName(name string) bool { return NameRegex.MatchString(name) }

// IsSpecName reports whether name conforms to the Agent Skills open spec (creation-time check).
//
// IsSpecName 报告 name 是否符合 Agent Skills 开放规范（创建时校验）。
func IsSpecName(name string) bool {
	return len(name) <= 64 && SpecNameRegex.MatchString(name)
}

var (
	ErrNotFound            = errorspkg.New(errorspkg.KindNotFound, "SKILL_NOT_FOUND", "skill not found")
	ErrInvalidName         = errorspkg.New(errorspkg.KindInvalid, "SKILL_INVALID_NAME", "invalid skill name (must be a lowercase slug)")
	ErrInvalidFrontmatter  = errorspkg.New(errorspkg.KindUnprocessable, "SKILL_INVALID_FRONTMATTER", "invalid skill frontmatter")
	ErrBodyTooLarge        = errorspkg.New(errorspkg.KindUnprocessable, "SKILL_BODY_TOO_LARGE", "skill body exceeds size limit")
	ErrNameConflict        = errorspkg.New(errorspkg.KindConflict, "SKILL_NAME_CONFLICT", "skill name already exists")
	ErrForkRequiresAgent   = errorspkg.New(errorspkg.KindUnprocessable, "SKILL_FORK_REQUIRES_AGENT", "context=fork requires an agent type")
	ErrSubagentUnavailable = errorspkg.New(errorspkg.KindUnavailable, "SKILL_SUBAGENT_UNAVAILABLE", "fork skill requires a subagent runner (not wired)")
	ErrFileNotFound        = errorspkg.New(errorspkg.KindNotFound, "SKILL_FILE_NOT_FOUND", "skill file not found")
	ErrFilePathInvalid     = errorspkg.New(errorspkg.KindInvalid, "SKILL_FILE_PATH_INVALID", "invalid skill file path")
	ErrFileTooLarge        = errorspkg.New(errorspkg.KindUnprocessable, "SKILL_FILE_TOO_LARGE", "skill file exceeds size limit")
)

// ListFilter narrows List queries; zero value = all skills.
//
// ListFilter 收窄 List 查询；零值 = 全部。
type ListFilter struct {
	Source string // "" = all
}

// FileInfo is one bundled-file entry inside a skill directory (SKILL.md included). Path is
// always the /-separated relative path from the skill root.
//
// FileInfo 是 skill 目录内的单个捆绑文件条目（含 SKILL.md）。Path 恒为相对 skill 根的
// `/` 分隔相对路径。
type FileInfo struct {
	Path      string    `json:"path"`
	Size      int64     `json:"size"`
	UpdatedAt time.Time `json:"updatedAt"`
}

// Repository is the persistence port — file-backed, so signatures carry no workspace id
// (the store derives the per-workspace directory from ctx). Save is the STRUCTURED write
// (fidelity read-modify-write under the hood: keys outside the typed view survive); SaveRaw
// is the verbatim write (bytes land as given — the file-is-truth surface). The file methods
// operate on bundled files by relative path, traversal-guarded by the store.
//
// Repository 是持久化端口——文件式，签名不带 workspace id（store 据 ctx 推导每 workspace 目录）。
// Save 是结构化写（底层保真读-改-写：类型化视图之外的键不丢）；SaveRaw 是逐字节原文写
// （文件即真相面）。file 方法按相对路径操作捆绑文件，穿越守卫由 store 承担。
type Repository interface {
	List(ctx context.Context, filter ListFilter) ([]*Skill, error) // 不含 Body
	Get(ctx context.Context, name string) (*Skill, error)          // 含 Body
	Save(ctx context.Context, name string, fm Frontmatter, body string) error
	SaveRaw(ctx context.Context, name string, raw []byte) error
	Delete(ctx context.Context, name string) error
	Exists(ctx context.Context, name string) (bool, error)
	Dir(ctx context.Context, name string) (string, error) // skill 目录绝对路径（${CLAUDE_SKILL_DIR} 取值）
	ListFiles(ctx context.Context, name string) ([]FileInfo, error)
	ReadFile(ctx context.Context, name, rel string) ([]byte, error)
	WriteFile(ctx context.Context, name, rel string, data []byte) error
	DeleteFile(ctx context.Context, name, rel string) error
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
