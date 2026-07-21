package freetier

import (
	"context"
	"errors"
	"testing"

	"go.uber.org/zap"

	apikeydomain "github.com/sunweilin/anselm/backend/internal/domain/apikey"
	llminfra "github.com/sunweilin/anselm/backend/internal/infra/llm"
)

type fakeQuotaKeys struct {
	rows         []*apikeydomain.APIKey
	creds        apikeydomain.Credentials
	resolveErr   error
	gotResolveID string
}

func (f *fakeQuotaKeys) List(_ context.Context, filter apikeydomain.ListFilter) ([]*apikeydomain.APIKey, string, error) {
	var out []*apikeydomain.APIKey
	for _, r := range f.rows {
		if filter.Provider == "" || r.Provider == filter.Provider {
			out = append(out, r)
		}
	}
	return out, "", nil
}

func (f *fakeQuotaKeys) ResolveCredentialsByID(_ context.Context, id string) (apikeydomain.Credentials, error) {
	f.gotResolveID = id
	if f.resolveErr != nil {
		return apikeydomain.Credentials{}, f.resolveErr
	}
	return f.creds, nil
}

type fakeFetcher struct {
	gotBase      string
	gotInstallID string
	res          llminfra.QuotaResult
	err          error
}

func (f *fakeFetcher) Fetch(_ context.Context, baseURL, installID string) (llminfra.QuotaResult, error) {
	f.gotBase, f.gotInstallID = baseURL, installID
	if f.err != nil {
		return llminfra.QuotaResult{}, f.err
	}
	return f.res, nil
}

func TestQuotaRead_NotProvisioned(t *testing.T) {
	// No managed anselm row → ErrNotProvisioned, so the settings gauge hides rather than zeroes.
	if _, err := NewQuotaReader(&fakeQuotaKeys{}, &fakeFetcher{}, zap.NewNop()).Read(context.Background()); !errors.Is(err, ErrNotProvisioned) {
		t.Fatalf("err = %v, want ErrNotProvisioned", err)
	}
}

func TestQuotaRead_ResolvesKeyAndProxies(t *testing.T) {
	// The managed row's id drives credential resolution; its public install id + base reach the
	// fetcher verbatim, and the gateway result maps field-for-field into Quota.
	keys := &fakeQuotaKeys{
		rows:  []*apikeydomain.APIKey{{ID: "aki_anselm", Provider: providerName}},
		creds: apikeydomain.Credentials{Provider: providerName, Key: "ins_test", BaseURL: "https://gw/v1"},
	}
	fetch := &fakeFetcher{res: llminfra.QuotaResult{Limit: 5000, Used: 1200, Remaining: 3800, ResetAt: "2026-07-01T00:00:00Z", Available: true}}
	q, err := NewQuotaReader(keys, fetch, zap.NewNop()).Read(context.Background())
	if err != nil {
		t.Fatal(err)
	}
	if keys.gotResolveID != "aki_anselm" {
		t.Errorf("resolve id = %q, want aki_anselm", keys.gotResolveID)
	}
	if fetch.gotBase != "https://gw/v1" || fetch.gotInstallID != "ins_test" {
		t.Errorf("fetch got (%q,%q), want (https://gw/v1, ins_test)", fetch.gotBase, fetch.gotInstallID)
	}
	if q.Limit != 5000 || q.Used != 1200 || q.Remaining != 3800 || q.ResetAt != "2026-07-01T00:00:00Z" || !q.Available {
		t.Errorf("quota = %+v, mismatch", q)
	}
}

func TestQuotaRead_GatewayErrorPropagates(t *testing.T) {
	// A gateway auth failure (stale/banned install) propagates its wire code verbatim — the reader
	// never swallows it into a zeroed quota.
	keys := &fakeQuotaKeys{
		rows:  []*apikeydomain.APIKey{{ID: "aki_anselm", Provider: providerName}},
		creds: apikeydomain.Credentials{Key: "ins_stale", BaseURL: "https://gw/v1"},
	}
	fetch := &fakeFetcher{err: llminfra.ErrAuthFailed}
	if _, err := NewQuotaReader(keys, fetch, zap.NewNop()).Read(context.Background()); !errors.Is(err, llminfra.ErrAuthFailed) {
		t.Fatalf("err = %v, want ErrAuthFailed", err)
	}
}
