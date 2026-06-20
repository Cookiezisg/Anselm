package llm

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
)

// QuotaClient reads the free-tier gateway's monthly quota for an install token. GET /quota is the
// gateway's second non-OpenAI-shaped endpoint (after /install), bearer-authenticated by the same
// gwk_ install token that authenticates chat. Stateless — the caller resolves the token from the
// managed api_key row and renders the result.
//
// QuotaClient 读免费档网关某 install token 的本月配额。GET /quota 是网关第二个非 OpenAI 形状端点（继
// /install 后），由认证 chat 的同一个 gwk_ install token 经 Bearer 鉴权。无状态——caller 从受管
// api_key 行解出 token 并渲染结果。
type QuotaClient struct {
	http *http.Client
}

// NewQuotaClient builds a QuotaClient reusing the shared transport (a short unary call, like install).
//
// NewQuotaClient 构造 QuotaClient，复用共享 transport（短的一元调用，同 install）。
func NewQuotaClient() *QuotaClient {
	return &QuotaClient{http: newSharedHTTPClient()}
}

// QuotaResult is the gateway's GET /quota response. remaining = limit-used (clamped ≥0); available
// also folds in the gateway's global daily budget, so it can be false even with remaining > 0.
//
// QuotaResult 是网关 GET /quota 的响应。remaining = limit-used（钳 ≥0）；available 还折入网关全局日预算，
// 故 remaining > 0 时仍可能为 false。
type QuotaResult struct {
	Limit     int64  `json:"limit"`
	Used      int64  `json:"used"`
	Remaining int64  `json:"remaining"`
	ResetAt   string `json:"resetAt"`
	Available bool   `json:"available"`
}

// Fetch reads the quota at baseURL+"/quota" using the gwk_ token as the Bearer credential. A non-200
// is mapped through classifyHTTPError (401/403→ErrAuthFailed, 429→ErrRateLimited, …), so a
// stale/banned token surfaces honestly rather than as a zeroed quota.
//
// Fetch 用 gwk_ token 作 Bearer 凭证读 baseURL+"/quota" 的配额。非 200 经 classifyHTTPError 映射
// （401/403→ErrAuthFailed、429→ErrRateLimited…），故失效/封禁 token 诚实失败、而非误报清零配额。
func (c *QuotaClient) Fetch(ctx context.Context, baseURL, token string) (QuotaResult, error) {
	httpReq, err := http.NewRequestWithContext(ctx, http.MethodGet, baseURL+"/quota", nil)
	if err != nil {
		return QuotaResult{}, fmt.Errorf("llm.anselm: build quota request: %w", err)
	}
	httpReq.Header.Set("Authorization", "Bearer "+token)

	resp, err := c.http.Do(httpReq)
	if err != nil {
		return QuotaResult{}, fmt.Errorf("llm.anselm: quota: %w", err)
	}
	defer resp.Body.Close()

	raw, _ := io.ReadAll(io.LimitReader(resp.Body, 64<<10))
	if resp.StatusCode != http.StatusOK {
		return QuotaResult{}, fmt.Errorf("llm.anselm: quota: %w", classifyHTTPError(resp.StatusCode, raw))
	}
	var out QuotaResult
	if err := json.Unmarshal(raw, &out); err != nil {
		return QuotaResult{}, fmt.Errorf("llm.anselm: decode quota response: %w", err)
	}
	return out, nil
}
