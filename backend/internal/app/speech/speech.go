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
