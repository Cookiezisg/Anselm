package function

import "time"

const (
	StatusPending  = "pending"
	StatusAccepted = "accepted"
	StatusRejected = "rejected"
)

// Version kind (doc 01 §"polling = Function entity 的 kind=polling"): kind is version-level so each
// version can flip normal↔polling. A polling version's code is fixed-signature `def poll(lastCursor)`
// returning {"events":[...], "nextCursor":...}; the platform calls it every PollingInterval.
//
// Kind 是 version 级；polling 版固定签名 def poll(lastCursor)->{events,nextCursor}，平台按 PollingInterval 反复跑。
const (
	KindNormal  = "normal"
	KindPolling = "polling"
)

func IsValidKind(k string) bool { return k == KindNormal || k == KindPolling }

const (
	EnvStatusPending = "pending"
	EnvStatusSyncing = "syncing"
	EnvStatusReady   = "ready"
	EnvStatusFailed  = "failed"
	EnvStatusEvicted = "evicted"
)

const DefaultPythonVersion = ">=3.12"

// Version is a snapshot of code+parameters+return_schema+deps for one Function.
//
// Version 是 Function 在某时刻 code/parameters/return_schema/deps 的快照。
type Version struct {
	ID            string          `gorm:"primaryKey;type:text" json:"id"`
	FunctionID    string          `gorm:"not null;index:idx_function_versions_function_id;type:text" json:"functionId"`
	Status        string          `gorm:"not null;check:status IN ('pending','accepted','rejected');type:text;default:'pending'" json:"status"`
	Version       *int            `gorm:"type:integer" json:"version,omitempty"`
	Code          string          `gorm:"type:text;default:''" json:"code"`
	Parameters    []ParameterSpec `gorm:"serializer:json;type:text;default:'[]'" json:"parameters"`
	ReturnSchema  map[string]any  `gorm:"serializer:json;type:text;default:'{}'" json:"returnSchema"`
	Dependencies  []string        `gorm:"serializer:json;type:text;default:'[]'" json:"dependencies"`
	PythonVersion string          `gorm:"type:text;default:''" json:"pythonVersion"`
	// Kind = normal (default) | polling (17 §1 function_versions). PollingInterval is the canon
	// location for the poll cadence (a duration string like "60s"); meaningful only when Kind=polling.
	//
	// Kind 默认 normal；PollingInterval 是 poll 间隔的 canon 位置（"60s" 形式），仅 polling 有意义。
	Kind            string          `gorm:"not null;check:kind IN ('normal','polling');type:text;default:'normal'" json:"kind"`
	PollingInterval string          `gorm:"type:text;default:''" json:"pollingInterval,omitempty"`
	EnvID         string          `gorm:"index:idx_function_versions_env_id;type:text;default:''" json:"envId"`
	EnvStatus     string          `gorm:"type:text;default:'pending'" json:"envStatus"`
	EnvError      string          `gorm:"type:text;default:''" json:"envError"`
	EnvSyncedAt   *time.Time      `json:"envSyncedAt,omitempty"`
	EnvSyncStage  string          `gorm:"type:text;default:''" json:"envSyncStage"`
	EnvSyncDetail string          `gorm:"type:text;default:''" json:"envSyncDetail"`
	ChangeReason  string          `gorm:"type:text;default:''" json:"changeReason"`
	// ForgedInConversationID records which conversation (if any) produced this version
	// via the create_forge / edit_forge LLM tool. NULL when created via manual HTTP
	// (UI editor / API client). Used by relation domain to derive forged/edited edges.
	//
	// ForgedInConversationID 记录哪一个对话（若有）通过 create_forge / edit_forge
	// LLM 工具产生本 version。NULL 表示由 HTTP 手工创建（UI 编辑器 / API 客户端）。
	// 由 relation domain 派生 forged/edited 边时使用。
	ForgedInConversationID *string         `gorm:"index;type:text" json:"forgedInConversationId,omitempty"`
	CreatedAt     time.Time       `json:"createdAt"`
	UpdatedAt     time.Time       `json:"updatedAt"`
}

func (Version) TableName() string { return "function_versions" }

// ParameterSpec describes one declared input parameter (LLM self-reports via set_parameters op).
//
// ParameterSpec 描述声明的一个入参（LLM 通过 set_parameters op 自报）。
type ParameterSpec struct {
	Name        string `json:"name"`
	Type        string `json:"type"`
	Description string `json:"description,omitempty"`
	Required    bool   `json:"required"`
	Default     any    `json:"default,omitempty"`
	Enum        []any  `json:"enum,omitempty"`
}
