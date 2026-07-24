package llm

import (
	"bytes"
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strconv"
	"strings"

	deviceproofinfra "github.com/sunweilin/anselm/backend/internal/infra/deviceproof"
)

// MediaClient is the managed-gateway resumable upload client. Its HTTP client
// must carry deviceproof.Transport; every create/chunk/complete request marks
// the install id so the transport signs the exact body.
//
// MediaClient 是受管网关的可恢复上传 client。它的 HTTP client 必须带 deviceproof.Transport；每个
// create/chunk/complete 请求都标注 install id，使 transport 对精确 body 签名。
type MediaClient struct{ http *http.Client }

func NewMediaClient(c *http.Client) *MediaClient { return &MediaClient{http: c} }

// Upload returns the absolute, short-lived provider fetch URL. It sends raw
// chunks rather than base64 so desktop→gateway bandwidth and memory stay bounded.
//
// Upload 返回绝对、短期有效的 provider fetch URL。它发送 raw chunk 而非 base64，使 desktop→gateway
// 带宽与内存保持有界。
func (c *MediaClient) Upload(ctx context.Context, baseURL, installID, mime string, data []byte) (string, error) {
	if c == nil || c.http == nil || len(data) == 0 {
		return "", fmt.Errorf("llm.media: invalid client or data")
	}
	sum := sha256.Sum256(data)
	var created struct {
		UploadID      string `json:"uploadId"`
		ChunkMaxBytes int    `json:"chunkMaxBytes"`
	}
	if err := c.json(ctx, http.MethodPost, strings.TrimRight(baseURL, "/")+"/media/uploads", installID, map[string]any{"sha256": hex.EncodeToString(sum[:]), "mimeType": mime, "totalBytes": len(data)}, &created); err != nil {
		return "", err
	}
	if created.UploadID == "" || created.ChunkMaxBytes <= 0 {
		return "", fmt.Errorf("llm.media: invalid create response")
	}
	for offset := 0; offset < len(data); {
		end := offset + created.ChunkMaxBytes
		if end > len(data) {
			end = len(data)
		}
		req, err := http.NewRequestWithContext(ctx, http.MethodPut, strings.TrimRight(baseURL, "/")+"/media/uploads/"+url.PathEscape(created.UploadID), bytes.NewReader(data[offset:end]))
		if err != nil {
			return "", err
		}
		req.Header.Set(deviceproofinfra.HeaderInstallID, installID)
		req.Header.Set("Upload-Offset", strconv.Itoa(offset))
		req.Header.Set("Content-Type", "application/offset+octet-stream")
		resp, err := c.http.Do(req)
		if err != nil {
			return "", err
		}
		raw, _ := io.ReadAll(io.LimitReader(resp.Body, 64<<10))
		_ = resp.Body.Close()
		if resp.StatusCode != http.StatusOK {
			return "", fmt.Errorf("llm.media append: %w", classifyHTTPError(resp.StatusCode, raw))
		}
		var appended struct {
			Offset int `json:"offset"`
		}
		if err := json.Unmarshal(raw, &appended); err != nil || appended.Offset != end {
			if err != nil {
				return "", fmt.Errorf("llm.media append: invalid response: %w", err)
			}
			return "", fmt.Errorf("llm.media append: acknowledged offset %d, want %d", appended.Offset, end)
		}
		offset = end
	}
	var completed struct {
		FetchPath string `json:"fetchPath"`
	}
	if err := c.json(ctx, http.MethodPost, strings.TrimRight(baseURL, "/")+"/media/uploads/"+url.PathEscape(created.UploadID)+"/complete", installID, nil, &completed); err != nil {
		return "", err
	}
	u, err := url.Parse(strings.TrimRight(baseURL, "/") + "/")
	if err != nil {
		return "", err
	}
	p, err := url.Parse(completed.FetchPath)
	if err != nil || p.IsAbs() {
		if err == nil {
			err = fmt.Errorf("llm.media: relative fetch path required")
		}
		return "", err
	}
	return u.ResolveReference(p).String(), nil
}

func (c *MediaClient) json(ctx context.Context, method, endpoint, installID string, in, out any) error {
	var body io.Reader
	if in != nil {
		b, e := json.Marshal(in)
		if e != nil {
			return e
		}
		body = bytes.NewReader(b)
	}
	req, e := http.NewRequestWithContext(ctx, method, endpoint, body)
	if e != nil {
		return e
	}
	req.Header.Set(deviceproofinfra.HeaderInstallID, installID)
	req.Header.Set("Content-Type", "application/json")
	resp, e := c.http.Do(req)
	if e != nil {
		return e
	}
	raw, _ := io.ReadAll(io.LimitReader(resp.Body, 64<<10))
	_ = resp.Body.Close()
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return fmt.Errorf("llm.media: %w", classifyHTTPError(resp.StatusCode, raw))
	}
	return json.Unmarshal(raw, out)
}
