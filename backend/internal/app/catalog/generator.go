// generator.go — LLM-driven Summary builder. Implements the Generator
// interface that Service.Refresh consults when source items change.
// Per catalog.md §7:
//
//   - 3-attempt retry: each attempt builds a prompt (with augmented
//     "previous attempt missed: [...]" hint on retries), calls the LLM,
//     parses JSON, validates coverage (every input item must appear in
//     the parsed Coverage map). On failure: increment attempt + retry.
//   - Output cap: ~10 KB defensive char limit (equivalent to ~2000
//     tokens). Past that → treat as malformed and retry.
//   - V1 simplification: uses llmclient.Resolve for the chat-scenario
//     bundle. Multi-key rotation (catalog.md §7 "Key 轮训") deferred to
//     V2 — typical solo-dev environment has 1 key, so the rotation
//     collapses to that single key anyway.
//
// On total failure (3 attempts exhausted OR no LLM key available),
// returns one of {ErrCoverageIncomplete, ErrGenerationFailed} so
// Service.Refresh switches to mechanicalFallback. The catalog still
// updates (mechanical Summary populated; lastFP advances) — user
// activity (description edit) drives the next LLM retry naturally.
//
// generator.go ——LLM-driven Summary 构建。实现 Service.Refresh 在 source
// items 变时查的 Generator 接口。catalog.md §7：3 次重试（重试时 prompt
// 加 "上次漏了 X" 提示）；JSON 解析 + coverage 校验（每个输入 item 必出
// 现在解析后 Coverage map）；输出字符上限 ~10 KB（~2000 token 等价）。
//
// V1 简化：用 llmclient.Resolve 取 chat 场景 bundle。多 key 轮训
// （§7 "Key 轮训"）推迟 V2——单人开发典型 1 个 key，轮训等价单 key。
//
// 全失败时（3 次 attempt 用尽 / 无 LLM key）返
// {ErrCoverageIncomplete, ErrGenerationFailed} 之一让 Service.Refresh
// 切 mechanicalFallback。catalog 仍更新（mechanical Summary + lastFP 前
// 推）——用户活动（编 description）自然驱动下次 LLM 重试。
package catalog

import (
	"context"
	"encoding/json"
	"fmt"
	"sort"
	"strings"

	"go.uber.org/zap"

	apikeydomain "github.com/sunweilin/forgify/backend/internal/domain/apikey"
	catalogdomain "github.com/sunweilin/forgify/backend/internal/domain/catalog"
	modeldomain "github.com/sunweilin/forgify/backend/internal/domain/model"
	llminfra "github.com/sunweilin/forgify/backend/internal/infra/llm"
	llmclientpkg "github.com/sunweilin/forgify/backend/internal/pkg/llmclient"
	llmparsepkg "github.com/sunweilin/forgify/backend/internal/pkg/llmparse"
)

const (
	// generatorMaxAttempts is the initial attempt + 2 retries per
	// catalog.md §7. Beyond that the LLM is treated as unable to
	// produce a valid catalog and the caller falls back to mechanical.
	//
	// generatorMaxAttempts：初次 + 2 次重试（catalog.md §7）。超过即视
	// LLM 无能力产合格 catalog，调用方退 mechanical。
	generatorMaxAttempts = 3

	// generatorOutputCharCap is the ~10 KB defensive cap. The LLM's
	// max_tokens=2000 (per catalog.md §7) yields ~8 KB at typical
	// English; 10 KB gives headroom. Past this we treat as malformed.
	//
	// generatorOutputCharCap：~10 KB 防御上限。LLM max_tokens=2000
	// （§7）典型英文 ~8 KB；10 KB 留余。超之视畸形。
	generatorOutputCharCap = 10 * 1024
)

// LLMGenerator is the production Generator. Constructed in main.go;
// plugged into Service via SetGenerator post-construction.
//
// LLMGenerator 是生产 Generator。main.go 构造；经 SetGenerator 后置注入。
type LLMGenerator struct {
	picker  modeldomain.ModelPicker
	keys    apikeydomain.KeyProvider
	factory *llminfra.Factory
	log     *zap.Logger
}

