package llm

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"

	deviceproofinfra "github.com/sunweilin/anselm/backend/internal/infra/deviceproof"
)

// InstallClient registers the device public key with the Anselm gateway. POST /install is the
// gateway's one non-OpenAI-shaped endpoint, so it lives beside the anselm provider rather than the
// streaming Provider plumbing. Stateless — the caller (the free-tier provisioner) persists the
// returned public install id in a managed api_key row.
//
// InstallClient 向 Anselm 网关登记设备公钥。POST /install 是网关唯一非 OpenAI 形状端点，故放
// 在 anselm provider 旁、不走流式 Provider 管道。无状态——caller（免费档 provisioner）将返回的
// 公开 install id 持久化为受管 api_key 行。
type InstallClient struct {
	http      *http.Client
	publicKey string
}

// NewInstallClient builds an InstallClient reusing the shared transport (its connect/TLS/header
// timeouts apply; the zero total-timeout is irrelevant here — install is a short unary call).
//
// NewInstallClient 构造 InstallClient，复用共享 transport（连接/TLS/头超时生效；零总超时在此无关——install
// 是短的一元调用）。
func NewInstallClient(httpClient *http.Client, publicKey string) *InstallClient {
	return &InstallClient{http: httpClient, publicKey: publicKey}
}

// InstallResult is the gateway's POST /install response.
//
// InstallResult 是网关 POST /install 的响应。
type InstallResult struct {
	InstallID    string `json:"installId"`
	MonthlyQuota int    `json:"monthlyQuota"`
	ResetAt      string `json:"resetAt"`
}

// Install registers this device at baseURL+"/install". fingerprintHash MUST be the hashed
// machine fingerprint, never the raw serial (privacy); client is a UA-style identifier. A non-200
// is mapped through classifyHTTPError, so a 402/429 surfaces as ErrQuotaExhausted/ErrRateLimited
// and the provisioner can degrade gracefully.
//
// Install 在 baseURL+"/install" 登记本设备。fingerprintHash 必须是哈希后的机器指纹、绝不传裸
// 序列号（隐私）；client 是 UA 风格标识。非 200 经 classifyHTTPError 映射，故 402/429 现为
// ErrQuotaExhausted/ErrRateLimited，provisioner 可优雅降级。
func (c *InstallClient) Install(ctx context.Context, baseURL, fingerprintHash, client string) (InstallResult, error) {
	reqBody, _ := json.Marshal(struct {
		Fingerprint string `json:"fingerprint"`
		Client      string `json:"client"`
	}{Fingerprint: fingerprintHash, Client: client})

	httpReq, err := http.NewRequestWithContext(ctx, http.MethodPost, baseURL+"/install", bytes.NewReader(reqBody))
	if err != nil {
		return InstallResult{}, fmt.Errorf("llm.anselm: build install request: %w", err)
	}
	httpReq.Header.Set("Content-Type", "application/json")
	httpReq.Header.Set(deviceproofinfra.HeaderPublicKey, c.publicKey)

	resp, err := c.http.Do(httpReq)
	if err != nil {
		return InstallResult{}, fmt.Errorf("llm.anselm: install: %w", err)
	}
	defer resp.Body.Close()

	raw, _ := io.ReadAll(io.LimitReader(resp.Body, 64<<10))
	if resp.StatusCode != http.StatusOK {
		return InstallResult{}, fmt.Errorf("llm.anselm: install: %w", classifyHTTPError(resp.StatusCode, raw))
	}
	var out InstallResult
	if err := json.Unmarshal(raw, &out); err != nil {
		return InstallResult{}, fmt.Errorf("llm.anselm: decode install response: %w", err)
	}
	if out.InstallID == "" {
		return InstallResult{}, fmt.Errorf("llm.anselm: install returned empty install id: %w", ErrProviderError)
	}
	return out, nil
}
