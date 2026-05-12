// version.go — HandlerVersion snapshot + status / env enums.
//
// version.go —— HandlerVersion 快照 + status / env 枚举。

package handler

import "time"

// ── Status enumeration(3,DB CHECK-constrained)───────────────────────

const (
	StatusPending  = "pending"
	StatusAccepted = "accepted"
	StatusRejected = "rejected"
)

// ── EnvStatus enumeration(5,service-layer 校验)─────────────────────

const (
	EnvStatusPending = "pending"
	EnvStatusSyncing = "syncing"
	EnvStatusReady   = "ready"
	EnvStatusFailed  = "failed"
	EnvStatusEvicted = "evicted"
)

// ── ConfigState enumeration(3,computed,not persisted)───────────────
//
// service.attachComputed 算后填到 Handler.ConfigState:
//   - unconfigured:从未填过 config(ConfigEncrypted=="")
//   - partially_configured:填过部分但缺必填项(schema 改动后常见)
//   - ready:Spawn 所需必填项齐全

const (
	ConfigStateUnconfigured        = "unconfigured"
	ConfigStatePartiallyConfigured = "partially_configured"
	ConfigStateReady               = "ready"
)

// DefaultPythonVersion is the fallback PEP 440 specifier when a Version's
// PythonVersion field is empty.
//
// DefaultPythonVersion 是 Version.PythonVersion 为空时的 fallback。
const DefaultPythonVersion = ">=3.12"

// AcceptedVersionCap is the max number of accepted versions kept per Handler;
// HardDeleteOldestAccepted hard-deletes the oldest after each new accept.
//
// AcceptedVersionCap 是每 Handler 保留的 accepted 版本上限,
// HardDeleteOldestAccepted 在 accept 后硬删最旧的。
const AcceptedVersionCap = 50

// Version is a HandlerVersion snapshot — class code-parts + methods +
// init_args schema + sandbox env state. Doubles as pending change storage
// (Status="pending", Version=NULL).
//
// Version 是 HandlerVersion 快照——class 各部分代码 + methods + init_args
// schema + sandbox env 状态。兼作 pending 变更存储。
type Version struct {
	ID        string `gorm:"primaryKey;type:text" json:"id"`
	HandlerID string `gorm:"not null;index:idx_handler_versions_handler_id;type:text" json:"handlerId"`
	Status    string `gorm:"not null;check:status IN ('pending','accepted','rejected');type:text;default:'pending'" json:"status"`
	Version   *int   `gorm:"type:integer" json:"version,omitempty"`

	// Class code parts. System composes:
	//   <Imports>
	//   class _Handler:
	//       def __init__(self, init_args): <InitBody>
	//       def shutdown(self):           <ShutdownBody>
	//       def <method.Name>(self, **args): <method.Body>  ... per method
	//
	// Class 代码各部分。系统拼装时按上面模板生成完整 class。
	Imports      string `gorm:"type:text;default:''" json:"imports"`
	InitBody     string `gorm:"type:text;default:''" json:"initBody"`
	ShutdownBody string `gorm:"type:text;default:''" json:"shutdownBody"`

	Methods        []MethodSpec  `gorm:"serializer:json;type:text;default:'[]'" json:"methods"`
	InitArgsSchema []InitArgSpec `gorm:"serializer:json;type:text;default:'[]'" json:"initArgsSchema"`
	Dependencies   []string      `gorm:"serializer:json;type:text;default:'[]'" json:"dependencies"`
	PythonVersion  string        `gorm:"type:text;default:''" json:"pythonVersion"`

	// Sandbox env state — mirrors function.Version fields exactly; SyncEnvForVersion
	// + recordExecution paths reuse the same status machine.
	//
	// Sandbox env 状态——跟 function.Version 字段一致;SyncEnvForVersion 复用同样状态机。
	EnvID         string     `gorm:"index:idx_handler_versions_env_id;type:text;default:''" json:"envId"`
	EnvStatus     string     `gorm:"type:text;default:'pending'" json:"envStatus"`
	EnvError      string     `gorm:"type:text;default:''" json:"envError"`
	EnvSyncedAt   *time.Time `json:"envSyncedAt,omitempty"`
	EnvSyncStage  string     `gorm:"type:text;default:''" json:"envSyncStage"`
	EnvSyncDetail string     `gorm:"type:text;default:''" json:"envSyncDetail"`

	ChangeReason string    `gorm:"type:text;default:''" json:"changeReason"`
	CreatedAt    time.Time `json:"createdAt"`
	UpdatedAt    time.Time `json:"updatedAt"`
}

func (Version) TableName() string { return "handler_versions" }
