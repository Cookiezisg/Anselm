package speech

import (
	"context"
	"testing"

	apikeydomain "github.com/sunweilin/anselm/backend/internal/domain/apikey"
)

type fakeKeys struct {
	rows  []*apikeydomain.APIKey
	creds apikeydomain.Credentials
}

func (f fakeKeys) List(context.Context, apikeydomain.ListFilter) ([]*apikeydomain.APIKey, string, error) {
	return f.rows, "", nil
}

func (f fakeKeys) ResolveCredentialsByID(context.Context, string) (apikeydomain.Credentials, error) {
	return f.creds, nil
}

func TestManagedGatewayResolvesManagedAnselmCredential(t *testing.T) {
	svc := New(fakeKeys{
		rows: []*apikeydomain.APIKey{{ID: "aki_1", Provider: "anselm"}},
		creds: apikeydomain.Credentials{
			Provider: "anselm",
			Key:      "ins_1",
			BaseURL:  "https://api.anselm.website/v1/",
		},
	})
	got, err := svc.ManagedGateway(context.Background())
	if err != nil {
		t.Fatal(err)
	}
	if got.InstallID != "ins_1" || got.BaseURL != "https://api.anselm.website/v1" {
		t.Fatalf("gateway = %+v", got)
	}
}

func TestManagedGatewayUnavailableWithoutManagedKey(t *testing.T) {
	_, err := New(fakeKeys{}).ManagedGateway(context.Background())
	if err == nil {
		t.Fatal("expected unavailable error")
	}
}

// The gateway refuses a speech session for several reasons, and the ones a user can act on need
// different next steps. Before this mapping, an exhausted monthly allowance and a momentary rate
// limit both surfaced as "speech transcription is unavailable" — a sentence that invites retrying
// forever when the truth is "nothing will work until the month rolls over".
//
// 网关拒绝语音会话有多种理由,其中用户能动手处理的那些需要不同的下一步。有这层映射之前,「本月额度用完」与
// 「一时限流」都显示为「语音转写不可用」——一句在真相是「跨月之前怎么试都没用」时邀请无限重试的话。
func TestClassifyHandshakeCodeSeparatesActionableRefusals(t *testing.T) {
	cases := map[string]error{
		"QUOTA_EXHAUSTED":      ErrQuotaExhausted,
		"BUDGET_EXHAUSTED":     ErrQuotaExhausted,
		"INSTALL_CAP_REACHED":  ErrQuotaExhausted,
		"RATE_LIMITED":         ErrRateLimited,
		"UPSTREAM_BUSY":        ErrRateLimited,
		"INSTALL_RATE_LIMITED": ErrRateLimited,
		"ACCOUNT_BANNED":       ErrAccountBanned,
	}
	for code, want := range cases {
		if got := ClassifyHandshakeCode(code); got != want {
			t.Errorf("ClassifyHandshakeCode(%q) = %v, want %v", code, got, want)
		}
	}
	// Anything outside the closed set must stay unclassified so the caller keeps ErrUnavailable — a
	// new gateway code must never acquire an invented meaning here.
	// 闭集之外一律不分类,调用方保持 ErrUnavailable——网关新增的码绝不能在此获得被臆造的含义。
	for _, unknown := range []string{"", "SOMETHING_NEW", "DEVICE_PROOF_NONCE_INVALID", "SPEECH_UNAVAILABLE"} {
		if got := ClassifyHandshakeCode(unknown); got != nil {
			t.Errorf("ClassifyHandshakeCode(%q) = %v, want nil (unclassified)", unknown, got)
		}
	}
}
