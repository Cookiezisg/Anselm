// polling.go — Service.Start, Stop, pollLoop, tryRefresh, Refresh,
// fingerprint helper, and the source-failure isolation policy. The
// runtime heart of the catalog: cold-start cache load → polling
// goroutine → fingerprint short-circuit → Generator (or mechanical
// fallback on Generator absence/failure) → atomic cache swap.
//
// polling.go ——Service.Start / Stop / pollLoop / tryRefresh / Refresh +
// fingerprint helper + source 失败隔离策略。catalog 运行时心脏：cold-
// start 加载 cache → polling goroutine → fingerprint 短路 → Generator
// （nil/失败 → mechanical fallback）→ 原子 swap cache。
package catalog

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"sort"
	"time"

	"go.uber.org/zap"

	catalogdomain "github.com/sunweilin/forgify/backend/internal/domain/catalog"
	reqctxpkg "github.com/sunweilin/forgify/backend/internal/pkg/reqctx"
)

// Start loads ~/.forgify/.catalog.json (cold-start optimization — chat
// runner gets a usable cache instantly even before the first tick) and
// launches the polling goroutine. Blocks only briefly for the disk
// load; polling runs in the background until ctx cancels.
//
// Per catalog.md §6 / §3:
//   - parse fail → move to .bak + start with empty cache (don't crash)
//   - missing file → benign (first launch)
//   - polling tick = pollInterval (default 1s)
//   - first tick fires immediately after Start (don't wait full second)
//
// Start 加载 ~/.forgify/.catalog.json（cold-start 优化——chat runner 在第
// 一 tick 前即得可用 cache）+ 启 polling goroutine。disk 加载短暂阻塞；
// polling 后台跑直到 ctx cancel。
//
// catalog.md §6 / §3：parse fail → .bak + 空启动；缺文件 → 良性（首次启
// 动）；tick = pollInterval（默认 1s）；首 tick 立即跑，不等满 1s。
func (s *Service) Start(ctx context.Context) error {
	cached, err := loadFromDisk(s.cachePath)
	switch {
	case err == nil && cached != nil:
		s.cache.Store(cached)
		s.lastFP.Store(cached.Fingerprint)
		s.versionMu.Lock()
		s.version = cached.Version
		s.versionMu.Unlock()
		s.log.Info("catalog cache loaded from disk",
			zap.String("path", s.cachePath),
			zap.Int("version", cached.Version),
			zap.String("fingerprint", cached.Fingerprint))
	case err != nil:
		s.log.Warn("catalog cache load failed; starting with empty cache",
			zap.String("path", s.cachePath), zap.Error(err))
		// loadFromDisk has already moved corrupted file to .bak.
		// loadFromDisk 已把损坏文件移 .bak。
		s.lastFP.Store("")
	default:
		// File doesn't exist — first launch. Empty cache is correct.
		// 文件不存在——首次启动。空 cache 正确。
		s.lastFP.Store("")
	}

	// Wrap caller's ctx so Stop() can cancel even when caller passed
	// context.Background. pollDone closes when the goroutine fully
	// exits — Stop() blocks on it.
	//
	// 包装调用方 ctx 让 Stop() 在 caller 传 context.Background 时也能
	// cancel。pollDone 在 goroutine 完全退后关闭——Stop() 阻塞其上。
	pollCtx, pollCancel := context.WithCancel(ctx)
	s.stopCancel = pollCancel
	s.pollDone = make(chan struct{})
	go func() {
		defer close(s.pollDone)
		s.pollLoop(pollCtx)
	}()
	return nil
}

