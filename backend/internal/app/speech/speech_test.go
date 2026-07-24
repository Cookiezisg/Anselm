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
