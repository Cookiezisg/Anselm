// Package speech exposes the managed Anselm realtime speech input capability.
// It deliberately does not implement model audio understanding: it only resolves
// the built-in gateway install and lets the HTTP layer proxy PCM-to-text events.
package speech

import (
	"context"
	"fmt"
	"strings"

	apikeydomain "github.com/sunweilin/anselm/backend/internal/domain/apikey"
	errorspkg "github.com/sunweilin/anselm/backend/internal/pkg/errors"
)

const providerName = "anselm"

var ErrUnavailable = errorspkg.New(errorspkg.KindUnavailable, "SPEECH_UNAVAILABLE", "speech transcription is unavailable")

// The gateway refuses a speech session for reasons the user can ACT on, and each needs a different
// next step. Collapsing them all into ErrUnavailable told a user whose monthly allowance had run out
// that "speech transcription is unavailable" — a sentence that invites them to retry forever.
//
// 网关拒绝语音会话的理由里,有些是用户**能动手处理**的,且各自的下一步不同。把它们全压成 ErrUnavailable,
// 会对一个额度已用完的用户说「语音转写不可用」——一句邀请他无限重试的话。
var (
	ErrQuotaExhausted = errorspkg.New(errorspkg.KindRateLimited, "SPEECH_QUOTA_EXHAUSTED", "this month's speech allowance is used up")
	ErrRateLimited    = errorspkg.New(errorspkg.KindRateLimited, "SPEECH_RATE_LIMITED", "too many speech requests just now; try again shortly")
	ErrAccountBanned  = errorspkg.New(errorspkg.KindForbidden, "SPEECH_ACCOUNT_BANNED", "this installation is not permitted to use speech")
)

// classifyHandshake maps the gateway's structured refusal, seen BEFORE the WebSocket upgrade, to a
// speech error the UI can act on. Only the closed set is translated; anything else keeps
// ErrUnavailable, so a new gateway code never acquires an invented meaning here.
//
// classifyHandshake 把网关在 WebSocket 升级**之前**给出的结构化拒绝,映射成 UI 能据以行动的语音错误。
// 只翻译闭集;其余保持 ErrUnavailable,故网关新增的码绝不会在此获得一个被臆造的含义。
func classifyHandshake(code string) error {
	switch code {
	case "QUOTA_EXHAUSTED", "BUDGET_EXHAUSTED", "INSTALL_CAP_REACHED":
		return ErrQuotaExhausted
	case "RATE_LIMITED", "UPSTREAM_BUSY", "INSTALL_RATE_LIMITED":
		return ErrRateLimited
	case "ACCOUNT_BANNED":
		return ErrAccountBanned
	default:
		return nil
	}
}

// ClassifyHandshakeCode exposes the mapping to the transport layer, which is where the handshake
// response body is available. 暴露给传输层——握手响应体在那里才拿得到。
func ClassifyHandshakeCode(code string) error { return classifyHandshake(code) }

type Keys interface {
	List(ctx context.Context, filter apikeydomain.ListFilter) ([]*apikeydomain.APIKey, string, error)
	ResolveCredentialsByID(ctx context.Context, apiKeyID string) (apikeydomain.Credentials, error)
}

type Service struct {
	keys Keys
}

type Gateway struct {
	BaseURL   string
	InstallID string
}

func New(keys Keys) *Service {
	return &Service{keys: keys}
}

func (s *Service) ManagedGateway(ctx context.Context) (Gateway, error) {
	if s == nil || s.keys == nil {
		return Gateway{}, ErrUnavailable
	}
	rows, _, err := s.keys.List(ctx, apikeydomain.ListFilter{Provider: providerName, Limit: 1})
	if err != nil {
		return Gateway{}, fmt.Errorf("speech.ManagedGateway: list managed key: %w", err)
	}
	if len(rows) == 0 || rows[0] == nil || strings.TrimSpace(rows[0].ID) == "" {
		return Gateway{}, ErrUnavailable
	}
	creds, err := s.keys.ResolveCredentialsByID(ctx, rows[0].ID)
	if err != nil {
		return Gateway{}, fmt.Errorf("speech.ManagedGateway: resolve managed key: %w", err)
	}
	if strings.TrimSpace(creds.Provider) != providerName || strings.TrimSpace(creds.Key) == "" || strings.TrimSpace(creds.BaseURL) == "" {
		return Gateway{}, ErrUnavailable
	}
	return Gateway{BaseURL: strings.TrimRight(strings.TrimSpace(creds.BaseURL), "/"), InstallID: strings.TrimSpace(creds.Key)}, nil
}
