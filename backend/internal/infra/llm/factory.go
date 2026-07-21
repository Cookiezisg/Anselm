package llm

import (
	"fmt"
	"net/http"
)

// Config selects and configures a Client.
//
// Config 用来选择并配置 Client。
type Config struct {
	Provider  string
	APIFormat string
	ModelID   string
	Key       string
	BaseURL   string
}

// Factory builds Clients per provider; the HTTP client is shared across requests.
//
// Factory 按 provider 构造 Client；HTTP client 跨请求复用。
type Factory struct {
	http *http.Client
	mock *MockClient
}

// NewFactory constructs a Factory ready for use.
//
// NewFactory 构造一个可直接使用的 Factory。
func NewFactory() *Factory {
	return NewFactoryWithHTTP(newSharedHTTPClient())
}

// NewFactoryWithHTTP injects the shared client used by provider transports.
func NewFactoryWithHTTP(httpClient *http.Client) *Factory {
	if httpClient == nil {
		httpClient = newSharedHTTPClient()
	}
	return &Factory{
		http: httpClient,
		mock: NewMockClient(),
	}
}

// Mock returns the singleton MockClient (T6 fake_llm + dev script endpoint).
//
// Mock 返回 MockClient 单例（T6 fake_llm + dev script 端点）。
func (f *Factory) Mock() *MockClient { return f.mock }

// Build returns the Client and resolved BaseURL for the given Config; provider "mock"
// short-circuits to the MockClient.
//
// Build 返回 Config 对应的 Client 与解析后的 BaseURL；provider "mock" 短路到 MockClient。
func (f *Factory) Build(cfg Config) (Client, string, error) {
	baseURL, err := resolveBaseURL(cfg)
	if err != nil {
		return nil, "", err
	}
	if cfg.Provider == "mock" {
		return f.mock, baseURL, nil
	}
	return &providerClient{provider: lookupProvider(cfg), http: f.http}, baseURL, nil
}

func resolveBaseURL(cfg Config) (string, error) {
	if cfg.BaseURL != "" {
		return cfg.BaseURL, nil
	}
	url := lookupProvider(cfg).DefaultBaseURL()
	if url == "" {
		return "", fmt.Errorf("llm.factory: %s provider requires base_url: %w", cfg.Provider, ErrBadRequest)
	}
	return url, nil
}