// Stop signals the polling goroutine to exit and blocks until it has
// fully drained (no in-flight tick still writing disk). Idempotent —
// safe to call multiple times. Test harnesses must call Stop in a
// t.Cleanup so the tempdir RemoveAll doesn't race with a final
// Refresh's saveToDisk.
//
// Stop 给 polling goroutine 发退出信号 + 阻塞到完全 drain（无在飞 tick
// 还在写 disk）。幂等——多次调用安全。测试 harness 必须在 t.Cleanup
// 调 Stop，让 tempdir RemoveAll 不与最后一次 Refresh 的 saveToDisk 竞态。
func (s *Service) Stop() {
	s.stopOnce.Do(func() {
		if s.stopCancel != nil {
			s.stopCancel()
		}
		if s.pollDone != nil {
			<-s.pollDone
		}
	})
}

// pollLoop runs Service.tryRefresh every pollInterval until ctx.Done.
// Fires once immediately at startup so cold-start doesn't wait a full
// pollInterval before producing the first catalog.
//
// pollLoop 每 pollInterval 跑一次 tryRefresh 直到 ctx.Done。启动时立即
// 跑一次让 cold-start 无需等满 pollInterval 才出第一份 catalog。
func (s *Service) pollLoop(ctx context.Context) {
	s.tryRefresh(ctx)

	ticker := time.NewTicker(s.pollInterval)
	defer ticker.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			s.tryRefresh(ctx)
		}
	}
}

// tryRefresh wraps Refresh with the single-flight busy guard. If a
// prior tick is still running (>1s LLM call) the next tick simply
// skips — no queueing, no concurrent regen.
//
// tryRefresh 用 single-flight busy guard 包 Refresh。上次 tick 还在跑
// （>1s LLM 调用）时下一 tick 直接跳——不排队、不并发 regen。
func (s *Service) tryRefresh(ctx context.Context) {
	if !s.busy.CompareAndSwap(false, true) {
		return
	}
	defer s.busy.Store(false)

	if err := s.Refresh(ctx); err != nil {
		s.log.Warn("catalog refresh skipped/failed; keeping previous cache",
			zap.Error(err))
	}
}

