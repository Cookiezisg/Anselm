// Package mcp (infra/mcp) is the infrastructure layer for the MCP
// integration. This file is the ~/.forgify/mcp.json reader/writer +
// drag-import merge — Claude Desktop-compatible schema (mcp.md §5)
// so users can paste their existing config and have it work.
//
// V1 split: D5 = config I/O (this file). D6 = stdio Client wrapping
// modelcontextprotocol/go-sdk for the actual subprocess management.
//
// Self-contained boundary (mcp.md §5 自包含原则): we read ONLY
// ~/.forgify/mcp.json, never Claude Desktop / Cursor / VSCode app
// directories. Migration is an explicit user action (drag-import or
// manual cp) — once imported, Forgify owns the copy.
//
// Package mcp（infra/mcp）是 MCP 集成的基础设施层。本文件是 ~/.forgify/
// mcp.json 读写 + 拖拽导入 merge——Claude Desktop 兼容 schema（mcp.md §5）
// 让用户直接粘贴现有配置就能用。
//
// V1 拆分：D5 = config I/O（本文件）；D6 = stdio Client wrap
// modelcontextprotocol/go-sdk 管子进程。
//
// 自包含边界（mcp.md §5）：只读 ~/.forgify/mcp.json，不读 Claude Desktop /
// Cursor / VSCode 等 app 目录。迁移是显式用户动作（拖拽或手 cp）——导入后
// Forgify 拥有副本。
package mcp

import (
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"sort"

	mcpdomain "github.com/sunweilin/forgify/backend/internal/domain/mcp"
)

// configFileMode is the umask for ~/.forgify/mcp.json. 0600 because env
// values often contain credentials (GitHub PAT, etc.); world-readable
// would leak secrets to other accounts on shared boxes.
//
// configFileMode 是 ~/.forgify/mcp.json 的权限。0600——env 值常含凭证
// （GitHub PAT 等），world-readable 会在共享机泄漏 secret。
const configFileMode os.FileMode = 0o600

// ErrConfigCorrupt wraps the underlying JSON parse error so callers can
// errors.Is to it. mcp.md §5.7 末段 says Service.Start must not panic
// on corrupt mcp.json — log + continue with no servers loaded so the
// user can fix the file.
//
// ErrConfigCorrupt 包装底层 JSON 解析错误供 errors.Is。mcp.md §5.7 末段：
// Service.Start 在 mcp.json 损坏时不能 panic——log + 当作空配置继续，
// 让用户有机会自己修。
var ErrConfigCorrupt = errors.New("mcp.json: corrupt JSON")

// fileSchema is the on-disk shape: a single "mcpServers" object keyed
// by server name. Field name kept verbatim from Claude Desktop so a
// user's existing config drops in unchanged.
//
// fileSchema 是磁盘形状：单个 "mcpServers" 对象按 server 名为 key。字段名
// 与 Claude Desktop 一致，用户现有配置原样可用。
type fileSchema struct {
	MCPServers map[string]serverEntry `json:"mcpServers"`
}

// serverEntry is the per-server JSON shape on disk. Mirrors
// mcpdomain.ServerConfig but without the redundant Name field — Name
// is the map key in mcpServers, not duplicated in each entry.
//
// serverEntry 是磁盘上 per-server JSON 形状。镜像 mcpdomain.ServerConfig
// 但无冗余 Name——Name 是 mcpServers map 的 key，不在条目内重复。
type serverEntry struct {
	Command    string            `json:"command"`
	Args       []string          `json:"args,omitempty"`
	Env        map[string]string `json:"env,omitempty"`
	TimeoutSec int               `json:"timeoutSec,omitempty"`
}

// Load reads path and returns the parsed configs keyed by server name.
// File-not-found returns (empty map, nil) so first-boot doesn't fail —
// users start with no MCP servers configured. Any other read or JSON
// parse failure wraps ErrConfigCorrupt so the caller can warn-and-
// continue per mcp.md §5.7.
//
// Load 读 path 返按 server 名 key 的 configs。文件不存在返 (空 map, nil)
// 让首次启动不挂——用户从无 MCP server 起步。其他读/解析错走 ErrConfigCorrupt
// 包装让调用方按 mcp.md §5.7 warn-and-continue。
func Load(path string) (map[string]mcpdomain.ServerConfig, error) {
	raw, err := os.ReadFile(path)
	if err != nil {
		if errors.Is(err, os.ErrNotExist) {
			return map[string]mcpdomain.ServerConfig{}, nil
		}
		return nil, fmt.Errorf("mcp.config.Load: read %s: %w", path, err)
	}
	if len(raw) == 0 {
		// Empty file is treated as no-servers (same as missing) — Claude
		// Desktop also tolerates this state.
		// 空文件等同于无 servers（同 Claude Desktop 行为）。
		return map[string]mcpdomain.ServerConfig{}, nil
	}
	var fs fileSchema
	if err := json.Unmarshal(raw, &fs); err != nil {
		return nil, fmt.Errorf("mcp.config.Load: %w: %v", ErrConfigCorrupt, err)
	}
	out := make(map[string]mcpdomain.ServerConfig, len(fs.MCPServers))
	for name, entry := range fs.MCPServers {
		out[name] = mcpdomain.ServerConfig{
			Name:       name,
			Command:    entry.Command,
			Args:       entry.Args,
			Env:        entry.Env,
			TimeoutSec: entry.TimeoutSec,
		}
	}
	return out, nil
}

