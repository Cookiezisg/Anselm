package mcp

import (
	"encoding/json"
	"fmt"
)

// ImportEntry is one server from a Claude Desktop-style mcp.json fragment. The store is the
// encrypted mcp_servers table; mcp.json is only an interop/migration format consumed by the
// :import endpoint.
//
// ImportEntry 是 Claude Desktop 式 mcp.json 片段里的一条。存储是加密的 mcp_servers 表；mcp.json
// 只作为 :import 端点消费的互操作/迁移格式。
type ImportEntry struct {
	Command    string            `json:"command,omitempty"`
	Args       []string          `json:"args,omitempty"`
	Env        map[string]string `json:"env,omitempty"`
	URL        string            `json:"url,omitempty"` // remote servers
	TimeoutSec int               `json:"timeoutSec,omitempty"`
}

type importFile struct {
	MCPServers map[string]ImportEntry `json:"mcpServers"`
}

// ParseImport parses a Claude Desktop mcp.json fragment into name→entry. Empty/invalid → error.
//
// ParseImport 把 Claude Desktop mcp.json 片段解析成 name→entry。空/非法返错误。
func ParseImport(raw []byte) (map[string]ImportEntry, error) {
	var f importFile
	if err := json.Unmarshal(raw, &f); err != nil {
		return nil, fmt.Errorf("mcp.ParseImport: %w", err)
	}
	if len(f.MCPServers) == 0 {
		return nil, fmt.Errorf("mcp.ParseImport: no servers found (mcpServers map empty or missing)")
	}
	return f.MCPServers, nil
}
