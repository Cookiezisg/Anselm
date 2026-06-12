package bootstrap

import (
	"context"
	"encoding/json"
	"fmt"
	"strings"

	apikeydomain "github.com/sunweilin/forgify/backend/internal/domain/apikey"
	modeldomain "github.com/sunweilin/forgify/backend/internal/domain/model"
	llminfra "github.com/sunweilin/forgify/backend/internal/infra/llm"
)

// llmSifter backs the search_blocks precision chain (§7.4) with the utility
// model — the same resolve → credentials → build → generate chain WebFetch's
// summariser uses. One short completion, strict numbers-only output; any
// failure makes the chain fall back to index ranking.
//
// llmSifter 用 utility 模型支撑 search_blocks 精度链（§7.4）——与 WebFetch 摘要器
// 同一条 resolve → credentials → build → generate 链。一次短补全、严格只回编号；
// 任何失败让链回退索引排序。
type llmSifter struct {
	picker  modeldomain.ModelPicker
	keys    apikeydomain.KeyProvider
	factory *llminfra.Factory
}

func (f *llmSifter) Sift(ctx context.Context, query string, items []string, topN int) ([]int, error) {
	ref, err := modeldomain.Resolve(ctx, modeldomain.ScenarioUtility, nil, f.picker)
	if err != nil {
		return nil, err
	}
	creds, err := f.keys.ResolveCredentialsByID(ctx, ref.APIKeyID)
	if err != nil {
		return nil, err
	}
	client, modelID, err := f.factory.Build(llminfra.Config{
		Provider:  creds.Provider,
		APIFormat: creds.APIFormat,
		ModelID:   ref.ModelID,
		Key:       creds.Key,
		BaseURL:   creds.BaseURL,
	})
	if err != nil {
		return nil, err
	}
	var sb strings.Builder
	fmt.Fprintf(&sb, "You select workflow building blocks. The user needs: %q\n\nCandidate blocks:\n", query)
	for i, item := range items {
		fmt.Fprintf(&sb, "%d) %s\n", i+1, item)
	}
	fmt.Fprintf(&sb, "\nReturn ONLY a JSON array of the numbers of the best-matching blocks, best first, at most %d, e.g. [3,1]. No other text. Return [] if nothing fits.", topN)

	out, err := llminfra.Generate(ctx, client, llminfra.Request{
		ModelID:  modelID,
		Key:      creds.Key,
		BaseURL:  creds.BaseURL,
		Options:  ref.Options,
		Messages: []llminfra.LLMMessage{{Role: llminfra.RoleUser, Content: sb.String()}},
	})
	if err != nil {
		return nil, err
	}
	return parseSiftPicks(out)
}

// parseSiftPicks extracts the first JSON int array from the reply (models love
// wrapping answers) and converts 1-based numbers to 0-based indexes.
//
// parseSiftPicks 从回复里取首个 JSON 整数数组（模型爱包话），并把 1 基编号转 0 基下标。
func parseSiftPicks(out string) ([]int, error) {
	start := strings.Index(out, "[")
	end := strings.LastIndex(out, "]")
	if start < 0 || end <= start {
		return nil, fmt.Errorf("sift: no JSON array in %q", out)
	}
	var nums []int
	if err := json.Unmarshal([]byte(out[start:end+1]), &nums); err != nil {
		return nil, fmt.Errorf("sift: parse %q: %w", out[start:end+1], err)
	}
	picks := make([]int, 0, len(nums))
	for _, n := range nums {
		picks = append(picks, n-1)
	}
	return picks, nil
}
