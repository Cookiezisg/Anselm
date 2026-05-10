// source.go — CatalogSource port and the Granularity enum that tells
// the Generator how aggressively it may merge a source's items in the
// summary text.
//
// source.go ——CatalogSource port 与 Granularity 枚举（告诉 Generator 在
// summary 文本里能合并多激进）。
package catalog

import "context"

// Granularity tells the Generator how aggressively it may merge a
// source's items when writing the Summary. PerItem allows free
// grouping ("5 CSV-processing forges"); PerServer requires one mention
// per server (MCP — different servers expose different tools so merging
// loses information).
//
// Granularity 告诉 Generator 写 Summary 时合并 source items 多激进。PerItem
// 允许自由分组（"5 个 CSV 处理 forge"）；PerServer 要求 per-server 一条
// （MCP——不同 server 暴露不同工具，合并丢信息）。
type Granularity int

const (
	// PerItem — generator may freely group / merge items into one
	// description (forge / skill).
	//
	// PerItem——generator 可自由分组 / 合并 item 为一个 description
	// （forge / skill）。
	PerItem Granularity = iota

	// PerServer — one mention per server, no merging across servers
	// (mcp). Different servers expose unrelated capability sets.
	//
	// PerServer——per-server 一条，不跨 server 合（mcp）。不同 server
	// 暴露无关能力集。
	PerServer
)

// String renders the enum for log lines and the Generator prompt
// (gives the LLM a stable label rather than an integer).
//
// String 渲染枚举给日志 + Generator prompt（给 LLM 稳定标签而非整数）。
func (g Granularity) String() string {
	switch g {
	case PerItem:
		return "PerItem"
	case PerServer:
		return "PerServer"
	default:
		return "Unknown"
	}
}

// Item is one entry in a source's ListItems return. Source + ID together
// must uniquely identify the item across the whole catalog (the Generator
// uses this combination to validate coverage). Description is what the
// LLM reads to write the summary line; Category is an optional grouping
// hint the Generator may use.
//
// Item 是 source 的 ListItems 返回的一条。Source + ID 组合在整 catalog 内
// 必须唯一（Generator 用此校验 coverage）。Description 是 LLM 读着写
// summary 行的；Category 可选分组 hint 给 Generator 用。
type Item struct {
	Source      string `json:"source"`
	ID          string `json:"id"`
	Name        string `json:"name"`
	Description string `json:"description"`
	Category    string `json:"category,omitempty"`
}

// CatalogSource is what every capability provider implements to be
// included in the catalog. Defined in the catalog domain so app/catalog
// has no knowledge of concrete sources (forge / skill / mcp implement
// it in their own packages and expose via svc.AsCatalogSource()).
//
// V1 contract: ListItems must return current truth — partially-loaded
// state (an MCP server still mid-connect) should NOT appear. Catalog
// will pick it up on the next 1s tick once the source surfaces it.
//
// CatalogSource 是所有能力提供方为参与 catalog 而实现的接口。定义在
// catalog domain 让 app/catalog 不知道任何具体 source（forge / skill /
// mcp 在自己包内实现 + svc.AsCatalogSource() 暴露）。V1 契约：ListItems
// 必须返当前真实状态——加载中（如 MCP 正在 connect）不该出现。catalog
// 在下次 1s tick source 暴露后自然 pickup。
type CatalogSource interface {
	// Name is the stable identifier (used in logs, fingerprints,
	// Generator prompt routing).
	//
	// Name 稳定标识（日志、fingerprint、Generator 路由 prompt 用）。
	Name() string

	// Granularity tells the Generator the merging policy for this
	// source's items.
	//
	// Granularity 告诉 Generator 本 source items 的合并策略。
	Granularity() Granularity

	// ListItems returns the source's current full item set. Called
	// every poll tick (1s). Errors here cause the source to be
	// substituted with an empty list for this tick (failed-source
	// isolation per catalog.md §3); other sources continue.
	//
	// ListItems 返 source 当前全 item 集。每 poll tick (1s) 调一次。
	// 出错时本 tick 该 source 被空列表替（失败隔离 §3）；其他 source
	// 不受影响。
	ListItems(ctx context.Context) ([]Item, error)
}
