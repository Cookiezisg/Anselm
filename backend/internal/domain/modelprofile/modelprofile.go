// Package modelprofile defines the durable, privacy-preserving runtime evidence
// used to learn an external model route's safe prompt budget. It deliberately
// records only route fingerprints and numeric measurements: never prompt text,
// attachment payloads, upstream raw errors, or plaintext API keys.
//
// Package modelprofile 定义外部模型路由的运行时证据。它只持久化路由指纹和数值测量，绝不
// 保存 prompt、附件载荷、上游原始错误或明文 API Key。
package modelprofile

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"strings"
	"time"
)

const (
	RequestClassText       = "text"
	RequestClassMultimodal = "multimodal"

	ObservationSuccess         = "success"
	ObservationContextOverflow = "context_overflow"
)

// Identity separates evidence whenever any property that can change a
// provider's effective context envelope changes. EndpointFingerprint and
// CredentialFingerprint are opaque SHA-256 digests produced outside this
// package; neither is a URL nor a plaintext credential.
//
// Identity 在任何可能改变上游实际上下文额度的属性变动时隔离证据。EndpointFingerprint 和
// CredentialFingerprint 都是本包外产生的不透明 SHA-256 摘要，不是 URL 或明文凭证。
type Identity struct {
	Provider              string
	APIKeyID              string
	EndpointFingerprint   string
	CredentialFingerprint string
	ModelID               string
	RequestClass          string
	ConfigFingerprint     string
}

// Key returns a stable non-secret identifier for this exact route/configuration.
func (i Identity) Key() string {
	h := sha256.New()
	for _, value := range []string{
		strings.TrimSpace(i.Provider), i.APIKeyID, i.EndpointFingerprint,
		i.CredentialFingerprint, i.ModelID, i.RequestClass, i.ConfigFingerprint,
	} {
		h.Write([]byte(value))
		h.Write([]byte{0})
	}
	return hex.EncodeToString(h.Sum(nil))
}

// Valid reports whether the identity is precise enough for learned evidence to
// be safely reused. Missing fingerprints intentionally mean "do not learn".
func (i Identity) Valid() bool {
	if strings.TrimSpace(i.Provider) == "" || i.APIKeyID == "" ||
		i.EndpointFingerprint == "" || i.CredentialFingerprint == "" ||
		i.ModelID == "" || i.ConfigFingerprint == "" {
		return false
	}
	return i.RequestClass == RequestClassText || i.RequestClass == RequestClassMultimodal
}

// Observation is one privacy-safe sampling fact. PredictedInputTokens is
// Anselm's stable local ruler and is deliberately the only unit used to derive
// future soft budgets; ActualInputTokens is retained for diagnostics only,
// because provider tokenizers need not agree with our ruler.
//
// Observation 是一次隐私安全的 sampling 事实。PredictedInputTokens 是 Anselm 自己稳定的
// 尺子，未来软预算只使用这一单位；ActualInputTokens 仅作诊断，因为上游 tokenizer 未必一致。
type Observation struct {
	Identity             Identity
	Kind                 string
	PredictedInputTokens int
	ActualInputTokens    int
	RequestBytes         int
	Recovery             bool // this successful attempt followed a context-overflow retry
	At                   time.Time
}

func (o Observation) Valid() bool {
	if !o.Identity.Valid() || (o.Kind != ObservationSuccess && o.Kind != ObservationContextOverflow) {
		return false
	}
	return o.PredictedInputTokens > 0 && o.ActualInputTokens >= 0 && o.RequestBytes >= 0
}

// Profile is the aggregate evidence for one route identity. LowestOverflowPredicted
// is an upper bound; HighestSuccessPredicted is a lower bound. A non-zero
// RecoveredOverflows means an overflow was followed by a successful retry, so
// it is safe to use the conservative soft budget derived by the app layer.
type Profile struct {
	ID                    string `db:"id,pk" json:"id"`
	WorkspaceID           string `db:"workspace_id,ws" json:"-"`
	IdentityKey           string `db:"identity_key" json:"-"`
	Provider              string `db:"provider" json:"provider"`
	APIKeyID              string `db:"api_key_id" json:"apiKeyId"`
	ModelID               string `db:"model_id" json:"modelId"`
	RequestClass          string `db:"request_class" json:"requestClass"`
	EndpointFingerprint   string `db:"endpoint_fingerprint" json:"-"`
	CredentialFingerprint string `db:"credential_fingerprint" json:"-"`
	ConfigFingerprint     string `db:"config_fingerprint" json:"-"`

	HighestSuccessPredicted int       `db:"highest_success_predicted" json:"highestSuccessPredicted"`
	HighestSuccessActual    int       `db:"highest_success_actual" json:"highestSuccessActual"`
	LowestOverflowPredicted int       `db:"lowest_overflow_predicted" json:"lowestOverflowPredicted"`
	Successes               int       `db:"successes" json:"successes"`
	Overflows               int       `db:"overflows" json:"overflows"`
	RecoveredOverflows      int       `db:"recovered_overflows" json:"recoveredOverflows"`
	ExpiresAt               time.Time `db:"expires_at" json:"expiresAt"`
	CreatedAt               time.Time `db:"created_at,created" json:"createdAt"`
	UpdatedAt               time.Time `db:"updated_at,updated" json:"updatedAt"`
}

// NewProfile constructs an empty evidence aggregate for identity.
func NewProfile(id string, identity Identity, now time.Time) *Profile {
	return &Profile{
		ID: id, IdentityKey: identity.Key(), Provider: identity.Provider, APIKeyID: identity.APIKeyID,
		ModelID: identity.ModelID, RequestClass: identity.RequestClass,
		EndpointFingerprint: identity.EndpointFingerprint, CredentialFingerprint: identity.CredentialFingerprint,
		ConfigFingerprint: identity.ConfigFingerprint, CreatedAt: now, UpdatedAt: now,
	}
}

// Apply folds one observation into the aggregate. It is intentionally monotonic
// within one identity: later, lower overflows tighten the upper bound; a changed
// route gets a different identity instead of mutating this history.
func (p *Profile) Apply(o Observation, expiresAt time.Time) {
	if o.Kind == ObservationContextOverflow {
		p.Overflows++
		if p.LowestOverflowPredicted == 0 || o.PredictedInputTokens < p.LowestOverflowPredicted {
			p.LowestOverflowPredicted = o.PredictedInputTokens
		}
	} else {
		p.Successes++
		if o.PredictedInputTokens > p.HighestSuccessPredicted {
			p.HighestSuccessPredicted = o.PredictedInputTokens
		}
		if o.ActualInputTokens > p.HighestSuccessActual {
			p.HighestSuccessActual = o.ActualInputTokens
		}
		if o.Recovery {
			p.RecoveredOverflows++
		}
	}
	p.ExpiresAt = expiresAt
	p.UpdatedAt = o.At
}

// Repository persists one aggregate per workspace and route identity.
type Repository interface {
	Find(ctx context.Context, identityKey string) (*Profile, bool, error)
	Save(ctx context.Context, profile *Profile) error
}
