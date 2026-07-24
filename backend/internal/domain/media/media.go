// Package media defines the durable identity and lifecycle of regenerable media work.
// Attachment rows remain the immutable user-visible original; this package records only
// derived proxies and perception evidence keyed by the exact original SHA and request
// parameters. It deliberately never stores original bytes or plaintext task input.
//
// Package media 定义可再生媒体工作的持久身份与生命周期。附件行仍是不可变、用户可见的原件；本包只记录
// 按精确原件 SHA 与请求参数键控的派生代理和感知证据，绝不保存原件字节或明文任务输入。
package media

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"time"

	errorspkg "github.com/sunweilin/anselm/backend/internal/pkg/errors"
)

const (
	StatusPending   = "pending"
	StatusRunning   = "running"
	StatusReady     = "ready"
	StatusFailed    = "failed"
	StatusCancelled = "cancelled"
)

// Derivative is a regenerable model/UI-oriented representation of an attachment: for example a
// normalised image proxy, a video key frame, or an extracted page image. SourceSHA256 + ParamsHash
// are both part of the cache identity; a record can therefore never be reused for a changed source
// or changed transform.
type Derivative struct {
	ID           string    `db:"id,pk" json:"id"`
	WorkspaceID  string    `db:"workspace_id,ws" json:"-"`
	AttachmentID string    `db:"attachment_id" json:"attachmentId"`
	Kind         string    `db:"kind" json:"kind"`
	SourceSHA256 string    `db:"source_sha256" json:"sourceSha256"`
	ParamsHash   string    `db:"params_hash" json:"paramsHash"`
	ParamsJSON   string    `db:"params_json" json:"-"`
	Status       string    `db:"status" json:"status"`
	BlobSHA256   string    `db:"blob_sha256" json:"blobSha256"`
	MimeType     string    `db:"mime_type" json:"mimeType"`
	SizeBytes    int64     `db:"size_bytes" json:"sizeBytes"`
	Width        int       `db:"width" json:"width"`
	Height       int       `db:"height" json:"height"`
	DurationMS   int64     `db:"duration_ms" json:"durationMs"`
	ErrorCode    string    `db:"error_code" json:"errorCode"`
	CreatedAt    time.Time `db:"created_at,created" json:"createdAt"`
	UpdatedAt    time.Time `db:"updated_at,updated" json:"updatedAt"`
}

// Perception is a task-scoped, bounded evidence capsule produced from an attachment. TaskHash is
// a SHA-256 digest, not the user question; this keeps private prompt content out of the database
// while making identical work reusable. CapsuleJSON is populated only by a successful processor.
type Perception struct {
	ID           string    `db:"id,pk" json:"id"`
	WorkspaceID  string    `db:"workspace_id,ws" json:"-"`
	AttachmentID string    `db:"attachment_id" json:"attachmentId"`
	Kind         string    `db:"kind" json:"kind"`
	SourceSHA256 string    `db:"source_sha256" json:"sourceSha256"`
	TaskHash     string    `db:"task_hash" json:"taskHash"`
	Provider     string    `db:"provider" json:"provider"`
	Model        string    `db:"model" json:"model"`
	ParamsHash   string    `db:"params_hash" json:"paramsHash"`
	ParamsJSON   string    `db:"params_json" json:"-"`
	Status       string    `db:"status" json:"status"`
	CapsuleJSON  string    `db:"capsule_json" json:"-"`
	InputTokens  int       `db:"input_tokens" json:"inputTokens"`
	OutputTokens int       `db:"output_tokens" json:"outputTokens"`
	ErrorCode    string    `db:"error_code" json:"errorCode"`
	CreatedAt    time.Time `db:"created_at,created" json:"createdAt"`
	UpdatedAt    time.Time `db:"updated_at,updated" json:"updatedAt"`
}

var (
	ErrInvalidRequest = errorspkg.New(errorspkg.KindInvalid, "MEDIA_INVALID_REQUEST", "invalid media preparation request")
	ErrNotFound       = errorspkg.New(errorspkg.KindNotFound, "MEDIA_NOT_FOUND", "media work not found")
)

// Hash returns a stable opaque SHA-256 identity for canonical request bytes. It is used for both
// transform parameters and task text, so neither leaks into logs, ids, or cache keys.
func Hash(b []byte) string {
	sum := sha256.Sum256(b)
	return hex.EncodeToString(sum[:])
}

func ValidStatus(status string) bool {
	switch status {
	case StatusPending, StatusRunning, StatusReady, StatusFailed, StatusCancelled:
		return true
	default:
		return false
	}
}

// Repository provides atomic work claiming. created=true means the caller owns the newly pending
// record and may schedule processing; created=false means an identical record already exists and
// must be reused rather than recomputed.
type Repository interface {
	ClaimDerivative(ctx context.Context, derivative *Derivative) (got *Derivative, created bool, err error)
	ClaimPerception(ctx context.Context, perception *Perception) (got *Perception, created bool, err error)
	GetDerivative(ctx context.Context, id string) (*Derivative, error)
	GetPerception(ctx context.Context, id string) (*Perception, error)
	SaveDerivative(ctx context.Context, derivative *Derivative) error
	SavePerception(ctx context.Context, perception *Perception) error
	ListPendingDerivatives(ctx context.Context, limit int) ([]*Derivative, error)
	ListPendingPerceptions(ctx context.Context, limit int) ([]*Perception, error)
	RequeueRunning(ctx context.Context) (int, error)
	ListReadyDerivativeBlobs(ctx context.Context) ([]string, error)
	ListReadyDerivatives(ctx context.Context) ([]*Derivative, error)
}
