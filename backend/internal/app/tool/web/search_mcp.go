// search_mcp.go — MCPSearchRouter port + helper. The web package owns the
// port (no import of app/mcp); main.go constructs an adapter that closes
// over *mcpapp.Service and injects it into WebTools. This keeps web → mcp
// dependency direction inverted (mcp doesn't know web exists either).
//
// search_mcp.go ——MCPSearchRouter 端口 + helper。web 包持端口（不导入
// app/mcp）；main.go 构造闭包 *mcpapp.Service 的 adapter 注入到 WebTools。
// 让 web → mcp 依赖方向反转（mcp 也不知 web 存在）。
package web

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
)

// ErrMCPSearchUnavailable signals "no MCP search server connected" so the
// router can fall through to the next tier without logging it as a failure.
//
// ErrMCPSearchUnavailable 表示"无连接的 MCP 搜索 server"，让路由不当失败 log
// 直接落到下一层。
var ErrMCPSearchUnavailable = errors.New("mcp search server unavailable")

// MCPSearchRouter is the port WebSearch uses to delegate a query to a
// connected MCP search server (currently hardcoded server name
// "duckduckgo-search" matching the marketplace registry entry; future
// could expand to capability-based discovery).
//
// MCPSearchRouter 是 WebSearch 委派 query 给已连接 MCP 搜索 server 的端口
// （当前硬编码 server 名 "duckduckgo-search" 匹配 marketplace 条目；将来可
// 扩成 capability 发现）。
type MCPSearchRouter interface {
	// CallSearchTool sends `query` to the MCP server's `search` tool and
	// returns the raw tool result string. Returns ErrMCPSearchUnavailable
	// if no MCP search server is configured/connected — caller falls
	// through. Other errors mean "found server, but call failed" — caller
	// can also fall through but should log.
	//
	// CallSearchTool 把 query 发给 MCP server 的 search 工具，返原始 tool result。
	// 无配置/未连接返 ErrMCPSearchUnavailable，调用方落下层；其他错误意为
	// "找到 server 但调用失败"，调用方也落下层但应 log。
	CallSearchTool(ctx context.Context, query string, limit int) (string, error)
}

// runMCPSearch invokes the MCP router and parses the result string into
// searchResult slice. The raw string from MCP servers is JSON; we accept
// either {"results":[...]} or a top-level array — duckduckgo-mcp-server
// returns the former in current versions.
//
// runMCPSearch 调 MCP router 并把 result string 解析为 searchResult 切片。
// MCP server 返的 raw string 是 JSON；接受 {"results":[...]} 或顶层数组——
// duckduckgo-mcp-server 当前版本返前者。
func (t *WebSearch) runMCPSearch(ctx context.Context, query string, limit int) ([]searchResult, error) {
	if t.mcpRouter == nil {
		return nil, ErrMCPSearchUnavailable
	}
	raw, err := t.mcpRouter.CallSearchTool(ctx, query, limit)
	if err != nil {
		return nil, err
	}
	results, perr := parseMCPSearchResults(raw)
	if perr != nil {
		return nil, fmt.Errorf("mcp: parse: %w", perr)
	}
	return results, nil
}

// parseMCPSearchResults handles the two known shapes from MCP search
// servers. Field names are best-effort union: title / name, url / link,
// snippet / description / content. Returns nil error on shape mismatch
// when at least 1 result was extractable; only fully-malformed JSON errors.
//
// parseMCPSearchResults 处理 MCP 搜索 server 的两种已知 shape。字段名按
// best-effort 取并集：title / name、url / link、snippet / description / content。
// shape 不匹配但至少抠出 1 条返 nil error；完全 JSON 畸形才报错。
func parseMCPSearchResults(raw string) ([]searchResult, error) {
	type item struct {
		Title       string `json:"title"`
		Name        string `json:"name"`
		URL         string `json:"url"`
		Link        string `json:"link"`
		Snippet     string `json:"snippet"`
		Description string `json:"description"`
		Content     string `json:"content"`
	}

	pickOne := func(it item) searchResult {
		title := it.Title
		if title == "" {
			title = it.Name
		}
		u := it.URL
		if u == "" {
			u = it.Link
		}
		snip := it.Snippet
		if snip == "" {
			snip = it.Description
		}
		if snip == "" {
			snip = it.Content
		}
		return searchResult{Title: title, URL: u, Snippet: snip}
	}

	var keyed struct {
		Results []item `json:"results"`
	}
	if err := json.Unmarshal([]byte(raw), &keyed); err == nil && len(keyed.Results) > 0 {
		out := make([]searchResult, 0, len(keyed.Results))
		for _, it := range keyed.Results {
			out = append(out, pickOne(it))
		}
		return out, nil
	}

	var bare []item
	if err := json.Unmarshal([]byte(raw), &bare); err == nil && len(bare) > 0 {
		out := make([]searchResult, 0, len(bare))
		for _, it := range bare {
			out = append(out, pickOne(it))
		}
		return out, nil
	}

	// Last shot: maybe the MCP server returned plain text (some return
	// markdown summaries). Surface as one result with the raw blob in
	// snippet so the LLM can at least see it.
	// 最后兜底：有的 MCP server 返纯文本（markdown 摘要）。当成一条结果，
	// raw 放 snippet 让 LLM 至少能看到。
	if raw != "" {
		return []searchResult{{Title: "MCP search result", Snippet: raw}}, nil
	}
	return nil, fmt.Errorf("empty MCP response")
}
