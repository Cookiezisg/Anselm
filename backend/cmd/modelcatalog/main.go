// Command modelcatalog refreshes the vendored direct-connection capability catalog: it downloads
// https://models.dev/api.json, trims it to our six followed providers with the shared
// llm.TrimUpstreamCatalog projection, and rewrites internal/infra/llm/modelcatalog.json in place.
// Run via the root `make update-model-catalog`; the output is source-equivalent configuration
// (S22) and is committed.
//
// modelcatalog 刷新 vendored 直连能力目录:下载 models.dev api.json,用共享的
// llm.TrimUpstreamCatalog 投影裁到六家,原地重写 internal/infra/llm/modelcatalog.json。
// 经根 `make update-model-catalog` 运行;产物是源等价配置(S22),入库。
package main

import (
	"fmt"
	"io"
	"net/http"
	"os"
	"time"

	llminfra "github.com/sunweilin/anselm/backend/internal/infra/llm"
)

const (
	upstreamURL = "https://models.dev/api.json"
	outPath     = "internal/infra/llm/modelcatalog.json"
)

func main() {
	if err := run(); err != nil {
		fmt.Fprintln(os.Stderr, "modelcatalog:", err)
		os.Exit(1)
	}
}

func run() error {
	client := &http.Client{Timeout: 120 * time.Second}
	resp, err := client.Get(upstreamURL)
	if err != nil {
		return fmt.Errorf("fetch %s: %w", upstreamURL, err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("fetch %s: HTTP %d", upstreamURL, resp.StatusCode)
	}
	raw, err := io.ReadAll(io.LimitReader(resp.Body, 64<<20))
	if err != nil {
		return fmt.Errorf("read body: %w", err)
	}
	cat, err := llminfra.TrimUpstreamCatalog(raw)
	if err != nil {
		return err
	}
	data, err := llminfra.MarshalCatalog(cat)
	if err != nil {
		return err
	}
	if err := os.WriteFile(outPath, data, 0o644); err != nil {
		return fmt.Errorf("write %s: %w (run from backend/)", outPath, err)
	}
	var count int
	for _, p := range cat.Providers {
		count += len(p.Models)
	}
	fmt.Printf("modelcatalog: wrote %s — %d providers, %d models\n", outPath, len(cat.Providers), count)
	return nil
}