// Refresh is the regen entry point. Used by both the polling loop and
// the HTTP POST /catalog:refresh handler. Per catalog.md §6:
//
//  1. Snapshot sources, walk each ListItems (failed sources substituted
//     with empty list, others continue)
//  2. If ALL sources failed → return without touching cache (preserves
//     previous good catalog)
//  3. Compute fingerprint, short-circuit if unchanged (~99% of ticks)
//  4. Call Generator (LLM); on nil generator OR error → mechanical
//     fallback
//  5. Stamp Fingerprint / GeneratedAt / Version / SourcesAt and atomic-
//     swap cache; persist to disk
//  6. lastFP ALWAYS updates regardless of llm-vs-mechanical — user-
//     activity-driven retry per §3 (user changes a source description
//     → fp changes → next tick gets a fresh LLM attempt)
//
// Refresh 是 regen 入口。polling loop 与 HTTP POST /catalog:refresh
// handler 都用。catalog.md §6：(1) 快照 sources 走 ListItems（失败用空替，
// 其他续）(2) 全 source 挂 → 不动 cache 返（保留上次好 catalog）(3) 算
// fingerprint，未变短路（~99% tick）(4) 调 Generator；nil 或失败 → 机械
// fallback (5) 戳 Fingerprint / GeneratedAt / Version / SourcesAt + 原子
// swap cache + 持久化 disk (6) lastFP 总更新无论 llm 还是 mechanical
// ——用户活动驱动重试 §3。
func (s *Service) Refresh(ctx context.Context) error {
	// Catalog runs in a background goroutine so the ctx never has the
	// HTTP middleware-stamped user ID. Single-user app: inject the
	// local user ID once here so every downstream call (source
	// ListItems → repo queries; LLM Generator → llmclient.Resolve →
	// model picker) sees a usable identity. Bypass when the caller
	// already set one (HTTP :refresh path comes through middleware).
	//
	// catalog 在后台 goroutine 跑，ctx 永无 HTTP middleware 注的 user
	// ID。单人 app：本处一次性注入本地 user ID 让所有下游调用（source
	// ListItems → repo 查询；LLM Generator → llmclient.Resolve → 模型
	// picker）见到可用身份。调用方已设时跳过（HTTP :refresh 路径走
	// middleware）。
	if _, ok := reqctxpkg.GetUserID(ctx); !ok {
		ctx = reqctxpkg.SetUserID(ctx, reqctxpkg.DefaultLocalUserID)
	}

	sources := s.snapshotSources()
	if len(sources) == 0 {
		return nil
	}

	items := []catalogdomain.Item{}
	sourcesAt := map[string]time.Time{}
	gMap := map[string]catalogdomain.Granularity{}
	failedCount := 0

	for _, src := range sources {
		srcItems, err := src.ListItems(ctx)
		if err != nil {
			s.log.Warn("catalog source ListItems failed; substituting empty",
				zap.String("source", src.Name()), zap.Error(err))
			failedCount++
			continue
		}
		items = append(items, srcItems...)
		sourcesAt[src.Name()] = time.Now().UTC()
		gMap[src.Name()] = src.Granularity()
	}

	// All sources failed → keep the previous cache. Per §3 design:
	// don't overwrite a good catalog with an empty one just because a
	// transient hiccup hit every source at once.
	// 全 source 挂 → 保留上次 cache。§3：不让瞬时全挂用空 catalog 覆盖
	// 之前好的。
	if failedCount == len(sources) {
		return fmt.Errorf("catalog: all %d sources failed; keeping previous cache", len(sources))
	}

	fp := fingerprint(items)
	if last, _ := s.lastFP.Load().(string); last == fp {
		// ~99% of ticks land here.
		// ~99% tick 走这里。
		return nil
	}

	var cat *catalogdomain.Catalog
	if s.generator != nil {
		var err error
		cat, err = s.generator.Generate(ctx, items, gMap)
		if err != nil {
			s.log.Warn("catalog Generator failed; using mechanical fallback",
				zap.Error(err))
			cat = mechanicalFallback(items, gMap)
		}
	} else {
		// No generator wired — D8-2 default; D8-3 plugs the LLM
		// generator. Still produces a valid catalog so chat.runner gets
		// per-source enumeration in the system prompt.
		// 未接 generator——D8-2 默认；D8-3 接 LLM generator。仍出有效
		// catalog 让 chat.runner 在 system prompt 拿到 per-source 枚举。
		cat = mechanicalFallback(items, gMap)
	}

	cat.Fingerprint = fp
	cat.GeneratedAt = time.Now().UTC()
	cat.Version = s.nextVersion()
	cat.SourcesAt = sourcesAt

	s.cache.Store(cat)
	s.lastFP.Store(fp)
	if err := saveToDisk(s.cachePath, cat); err != nil {
		s.log.Warn("catalog write to disk failed; in-memory cache still updated",
			zap.String("path", s.cachePath), zap.Error(err))
	}
	return nil
}

// fingerprint hashes the (source + name + description) triplet for
// every item, sorted for determinism. Per catalog.md §6: only fields
// that affect the Summary text are hashed — user changes to forge code,
// tags, etc. don't trigger a regen, only name/description changes do.
//
// fingerprint 哈希每个 item 的 (source + name + description) 三元组，
// 排序求确定性。§6：仅影响 Summary 文本的字段进哈希——用户改 forge code
// / tags 等不触发 regen，只 name/description 改触发。
func fingerprint(items []catalogdomain.Item) string {
	sorted := make([]catalogdomain.Item, len(items))
	copy(sorted, items)
	sort.Slice(sorted, func(i, j int) bool {
		if sorted[i].Source != sorted[j].Source {
			return sorted[i].Source < sorted[j].Source
		}
		return sorted[i].Name < sorted[j].Name
	})
	h := sha256.New()
	for _, it := range sorted {
		h.Write([]byte(it.Source))
		h.Write([]byte{0})
		h.Write([]byte(it.Name))
		h.Write([]byte{0})
		h.Write([]byte(it.Description))
		h.Write([]byte{0})
	}
	return hex.EncodeToString(h.Sum(nil))
}
