//go:build integration

package llm

import (
	"context"
	"net/http"
	"os"
	"testing"

	deviceproofinfra "github.com/sunweilin/anselm/backend/internal/infra/deviceproof"
)

type integrationEncryptor struct{}

func (integrationEncryptor) Encrypt(_ context.Context, plaintext []byte) ([]byte, error) {
	return append([]byte(nil), plaintext...), nil
}

func (integrationEncryptor) Decrypt(_ context.Context, ciphertext []byte) ([]byte, error) {
	return append([]byte(nil), ciphertext...), nil
}

// TestGatewayDeviceProofContract exercises the real desktop signer/transport
// against a separately running gateway. Set ANSELM_GATEWAY_INTEGRATION_URL to
// its /v1 base; the test stays opt-in because the two repositories are released
// independently.
func TestGatewayDeviceProofContract(t *testing.T) {
	baseURL := os.Getenv("ANSELM_GATEWAY_INTEGRATION_URL")
	if baseURL == "" {
		t.Skip("ANSELM_GATEWAY_INTEGRATION_URL is not set")
	}
	signer, err := deviceproofinfra.LoadOrCreate(context.Background(), "", integrationEncryptor{})
	if err != nil {
		t.Fatal(err)
	}
	client := NewHTTPClient()
	client.Transport = deviceproofinfra.NewTransport(client.Transport, signer)

	installed, err := NewInstallClient(client, signer.PublicKey()).Install(
		context.Background(), baseURL, "integration-fingerprint", "anselm-integration-test",
	)
	if err != nil {
		t.Fatal(err)
	}
	if installed.InstallID == "" || installed.MonthlyQuota <= 0 {
		t.Fatalf("install result = %+v", installed)
	}
	quota, err := NewQuotaClient(client).Fetch(context.Background(), baseURL, installed.InstallID)
	if err != nil {
		t.Fatal(err)
	}
	if quota.Limit != int64(installed.MonthlyQuota) || !quota.Available {
		t.Fatalf("quota = %+v; install = %+v", quota, installed)
	}

	// A request carrying only the public id and no proof must remain unusable.
	req, err := http.NewRequest(http.MethodGet, baseURL+"/quota", nil)
	if err != nil {
		t.Fatal(err)
	}
	req.Header.Set(deviceproofinfra.HeaderInstallID, installed.InstallID)
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatal(err)
	}
	_ = resp.Body.Close()
	if resp.StatusCode != http.StatusUnauthorized {
		t.Fatalf("unsigned quota status = %d, want 401", resp.StatusCode)
	}
}