// NewLLMGenerator constructs an LLMGenerator. picker / keys / factory
// are the same triplet used by mcp.Search + skill.Search + forge.search
// — wired in main.go from existing services.
//
// NewLLMGenerator 构造 LLMGenerator。picker / keys / factory 三元组同
// mcp.Search + skill.Search + forge.search——main.go 接已有 service。
func NewLLMGenerator(picker modeldomain.ModelPicker, keys apikeydomain.KeyProvider, factory *llminfra.Factory, log *zap.Logger) *LLMGenerator {
	if log == nil {
		log = zap.NewNop()
	}
	return &LLMGenerator{
		picker:  picker,
		keys:    keys,
		factory: factory,
		log:     log.Named("catalog.generator"),
	}
}

// Generate runs the 3-attempt retry loop. Each attempt builds a fresh
// prompt (with "previous miss" augmentation on retries), calls the LLM,
// parses + validates coverage. First success wins. Total failure returns
// ErrCoverageIncomplete or ErrGenerationFailed.
//
// Generate 跑 3 次重试。每次新建 prompt（重试时加 "上次漏了" 提示），
// 调 LLM，解 + 校 coverage。首个成功胜。全失败返
// ErrCoverageIncomplete 或 ErrGenerationFailed。
func (g *LLMGenerator) Generate(ctx context.Context, items []catalogdomain.Item, gMap map[string]catalogdomain.Granularity) (*catalogdomain.Catalog, error) {
	if len(items) == 0 {
		return mechanicalFallback(items, gMap), nil
	}

	bundle, err := llmclientpkg.Resolve(ctx, g.picker, g.keys, g.factory)
	if err != nil {
		return nil, fmt.Errorf("%w: resolve LLM: %v", catalogdomain.ErrGenerationFailed, err)
	}

	wantCoverage := groupSourceIDs(items)
	var missingHint []string

	for attempt := 0; attempt < generatorMaxAttempts; attempt++ {
		prompt := buildPrompt(items, gMap, missingHint)

		raw, err := llminfra.Generate(ctx, bundle.Client, llminfra.Request{
			ModelID: bundle.ModelID,
			Key:     bundle.Key,
			BaseURL: bundle.BaseURL,
			Messages: []llminfra.LLMMessage{
				{Role: llminfra.RoleUser, Content: prompt},
			},
		})
		if err != nil {
			g.log.Warn("catalog generation LLM call failed",
				zap.Int("attempt", attempt), zap.Error(err))
			// Transport-level failures don't get auto-retried within
			// Generate (the same client/key would fail the same way).
			// Bubble up to Service.Refresh which falls back to mechanical.
			// 传输层失败不在 Generate 内自动重试（同 client/key 会同样失
			// 败）。冒泡到 Service.Refresh 切 mechanical。
			return nil, fmt.Errorf("%w: %v", catalogdomain.ErrGenerationFailed, err)
		}

		if len(raw) > generatorOutputCharCap {
			g.log.Warn("catalog generation output exceeds char cap; retrying",
				zap.Int("attempt", attempt), zap.Int("chars", len(raw)))
			continue
		}

		jsonStr, ok := llmparsepkg.ExtractJSON(raw)
		if !ok {
			g.log.Warn("catalog generation: no JSON in LLM response; retrying",
				zap.Int("attempt", attempt),
				zap.String("response_snippet", trimResp(raw, 200)))
			continue
		}

		var parsed struct {
			Summary  string              `json:"summary"`
			Coverage map[string][]string `json:"coverage"`
		}
		if err := json.Unmarshal([]byte(jsonStr), &parsed); err != nil {
			g.log.Warn("catalog generation: JSON parse failed; retrying",
				zap.Int("attempt", attempt), zap.Error(err))
			continue
		}

		if strings.TrimSpace(parsed.Summary) == "" {
			g.log.Warn("catalog generation: empty Summary; retrying",
				zap.Int("attempt", attempt))
			continue
		}

		missing := findMissing(wantCoverage, parsed.Coverage)
		if len(missing) > 0 {
			g.log.Warn("catalog generation: coverage incomplete; retrying",
				zap.Int("attempt", attempt),
				zap.Strings("missing", missing))
			missingHint = missing
			continue
		}

		return &catalogdomain.Catalog{
			Summary:     parsed.Summary,
			Coverage:    parsed.Coverage,
			GeneratedBy: "llm",
		}, nil
	}

	return nil, fmt.Errorf("%w: %d attempts exhausted", catalogdomain.ErrCoverageIncomplete, generatorMaxAttempts)
}

// ── prompt + parsing helpers ─────────────────────────────────────────