// Save writes configs to path atomically (tmp + rename), with mode 0600
// so the env credentials inside aren't world-readable. Writes are
// pretty-printed (2-space indent) + sorted by server name so diffs in
// version control / hand-editing are stable across saves. Always creates
// the parent directory if missing.
//
// Save 原子写 configs 到 path（tmp + rename），mode 0600 防 env 凭证
// world-readable。pretty-print（2 空格）+ 按 server 名排序，让版本控制
// 与手编辑的 diff 跨次保存稳定。父目录缺则自动建。
func Save(path string, configs map[string]mcpdomain.ServerConfig) error {
	dir := filepath.Dir(path)
	if err := os.MkdirAll(dir, 0o755); err != nil {
		return fmt.Errorf("mcp.config.Save: mkdir %s: %w", dir, err)
	}

	// Build the file shape with sorted keys for stable output.
	// Go's json.Marshal of a map already sorts keys alphabetically since
	// 1.12, but we go through a slice-then-map round-trip explicitly so
	// the contract is obvious + survives any future encoder change.
	//
	// 用排序 key 构建文件形状以保证输出稳定。Go 1.12+ json.Marshal map 已
	// 自动按 key 排序，但显式 slice→map 让契约明显 + 抗未来编码器变更。
	names := make([]string, 0, len(configs))
	for n := range configs {
		names = append(names, n)
	}
	sort.Strings(names)

	servers := make(map[string]serverEntry, len(configs))
	for _, n := range names {
		c := configs[n]
		servers[n] = serverEntry{
			Command:    c.Command,
			Args:       c.Args,
			Env:        c.Env,
			TimeoutSec: c.TimeoutSec,
		}
	}

	body, err := json.MarshalIndent(fileSchema{MCPServers: servers}, "", "  ")
	if err != nil {
		return fmt.Errorf("mcp.config.Save: marshal: %w", err)
	}
	body = append(body, '\n') // POSIX-friendly trailing newline

	tmp := path + ".tmp"
	if err := os.WriteFile(tmp, body, configFileMode); err != nil {
		return fmt.Errorf("mcp.config.Save: write tmp: %w", err)
	}
	if err := os.Rename(tmp, path); err != nil {
		_ = os.Remove(tmp)
		return fmt.Errorf("mcp.config.Save: rename %s → %s: %w", tmp, path, err)
	}
	return nil
}

// MergeResult reports the outcome of a drag-import merge. Imported lists
// the names successfully added (or replaced when overwrite=true);
// Conflicts lists the names that already existed and were SKIPPED
// because overwrite=false. Frontend uses Conflicts to surface a "These
// already exist — confirm overwrite?" prompt.
//
// MergeResult 是拖拽导入 merge 的结果。Imported 是成功加入（overwrite
// =true 时含替换）的名单；Conflicts 是已存在因 overwrite=false 跳过的
// 名单。前端用 Conflicts 弹"已存在——确认覆盖？"提示。
type MergeResult struct {
	Imported  []string `json:"imported"`
	Conflicts []string `json:"conflicts"`
}

// Merge folds incoming server configs into existing. By default an
// existing entry is left alone and recorded in Conflicts; pass
// overwrite=true to force-replace. Mutates and returns existing for
// caller convenience (typical use: result := Merge(load(), incoming, false)
// then save(result)). Imported / Conflicts are sorted alphabetically.
//
// Merge 把 incoming server 配置叠到 existing。默认已存在保留并记 Conflicts；
// overwrite=true 强制替换。原地改 + 返 existing 让调用方便用。Imported /
// Conflicts 按字母序排序。
func Merge(existing, incoming map[string]mcpdomain.ServerConfig, overwrite bool) (map[string]mcpdomain.ServerConfig, MergeResult) {
	if existing == nil {
		existing = make(map[string]mcpdomain.ServerConfig, len(incoming))
	}
	res := MergeResult{
		Imported:  make([]string, 0, len(incoming)),
		Conflicts: make([]string, 0),
	}
	for name, cfg := range incoming {
		// Stamp Name field so the output map's value carries the canonical
		// Name (callers may have left cfg.Name empty when constructing
		// from raw JSON via the file schema).
		// 标 Name 字段让 output map 值含规范 Name（调用方可能从 file schema
		// 构造时把 cfg.Name 留空）。
		cfg.Name = name
		if _, exists := existing[name]; exists && !overwrite {
			res.Conflicts = append(res.Conflicts, name)
			continue
		}
		existing[name] = cfg
		res.Imported = append(res.Imported, name)
	}
	sort.Strings(res.Imported)
	sort.Strings(res.Conflicts)
	return existing, res
}
