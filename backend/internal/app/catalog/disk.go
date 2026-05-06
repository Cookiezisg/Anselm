// disk.go — atomic ~/.forgify/.catalog.json reader/writer. Mirrors the
// pattern used by infra/mcp/config.go for mcp.json: atomic write
// (.tmp + rename) so concurrent reads never see a half-written file,
// 0644 perms (catalog has no secrets so we don't need 0600 like mcp).
//
// Corruption policy: parse failure on Load moves the bad file to .bak
// and returns the parse error wrapped — the Service treats this same
// as "file missing" + logs the back-up path so the user can inspect.
//
// disk.go ——~/.forgify/.catalog.json 原子读写。模式同 infra/mcp/config.go
// 的 mcp.json：atomic 写（.tmp + rename）让并发读永不见半截；0644 权限
// （catalog 无 secret，不需 mcp 的 0600）。
//
// 损坏策略：Load 解析失败把坏文件移 .bak，返 wrap 后的解析错——Service
// 视为"文件缺"+ log .bak 路径让用户检查。
package catalog

import (
	"encoding/json"
	"errors"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"

	catalogdomain "github.com/sunweilin/forgify/backend/internal/domain/catalog"
)

// loadFromDisk reads + parses the catalog cache. Returns:
//   - (*Catalog, nil) on success
//   - (nil, nil)      when file doesn't exist (first launch)
//   - (nil, err)      when file exists but corrupted (already moved
//                     to .bak by this function — Service.Start logs
//                     the error and starts with empty cache)
//
// loadFromDisk 读+解 catalog cache。返：成功 (*Catalog, nil)；文件不存
// 在 (nil, nil)；存在但损坏 (nil, err)（本函数已移到 .bak，Service.Start
// log 错+空 cache 启动）。
func loadFromDisk(path string) (*catalogdomain.Catalog, error) {
	raw, err := os.ReadFile(path)
	if err != nil {
		if errors.Is(err, fs.ErrNotExist) {
			return nil, nil
		}
		return nil, fmt.Errorf("catalog: read %s: %w", path, err)
	}
	var cat catalogdomain.Catalog
	if err := json.Unmarshal(raw, &cat); err != nil {
		// Move corrupted file aside so the user can inspect later;
		// return the parse error so Service.Start logs it. Best-effort
		// rename — if the move itself fails (perms) we still return
		// the parse error so the caller doesn't accidentally trust the
		// bad file.
		// 把坏文件挪到旁边让用户事后查；返解析错给 Service.Start log。
		// 移动 best-effort——失败（权限）也返解析错防调用方误信坏文件。
		bak := path + ".bak"
		_ = os.Rename(path, bak)
		return nil, fmt.Errorf("catalog: parse %s (moved to %s): %w", path, bak, err)
	}
	return &cat, nil
}

// saveToDisk writes the catalog atomically (.tmp + rename). Creates
// the parent directory if missing. 0644 perms — catalog content is not
// sensitive (no API keys, no user secrets); the strict 0600 mcp.json
// uses isn't warranted here.
//
// saveToDisk 原子写 catalog（.tmp + rename）。父目录缺则建。0644 权限
// ——catalog 内容非敏感（无 API key / 用户 secret），mcp.json 用的严格
// 0600 此处无需。
func saveToDisk(path string, cat *catalogdomain.Catalog) error {
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return fmt.Errorf("catalog: mkdir %s: %w", filepath.Dir(path), err)
	}
	raw, err := json.MarshalIndent(cat, "", "  ")
	if err != nil {
		return fmt.Errorf("catalog: marshal: %w", err)
	}
	tmp := path + ".tmp"
	if err := os.WriteFile(tmp, raw, 0o644); err != nil {
		return fmt.Errorf("catalog: write tmp: %w", err)
	}
	if err := os.Rename(tmp, path); err != nil {
		_ = os.Remove(tmp)
		return fmt.Errorf("catalog: rename: %w", err)
	}
	return nil
}
