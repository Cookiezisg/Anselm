package control

import "context"

// VersionCap bounds how many versions one control logic retains; edits beyond this trim
// the oldest — but never the active version (it can be old after a revert).
//
// VersionCap 限制单 control 逻辑保留的版本数；超出裁最老的——但绝不裁 active 版本（revert 后
// 它可能很老）。
const VersionCap = 50

// ListFilter is a cursor page request for control logics.
//
// ListFilter 是 control 逻辑的 cursor 分页请求。
type ListFilter struct {
	Cursor string
	Limit  int
}

// VersionListFilter is a cursor page request for one control logic's versions.
//
// VersionListFilter 是单 control 逻辑版本的 cursor 分页请求。
type VersionListFilter struct {
	Cursor string
	Limit  int
}

// Repository is the storage contract for ControlLogic + Version. Workspace isolation is
// applied by the orm layer from ctx (the ,ws column tag), so methods take no workspace id.
//
// Repository 是 ControlLogic + Version 的存储契约。workspace 隔离由 orm 层据 ctx 施加（,ws 列
// tag），故方法不带 workspace id。
type Repository interface {
	SaveControl(ctx context.Context, c *ControlLogic) error
	GetControl(ctx context.Context, id string) (*ControlLogic, error)
	GetControlsByIDs(ctx context.Context, ids []string) ([]*ControlLogic, error)
	ListControls(ctx context.Context, filter ListFilter) ([]*ControlLogic, string, error)
	ListAllControls(ctx context.Context) ([]*ControlLogic, error)
	DeleteControl(ctx context.Context, id string) error // soft-delete (tombstone)
	SetActiveVersion(ctx context.Context, controlID, versionID string) error
	CreateWithVersion(ctx context.Context, e *ControlLogic, v *Version) error      // create + v1, one tx (review PD-3)
	SaveVersionAndActivate(ctx context.Context, v *Version, entityID string) error // new version + pointer move, one tx (review PD-3)

	SaveVersion(ctx context.Context, v *Version) error
	GetVersion(ctx context.Context, versionID string) (*Version, error)
	GetVersionByNumber(ctx context.Context, controlID string, versionN int) (*Version, error)
	ListVersions(ctx context.Context, controlID string, filter VersionListFilter) ([]*Version, string, error)

	// MaxVersionNumber returns the highest version number for a control logic (0 if none)
	// — the next write is MaxVersionNumber+1.
	//
	// MaxVersionNumber 返某 control 逻辑的最大版本号（无则 0）——下一次写入为 +1。
	MaxVersionNumber(ctx context.Context, controlID string) (int, error)

	// TrimOldestVersions hard-deletes versions beyond the newest `keep`, never deleting
	// the control logic's current active version.
	//
	// TrimOldestVersions 硬删超出最新 keep 个的版本，绝不删 control 逻辑当前 active 版本。
	TrimOldestVersions(ctx context.Context, controlID string, keep int) error
}