const generatorPromptTemplate = `You are generating a "Capability Catalog" summary that will be inserted into another LLM's system prompt.
The summary tells the other LLM what high-level capability categories are available, when to use each, and how to discover details.

CONSTRAINTS — ALL MANDATORY:
1. Coverage: every item below MUST be represented (directly named or grouped).
   You MUST output a "coverage" field listing every source ID you grouped/named.
2. Brevity: total summary <= 600 tokens. Prefer "5 file-processing tools" over listing 5 names.
3. Granularity rules:
   - source granularity=PerItem (forge, skill): grouping/merging allowed
   - source granularity=PerServer (mcp): one mention per server, do NOT merge
   - source granularity=PerCollection: one mention per collection
4. Detect overlap and write routing observations inline: If two items in different
   sources serve similar purposes (e.g., a forge that calls GitHub API + a github MCP server),
   add a "Notes on choosing" section to the summary telling the LLM which to prefer and why.
   Inferences should come from the item descriptions provided below.
5. End with: "If a task could fit multiple categories, you MAY call multiple search tools in parallel."

OUTPUT JSON only (no surrounding prose, no markdown fences):
{
  "summary": "...",
  "coverage": { "forge": [<all forge IDs>], "skill": [...], "mcp": [...] }
}

ITEMS:
%s
%s`

// buildPrompt assembles the LLM request. items rendered as a numbered
// list per source with id + name + description so the LLM has both a
// stable handle (id) for the coverage field and human-readable text
// for the summary. missingHint is empty on first attempt; populated on
// retry with the IDs the previous attempt dropped.
//
// buildPrompt 装 LLM 请求。items 按 source 编号 + id + name + description
// ——LLM 既有稳定 handle（id）填 coverage，又有人类可读文本写 summary。
// missingHint 首次为空；重试时填上次漏掉的 ID。
func buildPrompt(items []catalogdomain.Item, gMap map[string]catalogdomain.Granularity, missingHint []string) string {
	var itemsBlock strings.Builder
	bySource := groupBySource(items)
	sourceNames := make([]string, 0, len(bySource))
	for name := range bySource {
		sourceNames = append(sourceNames, name)
	}
	sort.Strings(sourceNames)
	for _, srcName := range sourceNames {
		gran := gMap[srcName]
		fmt.Fprintf(&itemsBlock, "\n[%s, granularity=%s]\n", srcName, gran.String())
		srcItems := bySource[srcName]
		sort.Slice(srcItems, func(i, j int) bool { return srcItems[i].Name < srcItems[j].Name })
		for _, it := range srcItems {
			fmt.Fprintf(&itemsBlock, "  - id=%q name=%q description=%q\n", it.ID, it.Name, it.Description)
		}
	}

	hint := ""
	if len(missingHint) > 0 {
		hint = fmt.Sprintf("\nIMPORTANT: previous attempt missed these IDs — you MUST include them in coverage this time: %s\n",
			strings.Join(missingHint, ", "))
	}

	return fmt.Sprintf(generatorPromptTemplate, itemsBlock.String(), hint)
}

// groupSourceIDs groups input items by source with the ID set per
// source. Used to validate the LLM's coverage map matches the input.
//
// groupSourceIDs 把输入 items 按 source 分 + 每 source ID 集合。校验
// LLM 的 coverage map 是否覆盖输入。
func groupSourceIDs(items []catalogdomain.Item) map[string]map[string]bool {
	out := map[string]map[string]bool{}
	for _, it := range items {
		if out[it.Source] == nil {
			out[it.Source] = map[string]bool{}
		}
		out[it.Source][it.ID] = true
	}
	return out
}

// findMissing returns the list of source/ID pairs from want that
// aren't in got. Each missing entry rendered as "source/id" so the
// retry hint can be a flat list. Empty result = full coverage.
//
// findMissing 返 want 里在 got 没出现的 source/ID 对。每条渲染为
// "source/id" 让重试 hint 是平列表。空结果=全覆盖。
func findMissing(want map[string]map[string]bool, got map[string][]string) []string {
	gotSet := map[string]map[string]bool{}
	for src, ids := range got {
		gotSet[src] = map[string]bool{}
		for _, id := range ids {
			gotSet[src][id] = true
		}
	}
	missing := []string{}
	for src, wantIDs := range want {
		for id := range wantIDs {
			if !gotSet[src][id] {
				missing = append(missing, src+"/"+id)
			}
		}
	}
	sort.Strings(missing)
	return missing
}

func trimResp(s string, n int) string {
	if len(s) <= n {
		return s
	}
	return s[:n] + "..."
}
