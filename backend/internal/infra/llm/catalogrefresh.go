package llm

import (
	"context"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"time"

	"go.uber.org/zap"
)

// Runtime catalog refresh (WRK-082 P11): 30s after boot — never contending with the startup
// gate — the app pulls models.dev, trims it with the same projection the vendored snapshot uses,
// and atomically swaps the in-memory catalog. Load priority is runtime cache > vendored snapshot;
// every failure is silent-but-logged and keeps the previous catalog — the refresh path must never
// degrade startup or blank the picker.
//
// 运行时目录刷新(P11):boot 后 30s——绝不与启动门控抢时序——拉 models.dev,用与 vendored 快照
// 同一投影裁剪,原子换入内存目录。载入优先级 运行时缓存 > vendored;一切失败静默留日志、保留旧
// 目录——刷新路径绝不降级启动、绝不清空选择器。

const (
	catalogRefreshDelay = 30 * time.Second
	catalogTTL          = 24 * time.Hour
	catalogCacheFile    = "catalog.json"
	catalogFetchBudget  = 120 * time.Second
)

// catalogUpstreamURL is a var only so the fail-silent test can point it at a dead port.
// catalogUpstreamURL 用 var 仅为让 fail-silent 测试指向死端口。
var catalogUpstreamURL = "https://models.dev/api.json"

// catalogRefreshURL permits the acceptance rig to point only this background fetch at a
// controlled endpoint. It is empty by default and must never be used as a production setting.
//
// catalogRefreshURL 允许验收台架只把这条后台 fetch 指向受控端点。默认为空，生产不能依赖它。
func catalogRefreshURL() string {
	if override := strings.TrimSpace(os.Getenv("ANSELM_RIG_MODEL_CATALOG_URL")); override != "" {
		return override
	}
	return catalogUpstreamURL
}

// LoadCatalogCache applies a previously cached trim if one exists and validates; a missing or
// corrupt cache is not an error — the vendored snapshot simply stays active.
//
// LoadCatalogCache 应用既有缓存裁剪(存在且校验通过时);缓存缺失/损坏不是错误——vendored 快照
// 继续生效。
func LoadCatalogCache(dir string) error {
	data, err := os.ReadFile(filepath.Join(dir, catalogCacheFile))
	if err != nil {
		if os.IsNotExist(err) {
			return nil
		}
		return err
	}
	cat, err := ParseCatalog(data)
	if err != nil {
		return err
	}
	currentCatalog.Store(cat)
	return nil
}

// StartCatalogRefresh runs the delayed-then-daily refresh loop; the returned stop/done pair
// follows the bootstrap background-loop convention.
//
// StartCatalogRefresh 跑「延迟一次 + 每日」刷新循环;返回的 stop/done 对遵循 bootstrap 后台循环
// 惯例。
func StartCatalogRefresh(dir string, log *zap.Logger) (stop func(), done <-chan struct{}) {
	if log == nil {
		log = zap.NewNop()
	}
	ctx, cancel := context.WithCancel(context.Background())
	d := make(chan struct{})
	go func() {
		defer close(d)
		delay := time.NewTimer(catalogRefreshDelay)
		defer delay.Stop()
		select {
		case <-ctx.Done():
			return
		case <-delay.C:
		}
		refreshCatalogOnce(ctx, dir, log)
		tick := time.NewTicker(catalogTTL)
		defer tick.Stop()
		for {
			select {
			case <-ctx.Done():
				return
			case <-tick.C:
				refreshCatalogOnce(ctx, dir, log)
			}
		}
	}()
	return cancel, d
}

// refreshCatalogOnce fetches, trims, caches and swaps — unless the cache is still within TTL
// (model catalogs move on a weekly cadence; a daily check is already generous).
//
// refreshCatalogOnce 拉取、裁剪、落缓存、换入——除非缓存仍在 TTL 内(模型目录以周为节奏变化,
// 每日一查已然宽裕)。
func refreshCatalogOnce(ctx context.Context, dir string, log *zap.Logger) {
	if log == nil {
		log = zap.NewNop()
	}
	cachePath := filepath.Join(dir, catalogCacheFile)
	if st, err := os.Stat(cachePath); err == nil && time.Since(st.ModTime()) < catalogTTL {
		return
	}
	cat, data, err := fetchTrimmedCatalog(ctx)
	if err != nil {
		log.Warn("llm: model catalog refresh failed (previous catalog kept)", zap.Error(err))
		return
	}
	if err := os.MkdirAll(dir, 0o755); err != nil {
		log.Warn("llm: model catalog cache dir", zap.Error(err))
		return
	}
	// Atomic tmp+rename so a crash mid-write never leaves a torn cache for the next boot's load.
	// tmp+rename 原子写,写一半崩溃也不会给下次 boot 留半截缓存。
	tmp := cachePath + ".tmp"
	if err := os.WriteFile(tmp, data, 0o644); err != nil {
		log.Warn("llm: model catalog cache write", zap.Error(err))
		return
	}
	if err := os.Rename(tmp, cachePath); err != nil {
		log.Warn("llm: model catalog cache rename", zap.Error(err))
		return
	}
	currentCatalog.Store(cat)
	var count int
	for _, p := range cat.Providers {
		count += len(p.Models)
	}
	log.Info("llm: model catalog refreshed from models.dev",
		zap.Int("providers", len(cat.Providers)), zap.Int("models", count))
}

func fetchTrimmedCatalog(ctx context.Context) (*ModelCatalog, []byte, error) {
	fctx, cancel := context.WithTimeout(ctx, catalogFetchBudget)
	defer cancel()
	req, err := http.NewRequestWithContext(fctx, http.MethodGet, catalogRefreshURL(), nil)
	if err != nil {
		return nil, nil, err
	}
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return nil, nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return nil, nil, fmt.Errorf("models.dev: HTTP %d", resp.StatusCode)
	}
	raw, err := io.ReadAll(io.LimitReader(resp.Body, 64<<20))
	if err != nil {
		return nil, nil, err
	}
	cat, err := TrimUpstreamCatalog(raw)
	if err != nil {
		return nil, nil, err
	}
	data, err := marshalCatalog(cat)
	if err != nil {
		return nil, nil, err
	}
	return cat, data, nil
}
